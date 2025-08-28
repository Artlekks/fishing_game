extends Node3D

class_name DirectionSelector

# ---- External references (set in Inspector) ----
@export var player_path: NodePath
@export var camera_controller_path: NodePath
@export var fishing_state_controller_path: NodePath   # Controller that emits `animation_change(anim: StringName)`

# Eight dots (N, NW, W, SW, S, SE, E, NE) or any number you use.
# Fill these in the Inspector. They can be Sprite3D or MeshInstance3D/GeometryInstance3D.
@export var dots: Array[Node3D] = []

# Optional: enable/disable input handling for DS (left/right). Not used unless you add logic later.
@export var action_left: StringName = &"ds_left"
@export var action_right: StringName = &"ds_right"
@export var enable_input: bool = false

# ---- Internal state ----
var _player: Node3D = null
var _camera_controller: Node = null
var _fsm: Node = null
var _active: bool = false

func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_camera_controller = get_node_or_null(camera_controller_path)
	_fsm = get_node_or_null(fishing_state_controller_path)

	# Apply overlay material and start hidden/inactive
	_apply_overlay_material_to_dots()
	_set_all(false)
	visible = false
	set_process(false)

	# Camera hooks — hide as soon as exit starts (align out), and after exit completes.
	if _camera_controller != null:
		if _camera_controller.has_signal("align_started"):
			var c1 := Callable(self, "_on_cam_align_started")
			if not _camera_controller.is_connected("align_started", c1):
				_camera_controller.connect("align_started", c1)
		if _camera_controller.has_signal("exited_to_exploration_view"):
			var c2 := Callable(self, "_on_cam_exited")
			if not _camera_controller.is_connected("exited_to_exploration_view", c2):
				_camera_controller.connect("exited_to_exploration_view", c2)

	# FSM hook — mirror UX without coupling DS into FSM code.
	# We only listen; we never call back into FSM or sprites.
	if _fsm != null and _fsm.has_signal("animation_change"):
		var c3 := Callable(self, "_on_fsm_animation_change")
		if not _fsm.is_connected("animation_change", c3):
			_fsm.connect("animation_change", c3)

func _process(_delta: float) -> void:
	if not _active:
		return
	# No input handling in this version. DS is display-only.

# ---- Public API (called by listeners only; safe to call from anywhere) ----
func show_for_fishing(origin: Node3D = null) -> void:
	# origin is optional (player). DS does not rely on it for visibility.
	if origin != null:
		_player = origin
	_active = true
	_set_all(true)
	visible = true
	set_process(true)

func hide_for_fishing() -> void:
	_active = false
	_set_all(false)
	visible = false
	set_process(false)

# ---- Listeners ----
func _on_cam_align_started(to_fishing: bool) -> void:
	# When exiting fishing view (to_fishing == false), hide immediately so DS never overlaps with exit sprites.
	if not to_fishing:
		hide_for_fishing()

func _on_cam_exited() -> void:
	# After camera fully returns to exploration, ensure DS is hidden.
	hide_for_fishing()

func _on_fsm_animation_change(anim_name: StringName) -> void:
	var s := String(anim_name)
	if s == "Fishing_Idle":
		show_for_fishing(_player)
	elif s == "Prep_Throw":
		hide_for_fishing()
	elif s == "Cancel_Fishing":
		hide_for_fishing()

# ---- Utilities (materials/visibility) ----
func _set_all(state: bool) -> void:
	var count := dots.size()
	var i := 0
	while i < count:
		var d := dots[i]
		if d != null:
			d.visible = state
		i += 1

func _apply_overlay_material_to_dots() -> void:
	# Provide a lightweight unshaded overlay so dots remain readable in any lighting.
	var count := dots.size()
	var i := 0
	while i < count:
		var d := dots[i]
		if d == null:
			i += 1
			continue

		# If author already assigned a material_override in the editor, leave it.
		if d is GeometryInstance3D:
			var gi := d as GeometryInstance3D
			if gi.material_override != null:
				i += 1
				continue

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.render_priority = 127
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y

		if d is Sprite3D:
			var spr := d as Sprite3D
			if spr.texture != null:
				mat.albedo_texture = spr.texture
			spr.material_override = mat
		elif d is GeometryInstance3D:
			var gi2 := d as GeometryInstance3D
			gi2.material_override = mat

		i += 1
