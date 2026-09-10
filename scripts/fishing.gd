extends Node

enum Phase {
	INACTIVE,
	ENTER,
	PREP,
	AIM,
	PUT_AWAY,
	EXIT
}

@export var game_mode: Node
@export var camera_rig: Node
@export var sprite_director: Node
@export var player: CharacterBody3D

var phase: int = Phase.INACTIVE


func _ready() -> void:
	game_mode.mode_changed.connect(_on_mode_changed)

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

	# No input allowed while entering or exiting.
	if phase == Phase.ENTER or phase == Phase.PREP or phase == Phase.EXIT:
		return

	if event.is_action_pressed("cancel_fishing"):
		if phase != Phase.AIM:
			return

		phase = Phase.PUT_AWAY
		sprite_director.play_backwards(&"Prep_Fishing")


func _on_mode_changed(new_mode) -> void:
	var active: bool = new_mode == game_mode.Mode.FISHING

	set_process_unhandled_input(active)

	if active:
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
	if animation_name != &"Prep_Fishing":
		return

	if phase == Phase.PREP:
		phase = Phase.AIM
		sprite_director.play(&"Fishing_Idle")
		return

	if phase == Phase.PUT_AWAY:
		player.restore_exploration_idle()

		phase = Phase.EXIT
		camera_rig.exit_fishing_view()


func _on_exploration_view_ready() -> void:
	if phase != Phase.EXIT:
		return

	phase = Phase.INACTIVE
	game_mode.exit_fishing()
