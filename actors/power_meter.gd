extends CanvasLayer

@onready var fill_bar := $power_bar_ui/PowerBarFill
@onready var distance_label := $power_bar_ui/DistanceLabel

@export var charge_speed := 1.0
@export var max_distance := 15.0

var _charging := false
var _power := 0.0
var _direction := 1

func _ready():
	_reset_bar()

func _process(delta):
	if not _charging:
		return

	_power += charge_speed * delta * _direction

	if _power >= 1.0:
		_power = 1.0
		_direction = -1
	elif _power <= 0.0:
		_power = 0.0
		_direction = 1

	_update_visuals()

func start_charge():
	_power = 0.0
	_direction = 1
	_charging = true
	visible = true

func freeze():
	_charging = false

func get_power_value() -> float:
	return _power

func _update_visuals():
	fill_bar.scale.x = _power  # Assumes default scale.x = 1 is full bar
	distance_label.text = "%.1f m" % (_power * max_distance)

func _reset_bar():
	_charging = false
	visible = false
	_power = 0.0
	_direction = 1
	fill_bar.scale.x = 0.0
	distance_label.text = "0.0 m"
