extends Node

enum State {
	FISHING_IDLE,
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
	print("Fishing test mode started")
	_enter_fishing_idle()

func _enter_fishing_idle():
	current_state = State.FISHING_IDLE
	print("Fishing idle — waiting for input")
	# Activate direction selector here (later step)

func _process(delta):
	if Input.is_action_just_pressed("fish_action"):
		if current_state == State.FISHING_IDLE:
			_enter_power_charge()
		elif current_state == State.POWER_CHARGE:
			_enter_throw_line()

func _enter_power_charge():
	current_state = State.POWER_CHARGE
	print("Power charge started")
	# Start power bar cycling (later)

func _enter_throw_line():
	current_state = State.THROW_LINE
	print("Throw line triggered")
	# Calculate power + direction, throw bait (later)
