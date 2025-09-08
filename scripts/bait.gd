extends Node3D

signal landed(point: Vector3)
signal reeled_in()

@export var gravity: float = 24.0
@export var reel_fps: float = 8.0
@export var reel_step_dist: float = 0.35
@export var reel_kill_radius: float = 0.7

enum Mode { INACTIVE, FLYING, LANDED, REELING }

var _mode: int = Mode.INACTIVE
var _vel: Vector3 = Vector3.ZERO
var _water_y: float = 0.0

var _reel_target: Node3D = null
var _reel_active: bool = false
var _reel_speed: float = 0.1   # world-units per second

func start(at_position: Vector3, initial_velocity: Vector3, water_surface_y: float) -> void:
	global_position = at_position
	_vel = initial_velocity
	_water_y = water_surface_y
	_mode = Mode.FLYING
	set_physics_process(true)

func start_reel(target: Node3D) -> void:
	_reel_target = target
	if _reel_speed <= 0.0:
		_reel_speed = max(0.01, reel_fps * reel_step_dist)
	_reel_active = false
	_mode = Mode.REELING
	set_physics_process(true)

func set_reel_active(active: bool) -> void:
	_reel_active = active

func set_reel_speed_per_sec(speed: float) -> void:
	_reel_speed = max(0.01, speed)

func despawn() -> void:
	queue_free()

func _physics_process(delta: float) -> void:
	match _mode:
		Mode.FLYING:
			_vel.y -= gravity * delta
			var curr := global_position
			var next := curr + _vel * delta

			if curr.y >= _water_y and next.y <= _water_y:
				var denom := curr.y - next.y
				var t := 0.0
				if absf(denom) > 0.0001:
					t = (curr.y - _water_y) / denom
				var hit := curr.lerp(next, t)
				hit.y = _water_y
				global_position = hit
				_mode = Mode.LANDED
				set_physics_process(false)
				landed.emit(hit)
			else:
				global_position = next

		Mode.REELING:
			var tgt := _reel_target
			if tgt == null or not is_instance_valid(tgt):
				set_physics_process(false)
				return

			if not _reel_active:
				return

			var to := tgt.global_position - global_position
			var dist := to.length()
			if dist <= reel_kill_radius:
				_mode = Mode.INACTIVE
				set_physics_process(false)
				reeled_in.emit()
				return

			if dist > 0.0:
				var step := _reel_speed * delta
				if step > dist:
					step = dist
				global_position += (to / dist) * step

		_:
			set_physics_process(false)

func set_kill_radius(r: float) -> void:
	reel_kill_radius = max(0.01, r)
