extends Node

@export_category("References")
@export var game_mode: Node
@export var exploration_hud: Node
@export var fishing_hud: Node


func _ready() -> void:
	if game_mode == null:
		push_warning("HudController: GameMode is not assigned.")
		return

	game_mode.mode_changed.connect(_on_mode_changed)
	_refresh_hud()


func _on_mode_changed(_new_mode: int) -> void:
	_refresh_hud()

func _refresh_hud() -> void:
	if exploration_hud != null:
		exploration_hud.visible = true

	if fishing_hud != null:
		fishing_hud.visible = game_mode.is_fishing()
