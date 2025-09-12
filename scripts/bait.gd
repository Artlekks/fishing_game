extends Node3D

signal landed(point: Vector3)
signal reeled_in()
signal depth_y_changed(y: float)

# ---------- Tuning ----------
@export var gravity: float = 24.0

# Reeling pacing (horizontal XZ), set by caster via set_reel_speed_per_sec()
@export var reel_fps: float = 8.0
@export var reel_step_dist: float = 0.35
@export var reel_kill_radius: float = 0.7

# Sinking controls
@export var sink_rate: float = 0.6
@export var sink_accel: float = 0.0
@export var water_max_depth: float = 3.0
@export var water_bottom_path: NodePath = NodePath("")

# Reeling vertical behavior (UNITS/SEC). This now truly controls the rise speed.
@export var reel_rise_rate: float = 0.25          # lower = slower rise to surface while reeling
@export var player_feet_offset_y: float = 0.0

# Depth zone / physics masks
@export var depth_zone_mask_bit: int = 8
@export var water_bottom_mask_bit: int = 12

# Curved reeling
@export var curve_max_strength: float = 0.8
@export var curve_ramp_up: float = 6.0
@export var curve_ramp_down: float = 8.0
@export var curve_falloff_start: float = 5.0
@export var curve_falloff_end: float = 1.0

# Visual splash alignment: center must reach water + offset to "touch"
@export var water_touch_offset: float = 0.06

# ---------- State ----------
enum Mode { INACTIVE, FLYING, LANDED, SINKING, REELING }

var _mode: int = Mode.INACTIVE
var _vel: Vector3 = Vector3.ZERO

var _water_y: float = 0.0
var _bottom_y: float = 0.0

var _reel_target: Node3D = null
var _reel_active: bool = false
var _reel_speed: float = 0.1

var _target_feet_y: float = 0.0

var _curve_input: int = 0                  # -1,0,+1 from FSM
var _curve_bias: float = 0.0
var _last_depth_y: float = 0.0

# sinking helper
var _sink_speed: float = 0.0

# depth zones via probe
@onready var _probe: Area3D = get_node_or_null("DepthProbe")
var _active_zones: Array[Area3D] = []
var _zone_recheck_t: float = 0.0
@export var zone_recheck_interval: float = 0.25

func _ready() -> void:
	_last_depth_y = global_position.y

	if _probe != null:
		_probe.area_entered.connect(_on_probe_area_entered)
		_probe.area_exited.connect(_on_probe_area_exited)

# ---------- Public API ----------

func start(at_position: Vector3, initial_velocity: Vector3, water_surface_y: float) -> void:
	global_position = at_position
	_vel = initial_velocity
	_water_y = water_surface_y

	_compute_bottom_y()

	# initialize probe overlaps once, then recompute
	_active_zones.clear()
	if _probe != null:
		var arr := _probe.get_overlapping_areas()
		var m := arr.size()
		var j := 0
		while j < m:
			var a := arr[j]
			if a != null and a.is_in_group(&"depth_zone"):
				_active_zones.append(a)
			j += 1
		_recompute_bottom_y()

	_sink_speed = 0.0
	_zone_recheck_t = 0.0
	_refresh_zones_from_probe()

	_mode = Mode.FLYING
	set_physics_process(true)

func start_reel(target: Node3D) -> void:
	_reel_target = target

	_target_feet_y = target.global_position.y + player_feet_offset_y
	if _target_feet_y < _surface_touch_y():
		_target_feet_y = _surface_touch_y()

	if _reel_speed <= 0.0:
		_reel_speed = max(0.01, reel_fps * reel_step_dist)

	_reel_active = false
	_mode = Mode.REELING
	set_physics_process(true)

func set_reel_active(active: bool) -> void:
	_reel_active = active
	if active:
		if _mode == Mode.SINKING or _mode == Mode.LANDED:
			_mode = Mode.REELING
	else:
		if _mode == Mode.REELING:
			_mode = Mode.SINKING

func set_reel_speed_per_sec(speed: float) -> void:
	_reel_speed = max(0.01, speed)

func set_curve_input(curve_sign: int) -> void:
	if curve_sign < -1:
		curve_sign = -1
	elif curve_sign > 1:
		curve_sign = 1
	_curve_input = curve_sign

func set_kill_radius(r: float) -> void:
	reel_kill_radius = max(0.01, r)

func despawn() -> void:
	queue_free()

# ---------- Depth zones ----------

func _on_probe_area_entered(a: Area3D) -> void:
	if a != null and a.is_in_group(&"depth_zone"):
		_active_zones.append(a)
		_recompute_bottom_y()

func _on_probe_area_exited(a: Area3D) -> void:
	if a != null and a.is_in_group(&"depth_zone"):
		var i := _active_zones.find(a)
		if i != -1:
			_active_zones.remove_at(i)
		_recompute_bottom_y()

func _recompute_bottom_y() -> void:
	var by: float = _query_bottom_y_physics()
	if by > _water_y:
		by = _water_y
	_bottom_y = by

# ---------- Internals ----------

