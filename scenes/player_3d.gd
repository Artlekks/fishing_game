extends Node3D

@onready var anim_tree = $AnimationTree
@onready var anim_state = anim_tree.get("parameters/playback")
@onready var anim_player = $AnimationPlayer

func _ready():
	anim_tree.active = true

	print("▶ Starting prep_fishing")

	anim_state.travel("prep_fishing")
	await get_tree().create_timer(anim_player.get_animation("prep_fishing").length).timeout

	print("▶ → fishing_idle")

	anim_state.travel("fishing_idle")
