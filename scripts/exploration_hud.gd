extends CanvasLayer

@onready var cast_ready_overlay: TextureRect = $Root/Compass/CastReadyOverlay
@onready var cast_ready_animation: AnimationPlayer = $Root/Compass/AnimationPlayer
@onready var menu: TextureRect = $Root/HelpPanel/Menu
@onready var menu_cast: TextureRect = $Root/HelpPanel/Menu_Cast

@export_category("References")
@export var exploration: Node


func _ready() -> void:
	set_cast_available(false)

	if exploration == null:
		push_warning("ExplorationHud: Exploration is not assigned.")
		return

	exploration.cast_availability_changed.connect(
		_on_cast_availability_changed
	)

func _on_cast_availability_changed(available: bool) -> void:
	set_cast_available(available)
	
func set_cast_available(available: bool) -> void:
	menu.visible = not available
	menu_cast.visible = available

	if available:
		cast_ready_overlay.visible = true

		if not cast_ready_animation.is_playing():
			cast_ready_animation.play("cast_ready")
	else:
		cast_ready_animation.stop()
		cast_ready_overlay.visible = false
