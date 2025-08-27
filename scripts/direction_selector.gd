extends Node3D

@export var player_path: NodePath                      # set this to your player root
@export var dots: Array[Node3D] = []                   # assign dot_0..dot_7 in order
@export var frame_hold_time: float = 0.10              # seconds between steps
@export var pause_frames: int = 6
@export var blank_frames: int = 0

@export var local_offset: Vector3 = Vector3(0.0, 0.8, 0.6)
# ^ position of the selector relative to the player (tweak to place it near the rod tip)

var _timer: float = 0.0
var _index: int = -1
var _active: bool = false
var _phase: String = "grow"                            # "grow" -> "pause" -> "blank"
var _player: Node3D
var _mat_always_on_top: StandardMaterial3D

func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_apply_overlay_material_to_dots()
	_set_all(false)

func _process(delta: float) -> void:
	if _active and is_instance_valid(_player):
		_update_pose_to_player()

	# animation loop
	if not _active:
		return

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

# --------------------------------------------------------------------
# Public API

func show_for_fishing(p: Node3D = null) -> void:
	if p != null:
		_player = p
	_active = true
	_restart_cycle()
	_set_all(false)

func start_looping(p: Node3D = null) -> void:
	show_for_fishing(p)

func stop_looping() -> void:
	hide_for_fishing()

func hide_for_fishing() -> void:
	_active = false
	_set_all(false)

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

		# If you already set a Material Override in the editor, don't touch it.
		if d is GeometryInstance3D:
			var gi: GeometryInstance3D = d
			if gi.material_override != null:
				continue

		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true                               # Godot 4 name
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.render_priority = 127
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # crisp pixels

		if d is Sprite3D:
			var spr: Sprite3D = d
			# preserve the sprite's texture so it doesn't turn white
			mat.albedo_texture = spr.texture
			spr.material_override = mat
		elif d is GeometryInstance3D:
			var gi2: GeometryInstance3D = d
			gi2.material_override = mat


func _update_pose_to_player() -> void:
	# 1) Set world position from player's transform + local offset
	var world_from_player := _player.global_transform
	var world_pos := world_from_player * local_offset
	global_position = world_pos

	# 2) Compute a stable horizontal facing direction from player:
	#    we align our LOCAL +Z to the player's LOCAL -Z projected on XZ plane.
	var dir := -_player.global_transform.basis.z
	dir.y = 0.0
	if dir.length() < 1e-6:
		return
	dir = dir.normalized()

	# 3) Use looking_at: in Godot, -Z looks at the target. We want +Z forward,
	#    so look_at then rotate 180° around Y to flip -Z -> +Z.
	look_at(global_position + dir, Vector3.UP)
	rotate_y(PI)
