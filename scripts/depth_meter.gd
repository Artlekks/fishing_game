extends Control

@export var frame_path: NodePath
@export var ground_path: NodePath
@export var arrow_path: NodePath

# --- Track definition ---
@export var use_explicit_track: bool = true            # ON = use the two numbers below
@export var track_surface_y_px: float = 18.0           # local Y where arrow sits when bait is at surface
@export var track_ground_y_px: float  = 132.0          # local Y where arrow sits when bait is on bottom
@export var track_top_inset_px: float = 8.0            # used only if use_explicit_track = false
@export var track_bottom_inset_px: float = 0.0         # used only if use_explicit_track = false
@export var arrow_tip_offset_px: float = 18.0          # distance from arrow node’s top to its tip

# optional shallow/mid/deep textures (assign in Inspector if you use them)
@export var shallow_tex: Texture2D
@export var mid_tex: Texture2D
@export var deep_tex: Texture2D
@export var min_depth_for_mid: float = 1.2
@export var min_depth_for_deep: float = 2.2

var _frame: TextureRect = null
var _ground: TextureRect = null
var _arrow: TextureRect = null

# world-space water bounds (set by your gate)
var _surface_y: float = 0.0
var _bottom_y: float = 0.0
var _last_bait_y: float = 0.0

# cached lane endpoints (local Y, in pixels)
var _lane_top_px: float = 0.0
var _lane_bottom_px: float = 0.0

func _ready() -> void:
	_frame = get_node_or_null(frame_path) as TextureRect
	_ground = get_node_or_null(ground_path) as TextureRect
	_arrow = get_node_or_null(arrow_path) as TextureRect

	# Compute initial lane
	_rebuild_lane_from_settings()

	# Force sane layout for arrow (Position mode so .position works as pixels)
	if _arrow != null:
		_arrow.size = _arrow.size  # touch to ensure the rect is valid

	# If the ground already has a texture, make sure it shows.
	_update_ground_visibility()

# --- Public API used by your gate ------------------------------------------------
func show_with_bounds(surface_y: float, bottom_y: float) -> void:
	_surface_y = surface_y
	_bottom_y = bottom_y
	_rebuild_lane_from_settings()
	_sync_ground_to_frame()

	# If Ground has no texture yet, fall back to shallow so it’s visible.
	if _ground != null and _ground.texture == null and shallow_tex != null:
		_ground.texture = shallow_tex
	_update_ground_visibility()
	visible = true

func hide_meter() -> void:
	visible = false

func set_bait_y(y: float) -> void:
	_last_bait_y = y
	_update_arrow_immediate()

# --- Internals -------------------------------------------------------------------

func _rebuild_lane_from_settings() -> void:
	# Determine lane endpoints (local Y, pixels) either explicitly or from the frame
	var top_px: float = 0.0
	var bottom_px: float = 0.0

	if use_explicit_track:
		top_px = track_surface_y_px
		bottom_px = track_ground_y_px
	else:
		if _frame == null:
			top_px = 0.0
			bottom_px = size.y
		else:
			var r: Rect2 = _frame.get_rect()
			top_px = r.position.y + track_top_inset_px
			bottom_px = r.position.y + r.size.y - track_bottom_inset_px

	# If someone swapped numbers, fix it so "top" < "bottom".
	if bottom_px < top_px:
		var tmp: float = top_px
		top_px = bottom_px
		bottom_px = tmp

	_lane_top_px = top_px
	_lane_bottom_px = bottom_px

func _update_arrow_immediate() -> void:
	if _arrow == null:
		return

	# Normalize bait Y: t=0 at bottom, t=1 at surface.
	var span: float = _surface_y - _bottom_y
	if absf(span) < 0.0001:
		span = 0.0001

	var t: float = (_last_bait_y - _bottom_y) / span
	if t < 0.0:
		t = 0.0
	elif t > 1.0:
		t = 1.0

	# Pixel Y along the lane, then align the arrow's TIP to that line.
	var y_px: float = lerpf(_lane_bottom_px, _lane_top_px, t)
	y_px -= arrow_tip_offset_px

	# Clamp into the lane (keep a small safety so the sprite never overflows).
	var min_y: float = _lane_top_px - arrow_tip_offset_px
	var max_y: float = _lane_bottom_px - arrow_tip_offset_px
	if y_px < min_y:
		y_px = min_y
	elif y_px > max_y:
		y_px = max_y

	var p: Vector2 = _arrow.position
	p.y = y_px
	_arrow.position = p

func _update_ground_visibility() -> void:
	if _ground != null:
		_ground.visible = _ground.texture != null

# Optional helper if you still pick a ground texture by depth value:
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
	_ground.texture = tex
	_update_ground_visibility()

func _sync_ground_to_frame() -> void:
	if _ground == null or _frame == null:
		return
	_ground.position = _frame.position
	_ground.size = _frame.size
	_ground.stretch_mode = TextureRect.STRETCH_SCALE  # SCALE or KEEP, your art choice
