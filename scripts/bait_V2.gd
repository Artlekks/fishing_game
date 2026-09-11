extends Node3D

signal landed(point: Vector3)
signal returned

@export var gravity: float = 24.0
@export var return_distance: float = 0.5
@export var data: BaitData

var reel_steering: float = 0.0

enum State {
	IDLE,
	FLYING,
	SINKING,
	IN_WATER
}

var state: int = State.IDLE

var velocity: Vector3 = Vector3.ZERO

var water_y: float = 0.0
var sink_target_y: float = 0.0

var reel_target: Node3D = null
var reeling: bool = false


func launch(
	start_position: Vector3,
	initial_velocity: Vector3,
	surface_y: float
) -> void:
	global_position = start_position
	velocity = initial_velocity
	water_y = surface_y
	state = State.FLYING


func set_reel_target(target: Node3D) -> void:
	reel_target = target


func set_reeling(active: bool) -> void:
	reeling = active

	if not reeling and global_position.y > sink_target_y:
		if state == State.IN_WATER:
			state = State.SINKING


func set_reel_steering(value: float) -> void:
	reel_steering = clampf(value, -1.0, 1.0)


func _physics_process(delta: float) -> void:
	match state:
		State.FLYING:
			_update_flying(delta)

		State.SINKING, State.IN_WATER:
			if reeling:
				_update_reeling(delta)
			elif state == State.SINKING:
				_update_sinking(delta)


func _update_flying(delta: float) -> void:
	velocity.y -= gravity * delta

	var previous_position := global_position
	var next_position := previous_position + velocity * delta

	if previous_position.y >= water_y and next_position.y <= water_y:
		next_position.y = water_y
		global_position = next_position

		landed.emit(global_position)

		sink_target_y = water_y - data.sink_depth
		state = State.SINKING
		return

	global_position = next_position


func _update_sinking(delta: float) -> void:
	global_position.y = move_toward(
		global_position.y,
		sink_target_y,
		data.sink_speed * delta
	)

	if is_equal_approx(global_position.y, sink_target_y):
		state = State.IN_WATER


func _update_reeling(delta: float) -> void:
	if reel_target == null:
		return

	var target_position := reel_target.global_position

	var to_target := Vector3(
		target_position.x - global_position.x,
		0.0,
		target_position.z - global_position.z
	)

	var distance := to_target.length()

	# Close enough: finish the reel immediately.
	if distance <= return_distance:
		reeling = false
		returned.emit()
		return

	var forward := to_target.normalized()
	var side := Vector3.UP.cross(forward).normalized()

	# Steering gradually disappears as the bait approaches Ryu.
	var steering_fade := clampf(distance / 2.0, 0.0, 1.0)

	var reel_direction := (
		forward
		+ side * reel_steering * data.reel_steer_strength * steering_fade
	).normalized()

	var move_distance := data.reel_speed * delta

	# Never step past the target.
	if move_distance >= distance:
		global_position.x = target_position.x
		global_position.z = target_position.z

		reeling = false
		returned.emit()
		return

	global_position += reel_direction * move_distance

	global_position.y = move_toward(
		global_position.y,
		water_y,
		data.reel_rise_speed * delta
	)

func set_data(new_data: BaitData) -> void:
	data = new_data
