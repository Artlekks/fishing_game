extends Control

# --- Scene paths ---------------------------------------------------------------
@export var frame_path: NodePath
@export var ground_path: NodePath
@export var arrow_path: NodePath

# --- Track definition ----------------------------------------------------------
@export var use_explicit_track: bool = true
@export var track_surface_y_px: float = 18.0
@export var track_ground_y_px: float  = 132.0
@export var track_top_inset_px: float = 8.0
@export var track_bottom_inset_px: float = 0.0
@export var arrow_tip_offset_px: float = 18.0

# --- Transition ----------------------------------------------------------------
@export var slide_time: float = 0.25
@export var slide_padding_px: float = 12.0

# Optional shallow/mid/deep textures
@export var shallow_tex: Texture2D
@export var mid_tex: Texture2D
@export var deep_tex: Texture2D
@export var min_depth_for_mid: float = 1.2
@export var min_depth_for_deep: float = 2.2
@export var use_animated_sprite2d: bool = false
@export var animated_sprite2d_path: NodePath
@export var anim_frames_count: int = 1   # total frames in the spriteframes resource

@export var depth_anim_name: StringName = &"Depth"  # must match the animation name in SpriteFrames
@export var depth_anim_speed: float = 1.0
@export var anim_follow_bait: bool = true  # true: frame = bait depth; false: loop the clip

var _animated_sprite: AnimatedSprite2D = null

# --- Internals -----------------------------------------------------------------
var _frame: TextureRect
var _ground: TextureRect
var _arrow: TextureRect

var _surface_y: float = 0.0
var _bottom_y: float = 0.0
var _last_bait_y: float = 0.0

var _lane_top_px: float = 0.0
var _lane_bottom_px: float = 0.0

var _rest_position: Vector2 = Vector2.ZERO
var _slide_tween: Tween = null

# ------------------------------------------------------------------------------
func _ready() -> void:
	_frame  = get_node_or_null(frame_path)  as TextureRect
	_ground = get_node_or_null(ground_path) as TextureRect
	_arrow  = get_node_or_null(arrow_path)  as TextureRect
	
	if use_animated_sprite2d:
		_animated_sprite = get_node_or_null(animated_sprite2d_path) as AnimatedSprite2D
		if _animated_sprite:
			if _ground: _ground.visible = false
			# select the animation and ensure it’s not auto-playing
			_animated_sprite.animation = depth_anim_name
			_animated_sprite.stop()


	# Make Ground render like Frame, but DO NOT touch its rect.
	_clone_frame_style_to_ground()

	if _ground != null:
		_ground.scale = Vector2.ONE
		_ground.custom_minimum_size = Vector2.ZERO
		_update_ground_visibility()

	_rebuild_lane_from_settings()

	if _frame != null and not _frame.resized.is_connected(_on_frame_resized):
		_frame.resized.connect(_on_frame_resized)

	_rest_position = position
	visible = false

# === Public API ================================================================
func show_with_bounds(surface_y: float, bottom_y: float) -> void:
	_surface_y = surface_y
	_bottom_y  = bottom_y
	_rebuild_lane_from_settings()

	if _ground != null and _ground.texture == null and shallow_tex != null:
		_apply_ground_tex(shallow_tex)

	if use_animated_sprite2d and _animated_sprite:
		if anim_follow_bait:
			_animated_sprite.stop()
			_update_animated_sprite_by_bait()
		else:
			_play_depth_anim()

	_slide_in_from_right()


func hide_meter() -> void:
	if use_animated_sprite2d:
		_stop_depth_anim()

	_slide_out_to_right()

func set_bait_y(y: float) -> void:
	_last_bait_y = y
	_update_arrow_immediate()
	if use_animated_sprite2d and anim_follow_bait:
		_update_animated_sprite_by_bait()


func _slide_in_from_right() -> void:
	_kill_slide_tween()

	position = _get_offscreen_right_position()
	visible = true

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(
		self,
		"position",
		_rest_position,
		slide_time
	)

	_slide_tween = tween


func _slide_out_to_right() -> void:
	_kill_slide_tween()

	if not visible:
		position = _rest_position
		return

	var end_position := _get_offscreen_right_position()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(
		self,
		"position",
		end_position,
		slide_time
	)
	tween.tween_callback(_finish_slide_out)

	_slide_tween = tween


func _finish_slide_out() -> void:
	visible = false
	position = _rest_position
	_slide_tween = null


func _kill_slide_tween() -> void:
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()

	_slide_tween = null


