extends Marker3D

@export_category("References")
@export var anchor: Node3D
@export var camera: Camera3D

@export_category("Screen Position")
@export var screen_offset: Vector2 = Vector2(35.0, 25.0)

func _ready() -> void:
	# Make sure this updates after the normal camera logic.
	process_priority = 100

func _process(_delta: float) -> void:
	if anchor == null or camera == null:
		return

	var anchor_screen_position := camera.unproject_position(
		anchor.global_position
	)

	var target_screen_position := (
		anchor_screen_position
		+ screen_offset
	)

	# Depth of the anchor from the camera.
	var anchor_camera_space := camera.to_local(
		anchor.global_position
	)

	var depth := -anchor_camera_space.z

	if depth <= 0.0:
		return

	global_position = camera.project_position(
		target_screen_position,
		depth
	)
