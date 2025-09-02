extends Node3D
class_name DirectionSelector

# --- References ---
@export var follow_target: Node3D            # anchor (player/hand). If null, uses self.
@export var fishing_camera: Camera3D         # used to copy yaw for the screen-facing plane
@export var camera_controller: Node = null   # optional; must implement orbit_apply_delta_immediate(deg)

@export var dots: Array[Node3D] = []         # optional: for batch visibility

# --- Tuning ---
@export var local_offset: Vector3 = Vector3(-0.2, 0.0, -0.015)

@export var max_local_deg: float = 30.0      # visual DS yaw range (±30°) before streaming
@export var max_total_deg: float = 90.0      # absolute cap from center (±90° total)
@export var edge_hold_time: float = 0.12     # short pause at ±30° before streaming

@export var yaw_speed_deg: float = 180.0     # speed for the first 30° (visual-only)
@export var stream_speed_deg: float = 90.0   # camera streaming speed once at edge

@export var enable_input: bool = true
@export var action_left: StringName = &"ds_left"
@export var action_right: StringName = &"ds_right"

# --- Internals ---
var _screen: Node3D = null        # DS_ScreenFacing
var _aim: Node3D = null           # DS_Aim
var _active: bool = false
var _local_yaw_deg: float = 0.0

var _edge_hold_t: float = 0.0
var _streaming: bool = false
var _last_input_sign: int = 0

# how many degrees of camera rotation we have streamed from center (right=+, left=-)
var _streamed_from_center_deg: float = 0.0
var _max_stream_deg: float = 60.0  # computed from max_total_deg - max_local_deg

func _ready() -> void:
	_screen = get_node_or_null("DS_ScreenFacing") as Node3D
	_aim = get_node_or_null("DS_ScreenFacing/DS_Aim") as Node3D

	if _screen == null or _aim == null:
		push_error("DirectionSelector: expected children 'DS_ScreenFacing/DS_Aim'.")
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
	_active = true
	_local_yaw_deg = 0.0
	_edge_hold_t = 0.0
	_streaming = false
	_last_input_sign = 0
	_streamed_from_center_deg = 0.0

	_set_all_dots_visible(true)
	visible = true
	set_process(true)
	_update_pose()
	_apply_local_yaw()

func hide_for_fishing() -> void:
	_active = false
	_set_all_dots_visible(false)
	visible = false
	set_process(false)

func _process(delta: float) -> void:
	if not _active:
		return

	_update_pose()

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
		# released: stop streaming, reset hold
		_edge_hold_t = 0.0
		_streaming = false
		_last_input_sign = 0
	else:
		# if direction flipped while streaming, require a new hold at the other edge
		if _streaming and input_sign != _last_input_sign:
			_streaming = false
			_edge_hold_t = 0.0

		if not _streaming:
			# move visual DS toward the edge at yaw_speed
			var target: float = float(input_sign) * max_local_deg
			var step: float = yaw_speed_deg * delta * float(input_sign)
			var next_yaw: float = _local_yaw_deg + step

			# clamp toward target without overshoot
			if input_sign > 0 and next_yaw > target:
				next_yaw = target
			elif input_sign < 0 and next_yaw < target:
				next_yaw = target

			_local_yaw_deg = next_yaw

			# when at edge, accumulate hold time
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
			# total cap: ±(max_local + max_stream) == ±max_total
			var remaining: float = _max_stream_deg - absf(_streamed_from_center_deg)
			if remaining > 0.0001:
				var delta_cam: float = stream_speed_deg * delta
				if delta_cam > remaining:
					delta_cam = remaining
				if camera_controller != null and camera_controller.has_method("orbit_apply_delta_immediate"):
					camera_controller.call("orbit_apply_delta_immediate", delta_cam * float(input_sign))
					_streamed_from_center_deg += delta_cam * float(input_sign)

			# keep DS aim pinned at the edge while streaming
			_local_yaw_deg = float(_last_input_sign) * max_local_deg

	_apply_local_yaw()

# --- Pose & alignment ---
func _update_pose() -> void:
	var anchor: Node3D = follow_target
	if anchor == null:
		anchor = self

	# place DS root at anchor + local offset
	var t: Transform3D = anchor.global_transform
	var offset_ws: Vector3 = t.basis * local_offset
	global_position = anchor.global_position + offset_ws

	# screen-facing: copy camera yaw only
	if fishing_camera != null:
		var yaw: float = _extract_camera_yaw(fishing_camera)
		var e: Vector3 = _screen.rotation
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
	# compute yaw from camera forward on XZ
	var fwd: Vector3 = -(cam.global_transform.basis.z)
	var y: float = 0.0
	if absf(fwd.x) > 0.000001 or absf(fwd.z) > 0.000001:
		y = atan2(fwd.x, fwd.z)
	return y
