extends Node

@export var game_mode: Node
@export var player: CharacterBody3D
@export var exploration_camera: Camera3D
@export var camera_rig: Node3D

func _ready() -> void:
	player.camera_reference = exploration_camera
	camera_rig.quarter_turned.connect(player.camera_quarter_turned)
	
func _unhandled_input(event: InputEvent) -> void:
	if game_mode == null:
		return

	if not game_mode.is_exploration():
		return

	if event.is_action_pressed("enter_fishing"):
		game_mode.set_mode(game_mode.Mode.FISHING)
		print("Mode:", game_mode.current_mode)

	if event.is_action_pressed("cam_right"):
		camera_rig.rotate_quarter_turn(1)

	if event.is_action_pressed("cam_left"):
		camera_rig.rotate_quarter_turn(-1)
