extends Area3D

signal player_entered_fish_zone(zone)
signal player_exited_fish_zone(zone)

var _inside: bool = false

@onready var water_facing: Node3D  = $WaterFacing       # +Z points to water
@onready var camera_anchor: Node3D = $CameraAnchor      # optional

func _ready() -> void:
	# Single connection style; no duplicates.
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Make sure the area actually monitors
	monitoring = true
	monitorable = true

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_inside = true
		emit_signal("player_entered_fish_zone", self)
		print("FishZone: entered. water_forward=", get_water_forward())

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_inside = false
		emit_signal("player_exited_fish_zone", self)
		print("FishZone: exited")

func is_player_inside() -> bool:
	return _inside

func get_water_forward() -> Vector3:
	# Safe fallback if the child is missing
	return (water_facing.global_transform.basis.z if water_facing else Vector3.FORWARD).normalized()

func get_camera_anchor() -> Node3D:
	return camera_anchor
