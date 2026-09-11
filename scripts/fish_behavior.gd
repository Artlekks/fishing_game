extends Node

signal movement_changed(lateral: float)

@export var min_change_time: float = 0.8
@export var max_change_time: float = 2.0

var active: bool = false
var time_until_change: float = 0.0
var lateral: float = 0.0


func _process(delta: float) -> void:
	if not active:
		return

	time_until_change -= delta

	if time_until_change <= 0.0:
		_choose_new_movement()


func start() -> void:
	active = true
	_choose_new_movement()


func stop() -> void:
	active = false
	lateral = 0.0
	movement_changed.emit(lateral)


func _choose_new_movement() -> void:
	lateral = randf_range(-1.0, 1.0)

	time_until_change = randf_range(
		min_change_time,
		max_change_time
	)

	movement_changed.emit(lateral)
