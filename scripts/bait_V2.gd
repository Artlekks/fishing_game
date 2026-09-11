extends Node3D

signal landed(point: Vector3)
signal returned
signal depth_changed(current_depth: float, total_depth: float)

@export var gravity: float = 24.0
@export var return_distance: float = 0.5
@export var data: BaitData
@export var floor_collision_mask: int = 2048
@export var floor_ray_depth: float = 100.0
@export var fight_reel_multiplier: float = 0.2
@export var max_fish_pull_speed: float = 1.5

var fish_pull_strength: float = 0.0
var fight_mode: bool = false
var reel_steering: float = 0.0
var fight_resistance: float = 1.0
var fish_lateral: float = 0.0

enum State {
	IDLE,
	FLYING,
	SINKING,
	IN_WATER
}

var state: int = State.IDLE

var velocity: Vector3 = Vector3.ZERO

var water_y: float = 0.0
var bottom_y: float = 0.0

var reel_target: Node3D = null
var reeling: bool = false


func launch(
	start_position: Vector3,
	initial_velocity: Vector3,
	surface_y: float,
	water_bottom_y: float
) -> void:
	global_position = start_position
	velocity = initial_velocity
	water_y = surface_y
	bottom_y = water_bottom_y
	state = State.FLYING

func set_reel_target(target: Node3D) -> void:
	reel_target = target


func set_reeling(active: bool) -> void:
	reeling = active

	if fight_mode:
		return

	if not reeling and global_position.y > bottom_y:
		if state == State.IN_WATER:
			state = State.SINKING

func set_reel_steering(value: float) -> void:
	reel_steering = clampf(value, -1.0, 1.0)


func _physics_process(delta: float) -> void:
	if state == State.SINKING or state == State.IN_WATER:
		_update_bottom_from_world()
	
	if fight_mode and not reeling and fish_pull_strength > 0.0:
		_update_fish_pull(delta)
	
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

		state = State.SINKING
		return

	global_position = next_position


func _update_sinking(delta: float) -> void:
	global_position.y = move_toward(
		global_position.y,
		bottom_y,
		data.sink_speed * delta
	)

	_emit_depth()

	if is_equal_approx(global_position.y, bottom_y):
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

	var reel_speed := data.reel_speed

	if fight_mode:
		var multiplier := lerpf(
			1.0,
			fight_reel_multiplier,
			fight_resistance
		)

		reel_speed *= multiplier

	var move_distance := reel_speed * delta

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

	_emit_depth()
	
func set_data(new_data: BaitData) -> void:
	data = new_data

func _emit_depth() -> void:
	var current_depth := water_y - global_position.y
	var total_depth := water_y - bottom_y

	depth_changed.emit(current_depth, total_depth)

func _update_bottom_from_world() -> void:
	var ray_from := Vector3(
		global_position.x,
		water_y + 0.5,
		global_position.z
	)

	var ray_to := Vector3(
		global_position.x,
		water_y - floor_ray_depth,
		global_position.z
	)

	var query := PhysicsRayQueryParameters3D.create(
		ray_from,
		ray_to,
		floor_collision_mask
	)

	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		return

	var hit_position: Vector3 = hit["position"]
	bottom_y = hit_position.y

	if global_position.y < bottom_y:
		global_position.y = bottom_y
		
func set_fight_mode(active: bool) -> void:
	fight_mode = active

	if fight_mode and state == State.SINKING:
		state = State.IN_WATER

func set_fight_resistance(value: float) -> void:
	fight_resistance = clampf(value, 0.0, 1.0)

func set_fish_pull_strength(value: float) -> void:
	fish_pull_strength = clampf(value, 0.0, 1.0)

func _update_fish_pull(delta: float) -> void:
	if reel_target == null:
		return

	var away := global_position - reel_target.global_position
	away.y = 0.0

	if away.length_squared() == 0.0:
		return

	away = away.normalized()

	var side := Vector3.UP.cross(away).normalized()

	var fish_direction := (
		away
		+ side * fish_lateral
	).normalized()

	global_position += (
		fish_direction
		* max_fish_pull_speed
		* fish_pull_strength
		* delta
	)

func set_fish_lateral(value: float) -> void:
	fish_lateral = clampf(value, -1.0, 1.0)
