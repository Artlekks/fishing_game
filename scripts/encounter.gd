extends Node

signal bite_triggered
signal bite_missed
signal fish_hooked
signal fish_caught
signal fish_stamina_changed(current: float, maximum: float)
signal fish_exhausted

@onready var bite_window_timer: Timer = $BiteWindowTimer
@onready var bite_timer: Timer = $BiteTimer

@export var max_fish_stamina: float = 100.0
@export var stamina_drain_speed: float = 30.0
@export var stamina_recovery_speed: float = 10.0
@export var caster: Node

var fish_stamina: float = 0.0
var fighting: bool = false
var player_reeling: bool = false
var exhausted_sent: bool = false
var bite_active: bool = false

func _ready() -> void:
	if caster == null:
		return

	caster.bait_landed.connect(_on_bait_landed)
	caster.bait_returned.connect(_on_bait_returned)
	bite_timer.timeout.connect(_on_bite_timer_timeout)
	bite_window_timer.timeout.connect(_on_bite_window_timeout)

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
	fish_stamina = max_fish_stamina
	fighting = true
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
		fish_stamina = minf(
			fish_stamina + stamina_recovery_speed * delta,
			max_fish_stamina
		)

	fish_stamina_changed.emit(fish_stamina, max_fish_stamina)

	if fish_stamina <= 0.0 and not exhausted_sent:
		exhausted_sent = true
		print("FISH EXHAUSTED!")
		fish_exhausted.emit()


func set_player_reeling(active: bool) -> void:
	player_reeling = active
