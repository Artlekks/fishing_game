extends CanvasLayer

@onready var root: Control = $Root
@onready var fill: Sprite2D = $Root/PowerBarFill
@onready var tension_meter: Sprite2D = $Root/TensionMeter

@export var power: Node
@export var encounter: Node
@export var caster: Node
@export var tracked_target: Node3D
@export var camera: Camera3D
@export var screen_offset: Vector2 = Vector2(90.0, 50.0)

var full_scale_x: float = 1.0
var showing_tension: bool = false


func _ready() -> void:
	full_scale_x = fill.scale.x

	power.power_changed.connect(_on_power_changed)
	power.started.connect(_on_power_started)
	power.stopped.connect(_on_power_stopped)

	encounter.tension_changed.connect(_on_tension_changed)
	encounter.hook_off.connect(_on_fishing_ended)
	encounter.line_broken.connect(_on_fishing_ended)
	encounter.fish_caught.connect(_on_fishing_ended)

	caster.bait_returned.connect(_on_bait_returned)

	root.visible = false
	tension_meter.visible = false

	_set_fill(0.0)


func _on_power_started() -> void:
	showing_tension = false

	root.visible = true
	tension_meter.visible = false

	_set_fill(0.0)


func _on_power_stopped() -> void:
	# The cast has been confirmed.
	# The same gauge now becomes the fishing/tension gauge.
	showing_tension = true

	root.visible = true
	tension_meter.visible = true

	_set_fill(0.0)


func _on_power_changed(value: float) -> void:
	if showing_tension:
		return

	_set_fill(value)


func _on_tension_changed(value: float) -> void:
	if not showing_tension:
		return

	_set_fill(value)


func _on_fishing_ended() -> void:
	showing_tension = false

	_set_fill(0.0)

	tension_meter.visible = false
	root.visible = false


func _on_bait_returned() -> void:
	showing_tension = false

	_set_fill(0.0)

	tension_meter.visible = false
	root.visible = false


func _set_fill(value: float) -> void:
	fill.scale.x = full_scale_x * clampf(value, 0.0, 1.0)


func _process(_delta: float) -> void:
	if tracked_target == null or camera == null:
		return

	if camera.is_position_behind(tracked_target.global_position):
		return

	var screen_position := camera.unproject_position(
		tracked_target.global_position
	)

	root.position = screen_position + screen_offset
