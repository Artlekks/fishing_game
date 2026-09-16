extends CanvasLayer

@onready var root: Control = $Root
@onready var fill: Sprite2D = $Root/PowerBarFill
@onready var tension_meter: Sprite2D = $Root/TensionMeter
@onready var distance_value: Control = $Root/DistanceValue
@onready var distance_decimal: Control = $Root/DistanceDecimal

@export var power: Node
@export var encounter: Node
@export var caster: Node

@export_category("Bar Textures")
@export var bar_green: Texture2D
@export var bar_red: Texture2D
@export var bar_blue: Texture2D

@export_category("Transitions")
@export var slide_time: float = 0.25
@export var slide_padding_px: float = 12.0

var full_scale_x: float = 1.0
var showing_tension: bool = false

var _rest_position: Vector2 = Vector2.ZERO
var _slide_tween: Tween = null
var _cancel_to_aim_pending: bool = false


func _ready() -> void:
	full_scale_x = fill.scale.x
	_rest_position = root.position

	power.power_changed.connect(_on_power_changed)
	power.started.connect(_on_power_started)
	power.stopped.connect(_on_power_stopped)

	encounter.tension_changed.connect(_on_tension_changed)
	encounter.hook_off.connect(_on_fishing_ended)
	encounter.line_broken.connect(_on_fishing_ended)
	encounter.fish_caught.connect(_on_fishing_ended)
	encounter.tension_state_changed.connect(_on_tension_state_changed)

	caster.bait_returned.connect(_on_bait_returned)
	caster.bait_distance_changed.connect(_on_bait_distance_changed)
	
	root.visible = false
	tension_meter.visible = false
	
func _on_bait_distance_changed(distance_meters: float) -> void:
	var scaled_distance := maxi(
		int(round(maxf(distance_meters, 0.0) * 10.0)),
		0
	)

	var whole := int(scaled_distance / 10)
	var decimal := scaled_distance % 10

	distance_value.set_text(str(whole))
	distance_decimal.set_text(str(decimal))

func _on_power_started() -> void:
	distance_value.set_text("0")
	distance_decimal.set_text("0")
	_cancel_to_aim_pending = false
	showing_tension = false

	tension_meter.visible = false
	fill.texture = bar_green
	_set_fill(0.0)

	_slide_in_from_bottom()


func _on_power_stopped() -> void:
	# A cancel also stops the power mechanic, but it must NOT switch
	# the HUD into tension mode.
	if _cancel_to_aim_pending:
		return

	# The cast has been confirmed.
	# The same gauge now becomes the fishing/tension gauge.
	showing_tension = true

	root.visible = true
	tension_meter.visible = true

	_set_fill(0.0)


func cancel_to_aim() -> void:
	_cancel_to_aim_pending = true
	showing_tension = false

	tension_meter.visible = false
	fill.texture = bar_green
	_set_fill(0.0)

	_slide_out_to_bottom()


func _on_power_changed(value: float) -> void:
	if showing_tension:
		return

	_set_fill(value)


func _on_tension_changed(value: float) -> void:
	if not showing_tension:
		return

	_set_fill(value)


func _on_fishing_ended() -> void:
	_cancel_to_aim_pending = false
	showing_tension = false

	_set_fill(0.0)

	tension_meter.visible = false
	_slide_out_to_bottom()


func _on_bait_returned() -> void:
	_cancel_to_aim_pending = false
	showing_tension = false

	_set_fill(0.0)

	tension_meter.visible = false
	_slide_out_to_bottom()


func _set_fill(value: float) -> void:
	fill.scale.x = full_scale_x * clampf(value, 0.0, 1.0)


func _on_tension_state_changed(state: int) -> void:
	match state:
		FishingTension.State.SLACK:
			fill.texture = bar_blue

		FishingTension.State.SAFE:
			fill.texture = bar_green

		FishingTension.State.OVERLOAD:
			fill.texture = bar_red


func _slide_in_from_bottom() -> void:
	_kill_slide_tween()

	var start_position := _get_offscreen_bottom_position()

	root.position = start_position
	root.visible = true

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(
		root,
		"position",
		_rest_position,
		slide_time
	)

	_slide_tween = tween


func _slide_out_to_bottom() -> void:
	_kill_slide_tween()

	if not root.visible:
		_cancel_to_aim_pending = false
		root.position = _rest_position
		return

	var end_position := _get_offscreen_bottom_position()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(
		root,
		"position",
		end_position,
		slide_time
	)
	tween.tween_callback(_finish_cancel_slide_out)

	_slide_tween = tween


func _finish_cancel_slide_out() -> void:
	root.visible = false
	root.position = _rest_position
	_cancel_to_aim_pending = false
	_slide_tween = null


func _hide_immediate() -> void:
	_kill_slide_tween()
	root.visible = false
	root.position = _rest_position


func _kill_slide_tween() -> void:
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()

	_slide_tween = null


func _get_offscreen_bottom_position() -> Vector2:
	# Work from the approved resting position, even if a tween is
	# currently part-way through.
	var current_position := root.position
	root.position = _rest_position
	var rest_global_y := root.global_position.y
	root.position = current_position

	var viewport_rect := get_viewport().get_visible_rect()
	var viewport_bottom := (
		float(viewport_rect.position.y)
		+ float(viewport_rect.size.y)
	)

	var visual_height := maxf(root.size.y, 1.0)
	var shift_y := (
		viewport_bottom
		- rest_global_y
		+ visual_height
		+ slide_padding_px
	)

	return _rest_position + Vector2(
		0.0,
		maxf(shift_y, slide_padding_px)
	)
