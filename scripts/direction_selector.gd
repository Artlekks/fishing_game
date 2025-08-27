extends Node3D

signal request_camera_orbit(delta_deg: float)  # ask camera to orbit by +/-step

@export var player_path: NodePath
@export var dots: Array[Node3D] = []
@export var frame_hold_time: float = 0.10
@export var pause_frames: int = 6
@export var blank_frames: int = 0

@export var local_offset: Vector3 = Vector3(0.0, 0.8, 0.6)

# --- Aiming sector + orbit handoff ---
@export var max_yaw_deg: float = 30.0               # DS local sector half-width
@export var yaw_speed_deg: float = 120.0            # key-hold turn speed
@export var follow_player_position: bool = true     # anchor to player

@export var orbit_step_deg: float = 30.0            # camera step per sector
@export var orbit_hysteresis_deg: float = 5.0       # back off from edge to avoid re-trigger
@export var orbit_cooldown_sec: float = 0.10        # tiny delay after a step
@export var camera_controller_path: NodePath

var _camera_controller: Node = null
var _cam_ctrl: Node = null

var _base_yaw_rad: float = 0.0     # captured on show (zero reference)
var _yaw_offset_rad: float = 0.0   # user offset from zero (clamped)

var _timer: float = 0.0
var _index: int = -1
var _active: bool = false
var _phase: String = "grow"        # "grow" -> "pause" -> "blank"
var _player: Node3D

# orbit state
var _orbit_in_progress: bool = false
var _orbit_cooldown: float = 0.0   # counts down

func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D

	# Prefer explicit path; optionally fall back to a group if you use one.
	_camera_controller = get_node_or_null(camera_controller_path)
	if _camera_controller == null:
		var cands: Array = get_tree().get_nodes_in_group("fishing_camera_controller")
		if cands.size() > 0:
			_camera_controller = cands[0]

	_apply_overlay_material_to_dots()
	_set_all(false)
	visible = false
	set_process(false)

	# Ensure Camera -> DS
	if _camera_controller and _camera_controller.has_signal("orbit_completed"):
		var cb := Callable(self, "_on_camera_orbit_completed")
		if not _camera_controller.is_connected("orbit_completed", cb):
			_camera_controller.connect("orbit_completed", cb)

	# Ensure DS -> Camera
	if _camera_controller and _camera_controller.has_method("orbit_around_player"):
		var call := Callable(_camera_controller, "orbit_around_player")
		if not is_connected("request_camera_orbit", call):
			connect("request_camera_orbit", call)


func _process(delta: float) -> void:
	if not _active or not is_instance_valid(_player):
		return

	# cooldown timer
	if _orbit_cooldown > 0.0:
		_orbit_cooldown -= delta
		if _orbit_cooldown < 0.0:
			_orbit_cooldown = 0.0

	# If a camera step is running or we're cooling down, skip input this frame
	if _orbit_in_progress or _orbit_cooldown > 0.0:
		_update_pose_to_player()
		_advance_dot_anim(delta)
		return

	# --- aiming input (ONLY when not stepping and not cooling down) ---
	var left: bool = Input.is_action_pressed("ds_left")
	var right: bool = Input.is_action_pressed("ds_right")

	var dir: float = 0.0
	if left:
		dir -= 1.0
	if right:
		dir += 1.0

	if dir != 0.0:
		var speed: float = deg_to_rad(yaw_speed_deg)
		_yaw_offset_rad += dir * speed * delta

		# clamp to local sector
		var max_rad: float = deg_to_rad(max_yaw_deg)
		if _yaw_offset_rad > max_rad:
			_yaw_offset_rad = max_rad
		if _yaw_offset_rad < -max_rad:
			_yaw_offset_rad = -max_rad

		# near the edge and still pushing -> request a camera orbit step
		var trigger_rad: float = max_rad - deg_to_rad(orbit_hysteresis_deg)
		var pushing_same_sign: bool = false
		if _yaw_offset_rad > 0.0 and dir > 0.0:
			pushing_same_sign = true
		elif _yaw_offset_rad < 0.0 and dir < 0.0:
			pushing_same_sign = true

		if absf(_yaw_offset_rad) >= trigger_rad and pushing_same_sign:
			var sign_i: int = 1
			if _yaw_offset_rad < 0.0:
				sign_i = -1
			# freeze at edge and ask camera to orbit
			_yaw_offset_rad = float(sign_i) * max_rad
			_orbit_in_progress = true
			var step_deg: float = float(sign_i) * orbit_step_deg
			request_camera_orbit.emit(step_deg)

	_update_pose_to_player()
	_advance_dot_anim(delta)


