extends Node3D

@onready var anim_tree = $AnimationTree
@onready var anim_state = anim_tree.get("parameters/playback")
@onready var anim_player = $AnimationPlayer

var current_state := "prep_fishing"
var transitioning := false

func _ready():
	anim_tree.active = true

	print("▶ Starting prep_fishing")
	await play_and_wait("prep_fishing")

	print("▶ → fishing_idle")
	await play_and_wait("fishing_idle")
	current_state = "fishing_idle"

func _unhandled_input(_event: InputEvent):  # <- warning fixed
	if transitioning:
		return

	if Input.is_action_just_pressed("throw_line"):
		match current_state:
			"fishing_idle":
				start_throw()
			"throw_line_idle":
				finish_throw()

func start_throw():
	print("▶ → throw_line")
	current_state = "throw_line"
	transitioning = true
	await play_and_wait("throw_line")

	print("▶ → throw_line_idle (waiting for 2nd K)")
	current_state = "throw_line_idle"
	await play_and_wait("throw_line_idle")

	transitioning = false  # ready for second K press

func finish_throw():
	print("▶ → throw_line_finish")
	current_state = "throw_line_finish"
	transitioning = true
	await play_and_wait("throw_line_finish")

	print("▶ → throw_idle")
	current_state = "throw_idle"
	await play_and_wait("throw_idle")

	# You’ll replace this later when bait touches water
	print("▶ throw complete. Waiting for bait logic...")
	transitioning = false

func play_and_wait(state_name: String) -> void:
	current_state = state_name
	anim_state.travel(state_name)

	var anim = anim_player.get_animation(state_name)
	if anim:
		await get_tree().create_timer(anim.length).timeout
