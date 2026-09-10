extends Node

@export var game_mode: Node
@export var camera_rig: Node3D

func _ready() -> void:
	game_mode.mode_changed.connect(_on_mode_changed)
	_on_mode_changed(game_mode.current_mode)

func _on_mode_changed(new_mode) -> void:
	var active: bool = new_mode == game_mode.Mode.FISHING
	set_process_unhandled_input(active)

	if active:
		camera_rig.enter_fishing_view()
	
func _unhandled_input(event: InputEvent) -> void:
	if game_mode == null:
		return

	if not game_mode.is_fishing():
		return

	if event.is_action_pressed("cancel_fishing"):
		game_mode.set_mode(game_mode.Mode.EXPLORATION)
		print("Mode:", game_mode.current_mode)
