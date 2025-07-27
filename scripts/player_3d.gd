extends Node3D

@onready var anim_tree = $AnimationTree
@onready var anim_state = anim_tree.get("parameters/playback")
@onready var anim_player = $AnimationPlayer

@onready var power_bar_layer = $power_bar_layer
@onready var power_bar_ui = $power_bar_layer/power_bar_ui
@onready var power_bar_fill = $power_bar_layer/power_bar_ui/PowerBarFill

var power := 0.0
var power_dir := 1
var charging := false
var power_bar_tween: Tween

var current_state := "prep_fishing"
var transitioning := false

const POWER_SPEED := 0.5
const POWERBAR_OFFSCREEN_Y := 800
const POWERBAR_ONSCREEN_Y := 500

func _ready():
	power_bar_fill.scale.x = 0.0
	power_bar_layer.visible = false
	power_bar_ui.position.y = POWERBAR_OFFSCREEN_Y

	anim_tree.active = true

	print("▶ Starting prep_fishing")
	await play_and_wait("prep_fishing")

	print("▶ → fishing_idle")
	await play_and_wait("fishing_idle")
	current_state = "fishing_idle"

func _unhandled_input(_event: InputEvent):
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

	# 👇 Power bar shows immediately
	power = 0.0
	power_dir = 1
	charging = true
	power_bar_fill.scale.x = 0.0
	power_bar_ui.position.y = POWERBAR_OFFSCREEN_Y
	power_bar_layer.visible = true

	power_bar_tween = create_tween()
	var track_in = power_bar_tween.tween_property(
		power_bar_ui, "position:y", POWERBAR_ONSCREEN_Y, 0.2
	)
	track_in.set_trans(Tween.TRANS_QUAD)
	track_in.set_ease(Tween.EASE_OUT)

	# THEN play the animations
	await play_and_wait("throw_line")
	await play_and_wait("throw_line_idle")

	print("▶ → throw_line_idle (waiting for 2nd K)")
	current_state = "throw_line_idle"
	transitioning = false


func finish_throw():
	print("▶ → throw_line_finish")
	current_state = "throw_line_finish"
	transitioning = true

	charging = false  # stop power fill, but leave bar visible

	var _locked_power = power  # placeholder until used

	await play_and_wait("throw_line_finish")

	print("▶ → throw_idle")
	current_state = "throw_idle"
	await play_and_wait("throw_idle")

	print("▶ throw complete. Waiting for bait logic...")
	transitioning = false


func play_and_wait(state_name: String) -> void:
	current_state = state_name
	anim_state.travel(state_name)

	var anim = anim_player.get_animation(state_name)
	if anim:
		await get_tree().create_timer(anim.length).timeout

func _process(delta):
	if charging:
		power += POWER_SPEED * power_dir * delta

		if power > 1.0:
			power = 1.0
			power_dir = -1
		elif power < 0.0:
			power = 0.0
			power_dir = 1

		power_bar_fill.scale.x = power
