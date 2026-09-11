extends Node3D

signal landed(point: Vector3)

@export var gravity: float = 24.0

var velocity: Vector3 = Vector3.ZERO
var water_y: float = 0.0
var flying: bool = false


func launch(start_position: Vector3, initial_velocity: Vector3, surface_y: float) -> void:
	global_position = start_position
	velocity = initial_velocity
	water_y = surface_y
	flying = true


func _physics_process(delta: float) -> void:
	if not flying:
		return

	velocity.y -= gravity * delta

	var previous_position := global_position
	var next_position := previous_position + velocity * delta

	if previous_position.y >= water_y and next_position.y <= water_y:
		next_position.y = water_y
		global_position = next_position

		flying = false
		landed.emit(global_position)
		return

	global_position = next_position
