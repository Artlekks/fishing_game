extends Node3D

@onready var anim_tree = $AnimationTree
@onready var anim_state = anim_tree.get("parameters/playback")
@onready var anim_player = $AnimationPlayer

@onready var power_bar_layer = $power_bar_layer
@onready var power_bar_ui = $power_bar_layer/power_bar_ui
@onready var power_bar_fill = $power_bar_layer/power_bar_ui/PowerBarFill

@onready var bait_spawn = $BaitSpawn
@onready var fish_zone = get_tree().current_scene.get_node("FishZone/Center")

@onready var direction_line = $DirectionLine
var direction_dots: Array[Sprite3D] = []
var show_dots := false

var power_bar_final_pos: Vector2
var power := 0.0
var power_dir := 1
var charging := false
var power_bar_tween: Tween

var bait_scene := preload("res://scenes/bait_3d.tscn")
var bait_instance: Node3D

var current_state := "prep_fishing"
var transitioning := false

const POWER_SPEED := 0.5

func _ready():
	# Setup power bar
	power_bar_final_pos = power_bar_ui.position
	power_bar_ui.position.y = 800
	power_bar_layer.visible = false
	power_bar_fill.scale.x = 0.0

	# Setup direction line
	for i in range(1, 9):
		var dot = direction_line.get_node("Dot%d" % i)
		dot.visible = false
		direction_dots.append(dot)
	direction_line.visible = false

	anim_tree.active = true

	print("▶ Starting prep_fishing")
	await play_and_wait("prep_fishing")

	print("▶ → fishing_idle")
	await show_direction_line()
	await play_and_wait("fishing_idle")
	current_state = "fishing_idle"

func _unhandled_input(_event: InputEvent):
	if transitioning:
		return

	if Input.is_action_just_pressed("throw_line"):
		# Hide direction line immediately
		show_dots = false
		direction_line.visible = false

		match current_state:
			"fishing_idle":
				start_throw()
			"throw_line_idle":
				finish_throw()

func start_throw():
	print("▶ → throw_line")
	current_state = "throw_line"
	transitioning = true

	# Show and animate power bar
	power = 0.0
	power_dir = 1
	charging = true
	power_bar_fill.scale.x = 0.0
	power_bar_layer.visible = true

	power_bar_tween = create_tween()
	var track = power_bar_tween.tween_property(
		power_bar_ui, "position", power_bar_final_pos, 0.2
	)
	track.set_trans(Tween.TRANS_QUAD)
	track.set_ease(Tween.EASE_OUT)

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

	print("▶ → throw_idle")
	current_state = "throw_idle"
	await play_and_wait("throw_idle")

	print("▶ throw complete. Waiting for bait logic...")
	transitioning = false

func spawn_bait(power_value: float):
	print("▶ Spawning bait...")

	bait_instance = bait_scene.instantiate()
	get_tree().current_scene.add_child(bait_instance)

	var start_pos = bait_spawn.global_position
	bait_instance.global_position = start_pos

	var distance = lerp(3.0, 10.0, power_value)
	var end_pos = fish_zone.global_position

	bait_instance.throw_to(end_pos, 1.5, 0.6)
	bait_instance.bait_landed.connect(_on_bait_landed)
	bait_instance.bait_despawned.connect(_on_bait_despawned)

func _on_bait_landed():
	print("🪝 Bait landed — ready to reel.")

func _on_bait_despawned():
	print("❌ Bait despawned.")
	bait_instance = null

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

func show_direction_line() -> void:
	show_dots = true
	direction_line.visible = true

	for i in range(direction_dots.size()):
		if not show_dots:
			break
		direction_dots[i].visible = true
		await get_tree().create_timer(0.05).timeout
