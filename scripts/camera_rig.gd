extends Node3D

@export var target: Node3D
@export var fishing_pitch_deg: float = -15.0
@export var fishing_distance: float = 6.0
@export var fishing_height: float = 2.5

var fishing_entry_turn: float = 0.0
var exploration_yaw_before_fishing: float = 0.0
var exploration_camera_position: Vector3
var exploration_camera_rotation: Vector3

func _ready() -> void:
	var camera := $Camera3D
	exploration_camera_position = camera.position
	exploration_camera_rotation = camera.rotation
	
func _process(_delta: float) -> void:
	if target == null:
		return

	global_position = target.global_position

var is_rotating := false

func rotate_quarter_turn(direction: int) -> void:
	if is_rotating:
		return

	is_rotating = true

	var target_rotation := rotation.y + deg_to_rad(90.0 * direction)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation:y", target_rotation, 0.3)

	await tween.finished
	is_rotating = false

func enter_fishing_view(water_forward: Vector3) -> void:
	exploration_yaw_before_fishing = rotation.y
	
	var target_yaw := atan2(-water_forward.x, -water_forward.z)

	fishing_entry_turn = wrapf(
		target_yaw - rotation.y,
		-PI,
		PI
	)

	target_yaw = rotation.y + fishing_entry_turn

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation:y", target_yaw, 0.5)
	
func exit_fishing_view() -> void:
	var target_yaw := rotation.y - fishing_entry_turn

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation:y", target_yaw, 0.5)
