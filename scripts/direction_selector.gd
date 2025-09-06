extends Node3D
class_name DirectionSelector

# --- References ---
@export var follow_target: Node3D
@export var fishing_camera: Camera3D
@export var camera_controller: Node = null      # must implement orbit_apply_delta_immediate(deg)
@export var dots: Array[Node3D] = []

# --- Visual placement / orientation ---
@export var local_offset: Vector3 = Vector3(-0.2, 0.0, -0.015)
@export var base_yaw_offset_deg: float = 180.0  # spawn flipped 180° from camera yaw (your request)

# --- Movement limits / timing ---
@export var max_local_deg: float = 30.0         # DS local range before streaming
@export var max_total_deg: float = 90.0         # absolute cap from center
@export var edge_hold_time: float = 0.12        # pause at ±30 before streaming

@export var yaw_speed_deg: float = 180.0        # speed for the first 30° (visual)
@export var stream_speed_deg: float = 90.0      # camera streaming speed after hold

# --- Input actions ---
@export var enable_input: bool = true
@export var action_left: StringName = &"ds_left"
@export var action_right: StringName = &"ds_right"

# --- Dot cadence (dot_0..dot_7, hold, clear, repeat) ---
@export var dot_step_time: float = 0.10         # seconds per step
@export var dot_hold_steps: int = 6             # how many steps to hold with all dots on

@export var spawn_local_deg: float = 15.0       # the on-screen slant you want at spawn

# --- Internals ---
var _screen: Node3D = null
var _aim: Node3D = null
var _active: bool = false
var _local_yaw_deg: float = 0.0

var _edge_hold_t: float = 0.0
var _streaming: bool = false
var _last_input_sign: int = 0

# signed camera-stream offset from center, in degrees (right +, left -)
var _streamed_from_center_deg: float = 0.0
var _max_stream_deg: float = 60.0

# dots animation state
var _dot_time: float = 0.0
var _dot_index: int = -1    # -1 means all off; 0..7 progressively on
var _dot_hold_left: int = 0

func _ready() -> void:
	_screen = get_node_or_null("DS_ScreenFacing") as Node3D
	_aim = get_node_or_null("DS_ScreenFacing/DS_Aim") as Node3D
	if _screen == null or _aim == null:
		push_error("DirectionSelector: expected 'DS_ScreenFacing/DS_Aim' children.")
		set_process(false)
		return

	_max_stream_deg = max_total_deg - max_local_deg
	if _max_stream_deg < 0.0:
		_max_stream_deg = 0.0

	_set_all_dots_visible(false)
	visible = false
	set_process(false)

func show_for_fishing(origin: Node3D = null) -> void:
	if origin != null:
		follow_target = origin

	top_level = true                    # <<< ignore parent transform while active
	rotation = Vector3.ZERO            # clean slate
	scale = Vector3.ONE

	# snap screen-facing yaw now
	if fishing_camera != null:
		var yaw_cam := _extract_camera_yaw(fishing_camera)
		var e := _screen.rotation
		e.y = yaw_cam + deg_to_rad(base_yaw_offset_deg)
		e.x = 0.0
		e.z = 0.0
		_screen.rotation = e

	_active = true
	_edge_hold_t = 0.0
	_streaming = false
	_last_input_sign = 0
	_streamed_from_center_deg = 0.0

	_local_yaw_deg = spawn_local_deg   # your fixed slant (e.g., 15)

	# (dot reset as you already have)

	_set_all_dots_visible(true)
	visible = true
	set_process(true)
	_update_pose()
	_apply_local_yaw()

func hide_for_fishing() -> void:
	_active = false
	top_level = false                   # <<< restore normal parenting
	_set_all_dots_visible(false)
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if not _active:
		return

	_update_pose()
	_update_dot_anim(delta)

	if not enable_input:
		return

	var left_pressed: bool = Input.is_action_pressed(action_left)
	var right_pressed: bool = Input.is_action_pressed(action_right)

	var input_sign: int = 0
	if left_pressed and not right_pressed:
		input_sign = -1
	elif right_pressed and not left_pressed:
		input_sign = 1

	if input_sign == 0:
		_edge_hold_t = 0.0
		_streaming = false
		_last_input_sign = 0
	else:
		# If direction flipped while streaming, stop streaming and require a new hold at the new edge
		if _streaming and input_sign != _last_input_sign:
			_streaming = false
			_edge_hold_t = 0.0

		if not _streaming:
			# steer visual DS toward new edge
			var target: float = float(input_sign) * max_local_deg
			var step: float = yaw_speed_deg * delta * float(input_sign)
			var next_yaw: float = _local_yaw_deg + step

			# clamp toward target without overshoot
			if input_sign > 0 and next_yaw > target:
				next_yaw = target
			elif input_sign < 0 and next_yaw < target:
				next_yaw = target

			_local_yaw_deg = next_yaw

			# hold timer once exactly at the edge
			var at_edge: bool = absf(_local_yaw_deg) >= max_local_deg - 0.001
			if at_edge:
				_edge_hold_t += delta
				if _edge_hold_t >= edge_hold_time:
					_streaming = true
					_last_input_sign = input_sign
					_edge_hold_t = 0.0
			else:
				_edge_hold_t = 0.0

		if _streaming:
			# compute remaining capacity toward the pressed direction (signed)
			var target_stream: float = float(_last_input_sign) * _max_stream_deg
			var signed_remaining: float = target_stream - _streamed_from_center_deg
			var mag_remaining: float = absf(signed_remaining)

			if mag_remaining > 0.0001:
				var step_deg: float = stream_speed_deg * delta
				if step_deg > mag_remaining:
					step_deg = mag_remaining
				var signed_step: float = step_deg
				if signed_remaining < 0.0:
					signed_step = -step_deg

				# apply to camera
				if camera_controller != null and camera_controller.has_method("orbit_apply_delta_immediate"):
					camera_controller.call("orbit_apply_delta_immediate", signed_step)

				_streamed_from_center_deg += signed_step

			# keep visual DS pinned at ±30 while streaming
			_local_yaw_deg = float(_last_input_sign) * max_local_deg

	_apply_local_yaw()

