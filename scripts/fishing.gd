extends Node

enum Phase {
	INACTIVE,
	ENTER,
	PREP,
	AIM,
	PREP_THROW,
	CHARGE,
	CANCEL_THROW,
	THROW,
	BAIT_FLYING,
	IN_WATER,
	FIGHT,
	CATCH,
	LINE_BROKEN,
	PUT_AWAY,
	EXIT
}

@onready var aim: Node = $Aim
@onready var power: Node = $Power
@onready var caster: Node3D = $Caster
@onready var encounter: Node = $Encounter

@export var game_mode: Node
@export var camera_rig: Node
@export var sprite_director: Node
@export var player: CharacterBody3D
@export var power_meter_view: Node

var phase: int = Phase.INACTIVE
var bait_landed_during_throw: bool = false
var current_reel_animation: StringName = &""
var strong_pull_animation_active: bool = false
var current_fish_pull: float = 0.0

func _ready() -> void:
	game_mode.mode_changed.connect(_on_mode_changed)
	aim.aim_changed.connect(_on_aim_changed)
	caster.bait_landed.connect(_on_bait_landed)
	caster.bait_returned.connect(_on_bait_returned)
	encounter.fish_hooked.connect(_on_fish_hooked)
	encounter.fish_exhausted.connect(_on_fish_exhausted)
	encounter.bite_triggered.connect(_on_bite_triggered)
	encounter.bite_missed.connect(_on_bite_missed)
	encounter.fish_resistance_changed.connect(_on_fish_resistance_changed)
	encounter.fish_pull_changed.connect(_on_fish_pull_changed)
	encounter.fish_movement_changed.connect(_on_fish_movement_changed)
	encounter.fish_depth_intent_changed.connect(_on_fish_depth_intent_changed)
	encounter.strong_pull_started.connect(_on_strong_pull_started)
	encounter.hook_off.connect(_on_fight_failed)
	encounter.line_broken.connect(_on_line_broken)

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
			power.start()
			sprite_director.play(&"Prep_Throw")
			return

		if event.is_action_pressed("cancel_fishing"):
			aim.stop()
			camera_rig.stop_fishing_aim()

			phase = Phase.PUT_AWAY
			sprite_director.play_backwards(&"Prep_Fishing")
			return
	
	if phase == Phase.PREP_THROW or phase == Phase.CHARGE:
		if event.is_action_pressed("cancel_fishing"):
			if (
				power_meter_view != null
				and power_meter_view.has_method("cancel_to_aim")
			):
				power_meter_view.cancel_to_aim()

			# Stop the power mechanic. The HUD has already been told
			# that this stop is a cancel, not a confirmed cast.
			power.capture()

			phase = Phase.CANCEL_THROW
			sprite_director.play_backwards(&"Prep_Throw")
			return
			
	if phase == Phase.CHARGE:
		if event.is_action_pressed("enter_fishing"):
			var captured_power: float = power.capture()

			var zone = game_mode.active_fish_zone

			if zone != null:
				var cast_direction: Vector3 = aim.get_direction()

				var cast_bait: Node3D = caster.perform_cast(
					captured_power,
					cast_direction,
					zone.get_water_y(),
					zone.get_bottom_y()
				)

				if is_instance_valid(cast_bait):
					camera_rig.arm_fishing_follow(
						cast_bait,
						cast_direction,
						zone.get_water_y()
					)

			bait_landed_during_throw = false
			phase = Phase.THROW
			sprite_director.play(&"Throw")
			return


	if phase == Phase.IN_WATER:
		if event.is_action_pressed("ds_left"):
			caster.twitch_bait(-1.0)
			encounter.add_lure_tension(0.05)
			return

		if event.is_action_pressed("ds_right"):
			caster.twitch_bait(1.0)
			encounter.add_lure_tension(0.05)
			return

		if event.is_action_pressed("enter_fishing"):
			if encounter.try_hook():
				encounter.set_player_reeling(true)
				caster.set_reeling(true)
				sprite_director.play(&"Reel")
				return

			encounter.set_player_reeling(true)
			caster.set_reeling(true)
			sprite_director.play(&"Reel")
			return

		if event.is_action_released("enter_fishing"):
			encounter.set_player_reeling(false)
			caster.set_reeling(false)
			sprite_director.play(&"Reel_Idle")
			return
	
	if phase == Phase.FIGHT:
		if event.is_action_pressed("enter_fishing"):
			_set_fight_reeling(true)
			return

		if event.is_action_released("enter_fishing"):
			_set_fight_reeling(false)
			return

