extends Node3D

signal landed(point: Vector3)
signal reeled_in()

@export var gravity: float = 24.0

# Reeling pacing (8 frames per second, each frame advances step distance)
@export var reel_fps: float = 1.0
@export var reel_step_dist: float = 0.35    # world units advanced per reel frame
@export var reel_kill_radius: float = 0.7   # despawn radius around target

enum Mode { INACTIVE, FLYING, LANDED, REELING }

var _mode: int = Mode.INACTIVE
var _vel: Vector3 = Vector3.ZERO
var _water_y: float = 0.0

var _reel_target: Node3D = null
var _reel_active: bool = false              # set true only while K is held
var _reel_speed: float = 0.1                # computed from fps * step

func start(at_position: Vector3, initial_velocity: Vector3, water_surface_y: float) -> void:
	global_position = at_position
	_vel = initial_velocity
	_water_y = water_surface_y
	_mode = Mode.FLYING
	set_physics_process(true)

func start_reel(target: Node3D) -> void:
	_reel_target = target
	_reel_speed = max(0.01, reel_fps * reel_step_dist) # 8 fps pacing
	_reel_active = false
	_mode = Mode.REELING
	set_physics_process(true)

func set_reel_active(active: bool) -> void:
	_reel_active = active

func despawn() -> void:
	queue_free()

func _physics_process(delta: float) -> void:
	match _mode:
		Mode.FLYING:
			_vel.y -= gravity * delta
			var curr: Vector3 = global_position
			var next: Vector3 = curr + _vel * delta

			if curr.y >= _water_y and next.y <= _water_y:
				var denom: float = curr.y - next.y
				var t: float = 0.0
				if absf(denom) > 0.0001:
					t = (curr.y - _water_y) / denom
				var hit: Vector3 = curr.lerp(next, t)
				hit.y = _water_y
				global_position = hit
				_mode = Mode.LANDED
				set_physics_process(false)
				landed.emit(hit)
			else:
				global_position = next

		Mode.REELING:
			var tgt: Node3D = _reel_target
			if tgt == null or not is_instance_valid(tgt):
				set_physics_process(false)
				return

			# stop if not holding K
			if not _reel_active:
				return

			var to: Vector3 = tgt.global_position - global_position
			var dist: float = to.length()
			if dist <= reel_kill_radius:
				_mode = Mode.INACTIVE
				set_physics_process(false)
				reeled_in.emit()
				return

			# pace: fps*step distance per second, clamp to remaining distance
			if dist > 0.0:
				var step: float = minf(dist, _reel_speed * delta)
				global_position += (to / dist) * step

		_:
			set_physics_process(false)

# Add anywhere in bait.gd (e.g., under start_reel)
func set_kill_radius(r: float) -> void:
	reel_kill_radius = max(0.01, r)
