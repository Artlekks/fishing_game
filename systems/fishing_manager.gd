extends Node

signal state_changed(state: String)

@export var player_anim_controller: Node
@export var bait_scene: PackedScene
@export var bait_spawn_point: Node3D
@export var fish_zone_target: Node3D
@export var direction_line: Node
@export var bait_target: Node3D
@export var power_bar: Node

enum ThrowState { NONE, STARTED, IDLE, FINISHED }

var throw_state := ThrowState.NONE
var current_state := "fishing_idle"
var locked_power := 0.0
var transitioning := false

var throw_phase := "none"  # "none", "started", "idle", "finish"

var bait_instance: Node3D = null

var power := 0.0
var power_dir := 1
var charging := false

const POWER_SPEED := 0.5

func _ready():
	if fish_zone_target == null:
		fish_zone_target = get_tree().get_root().get_node("World3D/FishZone/Center")

	power_bar.call("reset")
	direction_line.call("stop_loop")
	await player_anim_controller.call("play_and_wait", "prep_fishing")
	direction_line.call("start_loop")
	await player_anim_controller.call("play_and_wait", "fishing_idle")
	current_state = "fishing_idle"
	emit_signal("state_changed", current_state)

func _process(delta):
	if charging:
		power += POWER_SPEED * power_dir * delta
		power = clamp(power, 0.0, 1.0)
		power_dir = -1 if power >= 1.0 else 1 if power <= 0.0 else power_dir
		power_bar.call("set_fill", power)

	if current_state == "reeling" and bait_instance:
		var holding_k = Input.is_action_pressed("throw_line")
		var left = Input.is_action_pressed("reeling_left")
		var right = Input.is_action_pressed("reeling_right")

		if holding_k:
			if left:
				player_anim_controller.call("play", "reeling_left")
				bait_instance.call("move_along_arc", bait_target.global_position, -1, delta)
			elif right:
				player_anim_controller.call("play", "reeling_right")
				bait_instance.call("move_along_arc", bait_target.global_position, 1, delta)
			else:
				player_anim_controller.call("play", "reeling_idle")
				bait_instance.call("move_toward", bait_target.global_position, delta)
		else:
			if left:
				player_anim_controller.call("play", "reeling_idle_left")
			elif right:
				player_anim_controller.call("play", "reeling_idle_right")
			else:
				player_anim_controller.call("play", "reeling_static")

func handle_input(event):
	if transitioning:
		return

	if event.is_action_pressed("throw_line"):
		if current_state == "fishing_idle":
			start_throw()
		elif current_state == "throw_line_idle" and throw_state == ThrowState.IDLE:
			finish_throw()



func start_throw():
	transitioning = true
	throw_state = ThrowState.STARTED
	current_state = "throwing"
	charging = true
	power = 0.0
	power_dir = 1

	power_bar.call("reset")
	power_bar.call("show_bar")
	direction_line.call("stop_loop")

	await player_anim_controller.call("play_and_wait", "throw_line")

	player_anim_controller.call("play", "throw_line_idle")  # <- no await
	throw_state = ThrowState.IDLE
	current_state = "throw_line_idle"
	transitioning = false


func finish_throw():
	transitioning = true
	throw_state = ThrowState.FINISHED
	charging = false
	locked_power = power

	await player_anim_controller.call("play_and_wait", "throw_line_finish")

	spawn_bait(locked_power)

	current_state = "reeling"
	throw_state = ThrowState.NONE
	transitioning = false


func spawn_bait(power_value):
	bait_instance = bait_scene.instantiate()
	get_tree().current_scene.add_child(bait_instance)
	bait_instance.global_position = bait_spawn_point.global_position
	bait_instance.call("throw_to", fish_zone_target.global_position, 1.5, 0.6)
	bait_instance.connect("bait_landed", _on_bait_landed)
	bait_instance.connect("bait_despawned", _on_bait_despawned)

func _on_bait_landed():
	player_anim_controller.call("play", "reeling_static")

func _on_bait_despawned():
	charging = false
	power = 0.0
	power_dir = 1
	power_bar.call("reset")
	bait_instance = null
	direction_line.call("start_loop")
	player_anim_controller.call("play", "fishing_idle")
	current_state = "fishing_idle"
	emit_signal("state_changed", current_state)
