extends Node3D

signal bait_landed(point: Vector3)
signal bait_returned

@export var bait_scene: PackedScene
@export var spawn_point: Node3D

@export var min_speed: float = 1.0
@export var max_speed: float = 10.0
@export var launch_angle_degrees: float = 45.0
@export var selected_bait_data: BaitData

var active_bait: Node3D


func perform_cast(
	power: float,
	direction: Vector3,
	water_y: float
) -> void:
	if bait_scene == null or spawn_point == null:
		return

	if is_instance_valid(active_bait):
		active_bait.queue_free()

	direction.y = 0.0
	direction = direction.normalized()

	var speed := lerpf(min_speed, max_speed, clampf(power, 0.0, 1.0))
	var angle := deg_to_rad(launch_angle_degrees)

	var initial_velocity := Vector3(
		direction.x * speed * cos(angle),
		speed * sin(angle),
		direction.z * speed * cos(angle)
	)

	active_bait = bait_scene.instantiate()
	add_child(active_bait)
	
	if selected_bait_data != null:
		active_bait.set_data(selected_bait_data)
	
	active_bait.landed.connect(_on_bait_landed)

	active_bait.launch(
		spawn_point.global_position,
		initial_velocity,
		water_y
	)
	
	active_bait.set_reel_target(spawn_point)
	active_bait.returned.connect(_on_bait_returned)

func _on_bait_landed(point: Vector3) -> void:
	bait_landed.emit(point)

func set_reeling(active: bool) -> void:
	if is_instance_valid(active_bait):
		active_bait.set_reeling(active)


func _on_bait_returned() -> void:
	if is_instance_valid(active_bait):
		active_bait.queue_free()

	active_bait = null
	bait_returned.emit()

func set_reel_steering(value: float) -> void:
	if is_instance_valid(active_bait):
		active_bait.set_reel_steering(value)
