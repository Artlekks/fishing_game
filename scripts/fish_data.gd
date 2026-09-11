extends Resource
class_name FishData

@export var fish_name: String = ""

@export var average_size: float = 1.0
@export var king_size: float = 2.0

@export var base_stamina: float = 100.0
@export var base_strength: float = 1.0

@export var preferred_depth_min: float = 0.0
@export var preferred_depth_max: float = 10.0

@export var max_points: int = 100

@export var preferred_lures: Array[StringName] = []
@export var locations: Array[StringName] = []

@export_category("Fight Behavior")

@export_range(0.0, 1.0, 0.05)
var lateral_activity: float = 1.0

@export_range(0.0, 1.0, 0.05)
var vertical_activity: float = 1.0

@export var direction_change_min: float = 0.8
@export var direction_change_max: float = 2.0

@export_category("Endurance")

@export_range(1, 8, 1)
var resistance_rounds: int = 2

@export var recovery_time_min: float = 0.8
@export var recovery_time_max: float = 1.5
