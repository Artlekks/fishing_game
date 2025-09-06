# res://fishing/bait.gd
extends Node3D

signal landed(point: Vector3)

@export var gravity: float = 24.0

var _vel: Vector3 = Vector3.ZERO
var _water_y: float = 0.0
var _active: bool = false

func start(at_position: Vector3, initial_velocity: Vector3, water_surface_y: float) -> void:
	global_position = at_position
	_vel = initial_velocity
	_water_y = water_surface_y
	_active = true
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if not _active:
		return

	# Integrate velocity with gravity
	_vel.y -= gravity * delta

	var curr := global_position
	var next := curr + _vel * delta

	# If we cross the water plane this frame, land exactly on it
	if curr.y >= _water_y and next.y <= _water_y:
		var denom := curr.y - next.y
		var t := 0.0
		if abs(denom) > 0.0001:
			t = (curr.y - _water_y) / denom
		var hit := curr.lerp(next, t)
		hit.y = _water_y
		global_position = hit
		_active = false
		set_physics_process(false)
		landed.emit(hit)
	else:
		global_position = next
