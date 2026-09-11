extends Node

enum Phase {
	INACTIVE,
	ENTER,
	PREP,
	AIM,
	PREP_THROW,
	CHARGE,
	THROW,
	PUT_AWAY,
	EXIT
}

@onready var aim: Node = $Aim
@onready var power: Node = $Power
@onready var caster: Node3D = $Caster

@export var game_mode: Node
@export var camera_rig: Node
@export var sprite_director: Node
@export var player: CharacterBody3D

var phase: int = Phase.INACTIVE


func _ready() -> void:
	game_mode.mode_changed.connect(_on_mode_changed)
	aim.aim_changed.connect(_on_aim_changed)
	
	camera_rig.connect(
		"fishing_view_ready",
		Callable(self, "_on_fishing_view_ready")
	)

	camera_rig.connect(
		"exploration_view_ready",
		Callable(self, "_on_exploration_view_ready")
	)

	sprite_director.connect(
		"animation_finished",
		Callable(self, "_on_animation_finished")
	)

	_on_mode_changed(game_mode.current_mode)


func _unhandled_input(event: InputEvent) -> void:
	if not game_mode.is_fishing():
		return

	if phase == Phase.AIM:
		if event.is_action_pressed("enter_fishing"):
			aim.stop()

			phase = Phase.PREP_THROW
			sprite_director.play(&"Prep_Throw")
			return

		if event.is_action_pressed("cancel_fishing"):
			aim.stop()
			camera_rig.stop_fishing_aim()

			phase = Phase.PUT_AWAY
			sprite_director.play_backwards(&"Prep_Fishing")
			return

	if phase == Phase.CHARGE:
		if event.is_action_pressed("enter_fishing"):
			var captured_power: float = power.capture()

			var zone = game_mode.active_fish_zone

			if zone != null:
				caster.perform_cast(
					captured_power,
					aim.get_direction(),
					zone.get_water_y()
				)

			phase = Phase.THROW
			sprite_director.play(&"Throw")
			return


func _on_mode_changed(new_mode) -> void:
	var active: bool = new_mode == game_mode.Mode.FISHING

	set_process_unhandled_input(active)

	if not active:
		return

	phase = Phase.ENTER

	var zone = game_mode.active_fish_zone

	if zone != null:
		camera_rig.enter_fishing_view(
			zone.get_water_forward()
		)


func _on_fishing_view_ready() -> void:
	if phase != Phase.ENTER:
		return

	phase = Phase.PREP
	sprite_director.play(&"Prep_Fishing")


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"Prep_Fishing":
		if phase == Phase.PREP:
			phase = Phase.AIM
			sprite_director.play(&"Fishing_Idle")

			var zone = game_mode.active_fish_zone

			if zone != null:
				camera_rig.start_fishing_aim(
					zone.get_water_forward()
				)

				aim.start(
					zone.get_water_forward()
				)

			return

		if phase == Phase.PUT_AWAY:
			player.restore_exploration_idle()

			phase = Phase.EXIT
			camera_rig.exit_fishing_view()
			return


	if animation_name == &"Prep_Throw" and phase == Phase.PREP_THROW:
		phase = Phase.CHARGE
		sprite_director.play(&"Prep_Throw_Idle")
		power.start()

	if animation_name == &"Throw" and phase == Phase.THROW:
		phase = Phase.AIM
		sprite_director.play(&"Fishing_Idle")
		aim.resume()
		return
	
func _on_exploration_view_ready() -> void:
	if phase != Phase.EXIT:
		return

	phase = Phase.INACTIVE
	game_mode.exit_fishing()

func _on_aim_changed(direction: Vector3) -> void:
	camera_rig.set_fishing_aim_direction(direction)
