extends Node

@export var camera: Camera3D
var is_in_fishing_zone := false
var fishing_target_position: Vector3
var original_follow_mode := true

func enter_fishing_mode(focus_pos: Vector3):
	is_in_fishing_zone = true
	fishing_target_position = focus_pos
	original_follow_mode = false

func exit_fishing_mode():
	is_in_fishing_zone = false
	original_follow_mode = true

func _process(delta):
	if is_in_fishing_zone:
		var target = fishing_target_position
		camera.global_transform.origin = camera.global_transform.origin.lerp(target, 8.0 * delta)
