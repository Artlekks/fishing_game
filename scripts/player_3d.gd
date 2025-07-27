extends Node3D

@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_state = anim_tree.get("parameters/playback")
@onready var anim_player: AnimationPlayer = $AnimationPlayer

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D

var current_state: String = "prep_fishing"
var transitioning: bool = false

func _ready():
	sprite.speed_scale = 0.0

	anim_tree.active = true

	print("▶ Starting prep_fishing")
	await play_state("prep_fishing")

	print("▶ → fishing_idle")
	await play_state("fishing_idle")

func _unhandled_input(event: InputEvent):
	if transitioning:
		return

	if Input.is_action_just_pressed("throw_line"):
		match current_state:
			"fishing_idle":
				start_throw()
			"throw_line_idle":
				finish_throw()

func start_throw():
	await play_state("throw_line")
	await play_state("throw_line_idle")  # waits for 2nd K

func finish_throw():
	await play_state("throw_line_finish")
	await play_state("throw_idle")

	# Optional for now — this will be replaced by bait landing logic later
	await play_state("reeling_idle")

func play_state(state_name: String) -> void:
	transitioning = true
	current_state = state_name
	print("▶ → %s" % state_name)

	anim_state.travel(state_name)

	await wait_for_anim(state_name)
	transitioning = false

func wait_for_anim(state_name: String) -> void:
	var anim_length = anim_player.get_animation(state_name).length
	await get_tree().create_timer(anim_length).timeout
