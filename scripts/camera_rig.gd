extends Node3D

@export var target: Node3D

@export var fishing_frame_right: float = 1.5
@export var fishing_frame_up: float = 0.5

var exploration_camera_position: Vector3

var fishing_entry_turn: float = 0.0
var is_rotating: bool = false


func _ready() -> void:
	exploration_camera_position = $Camera3D.position


func _process(_delta: float) -> void:
	if target == null:
		return

	global_position = target.global_position


func rotate_quarter_turn(direction: int) -> void:
	if is_rotating:
		return

	is_rotating = true

	var target_yaw := rotation.y + deg_to_rad(90.0 * direction)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation:y", target_yaw, 0.3)

	await tween.finished
	is_rotating = false


func enter_fishing_view(water_forward: Vector3) -> void:
	var target_yaw := atan2(
		-water_forward.x,
		-water_forward.z
	)

	fishing_entry_turn = wrapf(
		target_yaw - rotation.y,
		-PI,
		PI
	)

	target_yaw = rotation.y + fishing_entry_turn

	var camera: Camera3D = $Camera3D

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	# 1. Rotate behind Ryu.
	tween.tween_property(
		self,
		"rotation:y",
		target_yaw,
		0.5
	)

	# 2. Change framing using ONLY the Camera3D child.
	tween.tween_property(
		camera,
		"position",
		exploration_camera_position + Vector3(
			fishing_frame_right,
			fishing_frame_up,
			0.0
		),
		0.35
	)


func exit_fishing_view() -> void:
	var camera: Camera3D = $Camera3D

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	# First remove fishing framing.
	tween.tween_property(
		camera,
		"position",
		exploration_camera_position,
		0.35
	)

	# Then exactly reverse the entry rotation.
	var target_yaw := rotation.y - fishing_entry_turn

	tween.tween_property(
		self,
		"rotation:y",
		target_yaw,
		0.5
	)