func _get_offscreen_right_position() -> Vector2:
	# Calculate the right-side exit from the approved resting position.
	var current_position := position
	position = _rest_position
	var rest_global_x := global_position.x
	position = current_position

	var viewport_rect := get_viewport().get_visible_rect()
	var viewport_right := (
		float(viewport_rect.position.x)
		+ float(viewport_rect.size.x)
	)

	var visual_width := maxf(size.x, 1.0)
	var shift_x := (
		viewport_right
		- rest_global_x
		+ visual_width
		+ slide_padding_px
	)

	return _rest_position + Vector2(
		maxf(shift_x, slide_padding_px),
		0.0
	)


# === Arrow mapping =============================================================
func _rebuild_lane_from_settings() -> void:
	var top_px: float
	var bottom_px: float

	if use_explicit_track:
		top_px = track_surface_y_px
		bottom_px = track_ground_y_px
	else:
		if _frame == null:
			top_px = 0.0
			bottom_px = size.y
		else:
			var r: Rect2 = Rect2(_frame.position, _frame.size)
			top_px = r.position.y + track_top_inset_px
			bottom_px = r.position.y + r.size.y - track_bottom_inset_px

	if bottom_px < top_px:
		var tmp: float = top_px
		top_px = bottom_px
		bottom_px = tmp

	_lane_top_px = top_px
	_lane_bottom_px = bottom_px

func _update_arrow_immediate() -> void:
	if _arrow == null:
		return

	var span: float = _surface_y - _bottom_y
	if absf(span) < 0.0001:
		span = 0.0001

	var t: float = clampf((_last_bait_y - _bottom_y) / span, 0.0, 1.0)
	var y_px: float = lerpf(_lane_bottom_px, _lane_top_px, t) - arrow_tip_offset_px
	var min_y: float = _lane_top_px    - arrow_tip_offset_px
	var max_y: float = _lane_bottom_px - arrow_tip_offset_px
	y_px = clampf(y_px, min_y, max_y)

	var p: Vector2 = _arrow.position
	p.y = y_px
	_arrow.position = p

# === Ground visuals ============================================================
func _apply_ground_tex(tex: Texture2D) -> void:
	if _ground == null:
		return
	_ground.texture = tex
	# Keep the same render behaviour as Frame; DO NOT touch position/size.
	_clone_frame_style_to_ground()
	_ground.scale = Vector2.ONE
	_ground.custom_minimum_size = Vector2.ZERO
	_update_ground_visibility()

func _update_ground_visibility() -> void:
	if _ground != null:
		_ground.visible = (_ground.texture != null)

func select_ground_texture(depth_value: float) -> void:
	if _ground == null:
		return
	var tex: Texture2D = null
	if depth_value < min_depth_for_mid:
		tex = shallow_tex
	elif depth_value < min_depth_for_deep:
		tex = mid_tex
	else:
		tex = deep_tex
	if tex != null:
		_apply_ground_tex(tex)

# === Events ====================================================================
func _on_frame_resized() -> void:
	# Only affects arrow lane if you use Frame-based lane; Ground rect is NOT touched.
	_rebuild_lane_from_settings()

# === Helpers ===================================================================
# Clone only valid TextureRect flags from Frame (no rect, no anchors).
func _play_depth_anim() -> void:
	if _animated_sprite == null:
		return
	var frames := _animated_sprite.sprite_frames
	if frames == null:
		return
	var anim_to_play: StringName = depth_anim_name
	if not frames.has_animation(anim_to_play):
		var names := frames.get_animation_names()
		if names.size() == 0:
			return
		anim_to_play = names[0]
	_animated_sprite.animation = anim_to_play
	_animated_sprite.speed_scale = depth_anim_speed
	_animated_sprite.play()

func _stop_depth_anim() -> void:
	if _animated_sprite != null:
		_animated_sprite.stop()

func _update_animated_sprite_by_bait() -> void:
	if not use_animated_sprite2d or _animated_sprite == null or anim_frames_count <= 0:
		return

	var span := _surface_y - _bottom_y
	if absf(span) < 0.0001:
		span = 0.0001
	var t := clampf((_last_bait_y - _bottom_y) / span, 0.0, 1.0)
	var idx := int(round(t * float(anim_frames_count - 1)))
	idx = clamp(idx, 0, anim_frames_count - 1)

	# make sure the right clip is selected
	if _animated_sprite.animation != depth_anim_name:
		_animated_sprite.animation = depth_anim_name

	# depth-driven, not time-driven: STOP and set the exact frame
	_animated_sprite.stop()
	_animated_sprite.frame = idx
	_animated_sprite.frame_progress = 0.0


func _clone_frame_style_to_ground() -> void:
	if _frame == null or _ground == null:
		return
	_ground.stretch_mode   = _frame.stretch_mode
	_ground.expand_mode    = _frame.expand_mode
	_ground.flip_h         = _frame.flip_h
	_ground.flip_v         = _frame.flip_v
	_ground.texture_filter = _frame.texture_filter
	_ground.texture_repeat = _frame.texture_repeat
