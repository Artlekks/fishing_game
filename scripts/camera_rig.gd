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
@export_category("Fishing Follow")
@export_range(0.1, 0.9, 0.05)

var fishing_follow_trigger_y_ratio: float = 0.50
var fishing_aim_active: bool = false
var fishing_aim_target_yaw: float = 0.0
var exploration_h_offset: float = 0.0
var exploration_v_offset: float = 0.0
var exploration_yaw_before_fishing: float = 0.0
var is_rotating: bool = false
var _last_heading_yaw: float = 0.0
var fishing_follow_target: Node3D = null

var fishing_follow_direction: Vector3 = Vector3.ZERO
var fishing_follow_cast_origin: Vector3 = Vector3.ZERO
var fishing_follow_base_position: Vector3 = Vector3.ZERO

var fishing_follow_water_y: float = 0.0
var fishing_follow_activation_progress: float = 0.0
var fishing_follow_offset: float = 0.0

var fishing_follow_armed: bool = false
var fishing_follow_active: bool = false
var fishing_camera_frozen: bool = false

func _ready() -> void:
	var camera: Camera3D = $Camera3D

	exploration_h_offset = camera.h_offset
	exploration_v_offset = camera.v_offset

func _process(_delta: float) -> void:
	if fishing_camera_frozen:
		return

	if target == null:
		return

	var follow_controls_position := _update_fishing_follow()

	if not follow_controls_position:
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

func arm_fishing_follow(
	track_target: Node3D,
	cast_direction: Vector3,
	water_y: float
) -> void:
	if not is_instance_valid(track_target):
		return

	var direction := cast_direction
	direction.y = 0.0

	if direction.length_squared() == 0.0:
		return

	direction = direction.normalized()

	fishing_follow_target = track_target
	fishing_follow_direction = direction
	fishing_follow_cast_origin = track_target.global_position
	fishing_follow_water_y = water_y

	fishing_follow_activation_progress = 0.0
	fishing_follow_offset = 0.0

	fishing_follow_armed = true
	fishing_follow_active = false


func reset_fishing_follow() -> void:
	fishing_follow_target = null

	fishing_follow_direction = Vector3.ZERO
	fishing_follow_cast_origin = Vector3.ZERO
	fishing_follow_base_position = Vector3.ZERO

	fishing_follow_water_y = 0.0
	fishing_follow_activation_progress = 0.0
	fishing_follow_offset = 0.0

	fishing_follow_armed = false
	fishing_follow_active = false

	if target != null:
		global_position = target.global_position


func _update_fishing_follow() -> bool:
	if not fishing_follow_armed and not fishing_follow_active:
		return false

	if not is_instance_valid(fishing_follow_target):
		if fishing_follow_active:
			global_position = (
				fishing_follow_base_position
				+ fishing_follow_direction * fishing_follow_offset
			)

			return true

		fishing_follow_armed = false
		return false

	var current_position := fishing_follow_target.global_position

	if fishing_follow_armed:
		var camera: Camera3D = $Camera3D

		# Ignore the height of the casting arc when deciding
		# when the camera should begin following.
		var projected_position := current_position
		projected_position.y = fishing_follow_water_y

		if not camera.is_position_behind(projected_position):
			var screen_position := camera.unproject_position(
				projected_position
			)

			var viewport_height := (
				get_viewport().get_visible_rect().size.y
			)

			var trigger_y := (
				viewport_height
				* fishing_follow_trigger_y_ratio
			)

			if screen_position.y <= trigger_y:
				fishing_follow_armed = false
				fishing_follow_active = true

				fishing_follow_base_position = global_position

				fishing_follow_activation_progress = (
					current_position
						- fishing_follow_cast_origin
				).dot(fishing_follow_direction)

	if not fishing_follow_active:
		return false

	var current_progress := (
		current_position
			- fishing_follow_cast_origin
	).dot(fishing_follow_direction)

	fishing_follow_offset = maxf(
		current_progress
			- fishing_follow_activation_progress,
		0.0
	)

	global_position = (
		fishing_follow_base_position
			+ fishing_follow_direction * fishing_follow_offset
	)

	return true
	
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

func set_fishing_camera_frozen(active: bool) -> void:
	fishing_camera_frozen = active
