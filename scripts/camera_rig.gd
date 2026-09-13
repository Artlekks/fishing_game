extends Node3D

signal fishing_view_ready
signal exploration_view_ready
signal heading_changed(yaw: float)
signal exploration_view_started

@export var target: Node3D

@export var fishing_h_offset: float = 0.9
@export var fishing_v_offset: float = 0.6
@export var aim_follow_speed: float = 6.0
@export var fishing_yaw_offset_degrees: float = -15.0

var fishing_aim_active: bool = false
var fishing_aim_target_yaw: float = 0.0
var exploration_h_offset: float = 0.0
var exploration_v_offset: float = 0.0

var exploration_yaw_before_fishing: float = 0.0
var is_rotating: bool = false
var _last_heading_yaw: float = 0.0

func _ready() -> void:
	var camera: Camera3D = $Camera3D

	exploration_h_offset = camera.h_offset
	exploration_v_offset = camera.v_offset

func _process(_delta: float) -> void:
	if target == null:
		return

	global_position = target.global_position

	if fishing_aim_active:
		rotation.y = lerp_angle(
			rotation.y,
			fishing_aim_target_yaw,
			clamp(aim_follow_speed * _delta, 0.0, 1.0)
		)

	if not is_equal_approx(rotation.y, _last_heading_yaw):
		_last_heading_yaw = rotation.y
		heading_changed.emit(rotation.y)

func rotate_quarter_turn(direction: int) -> void:
	if is_rotating:
		return

	is_rotating = true

	var target_yaw := rotation.y + deg_to_rad(90.0 * direction)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		self,
		"rotation:y",
		target_yaw,
		0.3
	)

	await tween.finished
	is_rotating = false


func enter_fishing_view() -> void:
	exploration_yaw_before_fishing = rotation.y

	if target == null:
		fishing_view_ready.emit()
		return

	var camera: Camera3D = $Camera3D

	var player_forward := target.global_transform.basis.z
	player_forward.y = 0.0
	player_forward = player_forward.normalized()

	var camera_forward := -camera.global_transform.basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()

	var yaw_difference := camera_forward.signed_angle_to(
		player_forward,
		Vector3.UP
	)

	var target_yaw := rotation.y + yaw_difference
	target_yaw += deg_to_rad(fishing_yaw_offset_degrees)
	
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		self,
		"rotation:y",
		target_yaw,
		0.7
	)

	tween.tween_property(
		camera,
		"h_offset",
		fishing_h_offset,
		0.5
	)

	tween.parallel().tween_property(
		camera,
		"v_offset",
		fishing_v_offset,
		0.5
	)

	await tween.finished
	fishing_view_ready.emit()

func exit_fishing_view() -> void:
	var camera: Camera3D = $Camera3D
		
	exploration_view_started.emit()
		
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.parallel().tween_property(
		self,
		"rotation:y",
		exploration_yaw_before_fishing,
		0.7
	)

	tween.parallel().tween_property(
		camera,
		"h_offset",
		exploration_h_offset,
		0.5
	)

	tween.parallel().tween_property(
		camera,
		"v_offset",
		exploration_v_offset,
		0.5
	)

	await tween.finished
	exploration_view_ready.emit()

func start_fishing_aim(direction: Vector3) -> void:
	fishing_aim_active = true
	set_fishing_aim_direction(direction)


func set_fishing_aim_direction(direction: Vector3) -> void:
	var camera: Camera3D = $Camera3D

	var desired_forward := direction
	desired_forward.y = 0.0

	if desired_forward.length_squared() == 0.0:
		return

	desired_forward = desired_forward.normalized()

	var camera_forward := -camera.global_transform.basis.z
	camera_forward.y = 0.0

	if camera_forward.length_squared() == 0.0:
		return

	camera_forward = camera_forward.normalized()

	var yaw_difference := camera_forward.signed_angle_to(
		desired_forward,
		Vector3.UP
	)

	fishing_aim_target_yaw = (
		rotation.y
		+ yaw_difference
		+ deg_to_rad(fishing_yaw_offset_degrees)
	)


func stop_fishing_aim() -> void:
	fishing_aim_active = false
