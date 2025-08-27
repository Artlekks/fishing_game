extends CanvasLayer

@export var root_path: NodePath = NodePath("Root")
@export var bg_path: NodePath
@export var fill_path: NodePath
@export var label_path: NodePath

@export var max_value: float = 100.0
@export var cycle_duration: float = 1.8   # seconds 0→100→0
@export var auto_hide_on_capture: bool = true
@export var use_crop_instead_of_scale: bool = false

@export var target_3d_path: NodePath
@export var camera_3d_path: NodePath
@export var local_offset_3d: Vector3 = Vector3.ZERO

@export var screen_offset_px: Vector2 = Vector2(0, -120)  # shift above feet in pixels
@export var anchor_norm: Vector2 = Vector2(0.5, 1.0)      # 0..1 (0.5,1.0 = bottom-center of the bar)
@export var clamp_inside_screen: bool = true
@export var follow_speed: float = 18.0                    # higher = snappier
@export var follow_target: bool = false   # false = static HUD (recommended for your case)

var _root: Node2D
var _bg: Sprite2D
var _fill: Sprite2D
var _label: Label
var _tween: Tween
var _ratio: float = 0.0
var _base_scale_x: float = 1.0
var _is_running: bool = false
var _target_3d: Node3D
var _camera_3d: Camera3D
var _bar_px_size: Vector2 = Vector2(240, 48) # fallback; overwritten if BG has a texture

func _ready() -> void:
	_root  = get_node_or_null(root_path) as Node2D
	if _root == null:
		_root = get_node_or_null("Root") as Node2D  # fallback by name

	_bg    = get_node_or_null(bg_path) as Sprite2D
	_fill  = get_node_or_null(fill_path) as Sprite2D
	_label = get_node_or_null(label_path) as Label

	# Fill safety
	if _fill:
		_fill.centered = false
		_fill.offset = Vector2(0.0, _fill.offset.y)
		_fill.scale = Vector2(1, 1)
		_base_scale_x = 1.0

	hide()
	_set_ratio(0.0)

	_target_3d = get_node_or_null(target_3d_path) as Node3D
	_camera_3d = get_node_or_null(camera_3d_path) as Camera3D

	# Determine pixel size from BG if available
	if _bg and _bg.texture:
		_bar_px_size = _bg.texture.get_size() * _bg.scale

	set_process(follow_target)

func _process(delta: float) -> void:
	if not follow_target:
		return
	if not visible:
		return
	# ... keep the rest of your existing _process() unchanged ...

	if not visible:
		return

	# re-acquire nodes lazily if needed
	if _root == null:
		_root = get_node_or_null(root_path) as Node2D
		if _root == null:
			_root = get_node_or_null("Root") as Node2D
		if _root == null:
			return

	if _target_3d == null and target_3d_path != NodePath():
		_target_3d = get_node_or_null(target_3d_path) as Node3D
	if _camera_3d == null:
		_camera_3d = get_node_or_null(camera_3d_path) as Camera3D
		if _camera_3d == null:
			_camera_3d = get_viewport().get_camera_3d()

	if _target_3d == null or _camera_3d == null:
		return

	# world position of the bar anchor (local offset is in the target's local space)
	var world_pos: Vector3 = _target_3d.global_transform * local_offset_3d

	# if behind camera, skip positioning this frame
	if _camera_3d.is_position_behind(world_pos):
		return

	# 3D → screen
	var feet_px: Vector2 = _camera_3d.unproject_position(world_pos)

	# top-left position from anchor + screen offset
	var anchor_px: Vector2 = _bar_px_size * anchor_norm
	var dst: Vector2 = feet_px + screen_offset_px - anchor_px

	# clamp
	if clamp_inside_screen:
		var vr: Rect2i = get_viewport().get_visible_rect()
		var min_x: float = float(vr.position.x)
		var min_y: float = float(vr.position.y)
		var max_x: float = float(vr.position.x + vr.size.x) - _bar_px_size.x
		var max_y: float = float(vr.position.y + vr.size.y) - _bar_px_size.y
		dst.x = clampf(dst.x, min_x, max_x)
		dst.y = clampf(dst.y, min_y, max_y)

	# smooth follow
	var t: float = 1.0 if follow_speed <= 0.0 else clampf(delta * follow_speed, 0.0, 1.0)
	_root.position = _root.position.lerp(dst, t)

# -------------------- Public API (used by your FSM adapter) --------------------

func start() -> void:
	# show + start ping-pong if not already running
	if _is_running:
		return
	if _fill == null:
		show() # still show container even if missing visuals
		return
	show()
	_is_running = true
	_set_ratio(0.0)
	_make_pingpong_tween()

func capture_power() -> float:
	# returns 0..max_value
	var power: float = _ratio * max_value
	_stop_all()
	if auto_hide_on_capture:
		hide()
	return power

func cancel() -> void:
	_stop_all()
	hide()

func set_distance_text(meters: float) -> void:
	if _label:
		_label.text = String.num(meters, 1) + " m"

# ------------------------------ Internals -------------------------------------

func _make_pingpong_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_set_ratio, 0.0, 1.0, cycle_duration)
	_tween.tween_method(_set_ratio, 1.0, 0.0, cycle_duration)
	_tween.set_loops()

func _stop_all() -> void:
	_is_running = false
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null

func _set_ratio(r: float) -> void:
	_ratio = clampf(r, 0.0, 1.0)
	if _fill == null:
		return

	if use_crop_instead_of_scale:
		if not _fill.region_enabled:
			_fill.region_enabled = true
			if _fill.texture:
				_fill.region_rect = Rect2(Vector2.ZERO, _fill.texture.get_size())

		if _fill.texture:
			var tex_size: Vector2 = _fill.texture.get_size()
			var full_w: float = tex_size.x
			var w: float = clampf(full_w * _ratio, 1.0, full_w) # smooth
			var rr: Rect2 = _fill.region_rect
			rr.size.x = w
			_fill.region_rect = rr
	else:
		_fill.scale = Vector2(_base_scale_x * _ratio, _fill.scale.y)
