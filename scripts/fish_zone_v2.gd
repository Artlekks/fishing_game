extends Area3D

@export var facing_tolerance_degrees: float = 60.0

@onready var water_facing: Node3D = $WaterFacing
@onready var water_surface: Node3D = $WaterSurface

func can_player_fish(player: Node3D) -> bool:
	if not overlaps_body(player):
		return false

	var player_forward := player.global_transform.basis.z.normalized()
	var water_forward := water_facing.global_transform.basis.z.normalized()

	var angle := rad_to_deg(player_forward.angle_to(water_forward))

	return angle <= facing_tolerance_degrees

func get_water_forward() -> Vector3:
	return water_facing.global_transform.basis.z.normalized()
	
func get_water_y() -> float:
	return water_surface.global_position.y
