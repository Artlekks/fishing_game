extends Control
class_name DepthMeter

@export var frame_path: NodePath
@export var ground_path: NodePath
@export var arrow_path: NodePath

@export var shallow_tex: Texture2D
@export var mid_tex: Texture2D
@export var deep_tex: Texture2D

@export var track_top_inset_px: float = 8.0
@export var track_ground_align_px: float = 0.0

@onready var _frame: TextureRect = get_node_or_null(frame_path) as TextureRect
@onready var _ground: TextureRect = get_node_or_null(ground_path) as TextureRect
@onready var _arrow: TextureRect = get_node_or_null(arrow_path) as TextureRect

var _surface_y: float = 0.0
var _bottom_y: float = 0.0
var _last_bait_y: float = 0.0

func _ready() -> void:
	visible = false

# -- called by gate on cast --
func show_with_bounds(surface_y: float, bottom_y: float) -> void:
	_surface_y = surface_y
	_bottom_y = bottom_y
	_select_ground_texture()
	if _frame != null:  _frame.visible = true
	if _ground != null: _ground.visible = _ground.texture != null
	if _arrow != null:  _arrow.visible = true
	visible = true
	_update_arrow_immediate()

# -- called by gate every frame while active --
func set_bait_y(bait_y: float) -> void:
	_last_bait_y = bait_y
	_update_arrow_immediate()

# -- called by gate on exit (optional) --
func hide_meter() -> void:
	visible = false

func _select_ground_texture() -> void:
	if _ground == null:
		return
	var depth_span: float = _surface_y - _bottom_y
	if absf(depth_span) < 0.0001:
		depth_span = 0.0001
	# Mid/deep thresholds (t in [0..1], 0=bottom, 1=surface)
	var t_mid: float = 1.2 / 3.0   # tune later
	var t_deep: float = 2.2 / 3.0

	# choose texture by actual depth
	var t: float = (_last_bait_y - _bottom_y) / depth_span
	if t < t_mid:
		_ground.texture = shallow_tex
	elif t < t_deep:
		_ground.texture = mid_tex
	else:
		_ground.texture = deep_tex

func _update_arrow_immediate() -> void:
	if _frame == null or _arrow == null:
		return
	var fr: Rect2 = _frame.get_rect()
	var track_top: float = fr.position.y + track_top_inset_px
	var track_bottom: float
	if _ground != null:
		track_bottom = _ground.position.y + track_ground_align_px
	else:
		track_bottom = fr.position.y + fr.size.y - track_top_inset_px
	if track_bottom < track_top + 1.0:
		track_bottom = track_top + 1.0

	var span_world: float = _surface_y - _bottom_y
	if absf(span_world) < 0.0001:
		span_world = 0.0001
	var t: float = (_last_bait_y - _bottom_y) / span_world
	if t < 0.0: t = 0.0
	elif t > 1.0: t = 1.0

	var y_px: float = lerp(track_bottom, track_top, t)
	var p: Vector2 = _arrow.position
	p.y = y_px - (_arrow.size.y * 0.5)
	_arrow.position = p
