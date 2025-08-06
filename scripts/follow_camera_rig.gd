extends Node3D

@export var target_path: NodePath
@export var offset: Vector3 = Vector3(0, 8, -8)  # tweak to match angle
var target: Node3D

func _ready():
	if has_node(target_path):
		target = get_node(target_path) as Node3D
	else:
		push_error("Invalid target_path on CameraRig.")
		set_process(false)

func _process(_delta):
	if not target:
		return
	global_position = target.global_position + offset
	# No look_at, no lerp—keep angle fixed
