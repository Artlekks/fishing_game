extends Node

enum State {
	FISHING_IDLE,
	POWER_CHARGE,
	THROW_LINE,
	BAIT_FLYING
}

var current_state = State.FISHING_IDLE

func _ready():
	_enter_fishing_idle()

func _process(_delta):
	match current_state:
		State.FISHING_IDLE:
			if Input.is_action_just_pressed("throw_line"):
				_enter_power_charge()

		State.POWER_CHARGE:
			if Input.is_action_just_pressed("throw_line"):
				_enter_throw_line()

func _enter_fishing_idle():
	current_state = State.FISHING_IDLE
	$DirectionSelector.start_looping_animation()

func _enter_power_charge():
	current_state = State.POWER_CHARGE
	$DirectionSelector.stop_looping()
	$PowerMeter.start_charge()


func _enter_throw_line():
	current_state = State.THROW_LINE
	$PowerMeter.freeze()

	var power = $PowerMeter.get_power_value()
	var direction = $DirectionSelector.get_direction_vector()
	print("🎯 THROW → power:", power, " direction:", direction)

	# TODO: spawn bait + apply force
	# _spawn_bait(power, direction)
