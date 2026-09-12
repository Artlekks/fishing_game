extends Node
class_name FishingTension

signal tension_changed(value: float)
signal state_changed(state: State)
signal hook_off
signal line_broken

enum State {
	SLACK,
	SAFE,
	OVERLOAD
}

@export_range(0.0, 1.0, 0.01) var start_tension: float = 0.45
@export var free_reel_gain_speed: float = 0.08

@export_category("Safe Zone")
@export_range(0.0, 1.0, 0.01) var safe_min: float = 0.35
@export_range(0.0, 1.0, 0.01) var safe_max: float = 0.55

@export_category("Tension Speeds")
@export var reel_gain_speed: float = 0.20
@export var release_loss_speed: float = 0.18
@export var resistance_gain_speed: float = 0.10

var value: float = 0.45
var active: bool = false
var player_reeling: bool = false
var fish_resistance: float = 0.0
var current_state: State = State.SAFE
var failure_enabled: bool = false
var reel_gain_multiplier: float = 1.0

func _process(delta: float) -> void:
	if not active:
		return

	var change := 0.0

	if player_reeling:
		if failure_enabled:
			change += reel_gain_speed * reel_gain_multiplier
		else:
			change += free_reel_gain_speed
	else:
		change -= release_loss_speed

	change += fish_resistance * resistance_gain_speed

	value = clampf(
		value + change * delta,
		0.0,
		1.0
	)

	tension_changed.emit(value)

	_update_state()

	if failure_enabled and value <= 0.0:
		active = false
		hook_off.emit()
		return

	if failure_enabled and value >= 1.0:
		active = false
		line_broken.emit()

func set_reel_gain_multiplier(value: float) -> void:
	reel_gain_multiplier = maxf(value, 0.0)
	
func start() -> void:
	value = start_tension
	active = true
	failure_enabled = true
	player_reeling = false
	reel_gain_multiplier = 1.0
	
	_update_state()
	tension_changed.emit(value)


func stop() -> void:
	active = false
	player_reeling = false
	fish_resistance = 0.0
	failure_enabled = false

func set_player_reeling(reeling: bool) -> void:
	player_reeling = reeling


func set_fish_resistance(resistance: float) -> void:
	fish_resistance = clampf(resistance, 0.0, 1.0)


func _update_state() -> void:
	var new_state: State

	if value < safe_min:
		new_state = State.SLACK

	elif value > safe_max:
		new_state = State.OVERLOAD

	else:
		new_state = State.SAFE

	if new_state == current_state:
		return

	current_state = new_state
	state_changed.emit(current_state)

func start_free_reel() -> void:
	value = 0.0
	active = true
	failure_enabled = false
	player_reeling = false
	fish_resistance = 0.0

	_update_state()
	tension_changed.emit(value)

func add_impulse(amount: float) -> void:
	if not active:
		return

	value = clampf(value + amount, 0.0, 1.0)

	tension_changed.emit(value)
	_update_state()
