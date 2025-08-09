extends Node3D

@export var target_path: NodePath
@export var offset: Vector3 = Vector3(0, 8, -8)

var target: Node3D
var follow_enabled: bool = true

func _ready():
	if has_node(target_path):
		target = get_node(target_path) as Node3D
	else:
		push_error("Invalid target_path on CameraRig.")
		set_process(false)

func _process(_delta: float) -> void:
	if not follow_enabled or not target:
		return
	global_position = target.global_position + offset

# --- called by FishingModeController ---
func set_follow_enabled(enabled: bool) -> void:
	follow_enabled = enabled
