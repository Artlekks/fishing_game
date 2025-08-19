extends CanvasLayer

@export var root_path: NodePath
@export var bg_path: NodePath
@export var fill_path: NodePath
@export var label_path: NodePath

@export var max_value: float = 100.0
@export var cycle_duration: float = 1.8   # seconds 0→100→0
@export var auto_hide_on_capture: bool = true
@export var use_crop_instead_of_scale: bool = false

var _root: Node2D
var _bg: Sprite2D
var _fill: Sprite2D
var _label: Label
var _tween: Tween
var _ratio: float = 0.0            # 0.0..1.0
var _base_scale_x: float = 1.0     # remembers initial scale.x for Fill
var _is_running: bool = false

func _ready() -> void:
	_root = get_node(root_path) as Node2D
	_bg = get_node(bg_path) as Sprite2D
	_fill = get_node(fill_path) as Sprite2D
	_label = get_node_or_null(label_path) as Label

	# Anchor scaling to the left edge; keep your vertical offset as-is.
	_fill.centered = false
	_fill.offset = Vector2(0.0, _fill.offset.y)  # X must be 0; keep your Y (-12) for alignment
	_fill.scale = Vector2(1, 1)
	_base_scale_x = 1.0

	hide()
	_set_ratio(0.0)


# ---- public API ------------------------------------------------------

## Call when entering Prep_Throw
func start() -> void:
	if _is_running:
		return
	show()
	_is_running = true
	_set_ratio(0.0)
	_make_pingpong_tween()

## Call during Prep_Throw_Idle when user confirms (K)
## Returns 0..max_value
func capture_power() -> float:
	var power := _ratio * max_value
	_stop_all()
	if auto_hide_on_capture:
		hide()
	return power

## Call on Cancel_Fishing or any exit
func cancel() -> void:
	_stop_all()
	hide()

## Optional: show predicted distance text
func set_distance_text(meters: float) -> void:
	if _label:
		_label.text = String.num(meters, 1) + " m"

# ---- internals -------------------------------------------------------

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

	if use_crop_instead_of_scale:
		if not _fill.region_enabled:
			_fill.region_enabled = true
			_fill.region_rect = Rect2(Vector2.ZERO, _fill.texture.get_size())

		var tex_size: Vector2 = _fill.texture.get_size()
		var full_w: float = tex_size.x
		# choose ONE of these two lines (both keep type = float):
		# var w: float = maxf(1.0, floor(full_w * _ratio))     # pixel step
		var w: float = clampf(full_w * _ratio, 1.0, full_w)    # smooth

		var rr: Rect2 = _fill.region_rect
		rr.size.x = w
		_fill.region_rect = rr
	else:
		var sx: float = _base_scale_x * _ratio
		_fill.scale = Vector2(sx, _fill.scale.y)