func _on_strong_pull_started() -> void:
	if phase != Phase.FIGHT:
		return

	if not Input.is_action_pressed("enter_fishing"):
		return

	if strong_pull_animation_active:
		return

	strong_pull_animation_active = true
	current_reel_animation = &"Reel_Back_Strong"
	sprite_director.play(&"Reel_Back_Strong")
	
func _set_fight_reeling(active: bool) -> void:
	encounter.set_player_reeling(active)
	caster.set_reeling(active)

	if not active:
		strong_pull_animation_active = false
		current_reel_animation = &""

	_update_reel_animation()
		
func _on_mode_changed(new_mode) -> void:
	var active: bool = new_mode == game_mode.Mode.FISHING

	set_process_unhandled_input(active)

	if not active:
		return

	phase = Phase.ENTER

	var zone = game_mode.active_fish_zone

	if zone != null:
		encounter.set_fish_population(
			zone.get_fish_population()
		)

		camera_rig.enter_fishing_view()


func _on_fishing_view_ready() -> void:
	if phase != Phase.ENTER:
		return

	phase = Phase.PREP
	sprite_director.play(&"Prep_Fishing")

func _update_reel_animation() -> void:
	if strong_pull_animation_active:
		return

	var is_reeling := Input.is_action_pressed("enter_fishing")

	var horizontal := Input.get_axis(
		"ds_left",
		"ds_right"
	)

	var vertical := Input.get_axis(
		"move_forward",
		"move_back"
	)

	var desired_animation: StringName

	if is_reeling and vertical < -0.1:
		desired_animation = &"Reel_Front"

	elif is_reeling and vertical > 0.1:
		desired_animation = &"Reel_Back"

	elif horizontal < -0.1:
		desired_animation = (
			&"Reel_Left"
			if is_reeling
			else &"Reel_Left_Idle"
		)

	elif horizontal > 0.1:
		desired_animation = (
			&"Reel_Right"
			if is_reeling
			else &"Reel_Right_Idle"
		)

	else:
		desired_animation = (
			&"Reel"
			if is_reeling
			else &"Reel_Idle"
		)

	if desired_animation == current_reel_animation:
		return

	current_reel_animation = desired_animation
	sprite_director.play(desired_animation)
	
func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"Prep_Fishing":
		if phase == Phase.PREP:
			phase = Phase.AIM
			sprite_director.play(&"Fishing_Idle")

			var fishing_forward := player.global_transform.basis.z
			fishing_forward.y = 0.0
			fishing_forward = fishing_forward.normalized()

			camera_rig.start_fishing_aim(fishing_forward)
			aim.start(fishing_forward)

			return

		if phase == Phase.PUT_AWAY:
			player.restore_exploration_idle()

			phase = Phase.EXIT
			camera_rig.exit_fishing_view()
			return


	if animation_name == &"Prep_Throw":
		if phase == Phase.PREP_THROW:
			phase = Phase.CHARGE
			sprite_director.play(&"Prep_Throw_Idle")
			return

		if phase == Phase.CANCEL_THROW:
			phase = Phase.AIM
			sprite_director.play(&"Fishing_Idle")
			aim.resume()
			return

	if animation_name == &"Throw" and phase == Phase.THROW:
		if bait_landed_during_throw:
			_enter_in_water()
		else:
			phase = Phase.BAIT_FLYING
			sprite_director.play(&"Throw_Idle")

		return
	
	if animation_name == &"Fishing_Catch" and phase == Phase.CATCH:
		camera_rig.reset_fishing_follow()

		phase = Phase.AIM
		sprite_director.play(&"Fishing_Idle")
		aim.resume()
		return
	
	if animation_name == &"Reel_Broken_Rod" and phase == Phase.LINE_BROKEN:
		camera_rig.reset_fishing_follow()

		phase = Phase.AIM
		sprite_director.play(&"Fishing_Idle")
		aim.resume()
		return
	
	if animation_name == &"Reel_Back_Strong":
		strong_pull_animation_active = false
		current_reel_animation = &""
		return
		
