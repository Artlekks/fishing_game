extends Node

@export var game_mode: Node

func _unhandled_input(event: InputEvent) -> void:
	if game_mode == null:
		return

	if not game_mode.is_fishing():
		return

	if event.is_action_pressed("cancel_fishing"):
		game_mode.set_mode(game_mode.Mode.EXPLORATION)
		print("Mode:", game_mode.current_mode)
