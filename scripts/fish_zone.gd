extends Area3D

signal player_entered_fish_zone(zone)
signal player_exited_fish_zone(zone)

var _inside: bool = false

@onready var water_facing: Node3D  = $WaterFacing       # +Z points to water
@onready var camera_anchor: Node3D = $CameraAnchor      # optional

func _ready() -> void:
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

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
	var f := (water_facing.global_transform.basis.z if water_facing else Vector3.FORWARD)
	return f.normalized()

func get_camera_anchor() -> Node3D:
	return camera_anchor

func get_stance_point(default_pos: Vector3) -> Vector3:
	# Stable base point used by the fishing camera for consistent framing
	return camera_anchor.global_position if camera_anchor else default_pos
