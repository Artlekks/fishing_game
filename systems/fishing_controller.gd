extends Node

enum State {
	FISHING_IDLE,
	DIRECTION_SELECT,
	POWER_CHARGE,
	THROW_LINE,
	BAIT_FLYING,
	BAIT_IDLE,
	BAIT_SINK,
	REELING,
	BITE_FIGHT,
	CATCH_SUCCESS,
	CATCH_FAIL,
	RESET_TO_IDLE
}

var current_state = State.FISHING_IDLE

func _ready():
	print("🎣 FishingController ready.")
	_enter_fishing_idle()

func _process(delta):
	match current_state:
		State.FISHING_IDLE:
			if Input.is_action_just_pressed("fish_action"):
				_enter_direction_select()

		State.DIRECTION_SELECT:
			if Input.is_action_just_pressed("fish_action"):
				_enter_power_charge()

		State.POWER_CHARGE:
			if Input.is_action_just_pressed("fish_action"):
				_enter_throw_line()

		# Add other states as needed...

# -- State Transitions --

func _enter_fishing_idle():
	current_state = State.FISHING_IDLE
	print("🐟 State: FISHING_IDLE")
	# Optionally hide direction and power UI

func _enter_direction_select():
	current_state = State.DIRECTION_SELECT
	print("🎯 State: DIRECTION_SELECT")
	if has_node("DirectionSelector"):
		$DirectionSelector.show_selector()

func _enter_power_charge():
	current_state = State.POWER_CHARGE
	print("⚡ State: POWER_CHARGE")
	if has_node("DirectionSelector"):
		$DirectionSelector.hide_selector()
	if has_node("PowerMeter"):
		$PowerMeter.start_charge()

func _enter_throw_line():
	current_state = State.THROW_LINE
	print("🎣 State: THROW_LINE")
	if has_node("PowerMeter"):
		var power = $PowerMeter.get_power_value()
		print("Power value:", power)
		$PowerMeter.reset()

	# TODO: Use power + direction to calculate bait trajectory
