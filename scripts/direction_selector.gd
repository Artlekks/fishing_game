extends Node3D

@export var player_path: NodePath
@export var dots: Array[Node3D] = []
@export var frame_hold_time: float = 0.10
@export var pause_frames: int = 6
@export var blank_frames: int = 0

@export var local_offset: Vector3 = Vector3(0.0, 0.8, 0.6)
@export var max_yaw_deg: float = 45.0              # clamp range
@export var yaw_speed_deg: float = 120.0           # turn speed
@export var follow_player_position: bool = true    # keep DS anchored on player

var _base_yaw_rad: float = 0.0     # captured on show (zero reference)
var _yaw_offset_rad: float = 0.0   # user-controlled offset from zero (clamped)

var _timer: float = 0.0
var _index: int = -1
var _active: bool = false
var _phase: String = "grow"        # "grow" -> "pause" -> "blank"
var _player: Node3D

func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_apply_overlay_material_to_dots()
	_set_all(false)
	visible = false
	set_process(false)

func _process(delta: float) -> void:
	if not _active or not is_instance_valid(_player):
		return

	# --- aiming input ---
	var left: bool = Input.is_action_pressed("ds_left")
	var right: bool = Input.is_action_pressed("ds_right")
	if left or right:
		var dir: float = 0.0
		if left:
			dir -= 1.0
		if right:
			dir += 1.0
		var speed: float = deg_to_rad(yaw_speed_deg)
		_yaw_offset_rad += dir * speed * delta
		var limit: float = deg_to_rad(max_yaw_deg)
		if _yaw_offset_rad > limit:
			_yaw_offset_rad = limit
		if _yaw_offset_rad < -limit:
			_yaw_offset_rad = -limit

	_update_pose_to_player()

	# --- frame gate for the dot animation ---
	_timer += delta
	if _timer < frame_hold_time:
		return
	_timer = 0.0

	# --- animation loop ---
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

# --------------------------------------------------------------------
# Public API

func show_for_fishing(p: Node3D = null) -> void:
	if p != null:
		_player = p
	if _player == null:
		_player = get_node_or_null(player_path) as Node3D

	_capture_base_yaw()
	_yaw_offset_rad = 0.0

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
	# keep yaw offset; it's the chosen aim

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

		if d is Sprite3D:
			var spr: Sprite3D = d
			mat.albedo_texture = spr.texture
			spr.material_override = mat
		elif d is GeometryInstance3D:
			var gi2: GeometryInstance3D = d
			gi2.material_override = mat

func _update_pose_to_player() -> void:
	# Position
	var pos: Vector3 = global_transform.origin
	if follow_player_position and _player != null:
		var xf: Transform3D = _player.global_transform
		pos = xf.origin + xf.basis * local_offset

	# Orientation: base + offset (do NOT re-align with look_at here)
	var yaw: float = _base_yaw_rad + _yaw_offset_rad
	var basis: Basis = Basis(Vector3.UP, yaw)

	global_transform = Transform3D(basis, pos)

# Optional helpers
func get_yaw_offset_deg() -> float:
	return rad_to_deg(_yaw_offset_rad)

func get_cast_forward() -> Vector3:
	var yaw: float = _base_yaw_rad + _yaw_offset_rad
	var dir: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))
	return dir.normalized()
