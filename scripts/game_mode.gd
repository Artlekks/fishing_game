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
	
var active_fish_zone: Area3D = null

func enter_fishing(zone: Area3D) -> void:
	active_fish_zone = zone
	set_mode(Mode.FISHING)

func exit_fishing() -> void:
	set_mode(Mode.EXPLORATION)
	active_fish_zone = null
