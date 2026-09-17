extends Node

@export var encounter: Node
@export var info_view: Node


func _ready() -> void:
	encounter.fish_resistance_started.connect(
		_on_fish_resistance_started
	)

	encounter.fish_spent.connect(
		_on_fish_spent
	)

	encounter.hook_off.connect(
		_on_hook_off
	)

	encounter.line_broken.connect(
		_on_line_broken
	)

func _on_fish_resistance_started() -> void:
	info_view.show_message(
		"The fish is thrashing about!"
	)


func _on_fish_spent() -> void:
	info_view.show_message(
		"The fish has calmed down."
	)

func _on_hook_off() -> void:
	info_view.show_message(
		"The fish got away with the lure!",
		2.0,
		FishingInfoView.Priority.CRITICAL
	)


func _on_line_broken() -> void:
	info_view.show_message(
		"Your line broke!",
		2.0,
		FishingInfoView.Priority.CRITICAL
	)
