extends Node

enum Mode {
	EXPLORATION,
	FISHING
}

var current_mode: Mode = Mode.EXPLORATION

signal mode_changed(new_mode: Mode)

func set_mode(new_mode: Mode) -> void:
	if current_mode == new_mode:
		return

	current_mode = new_mode
	mode_changed.emit(current_mode)

func is_exploration() -> bool:
	return current_mode == Mode.EXPLORATION

func is_fishing() -> bool:
	return current_mode == Mode.FISHING
