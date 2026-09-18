extends CanvasLayer


@onready var root: Control = $Root
@onready var fish_portrait: TextureRect = $Root/FishPortrait


func _ready() -> void:
	root.visible = false


func show_catch(fish: FishInstance) -> void:
	# The result frame must ALWAYS appear.
	root.visible = true

	# Default to the baked placeholder artwork.
	fish_portrait.visible = false
	fish_portrait.texture = null

	if fish == null:
		push_warning("FishingCatchView: Received a null FishInstance.")
		return

	if fish.species == null:
		push_warning("FishingCatchView: Caught fish has no species.")
		return

	# Only replace the placeholder artwork if this species
	# actually has a portrait assigned.
	if fish.species.portrait != null:
		fish_portrait.texture = fish.species.portrait
		fish_portrait.visible = true

func hide_catch() -> void:
	root.visible = false
