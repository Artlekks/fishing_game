extends Node3D

@export var target: Node3D

@export var fishing_h_offset: float = 0.9
@export var fishing_v_offset: float = 0.6

var exploration_h_offset: float = 0.0
var exploration_v_offset: float = 0.0

var fishing_entry_turn: float = 0.0
var is_rotating: bool = false


func _ready() -> void:
	var camera: Camera3D = $Camera3D

	exploration_h_offset = camera.h_offset
	exploration_v_offset = camera.v_offset


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
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)

	# 1. Rotate behind Ryu.
	tween.tween_property(
		self,
		"rotation:y",
		target_yaw,
		0.7
	)

	# 2. Then shift the screen framing.
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


func exit_fishing_view() -> void:
	var camera: Camera3D = $Camera3D

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)

	# 1. Recenter Ryu on screen.
	tween.tween_property(
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

	# 2. Then reverse the exact entry rotation.
	var target_yaw := rotation.y - fishing_entry_turn

	tween.tween_property(
		self,
		"rotation:y",
		target_yaw,
		0.7
	)
