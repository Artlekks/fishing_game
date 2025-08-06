extends Node3D

@export var target_path: NodePath  # Drag the player here in the inspector
@export var follow_speed: float = 8.0
@export var position_offset: Vector3 = Vector3(0, 2, 0)
@export var match_rotation: bool = false
@export var rotation_lerp_speed: float = 6.0

var target: Node3D

func _ready():
	if has_node(target_path):
		target = get_node(target_path)
	else:
		push_warning("Invalid target path on follower.")

func _process(delta):
	if not target:
		return

	# Smooth position follow
	var target_position = target.global_transform.origin + position_offset
	global_transform.origin = global_transform.origin.lerp(target_position, delta * follow_speed)

	# Optional rotation matching
	if match_rotation:
		var target_rot = target.global_transform.basis.get_rotation_quaternion()
		var current_rot = global_transform.basis.get_rotation_quaternion()
		var new_rot = current_rot.slerp(target_rot, delta * rotation_lerp_speed)
		global_transform.basis = Basis(new_rot)
