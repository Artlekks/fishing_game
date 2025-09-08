extends Node3D
class_name DirectionSelector

@export var follow_target: Node3D
@export var fishing_camera: Camera3D
@export var camera_controller: Node = null
@export var dots: Array[Node3D] = []

@export var local_offset: Vector3 = Vector3(-0.2, 0.0, -0.015)
@export var base_yaw_offset_deg: float = 180.0
@export var max_local_deg: float = 30.0
@export var max_total_deg: float = 90.0
@export var edge_hold_time: float = 0.12
@export var yaw_speed_deg: float = 180.0
@export var stream_speed_deg: float = 90.0
@export var enable_input: bool = true
@export var action_left: StringName = &"ds_left"
@export var action_right: StringName = &"ds_right"
@export var dot_step_time: float = 0.10
@export var dot_hold_steps: int = 6
@export var spawn_local_deg: float = 15.0

# NEW: only place to fix sign/constant offset (if your art/gizmo differs)
@export var invert_forward: bool = true          # toggle if mirrored
@export var aim_yaw_trim_deg: float = 0.0        # small constant trim (+CCW)

var _screen: Node3D = null
var _aim: Node3D = null
var _active: bool = false
var _local_yaw_deg: float = 0.0
var _edge_hold_t: float = 0.0
var _streaming: bool = false
var _last_input_sign: int = 0
var _streamed_from_center_deg: float = 0.0
var _max_stream_deg: float = 0.0
var _dot_time: float = 0.0
var _dot_index: int = -1
var _dot_hold_left: int = 0

func _ready() -> void:
	_screen = get_node_or_null("DS_ScreenFacing") as Node3D
	_aim = get_node_or_null("DS_ScreenFacing/DS_Aim") as Node3D
	if _screen == null or _aim == null:
		push_error("DirectionSelector needs DS_ScreenFacing/DS_Aim children.")
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

	top_level = true
	rotation = Vector3.ZERO
	scale = Vector3.ONE

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
	_local_yaw_deg = spawn_local_deg

	_set_all_dots_visible(true)
	visible = true
	set_process(true)
	_update_pose()
	_apply_local_yaw()

func hide_for_fishing() -> void:
	_active = false
	top_level = false
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

	var left_pressed := Input.is_action_pressed(action_left)
	var right_pressed := Input.is_action_pressed(action_right)

	var input_sign := 0
	if left_pressed and not right_pressed:
		input_sign = -1
	elif right_pressed and not left_pressed:
		input_sign = 1

	if input_sign == 0:
		_edge_hold_t = 0.0
		_streaming = false
		_last_input_sign = 0
	else:
		if _streaming and input_sign != _last_input_sign:
			_streaming = false
			_edge_hold_t = 0.0

		if not _streaming:
			var target := float(input_sign) * max_local_deg
			var step := yaw_speed_deg * delta * float(input_sign)
			var next_yaw := _local_yaw_deg + step
			if input_sign > 0 and next_yaw > target:
				next_yaw = target
			elif input_sign < 0 and next_yaw < target:
				next_yaw = target
			_local_yaw_deg = next_yaw

			var at_edge := absf(_local_yaw_deg) >= max_local_deg - 0.001
			if at_edge:
				_edge_hold_t += delta
				if _edge_hold_t >= edge_hold_time:
					_streaming = true
					_last_input_sign = input_sign
					_edge_hold_t = 0.0
			else:
				_edge_hold_t = 0.0

		if _streaming:
			var target_stream := float(_last_input_sign) * _max_stream_deg
			var signed_remaining := target_stream - _streamed_from_center_deg
			var mag_remaining := absf(signed_remaining)
			if mag_remaining > 0.0001:
				var step_deg := stream_speed_deg * delta
				if step_deg > mag_remaining:
					step_deg = mag_remaining
				var signed_step := step_deg
				if signed_remaining < 0.0:
					signed_step = -step_deg
				if camera_controller != null and camera_controller.has_method("orbit_apply_delta_immediate"):
					camera_controller.call("orbit_apply_delta_immediate", signed_step)
				_streamed_from_center_deg += signed_step
			_local_yaw_deg = float(_last_input_sign) * max_local_deg

	_apply_local_yaw()

func _update_pose() -> void:
	var anchor: Node3D = follow_target
	if anchor == null:
		anchor = self
	var p := anchor.global_position
	if fishing_camera != null:
		var yaw_cam := _extract_camera_yaw(fishing_camera)
		var yaw := yaw_cam + deg_to_rad(base_yaw_offset_deg)
		var screen_basis := Basis(Vector3.UP, yaw)
		var offset_ws := screen_basis * local_offset
		global_transform = Transform3D(Basis.IDENTITY, p + offset_ws)
		var e := _screen.rotation
		e.y = yaw
		e.x = 0.0
		e.z = 0.0
		_screen.rotation = e

func _apply_local_yaw() -> void:
	var e := _aim.rotation
	e.y = deg_to_rad(_local_yaw_deg)
	_aim.rotation = e

func _update_dot_anim(delta: float) -> void:
	_dot_time += delta
	if _dot_hold_left > 0:
		if _dot_time >= dot_step_time:
			_dot_time = 0.0
			_dot_hold_left -= 1
			if _dot_hold_left <= 0:
				_dot_index = -1
				_apply_dot_frame()
		return

	if _dot_time >= dot_step_time:
		_dot_time = 0.0
		if _dot_index < 7:
			_dot_index += 1
			_apply_dot_frame()
		else:
			_dot_hold_left = dot_hold_steps

func _apply_dot_frame() -> void:
	var n := dots.size()
	var i := 0
	while i < n:
		var d := dots[i]
		if d != null:
			if _dot_index < 0:
				d.visible = false
			elif i <= _dot_index:
				d.visible = true
			else:
				d.visible = false
		i += 1

func _set_all_dots_visible(v: bool) -> void:
	var n := dots.size()
	var i := 0
	while i < n:
		var d := dots[i]
		if d != null:
			d.visible = v
		i += 1

func _extract_camera_yaw(cam: Camera3D) -> float:
	var fwd := -(cam.global_transform.basis.z)
	var y := 0.0
	if absf(fwd.x) > 0.000001 or absf(fwd.z) > 0.000001:
		y = atan2(fwd.x, fwd.z)
	return y

# === PUBLIC: the ONLY place others read the cast direction ===
func get_cast_forward() -> Vector3:
	var aim := _aim
	var fwd := Vector3.ZERO
	if aim == null:
		fwd = global_transform.basis.z
	else:
		fwd = aim.global_transform.basis.z

	fwd.y = 0.0
	if fwd.length() > 0.0:
		fwd = fwd.normalized()
	else:
		fwd = Vector3(0, 0, 1)

	if invert_forward:
		fwd = -fwd

	if aim_yaw_trim_deg != 0.0:
		var ang := deg_to_rad(aim_yaw_trim_deg)
		var R := Basis(Vector3.UP, ang)
		fwd = (R * fwd).normalized()

	return fwd