func _on_exploration_view_ready() -> void:
	if phase != Phase.EXIT:
		return

	phase = Phase.INACTIVE
	game_mode.exit_fishing()

func _on_aim_changed(direction: Vector3) -> void:
	camera_rig.set_fishing_aim_direction(direction)

func _on_bait_landed(_point: Vector3) -> void:
	if phase == Phase.THROW:
		bait_landed_during_throw = true
		return

	if phase == Phase.BAIT_FLYING:
		_enter_in_water()
		
func _enter_in_water() -> void:
	phase = Phase.IN_WATER
	sprite_director.play(&"Reel_Idle")

func _on_bait_returned() -> void:
	if phase != Phase.IN_WATER and phase != Phase.FIGHT:
		return

	if phase == Phase.FIGHT:
		encounter.catch_fish()

		phase = Phase.CATCH
		sprite_director.play(&"Fishing_Catch")
		return

	camera_rig.reset_fishing_follow()

	phase = Phase.AIM
	sprite_director.play(&"Fishing_Idle")
	aim.resume()
	
func _process(_delta: float) -> void:
	if phase == Phase.THROW or phase == Phase.BAIT_FLYING:
		var air_curve := Input.get_axis(
			"ds_left",
			"ds_right"
		)

		caster.set_air_curve(air_curve)
		return
		
	if phase != Phase.IN_WATER and phase != Phase.FIGHT:
		return

	var steering := Input.get_axis("ds_left", "ds_right")
	var vertical := Input.get_axis(
		"move_forward",
		"move_back"
	)

	encounter.set_player_tension_bias(vertical)
	caster.set_reel_steering(steering)
	
	if phase == Phase.FIGHT:
		encounter.set_player_steering(steering)
	
	if phase == Phase.IN_WATER or phase == Phase.FIGHT:
		_update_reel_animation()
	
func _on_fish_hooked() -> void:
	if phase != Phase.IN_WATER:
		return

	phase = Phase.FIGHT
	sprite_director.play(&"Reel")
	caster.set_fight_mode(true)

func _on_fish_exhausted() -> void:
	if phase != Phase.FIGHT:
		return
	
func _on_bite_triggered() -> void:
	if phase != Phase.IN_WATER:
		return

	sprite_director.play(&"Reel_Bite")


func _on_bite_missed() -> void:
	if phase != Phase.IN_WATER:
		return

	sprite_director.play(&"Reel_Idle")

func _on_fish_resistance_changed(value: float) -> void:
	if phase != Phase.FIGHT:
		return

	caster.set_fight_resistance(value)

func _on_fish_pull_changed(value: float) -> void:
	if phase != Phase.FIGHT:
		return

	current_fish_pull = value
	caster.set_fish_pull_strength(value)

func _on_fish_movement_changed(lateral: float) -> void:
	if phase != Phase.FIGHT:
		return

	caster.set_fish_lateral(lateral)

func _on_fish_depth_intent_changed(value: float) -> void:
	if phase != Phase.FIGHT:
		return

	caster.set_fish_depth_intent(value)

func _on_line_broken() -> void:
	if phase != Phase.FIGHT:
		return

	caster.cancel_bait()

	current_fish_pull = 0.0
	current_reel_animation = &""
	strong_pull_animation_active = false

	phase = Phase.LINE_BROKEN
	sprite_director.play(&"Reel_Broken_Rod")
	
func _on_fight_failed() -> void:
	if phase != Phase.FIGHT:
		return

	caster.cancel_bait()
	camera_rig.reset_fishing_follow()

	current_fish_pull = 0.0
	current_reel_animation = &""

	phase = Phase.AIM

	sprite_director.play(&"Fishing_Idle")
	aim.resume()
