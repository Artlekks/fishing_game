extends CanvasLayer


@onready var root: Control = $Root
@onready var fish_portrait: TextureRect = $Root/FishPortrait


func _ready() -> void:
	root.visible = false


func show_catch(fish: FishInstance) -> void:
	if fish == null:
		return

	if fish.species == null:
		return

	if fish.species.portrait == null:
		return

	fish_portrait.texture = fish.species.portrait
	root.visible = true


func hide_catch() -> void:
	root.visible = false
