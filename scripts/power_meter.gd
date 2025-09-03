extends CanvasLayer

# ----- Scene paths -----
@export var root_path: NodePath = ^"Root"
@export var bg_path: NodePath
@export var fill_path: NodePath
@export var label_path: NodePath

# ----- Bar behaviour -----
@export var max_value: float = 100.0
@export var cycle_duration: float = 1.8      # 0 → 100 → 0
@export var auto_hide_on_capture: bool = false

# ----- Static HUD placement (Follow Target = Off) -----
@export var hud_left_px: float = 24.0        # distance from left edge
@export var hud_bottom_px: float = 60.0      # distance from bottom edge
@export var appear_time: float = 0.25
@export var disappear_time: float = 0.20
@export var debug_force_show: bool = false   # editor preview only

# ----- Optional target tracking (leave Off for your case) -----
@export var use_crop_instead_of_scale: bool = false
@export var target_3d_path: NodePath
@export var camera_3d_path: NodePath
@export var local_offset_3d: Vector3 = Vector3.ZERO
@export var screen_offset_px: Vector2 = Vector2(0, -120)
@export var clamp_inside_screen: bool = true
@export var follow_speed: float = 18.0
@export var follow_target: bool = false

# ----- Internal -----
var _root: CanvasItem = null
var _bg: Sprite2D = null
var _fill: Sprite2D = null
var _label: Label = null
var _camera_3d: Camera3D = null
var _target_3d: Node3D = null

var _bar_px_size: Vector2 = Vector2(240, 48)  # overridden by BG if present
var _base_scale_x: float = 1.0
var _ratio: float = 0.0
var _running: bool = false

var _fill_tween: Tween = null
var _slide_tween: Tween = null

# -----------------------------------------------------------------------------
func _ready() -> void:
	_root = get_node_or_null(root_path) as CanvasItem
	_bg   = get_node_or_null(bg_path) as Sprite2D
	_fill = get_node_or_null(fill_path) as Sprite2D
	_label = get_node_or_null(label_path) as Label

	if _fill != null:
		_fill.centered = false
		_fill.offset = Vector2(0.0, _fill.offset.y)
		_fill.scale = Vector2(1.0, 1.0)
		_base_scale_x = 1.0

	if _bg != null and _bg.texture != null:
		_bar_px_size = _bg.texture.get_size() * _bg.scale

	_target_3d = get_node_or_null(target_3d_path) as Node3D
	_resolve_camera_from_path()

	_set_ratio(0.0)
	_set_ui_visible(false)

	# Editor preview only
	if debug_force_show:
		_place_hud_immediate()
		_set_ui_visible(true)

	set_process(follow_target)

# -----------------------------------------------------------------------------
# Public API (used by your FSM adapter)

func start() -> void:
	# Slide up + start ping-pong
	if _root == null:
		return

	_running = true
	_set_ratio(0.0)
	_make_fill_pingpong()

	# Place off-screen at bottom, then tween to final HUD position
	var dst: Vector2 = _hud_target_pos()
	var start_y: float = _offscreen_y()

	_kill_slide()
	_set_root_pos(Vector2(dst.x, start_y))
	_set_ui_visible(true)

	_slide_tween = create_tween()
	_slide_tween.set_trans(Tween.TRANS_SINE)
	_slide_tween.set_ease(Tween.EASE_OUT)
	_slide_tween.tween_property(_root, "position", dst, appear_time)

func capture_power() -> float:
	var power: float = _ratio * max_value
	if auto_hide_on_capture:
		cancel()
	return power

func cancel() -> void:
	# Slide down and hide, stop fill tween
	_kill_slide()
	var end_pos: Vector2 = _get_root_pos()
	end_pos.y = _offscreen_y()

	_slide_tween = create_tween()
	_slide_tween.set_trans(Tween.TRANS_SINE)
	_slide_tween.set_ease(Tween.EASE_IN)
	_slide_tween.tween_property(_root, "position", end_pos, disappear_time)
	_slide_tween.tween_callback(Callable(self, "_on_slide_out_done"))

	_stop_fill()

func set_distance_text(meters: float) -> void:
	if _label != null:
		_label.text = String.num(meters, 1) + " m"

# -----------------------------------------------------------------------------
# Process (only if follow_target = true)

func _process(delta: float) -> void:
	if not follow_target:
		return
	if not _is_visible():
		return
	_update_screen_position(delta)

# -----------------------------------------------------------------------------
# Internals

func _on_slide_out_done() -> void:
	_set_ui_visible(false)

func _make_fill_pingpong() -> void:
	_stop_fill()
	_fill_tween = create_tween()
	_fill_tween.set_trans(Tween.TRANS_SINE)
	_fill_tween.set_ease(Tween.EASE_IN_OUT)
	_fill_tween.tween_method(_set_ratio, 0.0, 1.0, cycle_duration)
	_fill_tween.tween_method(_set_ratio, 1.0, 0.0, cycle_duration)
	_fill_tween.set_loops()