# --------------------------------------------------------------------
# Public API

func show_for_fishing(p: Node3D = null) -> void:
	if p != null:
		_player = p
	if _player == null:
		_player = get_node_or_null(player_path) as Node3D

	_capture_base_yaw()
	_yaw_offset_rad = 0.0
	_orbit_in_progress = false
	_orbit_cooldown = 0.0

	_active = true
	visible = true
	set_process(true)

	_restart_cycle()
	_update_pose_to_player()

func start_looping(p: Node3D = null) -> void:
	show_for_fishing(p)

func stop_looping() -> void:
	hide_for_fishing()

func hide_for_fishing() -> void:
	_active = false
	_set_all(false)
	visible = false
	set_process(false)

# Called by the camera when its orbit tween completes.
# sign is +1 for CCW (positive degrees), -1 for CW (negative degrees).
# Supports both signatures:
#   orbit_completed(sign)
#   orbit_completed(sign, step_deg)
func _on_camera_orbit_completed(sign: int, step_deg: float = -1.0) -> void:
	var step_used: float = step_deg
	if step_used <= 0.0:
		step_used = orbit_step_deg

	var delta_rad: float = deg_to_rad(step_used) * float(sign)

	# Preserve world-facing after camera rotates:
	_base_yaw_rad += delta_rad
	_yaw_offset_rad -= delta_rad

	# Re-clamp to sector
	var limit: float = deg_to_rad(max_yaw_deg)
	if _yaw_offset_rad > limit:
		_yaw_offset_rad = limit
	if _yaw_offset_rad < -limit:
		_yaw_offset_rad = -limit

	_orbit_in_progress = false
	_orbit_cooldown = orbit_cooldown_sec

	_update_pose_to_player()


# Zero reference from player's facing
func _capture_base_yaw() -> void:
	if _player == null:
		_base_yaw_rad = 0.0
		return
	var fwd: Vector3 = -_player.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.0001:
		_base_yaw_rad = 0.0
	else:
		fwd = fwd.normalized()
		_base_yaw_rad = atan2(fwd.x, fwd.z)

# --------------------------------------------------------------------
# Internals

func _restart_cycle() -> void:
	_set_all(false)
	_index = -1
	_phase = "grow"
	_timer = 0.0

func _set_all(state: bool) -> void:
	for d in dots:
		if d:
			d.visible = state

func _apply_overlay_material_to_dots() -> void:
	for d in dots:
		if d == null:
			continue

		# If a Material Override already exists (set in editor), keep it
		if d is GeometryInstance3D:
			var gi: GeometryInstance3D = d
			if gi.material_override != null:
				continue

		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.render_priority = 127
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y  # keep dots facing camera

		if d is Sprite3D:
			var spr: Sprite3D = d
			mat.albedo_texture = spr.texture
			spr.material_override = mat
		elif d is GeometryInstance3D:
			var gi2: GeometryInstance3D = d
			gi2.material_override = mat

func _update_pose_to_player() -> void:
	# Position (follow player if enabled)
	var pos: Vector3 = global_transform.origin
	if follow_player_position and _player != null:
		var xf: Transform3D = _player.global_transform
		pos = xf.origin + xf.basis * local_offset

	# Orientation: base yaw (captured on show) + user offset
	var yaw: float = _base_yaw_rad + _yaw_offset_rad
	var basis: Basis = Basis(Vector3.UP, yaw)

	global_transform = Transform3D(basis, pos)

# Optional helpers
func _advance_dot_anim(delta: float) -> void:
	_timer += delta
	if _timer < frame_hold_time:
		return
	_timer = 0.0

	if _phase == "grow":
		_index += 1
		if _index < dots.size():
			var d := dots[_index]
			if d:
				d.visible = true
			if _index == dots.size() - 1:
				_phase = "pause"
				_index = pause_frames
		else:
			_phase = "pause"
			_index = pause_frames

	elif _phase == "pause":
		_index -= 1
		if _index <= 0:
			if blank_frames > 0:
				_phase = "blank"
				_index = blank_frames
			else:
				_restart_cycle()

	elif _phase == "blank":
		_index -= 1
		if _index <= 0:
			_restart_cycle()

func get_yaw_offset_deg() -> float:
	return rad_to_deg(_yaw_offset_rad)

func get_cast_forward() -> Vector3:
	var yaw: float = _base_yaw_rad + _yaw_offset_rad
	var dir: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))
	return dir.normalized()
