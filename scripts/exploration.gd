extends Node

@export var game_mode: Node
@export var player: CharacterBody3D
@export var exploration_camera: Camera3D
@export var camera_rig: Node3D
@export var fish_zone: Area3D

func _ready() -> void:
	player.camera_reference = exploration_camera
	game_mode.mode_changed.connect(_on_mode_changed)
	_on_mode_changed(game_mode.current_mode)

func _on_mode_changed(new_mode) -> void:
	set_active(new_mode == game_mode.Mode.EXPLORATION)
	
func _unhandled_input(event: InputEvent) -> void:
	if game_mode == null:
		return

	if not game_mode.is_exploration():
		return

	if event.is_action_pressed("enter_fishing"):
		if fish_zone != null and fish_zone.can_player_fish(player):
			game_mode.enter_fishing(fish_zone)

	if event.is_action_pressed("cam_right"):
		camera_rig.rotate_quarter_turn(1)

	if event.is_action_pressed("cam_left"):
		camera_rig.rotate_quarter_turn(-1)

func set_active(active: bool) -> void:
	player.movement_enabled = active
	set_process_unhandled_input(active)
