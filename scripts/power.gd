extends Node

signal power_changed(value: float)
signal power_captured(value: float)
signal started
signal stopped

@export var speed: float = 1.5

var active: bool = false
var value: float = 0.0
var direction: float = 1.0


func _process(delta: float) -> void:
	if not active:
		return

	value += speed * direction * delta

	if value >= 1.0:
		value = 1.0
		direction = -1.0

	elif value <= 0.0:
		value = 0.0
		direction = 1.0

	power_changed.emit(value)


func start() -> void:
	value = 0.0
	direction = 1.0
	active = true

	started.emit()
	power_changed.emit(value)


func capture() -> float:
	active = false

	stopped.emit()
	power_captured.emit(value)

	return value


func stop() -> void:
	active = false
	stopped.emit()
