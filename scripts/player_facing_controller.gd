# player_facing_controller.gd
extends Node3D

@export var turn_speed_deg_per_sec: float = 540.0

var _target_yaw_deg: float = 0.0
var _active: bool = false

# Call this when entering a FishZone to start turning toward water
func align_to_forward(world_forward: Vector3) -> void:
	if world_forward == Vector3.ZERO:
		return
	_target_yaw_deg = rad_to_deg(atan2(world_forward.x, world_forward.z))
	_active = true
	print("[FacingRoot] Aligning to yaw:", _target_yaw_deg)

# Instantly snap toward given direction
func snap_to_forward(world_forward: Vector3) -> void:
	if world_forward == Vector3.ZERO:
		return
	rotation_degrees.y = rad_to_deg(atan2(world_forward.x, world_forward.z))
	_active = false
	print("[FacingRoot] Snapped to yaw:", rotation_degrees.y)

# Stop rotating
func stop_align() -> void:
	_active = false
	print("[FacingRoot] Stopped alignment")

func _process(delta: float) -> void:
	if not _active:
		return

	var cur: float = rotation_degrees.y
	var diff: float = fposmod((_target_yaw_deg - cur) + 540.0, 360.0) - 180.0
	var max_step: float = turn_speed_deg_per_sec * delta
	var step: float = clamp(diff, -max_step, max_step)
	rotation_degrees.y = cur + step

	print("[FacingRoot] Current yaw:", rotation_degrees.y)
