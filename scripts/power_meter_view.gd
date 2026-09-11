extends CanvasLayer

@export var power: Node

@onready var root: Control = $Root
@onready var fill: Sprite2D = $Root/PowerBarFill
@export var tracked_target: Node3D
@export var camera: Camera3D
@export var screen_offset: Vector2 = Vector2(90.0, 50.0)

var full_scale_x: float = 1.0


func _ready() -> void:
	full_scale_x = fill.scale.x

	power.power_changed.connect(_on_power_changed)
	power.started.connect(_on_power_started)
	power.stopped.connect(_on_power_stopped)

	root.visible = false
	_on_power_changed(0.0)


func _on_power_started() -> void:
	root.visible = true


func _on_power_stopped() -> void:
	root.visible = false


func _on_power_changed(value: float) -> void:
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