func _stop_fill() -> void:
	_running = false
	if _fill_tween != null and _fill_tween.is_valid():
		_fill_tween.kill()
	_fill_tween = null

func _kill_slide() -> void:
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	_slide_tween = null

# ----- UI helpers (Control or Node2D root supported) -------------------------

func _get_root_pos() -> Vector2:
	if _root == null:
		return Vector2.ZERO
	if _root is Control:
		return (_root as Control).position
	if _root is Node2D:
		return (_root as Node2D).position
	return Vector2.ZERO

func _set_root_pos(p: Vector2) -> void:
	if _root == null:
		return
	if _root is Control:
		(_root as Control).position = p
	elif _root is Node2D:
		(_root as Node2D).position = p

func _set_ui_visible(v: bool) -> void:
	if _root != null:
		_root.visible = v

func _is_visible() -> bool:
	if _root == null:
		return false
	return _root.visible

# ----- Static HUD placement ---------------------------------------------------

func _hud_target_pos() -> Vector2:
	# Top-left bar position from left/bottom margins
	var vr: Rect2i = get_viewport().get_visible_rect()
	var x: float = float(vr.position.x) + hud_left_px
	var y: float = float(vr.position.y + vr.size.y) - hud_bottom_px - _bar_px_size.y
	return Vector2(x, y)

func _offscreen_y() -> float:
	var vr: Rect2i = get_viewport().get_visible_rect()
	return float(vr.position.y + vr.size.y) + 8.0

func _place_hud_immediate() -> void:
	_set_root_pos(_hud_target_pos())

# ----- Target follow (unused for your current setup) --------------------------

func _update_screen_position(delta: float) -> void:
	var dst: Vector2 = _compute_dst()
	var t: float = 1.0
	if follow_speed > 0.0:
		var speed: float = follow_speed
		t = clampf(delta * speed, 0.0, 1.0)
	var cur: Vector2 = _get_root_pos()
	_set_root_pos(cur.lerp(dst, t))

func _compute_dst() -> Vector2:
	# Resolve refs lazily if they dropped
	if _target_3d == null and target_3d_path != NodePath(""):
		_target_3d = get_node_or_null(target_3d_path) as Node3D

	var cam: Camera3D = _active_camera()
	if _target_3d == null or cam == null:
		return _get_root_pos()

	# 3D world position to attach to
	var world_pos: Vector3 = _target_3d.global_transform * local_offset_3d
	if cam.is_position_behind(world_pos):
		return _get_root_pos()

	# 3D → 2D (pixels, top-left origin)
	var feet_px: Vector2 = cam.unproject_position(world_pos)

	# Compute top-left from offset
	var anchor_px: Vector2 = Vector2(_bar_px_size.x * 0.0, _bar_px_size.y * 1.0) # bottom-left anchor
	var dst: Vector2 = feet_px + screen_offset_px - anchor_px

	if clamp_inside_screen:
		var vr: Rect2i = get_viewport().get_visible_rect()
		var min_x: float = float(vr.position.x)
		var max_x: float = float(vr.position.x + vr.size.x) - _bar_px_size.x
		var min_y: float = float(vr.position.y)
		var max_y: float = float(vr.position.y + vr.size.y) - _bar_px_size.y
		if dst.x < min_x:
			dst.x = min_x
		if dst.x > max_x:
			dst.x = max_x
		if dst.y < min_y:
			dst.y = min_y
		if dst.y > max_y:
			dst.y = max_y

	return dst

# ----- Cameras ----------------------------------------------------------------

func _resolve_camera_from_path() -> void:
	if camera_3d_path != NodePath(""):
		_camera_3d = get_node_or_null(camera_3d_path) as Camera3D
	else:
		_camera_3d = null

func _active_camera() -> Camera3D:
	var cam: Camera3D = _camera_3d
	if cam == null or not cam.current:
		cam = get_viewport().get_camera_3d()
	return cam

# ----- Fill visuals -----------------------------------------------------------

func _set_ratio(r: float) -> void:
	_ratio = clampf(r, 0.0, 1.0)
	if _fill == null:
		return

	if use_crop_instead_of_scale:
		if not _fill.region_enabled:
			_fill.region_enabled = true
			if _fill.texture != null:
				_fill.region_rect = Rect2(Vector2.ZERO, _fill.texture.get_size())
		if _fill.texture != null:
			var tex_size: Vector2 = _fill.texture.get_size()
			var full_w: float = tex_size.x
			var w: float = clampf(full_w * _ratio, 1.0, full_w)
			var rr: Rect2 = _fill.region_rect
			rr.size.x = w
			_fill.region_rect = rr
	else:
		_fill.scale = Vector2(_base_scale_x * _ratio, _fill.scale.y)
