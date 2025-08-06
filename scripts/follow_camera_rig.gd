extends Node3D

@export var target_path: NodePath
@export var follow_speed: float = 8.0
@export var position_offset: Vector3 = Vector3(0, 2, 0)
@export var match_rotation: bool = false
@export var rotation_lerp_speed: float = 6.0

var target: Node3D

func _ready() -> void:
	if not has_node(target_path):
		push_error("FollowCameraRig: Invalid or missing target_path.")
		set_process(false)
		return

	target = get_node(target_path)
	if not target is Node3D:
		push_error("FollowCameraRig: Target must be a Node3D-compatible type.")
		set_process(false)

func _process(delta: float) -> void:
	if not target:
		return

	# POSITION FOLLOW
	var desired_pos: Vector3 = target.global_position + position_offset
	position = position.lerp(desired_pos, clamp(delta * follow_speed, 0.0, 1.0))

	# ROTATION FOLLOW (optional)
	if match_rotation:
		var target_rot: Quaternion = target.global_transform.basis.get_rotation_quaternion()
		var current_rot: Quaternion = global_transform.basis.get_rotation_quaternion()
		var smoothed_rot: Quaternion = current_rot.slerp(target_rot, clamp(delta * rotation_lerp_speed, 0.0, 1.0))
		rotation = Basis(smoothed_rot).get_euler()
