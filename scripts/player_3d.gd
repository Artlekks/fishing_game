extends Node3D

# Animation
@onready var anim_tree = $AnimationTree
@onready var anim_state = anim_tree.get("parameters/playback")
@onready var anim_player = $AnimationPlayer

# UI - Power Bar
@onready var power_bar_layer = $power_bar_layer
@onready var power_bar_ui = $power_bar_layer/power_bar_ui
@onready var power_bar_fill = $power_bar_layer/power_bar_ui/PowerBarFill

# Bait and Scene References
@onready var bait_spawn = $BaitSpawn
@onready var fish_zone = get_tree().get_root().get_node("World3D/FishZone/Center")
@onready var direction_line = $DirectionLine
@onready var bait_target = $BaitTarget

# Bait
var bait_scene := preload("res://scenes/bait_3d.tscn")
var bait_instance: Node3D
var is_reeling := false
var is_bait_ready := false

# States
var current_state := "prep_fishing"
var transitioning := false

# Power bar
var power := 0.0
var power_dir := 1
var charging := false
var power_bar_tween: Tween
var power_bar_final_pos: Vector2

const POWER_SPEED := 0.5

# ---------------------------------------------------------
# INIT + RESET
# ---------------------------------------------------------

func _ready():
	power_bar_final_pos = power_bar_ui.position
	power_bar_ui.position.y = 800
	power_bar_layer.visible = false
	power_bar_fill.scale.x = 0.0

	direction_line.stop_loop()
	anim_tree.active = true

	print("▶ Starting prep_fishing")
	await play_and_wait("prep_fishing")

	print("▶ → fishing_idle")
	direction_line.start_loop()
	await play_and_wait("fishing_idle")

	current_state = "fishing_idle"

func _reset_after_reeling():
	print("🔁 Returning to fishing_idle...")

	# Reset bait-related flags
	bait_instance = null
	is_bait_ready = false
	is_reeling = false

	# Reset power bar UI
	charging = false
	power = 0.0
	power_dir = 1
	if power_bar_tween:
		power_bar_tween.kill()

	power_bar_fill.scale.x = 0.0
	power_bar_layer.visible = false
	power_bar_ui.position.y = 800  # back offscreen

	# Back to fishing_idle
	anim_state.travel("fishing_idle")
	direction_line.start_loop()
	current_state = "fishing_idle"


# ---------------------------------------------------------
# INPUT
# ---------------------------------------------------------

func _unhandled_input(_event: InputEvent):
	if transitioning:
		return

	if Input.is_action_just_pressed("throw_line"):
		match current_state:
			"fishing_idle":
				start_throw()
			"throw_line_idle":
				finish_throw()

# ---------------------------------------------------------
# THROW & BAIT
# ---------------------------------------------------------

func start_throw():
	print("▶ → throw_line")
	direction_line.stop_loop()
	current_state = "throw_line"
	transitioning = true
	charging = true
	power = 0.0
	power_dir = 1
	power_bar_fill.scale.x = 0.0
	power_bar_layer.visible = true

	power_bar_tween = create_tween()
	power_bar_tween.tween_property(power_bar_ui, "position", power_bar_final_pos, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await play_and_wait("throw_line")
	await play_and_wait("throw_line_idle")

	print("▶ → throw_line_idle (waiting for 2nd K)")
	current_state = "throw_line_idle"
	transitioning = false

func finish_throw():
	print("▶ → throw_line_finish")
	current_state = "throw_line_finish"
	transitioning = true
	charging = false

	var locked_power = power
	spawn_bait(locked_power)

	await play_and_wait("throw_line_finish")
	print("▶ Throw complete.")
	transitioning = false

func spawn_bait(power_value: float):
	print("▶ Spawning bait...")
	bait_instance = bait_scene.instantiate()
	get_tree().current_scene.add_child(bait_instance)
	bait_instance.global_position = bait_spawn.global_position

	# Throw bait to fish zone with arc
	var end_pos = fish_zone.global_position
	bait_instance.throw_to(end_pos, 1.5, 0.6)

	# Signals
	bait_instance.bait_landed.connect(_on_bait_landed)
	bait_instance.bait_despawned.connect(_on_bait_despawned)

func _on_bait_landed():
	print("🪝 Bait landed — reeling ready.")
	is_bait_ready = true
	anim_state.travel("reeling_static")

func _on_bait_despawned():
	print("🐟 Bait despawned — resetting to fishing_idle.")
	_reset_after_reeling()

# ---------------------------------------------------------
# ANIMATION UTILITY
# ---------------------------------------------------------

func play_and_wait(state_name: String) -> void:
	current_state = state_name
	anim_state.travel(state_name)
	var anim = anim_player.get_animation(state_name)
	if anim:
		await get_tree().create_timer(anim.length).timeout

# ---------------------------------------------------------
# PROCESS LOOP
# ---------------------------------------------------------

func _process(delta):
	if charging:
		power += POWER_SPEED * power_dir * delta
		power = clamp(power, 0.0, 1.0)
		power_bar_fill.scale.x = power
		power_dir = -1 if power >= 1.0 else 1 if power <= 0.0 else power_dir

	if not is_bait_ready or bait_instance == null:
		return

	var holding_k = Input.is_action_pressed("throw_line")
	var left = Input.is_action_pressed("reeling_left")
	var right = Input.is_action_pressed("reeling_right")

	if holding_k:
		if not is_reeling:
			is_reeling = true
			bait_instance.reel_to(bait_target.global_position)



		if left:
			anim_state.travel("reeling_left")
		elif right:
			anim_state.travel("reeling_right")
		else:
			anim_state.travel("reeling_idle")
	else:
		if is_reeling:
			is_reeling = false
			bait_instance.stop_reeling()

		if left:
			anim_state.travel("reeling_idle_left")
		elif right:
			anim_state.travel("reeling_idle_right")
		else:
			anim_state.travel("reeling_static")
