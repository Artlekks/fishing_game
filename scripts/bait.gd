extends Node3D

signal landed(point: Vector3)
signal reeled_in()

@export var gravity: float = 24.0
@export var reel_fps: float = 8.0
@export var reel_step_dist: float = 0.35
@export var reel_kill_radius: float = 0.7
# --- Curved reeling params ---
@export var curve_max_strength: float = 0.8      # 0..1 ~ how hard it can bend sideways
@export var curve_ramp_up: float = 6.0           # how fast curve ramps in  (1/s)
@export var curve_ramp_down: float = 8.0         # how fast it relaxes back to straight (1/s)
@export var curve_falloff_start: float = 5.0     # distance (m) where full curve is allowed
@export var curve_falloff_end: float = 1.0       # distance (m) where curve goes to 0

var _curve_input: int = 0                        # -1(left), 0(straight), +1(right), set by FSM
var _curve_bias: float = 0.0                     # smoothed version of _curve_input

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

func set_curve_input(sign: int) -> void:
	# accepted: -1, 0, +1 (anything else is clamped)
	if sign < -1: sign = -1
	if sign > 1: sign = 1
	_curve_input = sign

func _curve_strength_for_dist(dist: float) -> float:
	# piecewise linear falloff: full beyond start, 0 at/below end
	if dist <= curve_falloff_end:
		return 0.0
	if dist >= curve_falloff_start:
		return curve_max_strength
	var span := curve_falloff_start - curve_falloff_end
	if span <= 0.001:
		return 0.0
	var t := (dist - curve_falloff_end) / span  # 0..1
	return curve_max_strength * t

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

			var to3 := tgt.global_position - global_position
			var to_xz := Vector3(to3.x, 0.0, to3.z)
			var dist := to_xz.length()
			if dist <= reel_kill_radius:
				_mode = Mode.INACTIVE
				set_physics_process(false)
				reeled_in.emit()
				return

			if dist > 0.0:
				var to_dir := to_xz / dist

				# --- smooth our curve bias toward input ---
				var target := float(_curve_input)   # -1..+1
				var rate := curve_ramp_up
				if absf(target) < absf(_curve_bias):
					rate = curve_ramp_down
				_curve_bias = move_toward(_curve_bias, target, rate * delta)

				# --- sideways vector (right-handed); negative bias makes it go left ---
				var side := Vector3.UP.cross(to_dir)   # right on +bias
				var k := _curve_bias * _curve_strength_for_dist(dist)

				# --- steer and move ---
				var steer := (to_dir + side * k).normalized()
				var step := _reel_speed * delta
				if step > dist:
					step = dist
				global_position += steer * step

func set_kill_radius(r: float) -> void:
	reel_kill_radius = max(0.01, r)
