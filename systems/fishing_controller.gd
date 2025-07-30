extends Node

enum State {
	FISHING_IDLE,
	DIRECTION_SELECT,
	POWER_CHARGE,
	THROW_LINE,
	THROW_WAIT,
	BAIT_FLYING
}

var current_state = State.FISHING_IDLE

func _ready():
	_enter_fishing_idle()

func _process(_delta):
	match current_state:
		State.FISHING_IDLE:
			if Input.is_action_just_pressed("throw_line"):
				_enter_direction_select()

		State.DIRECTION_SELECT:
			if Input.is_action_just_pressed("throw_line"):
				_enter_power_charge()

		State.POWER_CHARGE:
			if Input.is_action_just_pressed("throw_line"):
				_enter_throw_line()

# -- States --

func _enter_fishing_idle():
	current_state = State.FISHING_IDLE
	$DirectionSelector.hide_selector()
	# TODO: play fishing_idle anim

func _enter_direction_select():
	current_state = State.DIRECTION_SELECT
	$DirectionSelector.show_selector()
	# TODO: play throw_line_start anim (rod pull-back)

func _enter_power_charge():
	current_state = State.POWER_CHARGE
	$DirectionSelector.hide_selector()
	$PowerMeter.start_charge()
	# TODO: play throw_line_idle anim (hold pose)

func _enter_throw_line():
	current_state = State.THROW_LINE
	$PowerMeter.freeze()
	var power = $PowerMeter.get_power_value()
	var direction = $DirectionSelector.get_direction_vector()
	print("Throw power:", power, " | direction:", direction)
	# TODO: play throw_line_finish anim
	# TODO: spawn bait with calculated force
	_enter_throw_wait()

func _enter_throw_wait():
	current_state = State.THROW_WAIT
	# Bait is flying; when it hits water, move to bait_idle
