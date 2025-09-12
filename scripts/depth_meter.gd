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
var _bait_ref: Node3D = null

func _ready() -> void:
	visible = false
	set_process(false)

# Called when casting finished and the bait is in water
func show_with_bounds(surface_y: float, bottom_y: float) -> void:
	_surface_y = surface_y
	_bottom_y = bottom_y
	_select_ground_texture()
	visible = true
	_update_arrow_immediate()
	
# Let the widget follow the actual bait node on its own
func set_bait_ref(bait: Node3D) -> void:
	_bait_ref = bait

# External push is still accepted (safe no-op if you keep it)
# --- called continuously by the gate (signal + polling) ---
func set_bait_y(bait_y: float) -> void:
	_last_bait_y = bait_y
	_update_arrow_immediate()

func hide_meter() -> void:
	visible = false

func _process(_dt: float) -> void:
	if _bait_ref != null:
		var y: float = _bait_ref.global_position.y
		# Pull live Y every frame so the arrow always mirrors the bait
		set_bait_y(y)

func _update_arrow_immediate() -> void:
	if _arrow == null or _frame == null:
		return

	# lane inside the frame, top -> bottom in local pixels
	var r: Rect2 = _frame.get_rect()                    # local rect of the frame
	var top_px: float = r.position.y + track_top_inset_px
	var bottom_px: float = r.position.y + r.size.y - track_ground_align_px
	var lane: float = bottom_px - top_px
	if lane < 0.001:
		lane = 0.001

	# map world Y (bottom..surface) -> t in [0..1]
	var span: float = _surface_y - _bottom_y            # surface is higher (less negative)
	if abs(span) < 0.0001:
		span = 0.0001
	var t: float = (_last_bait_y - _bottom_y) / span    # 0 at bottom, 1 at surface
	if t < 0.0:
		t = 0.0
	elif t > 1.0:
		t = 1.0

	# convert t -> pixel Y (bottom up)
	var y_px: float = bottom_px - lane * t

	# place arrow (keep X set in editor)
	var pos: Vector2 = _arrow.position
	# align by top-left of arrow; if you want center, subtract _arrow.size.y * 0.5
	pos.y = y_px
	_arrow.position = pos

func _select_ground_texture() -> void:
	if _ground == null:
		return
	var depth: float = _surface_y - _bottom_y
	var mid_th: float = 1.2
	var deep_th: float = 2.2
	if depth < mid_th and shallow_tex != null:
		_ground.texture = shallow_tex
	elif depth < deep_th and mid_tex != null:
		_ground.texture = mid_tex
	elif deep_tex != null:
		_ground.texture = deep_tex
