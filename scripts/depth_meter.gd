extends Control

@export var shallow_tex: Texture2D
@export var mid_tex: Texture2D
@export var deep_tex: Texture2D

const UPDATE_HZ := 30.0

var _surface_y: float = 0.0
var _bottom_y: float = 0.0
var _last_bait_y: float = 0.0
var _accum: float = 0.0
var _min_depth_for_mid: float = 1.2   # meters; tweak
var _min_depth_for_deep: float = 2.2  # meters; tweak

@onready var _frame: TextureRect = $Frame
@onready var _ground: TextureRect = $Ground
@onready var _arrow: TextureRect = $Arrow

func _ready() -> void:
	visible = false
	if shallow_tex == null:
		shallow_tex = load("res://Shallow_Depth.png")
	if mid_tex == null:
		mid_tex = load("res://Mid_Depth.png")
	if deep_tex == null:
		deep_tex = load("res://Deep_Depth.png")

func show_with_bounds(surface_y: float, bottom_y: float) -> void:
	_surface_y = surface_y
	_bottom_y = bottom_y
	_pick_ground_texture()
	visible = true

func hide_meter() -> void:
	visible = false

func set_bait_y(bait_y: float) -> void:
	_last_bait_y = bait_y
	_update_arrow_immediate()

func _process(delta: float) -> void:
	if not visible:
		return
	_accum += delta
	var step := 1.0 / UPDATE_HZ
	if _accum >= step:
		_accum -= step
		_update_arrow_immediate()

func _update_arrow_immediate() -> void:
	# Map bait_y in [_bottom_y .. _surface_y] to Arrow Y in [bottom_px .. top_px]
	var r := get_rect()
	var top_px := r.position.y + 8.0
	var bottom_px := r.position.y + r.size.y - 8.0

	var depth_span := _surface_y - _bottom_y  # note: surface > bottom (less negative)
	if absf(depth_span) < 0.0001:
		depth_span = 0.0001

	var t := (_last_bait_y - _bottom_y) / depth_span  # 0 at bottom, 1 at surface
	if t < 0.0:
		t = 0.0
	elif t > 1.0:
		t = 1.0

	var y_px := lerp(bottom_px, top_px, t)

	var pos := _arrow.position
	pos.y = y_px - r.position.y - _arrow.size.y * 0.5
	_arrow.position = pos

func _pick_ground_texture() -> void:
	var depth := _surface_y - _bottom_y
	if depth < _min_depth_for_mid:
		_ground.texture = shallow_tex
	elif depth < _min_depth_for_deep:
		_ground.texture = mid_tex
	else:
		_ground.texture = deep_tex
