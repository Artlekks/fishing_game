extends Node

@export var player: Node3D
@export var cam_focus: Node3D
@export var cam_exploration: Node3D     # PhantomCamera3D OR Camera3D
@export var cam_fishing: Camera3D       # plain Camera3D

@export var align_time: float = 0.25
@export var exploration_priority: int = 100
@export var print_debug: bool = false
@export var fishing_state: Node = null   # optional: a node with fishing_state_controller.gd
@export var direction_selector: Node3D = null
@export var gate_by_zone: bool = true            # turn gating on/off
@export var zone_facing_ref: Node3D              # a node whose +Z points toward water
@export var cone_half_angle_deg: float = 45.0    # 90° total; tweak in Inspector

var _in_fishing: bool = false

# spherical orbit about cam_focus
var _radius: float = 6.0
var _elev_phi: float = 0.0              # radians
var _theta: float = 0.0                 # current azimuth

# alignment state (used both for enter and exit)
var _theta_start: float = 0.0
var _theta_goal: float = 0.0
var _t_elapsed: float = 0.0
var _aligning: bool = false
var _align_to_exploration: bool = false  # false = aligning to fishing, true = aligning back to exploration

func _ready() -> void:
	if player == null or cam_focus == null or cam_exploration == null or cam_fishing == null:
		push_error("Assign player, cam_focus, cam_exploration, cam_fishing.")
		return

	_make_exploration_current()
	cam_fishing.current = false
	_sample_from_exploration()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("enter_fishing"):
		if _is_facing_water():
			_enter_fishing_mode()
	elif event.is_action_pressed("exit_fishing"):
		_exit_fishing_mode()


func _process(delta: float) -> void:
	# We drive the fishing camera whenever it is current OR we are in the middle of an exit align.
	var driving_fish_cam := cam_fishing.current or (_aligning and _align_to_exploration)

	if driving_fish_cam:
		if _aligning:
			_t_elapsed += delta
			if _t_elapsed > align_time:
				_t_elapsed = align_time

			var t: float = 0.0
			if align_time > 0.0:
				t = _t_elapsed / align_time
			# ease-out so it lands softly
			t = _ease_out(t)

			_theta = _theta_start + _shortest_delta(_theta_start, _theta_goal) * t

			# when finished, finalize state/switch cams if needed
			if _t_elapsed >= align_time:
				_aligning = false
				if _align_to_exploration:
					_make_exploration_current()
					cam_fishing.current = false
					_in_fishing = false
					if print_debug:
						await get_tree().process_frame
						_print_distances("EXIT")
				else:
					# finished entering; remain in fishing mode
					pass

		_set_fish_pos_from_angles(_theta, _elev_phi, _radius)
		cam_fishing.look_at(cam_focus.global_position, Vector3.UP)

# ---------------- enter / exit ----------------
func _is_facing_water() -> bool:
	# Compatible defaults: if not wired, do nothing special.
	if not gate_by_zone or zone_facing_ref == null or player == null:
		return true

	# Player forward (+Z) on XZ plane
	var pfwd: Vector3 = player.global_transform.basis.z
	pfwd.y = 0.0
	if pfwd.length() == 0.0:
		return false
	pfwd = pfwd.normalized()

	# Allowed direction: zone_facing_ref +Z on XZ plane
	var zdir: Vector3 = zone_facing_ref.global_transform.basis.z
	zdir.y = 0.0
	if zdir.length() == 0.0:
		return false
	zdir = zdir.normalized()

	# Compare dot to cos(limit) with a tiny tolerance for borderline diagonals
	var dot: float = clampf(pfwd.dot(zdir), -1.0, 1.0)
	var cos_limit: float = cos(deg_to_rad(cone_half_angle_deg))
	return dot >= cos_limit - 0.001

