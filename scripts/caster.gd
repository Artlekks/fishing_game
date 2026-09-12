extends Node3D

signal bait_landed(point: Vector3)
signal bait_returned
signal bait_depth_changed(current_depth: float, total_depth: float)

@export var bait_scene: PackedScene
@export var spawn_point: Node3D

@export var min_speed: float = 1.0
@export var max_speed: float = 10.0
@export var launch_angle_degrees: float = 45.0
@export var selected_bait_data: BaitData
@export var reel_target: Node3D

var active_bait: Node3D
var current_bait_depth: float = 0.0
var current_total_depth: float = 0.0

func perform_cast(
	power: float,
	direction: Vector3,
	water_y: float,
	bottom_y: float
) -> void:
	if bait_scene == null or spawn_point == null:
		return

	if is_instance_valid(active_bait):
		active_bait.queue_free()

	direction.y = 0.0
	direction = direction.normalized()

	var speed := lerpf(
		min_speed,
		max_speed,
		clampf(power, 0.0, 1.0)
	)

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
	active_bait.depth_changed.connect(_on_bait_depth_changed)
	active_bait.returned.connect(_on_bait_returned)

	active_bait.set_reel_target(reel_target)

	active_bait.launch(
		spawn_point.global_position,
		initial_velocity,
		water_y,
		bottom_y
	)


func _on_bait_landed(point: Vector3) -> void:
	bait_landed.emit(point)


func _on_bait_depth_changed(
	current_depth: float,
	total_depth: float
) -> void:
	current_bait_depth = current_depth
	current_total_depth = total_depth

	bait_depth_changed.emit(
		current_depth,
		total_depth
	)

func _on_bait_returned() -> void:
	if is_instance_valid(active_bait):
		active_bait.queue_free()

	active_bait = null
	bait_returned.emit()


func set_reeling(active: bool) -> void:
	if is_instance_valid(active_bait):
		active_bait.set_reeling(active)


func set_reel_steering(value: float) -> void:
	if is_instance_valid(active_bait):
		active_bait.set_reel_steering(value)

func twitch_bait(direction: float) -> void:
	if is_instance_valid(active_bait):
		active_bait.twitch_side(direction)
		
func set_fight_mode(active: bool) -> void:
	if is_instance_valid(active_bait):
		active_bait.set_fight_mode(active)

func set_fight_resistance(value: float) -> void:
	if is_instance_valid(active_bait):
		active_bait.set_fight_resistance(value)

func set_fish_pull_strength(value: float) -> void:
	if is_instance_valid(active_bait):
		active_bait.set_fish_pull_strength(value)

func set_fish_lateral(value: float) -> void:
	if is_instance_valid(active_bait):
		active_bait.set_fish_lateral(value)

func set_fish_depth_intent(value: float) -> void:
	if is_instance_valid(active_bait):
		active_bait.set_fish_depth_intent(value)

func get_current_bait_depth() -> float:
	return current_bait_depth

func get_current_total_depth() -> float:
	return current_total_depth

func cancel_bait() -> void:
	if is_instance_valid(active_bait):
		active_bait.queue_free()

	active_bait = null
