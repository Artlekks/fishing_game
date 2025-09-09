extends Node3D

signal landed(point: Vector3)
signal reeled_in()

# ---------- Tuning ----------
@export var gravity: float = 24.0

# Reeling pacing (world units / sec). Set by BaitCaster via set_reel_speed_per_sec().
@export var reel_fps: float = 8.0
@export var reel_step_dist: float = 0.35
@export var reel_kill_radius: float = 0.7

# Sinking controls (when not reeling)
@export var sink_rate: float = 0.6                    # m/s downward in water
@export var sink_accel: float = 0.0                   # optional ease-in (m/s^2); keep 0 for linear
@export var water_max_depth: float = 3.0              # fallback depth if no bottom node is provided
@export var water_bottom_path: NodePath = NodePath("")# optional: node whose Y defines the bottom

# Reeling vertical behavior
@export var reel_rise_rate: float = 1.5               # m/s the bait climbs while reeling
@export var player_feet_offset_y: float = 0.0         # adjust if player origin isn’t feet
@export var depth_zone_mask_bit: int = 8   # the bit your DepthZones are on (UI shows 1..20)

# Depth zones (detected via Area3D child "DepthProbe")
var _active_zones: Array[Area3D] = []
@onready var _probe: Area3D = get_node_or_null("DepthProbe")
@export var water_bottom_mask_bit: int = 12  # physics bit used by BottomWall StaticBody3D

var _target_feet_y: float = 0.0

# ---------- State ----------
enum Mode { INACTIVE, FLYING, LANDED, SINKING, REELING }

var _mode: int = Mode.INACTIVE
var _vel: Vector3 = Vector3.ZERO
var _water_y: float = 0.0                 # water surface Y for this cast
var _bottom_y: float = 0.0                # computed bottom limit for sinking

var _reel_target: Node3D = null
var _reel_active: bool = false            # true only while K is held
var _reel_speed: float = 0.1              # world units per second

# Curved reeling
@export var curve_max_strength: float = 0.8
@export var curve_ramp_up: float = 6.0
@export var curve_ramp_down: float = 8.0
@export var curve_falloff_start: float = 5.0
@export var curve_falloff_end: float = 1.0
var _zone_recheck_t: float = 0.0
@export var zone_recheck_interval: float = 0.25   # seconds

var _curve_input: int = 0                 # -1, 0, +1 from FSM
var _curve_bias: float = 0.0              # smoothed curve input
var _sink_speed: float = 0.0              # current sinking speed (for accel option)

func _ready() -> void:
	if _probe != null:
		_probe.area_entered.connect(_on_probe_area_entered)
		_probe.area_exited.connect(_on_probe_area_exited)

# ---------- Public API ----------
func start(at_position: Vector3, initial_velocity: Vector3, water_surface_y: float) -> void:
	global_position = at_position
	_vel = initial_velocity
	_water_y = water_surface_y
	
	
	# Compute a baseline bottom
	_compute_bottom_y()

	# Initialize active zones from the probe (one-shot at cast start)
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
	
		_compute_bottom_y()
	_sink_speed = 0.0
	_zone_recheck_t = 0.0
	_refresh_zones_from_probe()   # <-- replace your old init code with this one-liner

	_sink_speed = 0.0
	_mode = Mode.FLYING
	set_physics_process(true)

	print("CAST: water_y=", _water_y)
# in _recompute_bottom_y end:
	print("BOTTOM_Y -> ", _bottom_y)

func start_reel(target: Node3D) -> void:
	_reel_target = target

	# capture the desired finish Y from the current player now
	_target_feet_y = 0.0
	if _reel_target != null:
		_target_feet_y = _reel_target.global_position.y + player_feet_offset_y

	# fallback reel speed if caster didn't set it yet
	if _reel_speed <= 0.0:
		_reel_speed = max(0.01, reel_fps * reel_step_dist)

	_reel_active = false
	_mode = Mode.REELING
	set_physics_process(true)

func set_reel_active(active: bool) -> void:
	_reel_active = active
	if active:
		# pause sinking immediately when reel engages
		if _mode == Mode.SINKING or _mode == Mode.LANDED:
			_mode = Mode.REELING
	else:
		# resume sinking if we are in water and not already reeling
		if _mode == Mode.REELING:
			_mode = Mode.SINKING

func set_reel_speed_per_sec(speed: float) -> void:
	_reel_speed = max(0.01, speed)

func set_curve_input(sign: int) -> void:
	if sign < -1:
		sign = -1
	if sign > 1:
		sign = 1
	_curve_input = sign

func set_kill_radius(r: float) -> void:
	reel_kill_radius = max(0.01, r)

func despawn() -> void:
	queue_free()

