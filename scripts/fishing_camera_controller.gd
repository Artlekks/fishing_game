extends Node

@export var player: Node3D
@export var cam_focus: Node3D
@export var cam_exploration: Node3D     # can be PhantomCamera3D
@export var cam_fishing: Camera3D       # plain Camera3D

@export var align_time: float = 0.25    # seconds to rotate to behind
@export var exploration_priority: int = 100
@export var print_debug: bool = false

var _in_fishing: bool = false
var _radius: float = 6.0
var _elev_phi: float = 0.0          # radians
var _theta: float = 0.0             # current azimuth
var _theta_start: float = 0.0
var _theta_goal: float = 0.0
var _t_elapsed: float = 0.0

func _ready() -> void:
	if player == null or cam_focus == null or cam_exploration == null or cam_fishing == null:
		push_error("Assign player, cam_focus, cam_exploration, cam_fishing.")
		return

	# Exploration starts active
	_make_exploration_current()
	cam_fishing.current = false

	# Sample initial orbit from exploration view so distances match
	_sample_from_exploration()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("enter_fishing"):
		_enter_fishing_mode()
	elif event.is_action_pressed("exit_fishing"):
		_exit_fishing_mode()

func _process(delta: float) -> void:
	if _in_fishing:
		# advance angle during align
		if _t_elapsed < align_time:
			_t_elapsed += delta
			if _t_elapsed > align_time:
				_t_elapsed = align_time
			var t: float = 0.0
			if align_time > 0.0:
				t = _t_elapsed / align_time
			_theta = _theta_start + _shortest_delta(_theta_start, _theta_goal) * t

		# rebuild pos from spherical coords and aim at focus
		_set_fish_pos_from_angles(_theta, _elev_phi, _radius)
		cam_fishing.look_at(cam_focus.global_position, Vector3.UP)

# ---------------- enter / exit ----------------

func _enter_fishing_mode() -> void:
	if _in_fishing:
		return
	_in_fishing = true

	# 1) resample from exploration so start pose matches exactly
	_sample_from_exploration()

	# 2) prepose the fishing camera to exploration view to avoid any pop
	_set_fish_pos_from_angles(_theta, _elev_phi, _radius)
	cam_fishing.look_at(cam_focus.global_position, Vector3.UP)

	# 3) compute goal azimuth = behind the player
	# player forward is +Z, so behind is -basis.z
	var fwd_plus_z: Vector3 = player.global_transform.basis.z
	var behind: Vector3 = -fwd_plus_z
	var behind_xz := Vector2(behind.x, behind.z)
	if behind_xz.length() > 0.0:
		behind_xz = behind_xz.normalized()
	_theta_goal = atan2(behind_xz.x, behind_xz.y)

	_theta_start = _theta
	_t_elapsed = 0.0

	# 4) make fishing camera current after prepose
	cam_fishing.current = true

	if print_debug:
		await get_tree().process_frame
		_print_distances("ENTER")

func _exit_fishing_mode() -> void:
	if not _in_fishing:
		return
	_in_fishing = false
	_make_exploration_current()
	cam_fishing.current = false

	if print_debug:
		await get_tree().process_frame
		_print_distances("EXIT")

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

func _make_exploration_current() -> void:
	# Works whether exploration cam is Phantom or Camera3D
	if cam_exploration is Camera3D:
		(cam_exploration as Camera3D).current = true
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
