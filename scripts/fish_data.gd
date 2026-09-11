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
