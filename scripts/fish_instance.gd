extends RefCounted
class_name FishInstance


var species: FishData

var size: float = 0.0
var max_stamina: float = 0.0
var strength: float = 0.0
var points: int = 0
var lateral_activity: float = 1.0
var vertical_activity: float = 1.0
var direction_change_min: float = 0.8
var direction_change_max: float = 2.0
var resistance_rounds: int = 1
var recovery_time_min: float = 0.8
var recovery_time_max: float = 1.5

func setup(data: FishData) -> void:
	species = data

	size = _roll_size(data)
	lateral_activity = data.lateral_activity
	vertical_activity = data.vertical_activity
	direction_change_min = data.direction_change_min
	direction_change_max = data.direction_change_max
	
	var size_ratio := size / data.average_size

	max_stamina = data.base_stamina * size_ratio
	strength = data.base_strength * lerpf(1.0, size_ratio, 0.5)

	points = int(round(
		data.max_points
		* clampf(size / data.king_size, 0.1, 1.0)
	))

func _roll_size(data: FishData) -> float:
	var minimum_size := data.average_size * 0.7

	var roll := randf()

	# Bias the result toward more common/smaller fish.
	roll *= roll

	return lerpf(
		minimum_size,
		data.king_size,
		roll
	)
