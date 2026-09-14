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

@export_category("Free Reel")
@export_range(0.0, 1.0, 0.01) var free_reel_start: float = 0.05
@export_range(0.0, 1.0, 0.01) var free_reel_max: float = 0.18
@export var free_reel_gain_speed: float = 0.08
@export var free_reel_loss_speed: float = 0.10

@export_category("Safe Zone")
@export_range(0.0, 1.0, 0.01) var safe_min: float = 0.35
@export_range(0.0, 1.0, 0.01) var safe_max: float = 0.55

@export_category("Tension Speeds")
@export var reel_gain_speed: float = 0.20
@export var release_loss_speed: float = 0.18
@export var resistance_gain_speed: float = 0.10
@export var directional_tension_speed: float = 0.035
@export_category("Failure")
@export var line_break_delay: float = 1.5

var value: float = 0.45
var active: bool = false
var player_reeling: bool = false
var fish_resistance: float = 0.0
var current_state: State = State.SAFE
var failure_enabled: bool = false
var reel_gain_multiplier: float = 1.0
var player_tension_bias: float = 0.0
var overload_time: float = 0.0

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
		if failure_enabled:
			change -= release_loss_speed
		else:
			change -= free_reel_loss_speed
			
	if player_reeling:
		change += player_tension_bias * directional_tension_speed
	
	change += fish_resistance * resistance_gain_speed

	var max_value := 1.0 if failure_enabled else free_reel_max

	value = clampf(
		value + change * delta,
		0.0,
		max_value
	)

	tension_changed.emit(value)

	_update_state()

	if failure_enabled and value <= 0.0:
		active = false
		hook_off.emit()
		return

	if failure_enabled:
		if current_state == State.OVERLOAD:
			overload_time += delta

			if overload_time >= line_break_delay:
				active = false
				overload_time = 0.0
				line_broken.emit()
				return
		else:
			overload_time = 0.0

func set_reel_gain_multiplier(value: float) -> void:
	reel_gain_multiplier = maxf(value, 0.0)
	
func start() -> void:
	value = (safe_min + safe_max) * 0.5
	active = true
	failure_enabled = true
	player_reeling = false
	reel_gain_multiplier = 1.0
	overload_time = 0.0
	
	_update_state()
	tension_changed.emit(value)


func stop() -> void:
	active = false
	player_reeling = false
	fish_resistance = 0.0
	failure_enabled = false
	overload_time = 0.0
	
func set_player_reeling(reeling: bool) -> void:
	player_reeling = reeling


func set_fish_resistance(resistance: float) -> void:
	fish_resistance = clampf(resistance, 0.0, 1.0)


func _update_state() -> void:
	var new_state: State

	if not failure_enabled:
		new_state = State.SAFE

	elif value < safe_min:
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
	value = free_reel_start

	active = true
	failure_enabled = false
	player_reeling = false
	fish_resistance = 0.0

	_update_state()
	tension_changed.emit(value)

func add_impulse(amount: float) -> void:
	if not active:
		return

	var max_value := 1.0 if failure_enabled else free_reel_max
	value = clampf(value + amount, 0.0, max_value)

	tension_changed.emit(value)
	_update_state()

func set_player_tension_bias(bias: float) -> void:
	player_tension_bias = clampf(bias, -1.0, 1.0)
	
