extends Node3D

@export var target: Node3D

func _process(_delta: float) -> void:
	if target == null:
		return

	global_position = target.global_position

signal quarter_turned(direction: int)

func rotate_quarter_turn(direction: int) -> void:
	rotation.y += deg_to_rad(90.0 * direction)
	quarter_turned.emit(direction)
