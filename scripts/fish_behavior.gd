extends Node

signal movement_changed(lateral: float)
signal depth_changed(value: float)
signal fight_back_started(fight_back_type: int)
signal strong_pull_started

@export var min_change_time: float = 0.8
@export var max_change_time: float = 2.0

enum FightBackType {
	SURGE_AWAY,
	SIDE_RUN,
	DIVE,
	RISE,
	ERRATIC
}

var current_fight_back: int = FightBackType.SURGE_AWAY
var side_direction: float = 1.0
var active: bool = false
var time_until_change: float = 0.0
var lateral: float = 0.0
var depth: float = 0.0
var lateral_activity: float = 1.0
var vertical_activity: float = 1.0
var intensity: float = 1.0

func _process(delta: float) -> void:
	if not active:
		return

	time_until_change -= delta

	if time_until_change <= 0.0:
		_choose_new_movement()


func start(new_intensity: float = 1.0) -> void:
	intensity = clampf(new_intensity, 0.0, 1.0)
	active = true

	current_fight_back = randi_range(
		FightBackType.SURGE_AWAY,
		FightBackType.ERRATIC
	)

	side_direction = -1.0 if randf() < 0.5 else 1.0
	fight_back_started.emit(current_fight_back)
	
	if current_fight_back == FightBackType.SURGE_AWAY:
		strong_pull_started.emit()
	
	print(
		"FIGHT BACK TYPE: ",
		FightBackType.keys()[current_fight_back]
	)

	_choose_new_movement()

func stop() -> void:
	active = false
	lateral = 0.0
	movement_changed.emit(lateral)
	depth = 0.0
	depth_changed.emit(depth)

func _choose_new_movement() -> void:
	match current_fight_back:
		FightBackType.SURGE_AWAY:
			lateral = randf_range(-0.15, 0.15) * lateral_activity
			depth = randf_range(-0.1, 0.1) * vertical_activity

		FightBackType.SIDE_RUN:
			lateral = side_direction * lateral_activity
			depth = randf_range(-0.2, 0.2) * vertical_activity

		FightBackType.DIVE:
			lateral = randf_range(-0.3, 0.3) * lateral_activity
			depth = -1.0 * vertical_activity

		FightBackType.RISE:
			lateral = randf_range(-0.3, 0.3) * lateral_activity
			depth = 1.0 * vertical_activity

		FightBackType.ERRATIC:
			lateral = randf_range(-1.0, 1.0) * lateral_activity
			depth = randf_range(-1.0, 1.0) * vertical_activity

	time_until_change = randf_range(
		min_change_time,
		max_change_time
	)
	
	lateral *= intensity
	depth *= intensity

	movement_changed.emit(lateral)
	depth_changed.emit(depth)

func configure(fish: FishInstance) -> void:
	lateral_activity = fish.lateral_activity
	vertical_activity = fish.vertical_activity

	min_change_time = fish.direction_change_min
	max_change_time = fish.direction_change_max
