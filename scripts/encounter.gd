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

@onready var bite_window_timer: Timer = $BiteWindowTimer
@onready var bite_timer: Timer = $BiteTimer
@onready var fish_behavior: Node = $FishBehavior

@export var max_fish_stamina: float = 100.0
@export var stamina_drain_speed: float = 30.0
@export var stamina_recovery_speed: float = 10.0
@export var caster: Node
@export var fish_data: FishData

var fish_stamina: float = 0.0
var fighting: bool = false
var player_reeling: bool = false
var exhausted_sent: bool = false
var bite_active: bool = false
var active_fish: FishInstance = null

func _ready() -> void:
	if caster == null:
		return

	caster.bait_landed.connect(_on_bait_landed)
	caster.bait_returned.connect(_on_bait_returned)
	bite_timer.timeout.connect(_on_bite_timer_timeout)
	bite_window_timer.timeout.connect(_on_bite_window_timeout)
	fish_behavior.movement_changed.connect(_on_fish_behavior_movement_changed)
	
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
	fighting = true
	fish_behavior.start()
	player_reeling = false
	exhausted_sent = false
	
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
	fighting = false
	player_reeling = false
	fish_behavior.stop()
	
	print("CAUGHT!")
	fish_caught.emit()

func _process(delta: float) -> void:
	if not fighting:
		return

	if player_reeling:
		fish_stamina = maxf(
			fish_stamina - stamina_drain_speed * delta,
			0.0
		)
	else:
		var max_stamina := _get_max_stamina()

		fish_stamina = minf(
			fish_stamina + stamina_recovery_speed * delta,
			max_stamina
		)

	var max_stamina := _get_max_stamina()

	fish_stamina_changed.emit(fish_stamina, max_stamina)
	
	var strength := _get_strength()

	var stamina_ratio := fish_stamina / max_stamina
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
	
	if fish_stamina <= 0.0 and not exhausted_sent:
		exhausted_sent = true
		print("FISH EXHAUSTED!")
		fish_exhausted.emit()


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
	if not fighting:
		return

	fish_movement_changed.emit(lateral)
