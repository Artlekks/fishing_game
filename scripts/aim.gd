extends Node

signal aim_changed(world_direction: Vector3)

@export var turn_speed_degrees: float = 60.0

var active: bool = false
var aim_yaw: float = 0.0


func _process(delta: float) -> void:
	if not active:
		return

	var input := Input.get_axis("ds_left", "ds_right")

	if is_zero_approx(input):
		return

	aim_yaw += deg_to_rad(turn_speed_degrees) * input * delta

	var direction := Vector3(
		sin(aim_yaw),
		0.0,
		cos(aim_yaw)
	)

	aim_changed.emit(direction)


func start(initial_direction: Vector3) -> void:
	aim_yaw = atan2(initial_direction.x, initial_direction.z)
	active = true

	aim_changed.emit(initial_direction.normalized())


func stop() -> void:
	active = false
