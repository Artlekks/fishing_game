extends Node

signal bite_triggered
signal bite_missed
signal fish_hooked
signal fish_caught
signal fish_stamina_changed(current: float, maximum: float)
signal fish_exhausted
signal fish_resistance_changed(value: float)
signal fish_pull_changed(value: float)
signal fish_movement_changed(lateral: float)
signal fish_depth_intent_changed(value: float)

@onready var bite_window_timer: Timer = $BiteWindowTimer
@onready var bite_timer: Timer = $BiteTimer
@onready var fish_behavior: Node = $FishBehavior

@export var max_fish_stamina: float = 100.0
@export var stamina_drain_speed: float = 30.0
@export var stamina_recovery_speed: float = 10.0
@export var caster: Node
@export var fish_data: FishData

enum FightState {
	NONE,
	RESISTING,
	EXHAUSTED,
	SPENT
}

var fish_stamina: float = 0.0
var player_reeling: bool = false
var bite_active: bool = false
var active_fish: FishInstance = null

var fight_state: int = FightState.NONE
var rounds_remaining: int = 0
var recovery_time_left: float = 0.0


func _ready() -> void:
	if caster == null:
		return

	caster.bait_landed.connect(_on_bait_landed)
	caster.bait_returned.connect(_on_bait_returned)
	bite_timer.timeout.connect(_on_bite_timer_timeout)
	bite_window_timer.timeout.connect(_on_bite_window_timeout)
	fish_behavior.movement_changed.connect(_on_fish_behavior_movement_changed)
	fish_behavior.depth_changed.connect(_on_fish_behavior_depth_changed)
	
func _on_bait_landed(_point: Vector3) -> void:
	bite_timer.start()


func _on_bait_returned() -> void:
	bite_timer.stop()
	bite_window_timer.stop()
	bite_active = false

func _on_bite_timer_timeout() -> void:
	bite_active = true
	print("BITE!")

	bite_triggered.emit()
	bite_window_timer.start()

func try_hook() -> bool:
	if not bite_active:
		return false

	bite_active = false
	bite_window_timer.stop()
	if fish_data != null:
		active_fish = FishInstance.new()
		active_fish.setup(fish_data)
		fish_behavior.configure(active_fish)
		print(
	"FISH: ",
	active_fish.species.fish_name,
	" | Size: ",
	active_fish.size,
	" | Stamina: ",
	active_fish.max_stamina,
	" | Strength: ",
	active_fish.strength
)
		fish_stamina = active_fish.max_stamina
	else:
		active_fish = null
		fish_stamina = max_fish_stamina

	player_reeling = false

	var total_rounds := 1

	if active_fish != null:
		total_rounds = active_fish.resistance_rounds

	rounds_remaining = maxi(total_rounds, 1)

	_start_resistance_round()
	
	print("HOOKED!")
	fish_hooked.emit()

	return true


func _on_bite_window_timeout() -> void:
	bite_active = false

	print("MISSED!")
	bite_missed.emit()

func catch_fish() -> void:
	bite_active = false
	bite_timer.stop()
	bite_window_timer.stop()
	fight_state = FightState.NONE
	rounds_remaining = 0
	recovery_time_left = 0.0
	player_reeling = false
	fish_behavior.stop()
	
	print("CAUGHT!")
	fish_caught.emit()

func _process(delta: float) -> void:
	if fight_state == FightState.NONE:
		return

	if fight_state == FightState.SPENT:
		return

	if fight_state == FightState.EXHAUSTED:
		recovery_time_left -= delta

		if recovery_time_left <= 0.0:
			_start_resistance_round()

		return

	# From here we know the fish is RESISTING.

	var max_stamina := _get_max_stamina()

	if player_reeling:
		fish_stamina = maxf(
			fish_stamina - stamina_drain_speed * delta,
			0.0
		)
	else:
		fish_stamina = minf(
			fish_stamina + stamina_recovery_speed * delta,
			max_stamina
		)

	fish_stamina_changed.emit(
		fish_stamina,
		max_stamina
	)

	var strength := _get_strength()

	var stamina_ratio := 0.0

	if max_stamina > 0.0:
		stamina_ratio = fish_stamina / max_stamina

	var resistance := clampf(
		stamina_ratio * strength,
		0.0,
		1.0
	)

	fish_resistance_changed.emit(resistance)

	var pull_strength := lerpf(
		0.2,
		1.0,
		resistance
	)

	if player_reeling:
		pull_strength = 0.0

	fish_pull_changed.emit(pull_strength)

	if fish_stamina <= 0.0:
		_finish_resistance_round() 
		
func set_player_reeling(active: bool) -> void:
	player_reeling = active

func _get_max_stamina() -> float:
	if active_fish != null:
		return active_fish.max_stamina

	return max_fish_stamina


func _get_strength() -> float:
	if active_fish != null:
		return active_fish.strength

	return 1.0

func _on_fish_behavior_movement_changed(lateral: float) -> void:
	if fight_state == FightState.NONE:
		return

	fish_movement_changed.emit(lateral)

func _on_fish_behavior_depth_changed(value: float) -> void:
	if fight_state == FightState.NONE:
		return

	fish_depth_intent_changed.emit(value)

func _start_resistance_round() -> void:
	fight_state = FightState.RESISTING
	recovery_time_left = 0.0

	fish_stamina = _get_max_stamina()

	fish_stamina_changed.emit(
		fish_stamina,
		_get_max_stamina()
	)

	fish_behavior.start()

	print(
		"RESISTANCE STARTED | Rounds remaining: ",
		rounds_remaining
	)


func _finish_resistance_round() -> void:
	rounds_remaining = maxi(
		rounds_remaining - 1,
		0
	)

	fish_stamina = 0.0
	fish_exhausted.emit()

	fish_resistance_changed.emit(0.0)
	fish_pull_changed.emit(0.0)

	fish_behavior.stop()

	if rounds_remaining <= 0:
		_enter_spent()
		return

	fight_state = FightState.EXHAUSTED

	var recovery_min := 0.8
	var recovery_max := 1.5

	if active_fish != null:
		recovery_min = active_fish.recovery_time_min
		recovery_max = active_fish.recovery_time_max

	recovery_time_left = randf_range(
		recovery_min,
		recovery_max
	)

	print(
		"FISH EXHAUSTED | Rounds left: ",
		rounds_remaining
	)


func _enter_spent() -> void:
	fight_state = FightState.SPENT

	fish_behavior.stop()
	fish_resistance_changed.emit(0.0)
	fish_pull_changed.emit(0.0)

	print("FISH SPENT!")