func _enter_fishing_mode() -> void:
	# ignore if already aligning toward fishing
	if _in_fishing and not _align_to_exploration:
		return

	_in_fishing = true
	_aligning = true
	_align_to_exploration = false

	# start from exploration pose to avoid any pop
	var pivot: Vector3 = cam_focus.global_position
	var rel: Vector3 = cam_exploration.global_position - pivot

	_radius = rel.length()
	if _radius < 0.01:
		_radius = 6.0

	var xz_len: float = Vector2(rel.x, rel.z).length()
	if xz_len < 0.0001:
		xz_len = 0.0001
	_elev_phi = atan2(rel.y, xz_len)
	_theta = atan2(rel.x, rel.z)

	# compute goal = behind player (player +Z means camera on -Z side)
	var fwd_plus_z: Vector3 = player.global_transform.basis.z
	var behind: Vector3 = -fwd_plus_z
	var behind_xz := Vector2(behind.x, behind.z)
	if behind_xz.length() > 0.0:
		behind_xz = behind_xz.normalized()
	_theta_goal = atan2(behind_xz.x, behind_xz.y)

	_theta_start = _theta
	_t_elapsed = 0.0

	# prepose and make current
	_set_fish_pos_from_angles(_theta, _elev_phi, _radius)
	cam_fishing.look_at(cam_focus.global_position, Vector3.UP)
	cam_fishing.current = true
	
	if fishing_state != null:
		# enable and start immediately; prep runs while camera continues aligning
		if fishing_state.has_method("set_enabled"):
			fishing_state.call("set_enabled", true)
		if fishing_state.has_method("start_sequence"):
			fishing_state.call("start_sequence")

	if print_debug:
		await get_tree().process_frame
		_print_distances("ENTER")

func _exit_fishing_mode() -> void:
	# If we are not in fishing and not aligning from fishing, ignore.
	if not _in_fishing and not ( _aligning and not _align_to_exploration ):
		return
		
	if direction_selector != null:
		direction_selector.call("hide_for_fishing")

	# Target = current exploration view
	var pivot: Vector3 = cam_focus.global_position
	var rel: Vector3 = cam_exploration.global_position - pivot

	var xz_len: float = Vector2(rel.x, rel.z).length()
	if xz_len < 0.0001:
		xz_len = 0.0001
	var theta_target: float = atan2(rel.x, rel.z)

	# start aligning back using same align_time
	_aligning = true
	_align_to_exploration = true
	_theta_start = _theta
	_theta_goal = theta_target
	_t_elapsed = 0.0

	# keep fishing cam current during the exit align to avoid any pop
	if not cam_fishing.current:
		cam_fishing.current = true
	if fishing_state != null and fishing_state.has_method("force_cancel"):
		fishing_state.call("force_cancel")
	if direction_selector != null:
		direction_selector.call("stop_looping")

# ---------------- orbit math ----------------

func _sample_from_exploration() -> void:
	var pivot: Vector3 = cam_focus.global_position
	var rel: Vector3 = cam_exploration.global_position - pivot

	_radius = rel.length()
	if _radius < 0.01:
		_radius = 6.0

	var xz_len: float = Vector2(rel.x, rel.z).length()
	if xz_len < 0.0001:
		xz_len = 0.0001
	_elev_phi = atan2(rel.y, xz_len)

	_theta = atan2(rel.x, rel.z)

func _set_fish_pos_from_angles(theta: float, phi: float, r: float) -> void:
	var pivot: Vector3 = cam_focus.global_position
	var cos_phi: float = cos(phi)
	var xz: float = cos_phi * r
	var x: float = sin(theta) * xz
	var z: float = cos(theta) * xz
	var y: float = sin(phi) * r
	cam_fishing.global_position = Vector3(pivot.x + x, pivot.y + y, pivot.z + z)

# ---------------- utils ----------------

func _shortest_delta(a: float, b: float) -> float:
	var d: float = fmod(b - a + PI, TAU)
	if d < 0.0:
		d += TAU
	return d - PI

func _ease_out(t: float) -> float:
	# cubic ease-out
	return 1.0 - pow(1.0 - t, 3.0)

func _make_exploration_current() -> void:
	if cam_exploration is Camera3D:
		(cam_exploration as Camera3D).current = true
	# Support Phantom priority knobs if present
	if _has_prop(cam_exploration, "priority_override"):
		cam_exploration.set("priority_override", true)
	if _has_prop(cam_exploration, "priority"):
		cam_exploration.set("priority", exploration_priority)

func _has_prop(o: Object, prop_name: String) -> bool:
	var lst := o.get_property_list()
	for p in lst:
		var nm: Variant = p.get("name")
		if typeof(nm) == TYPE_STRING:
			if String(nm) == prop_name:
				return true
	return false

func _print_distances(tag: String) -> void:
	var de := cam_exploration.global_position.distance_to(cam_focus.global_position)
	var df := cam_fishing.global_position.distance_to(cam_focus.global_position)
	print("[", tag, "] EXP=", de, "  FISH=", df)