func _physics_process(delta: float) -> void:
	var y: float = global_position.y
	if y != _last_depth_y:
		_last_depth_y = y
		emit_signal("depth_y_changed", y)

	match _mode:
		Mode.FLYING:
			# ballistic step
			_vel.y -= gravity * delta
			var curr := global_position
			var next := curr + _vel * delta

			# plane cross at touch height
			var touch_y := _surface_touch_y()
			if curr.y >= touch_y and next.y <= touch_y:
				var denom := curr.y - next.y
				var t: float = 0.0
				if absf(denom) > 0.0001:
					t = (curr.y - touch_y) / denom

				var hit := curr.lerp(next, t)
				hit.y = touch_y
				global_position = hit
				landed.emit(hit)

				if _reel_active:
					_mode = Mode.REELING
				else:
					_sink_speed = 0.0
					_mode = Mode.SINKING
			else:
				global_position = next

		Mode.LANDED:
			# legacy step; immediately choose sink or reel
			if _reel_active:
				_mode = Mode.REELING
			else:
				_sink_speed = 0.0
				_mode = Mode.SINKING

		Mode.SINKING:
			_zone_recheck_t -= delta
			if _zone_recheck_t <= 0.0:
				_zone_recheck_t = zone_recheck_interval
				_refresh_zones_from_probe()

			var pos := global_position
			if pos.y > _bottom_y:
				if sink_accel > 0.0:
					_sink_speed += sink_accel * delta
				else:
					_sink_speed = sink_rate
				var dy := _sink_speed * delta
				var new_y := pos.y - dy
				if new_y < _bottom_y:
					new_y = _bottom_y
				pos.y = new_y
				global_position = pos

			if _reel_active:
				_mode = Mode.REELING

		Mode.REELING:
			_zone_recheck_t -= delta
			if _zone_recheck_t <= 0.0:
				_zone_recheck_t = zone_recheck_interval
				_refresh_zones_from_probe()

			var tgt := _reel_target
			if tgt == null or not is_instance_valid(tgt):
				set_physics_process(false)
				return

			if not _reel_active:
				_mode = Mode.SINKING
				return

			# --- vertical: single, authoritative rule ---
			var surf_y := _surface_touch_y()
			var y_now := global_position.y
			var rise_step := reel_rise_rate * delta
			if y_now < surf_y:
				y_now = min(y_now + rise_step, surf_y)
				global_position.y = y_now
			else:
				# already at/above surf_y -> clamp to surf_y (no flying)
				if y_now > surf_y:
					global_position.y = surf_y

			# --- horizontal pull (XZ) with curve ---
			var to3 := tgt.global_position - global_position
			var to_xz := Vector3(to3.x, 0.0, to3.z)
			var dist := to_xz.length()

			# finish when overall distance is close
# finish when we're close horizontally (XZ only)
			if dist <= reel_kill_radius:
				# snap XZ to player target
				var final := global_position
				final.x = tgt.global_position.x
				final.z = tgt.global_position.z

				# snap Y to feet but never above the water surface
				var cap_y := _target_feet_y
				if cap_y > _water_y:
					cap_y = _water_y
				final.y = cap_y

				global_position = final

				_mode = Mode.INACTIVE
				set_physics_process(false)
				reeled_in.emit()   # bait_caster listens and despawns the bait
				return

			if dist > 0.0:
				var to_dir := to_xz / dist

				var target_bias := float(_curve_input)
				var rate := curve_ramp_up
				if absf(target_bias) < absf(_curve_bias):
					rate = curve_ramp_down
				_curve_bias = move_toward(_curve_bias, target_bias, rate * delta)

				var side := Vector3.UP.cross(to_dir)
				var k := _curve_bias * _curve_strength_for_dist(dist)
				var steer := (to_dir + side * k).normalized()

				var step := _reel_speed * delta
				if step > dist:
					step = dist
				global_position += steer * step

		_:
			set_physics_process(false)

func _curve_strength_for_dist(dist: float) -> float:
	if dist <= curve_falloff_end:
		return 0.0
	if dist >= curve_falloff_start:
		return curve_max_strength
	var span := curve_falloff_start - curve_falloff_end
	if span <= 0.001:
		return 0.0
	var t := (dist - curve_falloff_end) / span
	return curve_max_strength * t

func _compute_bottom_y() -> void:
	var bottom_node := get_node_or_null(water_bottom_path) as Node3D
	if bottom_node != null:
		_bottom_y = bottom_node.global_position.y
	else:
		_bottom_y = _water_y - max(0.0, water_max_depth)

func _refresh_zones_from_probe() -> void:
	_active_zones.clear()

	var probe_xform: Transform3D = global_transform
	var radius: float = 0.4

	if _probe != null:
		probe_xform = _probe.global_transform
		var cs := _probe.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if cs != null and cs.shape != null and cs.shape is SphereShape3D:
			var sc := _probe.global_transform.basis.get_scale()
			radius = (cs.shape as SphereShape3D).radius * absf(sc.x)

	var sphere := SphereShape3D.new()
	sphere.radius = radius

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.transform = probe_xform
	params.collide_with_areas = true
	params.collide_with_bodies = false

	var mask: int = 1 << (max(1, depth_zone_mask_bit) - 1)
	params.collision_mask = mask

	var space := get_world_3d().direct_space_state
	var results := space.intersect_shape(params, 32)

	var n := results.size()
	var i := 0
	while i < n:
		var d := results[i]
		if d.has("collider"):
			var a := d["collider"] as Object
			if a is Area3D and (a as Area3D).is_in_group(&"depth_zone"):
				_active_zones.append(a)
		i += 1

	_recompute_bottom_y()

func _query_bottom_y_physics() -> float:
	var from: Vector3 = global_position + Vector3(0.0, 0.1, 0.0)
	var to: Vector3 = from + Vector3(0.0, -50.0, 0.0)
	var mask: int = 1 << (max(1, water_bottom_mask_bit) - 1)

	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	q.collide_with_bodies = true
	q.collide_with_areas = false
	q.hit_from_inside = true

	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(q)

	if hit.has("position"):
		var y: float = (hit["position"] as Vector3).y
		if y > _water_y:
			y = _water_y
		return y

	return _water_y - max(0.0, water_max_depth)

func _surface_touch_y() -> float:
	return _water_y + water_touch_offset