# ---------- Depth zone hooks ----------
func _on_probe_area_entered(a: Area3D) -> void:
	if a != null and a.is_in_group(&"depth_zone"):
		_active_zones.append(a)
		_recompute_bottom_y()
		print("ENTER:", a.name, " bottom_y=", _bottom_y, " water_y=", _water_y)

func _on_probe_area_exited(a: Area3D) -> void:
	if a != null and a.is_in_group(&"depth_zone"):
		var i := _active_zones.find(a)
		if i != -1:
			_active_zones.remove_at(i)
		_recompute_bottom_y()
		print("EXIT :", a.name, " bottom_y=", _bottom_y, " water_y=", _water_y)

func _recompute_bottom_y() -> void:
	# Prefer physics bottom (StaticBody3D on WaterBottom layer)
	var by: float = _query_bottom_y_physics()

	# Safety: never above the surface
	if by > _water_y:
		by = _water_y

	_bottom_y = by

# ---------- Internals ----------
func _physics_process(delta: float) -> void:
	match _mode:
		Mode.FLYING:
			# ballistic
			_vel.y -= gravity * delta
			var curr := global_position
			var next := curr + _vel * delta

			# cross water plane this frame?
			if curr.y >= _water_y and next.y <= _water_y:
				var denom := curr.y - next.y
				var t := 0.0
				if absf(denom) > 0.0001:
					t = (curr.y - _water_y) / denom
				var hit := curr.lerp(next, t)
				hit.y = _water_y
				global_position = hit
				landed.emit(hit)

				# enter sinking unless reel is immediately active
				if _reel_active:
					_mode = Mode.REELING
				else:
					_sink_speed = 0.0
					_mode = Mode.SINKING
			else:
				global_position = next

		Mode.LANDED:
			# kept for compatibility; immediately flow into SINKING unless reeling
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

			# gradual Y drop toward bottom while not reeling
			var pos := global_position
			if pos.y > _bottom_y:
				# optional accel
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

			# if player begins holding reel, switch mode (handled in set_reel_active too)
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

			# Horizontal pull (XZ) + curve
			var to3 := tgt.global_position - global_position
			var to_xz := Vector3(to3.x, 0.0, to3.z)
			var dist := to_xz.length()

			# compute desired cap Y: cannot exceed water surface, should end at player's feet
			var cap_y := _target_feet_y
			if cap_y > _water_y:
				cap_y = _water_y

			# finish when close in 3D (after we raise to cap)
			var to3_len := to3.length()
			if to3_len <= reel_kill_radius:
				# snap Y to the capped feet level so it doesn't finish below surface
				var p0 := global_position
				if p0.y != cap_y:
					global_position = Vector3(p0.x, cap_y, p0.z)
				_mode = Mode.INACTIVE
				set_physics_process(false)
				reeled_in.emit()
				return

			if dist > 0.0:
				var to_dir := to_xz / dist

				# curve ramping
				var target := float(_curve_input)   # -1..+1
				var rate := curve_ramp_up
				if absf(target) < absf(_curve_bias):
					rate = curve_ramp_down
				_curve_bias = move_toward(_curve_bias, target, rate * delta)

				var side := Vector3.UP.cross(to_dir)
				var k := _curve_bias * _curve_strength_for_dist(dist)

				var steer := (to_dir + side * k).normalized()
				var step := _reel_speed * delta
				if step > dist:
					step = dist
				global_position += steer * step

			# vertical rise toward cap_y (never fly above surface)
			var p := global_position
			if p.y < cap_y:
				var dy := reel_rise_rate * delta
				var new_y := p.y + dy
				if new_y > cap_y:
					new_y = cap_y
				global_position = Vector3(p.x, new_y, p.z)

		_:
			set_physics_process(false)

func _curve_strength_for_dist(dist: float) -> float:
	# linear falloff between end and start
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
	# prefer a bottom node if provided; otherwise surface - depth
	var bottom_node := get_node_or_null(water_bottom_path) as Node3D
	if bottom_node != null:
		_bottom_y = bottom_node.global_position.y
	else:
		_bottom_y = _water_y - max(0.0, water_max_depth)

func _refresh_zones_from_probe() -> void:
	_active_zones.clear()

	# Sphere positioned at the probe (or bait if no probe)
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

	# IMPORTANT: look for AREAS, not bodies
	params.collide_with_areas = true
	params.collide_with_bodies = false

	# Mask for your depth zones (UI bit index; 1..20)
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
	# Debug once: uncomment to see hits
	# print("Probe overlaps:", _active_zones.size(), " -> ", _active_zones.map(func(x): return x.name))

func _query_bottom_y_physics() -> float:
	var from: Vector3 = global_position + Vector3(0.0, 0.1, 0.0)
	var to: Vector3 = from + Vector3(0.0, -50.0, 0.0)  # “deep enough”
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

	# Fallback if nothing was hit
	return _water_y - max(0.0, water_max_depth)
