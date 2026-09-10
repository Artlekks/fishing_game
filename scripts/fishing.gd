extends Node

enum Phase {
	INACTIVE,
	ENTER,
	PREP,
	AIM,
	EXIT
}

@export var game_mode: Node
@export var camera_rig: Node
@export var sprite_director: Node

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

	if event.is_action_pressed("cancel_fishing"):
		phase = Phase.EXIT
		game_mode.exit_fishing()


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
	else:
		camera_rig.exit_fishing_view()


func _on_fishing_view_ready() -> void:
	if phase != Phase.ENTER:
		return

	phase = Phase.PREP
	sprite_director.play(&"Prep_Fishing")


func _on_animation_finished(animation_name: StringName) -> void:
	if phase != Phase.PREP:
		return

	if animation_name != &"Prep_Fishing":
		return

	phase = Phase.AIM
	sprite_director.play(&"Fishing_Idle")


func _on_exploration_view_ready() -> void:
	phase = Phase.INACTIVE
