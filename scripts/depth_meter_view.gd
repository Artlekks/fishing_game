extends Control

@export_category("References")
@export var caster: Node

@export_category("Depth Display")
@export var max_display_depth: float = 4.0

# Where the water/ground boundary exists inside DepthStrip.
# 0.5 means exactly halfway down the long texture.
@export_range(0.0, 1.0, 0.01)
var ground_line_ratio: float = 0.5

@export_category("Transition")
@export var slide_time: float = 0.55
@export var slide_padding: float = 20.0

@onready var depth_window: Control = $DepthWindow
@onready var depth_strip: Control = $DepthWindow/DepthStrip
@onready var arrow: Control = $Arrow

var rest_position: Vector2
var slide_tween: Tween
var is_shown: bool = false

func _ready() -> void:
	if caster == null:
		push_warning("DepthMeter: Caster is not assigned.")
		return

	caster.bait_depth_changed.connect(_on_depth_changed)
	caster.bait_returned.connect(_on_bait_returned)

	depth_window.clip_contents = true

	rest_position = position
	visible = false


func _on_depth_changed(
	current_depth: float,
	total_depth: float
) -> void:
	if not is_shown:
		_slide_in()

	current_depth = maxf(current_depth, 0.0)
	total_depth = maxf(total_depth, 0.0)

	_update_depth_strip(total_depth)
	_update_arrow(current_depth, total_depth)


func _update_depth_strip(total_depth: float) -> void:
	var depth_ratio := clampf(
		total_depth / max_display_depth,
		0.0,
		1.0
	)

	# Pixel position of the water/ground boundary
	# inside the long DepthStrip image.
	var ground_line_y := (
		depth_strip.size.y
		* ground_line_ratio
	)

	# Where that boundary should appear inside
	# the visible DepthWindow.
	var target_ground_y := (
		depth_window.size.y
		* depth_ratio
	)

	depth_strip.position.y = (
		target_ground_y
		- ground_line_y
	)


func _update_arrow(
	current_depth: float,
	total_depth: float
) -> void:
	var bait_ratio := 0.0

	if total_depth > 0.0:
		bait_ratio = clampf(
			current_depth / total_depth,
			0.0,
			1.0
		)

	var ground_ratio := clampf(
		total_depth / max_display_depth,
		0.0,
		1.0
	)

	var arrow_half_height := arrow.size.y * 0.5

	var water_top_y := (
		depth_window.position.y
		- arrow_half_height
	)

	var water_bottom_y := (
		depth_window.position.y
		+ depth_window.size.y * ground_ratio
		- arrow_half_height
	)

	arrow.position.y = lerpf(
		water_top_y,
		water_bottom_y,
		bait_ratio
	)


func _on_bait_returned() -> void:
	_slide_out()

func _slide_in() -> void:
	if slide_tween != null and slide_tween.is_valid():
		slide_tween.kill()

	is_shown = true
	visible = true

	var viewport_width := get_viewport_rect().size.x
	position = Vector2(
		viewport_width + slide_padding,
		rest_position.y
	)

	slide_tween = create_tween()
	slide_tween.set_trans(Tween.TRANS_SINE)
	slide_tween.set_ease(Tween.EASE_OUT)

	slide_tween.tween_property(
		self,
		"position",
		rest_position,
		slide_time
	)


func _slide_out() -> void:
	if not is_shown:
		return

	if slide_tween != null and slide_tween.is_valid():
		slide_tween.kill()

	is_shown = false

	var viewport_width := get_viewport_rect().size.x
	var offscreen_position := Vector2(
		viewport_width + slide_padding,
		rest_position.y
	)

	slide_tween = create_tween()
	slide_tween.set_trans(Tween.TRANS_SINE)
	slide_tween.set_ease(Tween.EASE_IN)

	slide_tween.tween_property(
		self,
		"position",
		offscreen_position,
		slide_time
	)

	slide_tween.tween_callback(_finish_slide_out)


func _finish_slide_out() -> void:
	visible = false
	position = rest_position

func reset_to_aim() -> void:
	if slide_tween != null and slide_tween.is_valid():
		slide_tween.kill()

	slide_tween = null
	is_shown = false
	visible = false
	position = rest_position