# --- Pose & alignment ---
func _update_pose() -> void:
	var anchor: Node3D = follow_target
	if anchor == null:
		anchor = self

	# anchor position
	var p := anchor.global_position

	# offset in SCREEN space (yaw from camera), not player space
	if fishing_camera != null:
		var yaw_cam := _extract_camera_yaw(fishing_camera)
		var yaw := yaw_cam + deg_to_rad(base_yaw_offset_deg)

		var screen_basis := Basis(Vector3.UP, yaw)   # yaw-only, level
		var offset_ws := screen_basis * local_offset

		# write a full global transform with identity basis -> no inherited rotation
		global_transform = Transform3D(Basis.IDENTITY, p + offset_ws)

		# keep the view-aligned child yawed to the camera
		var e := _screen.rotation
		e.y = yaw
		e.x = 0.0
		e.z = 0.0
		_screen.rotation = e


func _apply_local_yaw() -> void:
	if _aim == null:
		return
	var e: Vector3 = _aim.rotation
	e.y = deg_to_rad(_local_yaw_deg)
	_aim.rotation = e

# --- Dots cadence ---
func _update_dot_anim(delta: float) -> void:
	_dot_time += delta
	if _dot_hold_left > 0:
		# holding with all dots visible
		if _dot_time >= dot_step_time:
			_dot_time = 0.0
			_dot_hold_left -= 1
			if _dot_hold_left <= 0:
				# clear and restart
				_dot_index = -1
				_apply_dot_frame()
		return

	if _dot_time >= dot_step_time:
		_dot_time = 0.0
		if _dot_index < 7:
			_dot_index += 1
			_apply_dot_frame()
		else:
			# reached dot_7: hold a few steps with all on
			_dot_hold_left = dot_hold_steps

func _apply_dot_frame() -> void:
	var n: int = dots.size()
	var i: int = 0
	while i < n:
		var d: Node3D = dots[i]
		if d != null:
			if _dot_index < 0:
				d.visible = false
			elif i <= _dot_index:
				d.visible = true
			else:
				d.visible = false
		i += 1

# --- Helpers ---
func _set_all_dots_visible(v: bool) -> void:
	var n: int = dots.size()
	var i: int = 0
	while i < n:
		var d: Node3D = dots[i]
		if d != null:
			d.visible = v
		i += 1

func _extract_camera_yaw(cam: Camera3D) -> float:
	var fwd: Vector3 = -(cam.global_transform.basis.z)
	var y: float = 0.0
	if absf(fwd.x) > 0.000001 or absf(fwd.z) > 0.000001:
		y = atan2(fwd.x, fwd.z)
	return y

# --- Public: world-space cast forward (XZ) – derived from the visible dots ---
func get_cast_forward() -> Vector3:
	# Use the first and last dot to infer the exact forward you see on screen
	var n := dots.size()
	if n >= 2:
		var tail := dots[0] as Node3D         # near the player
		var head := dots[n - 1] as Node3D     # farthest dot
		if tail != null and head != null:
			var v := head.global_position - tail.global_position
			v.y = 0.0
			var m := v.length()
			if m > 0.0001:
				return v / m

	# Fallback (unlikely needed): camera yaw + DS offsets
	var yaw_cam: float = _extract_camera_yaw(fishing_camera)
	var total_deg: float = base_yaw_offset_deg + _local_yaw_deg + _streamed_from_center_deg
	var yaw: float = yaw_cam + deg_to_rad(total_deg)
	return Vector3(sin(yaw), 0.0, cos(yaw)).normalized()


func get_cast_yaw_deg() -> float:
	var yaw_cam: float = _extract_camera_yaw(fishing_camera)
	return rad_to_deg(yaw_cam) + base_yaw_offset_deg + _local_yaw_deg + _streamed_from_center_deg
