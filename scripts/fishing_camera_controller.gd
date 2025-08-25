# fishing_camera_controller.gd — v2.1 (camera-only, modular, warning-free)
extends Node

# ---- Wiring ----
@export var player: Node3D
@export var pivot: Node3D
@export var exploration_camera: Node          # Camera3D or Phantom (must be a Node3D)
@export var fishing_camera: Camera3D
@export var water_facing: Node3D = null       # optional: +Z toward water

# ---- Gating ----
@export var gate_by_zone: bool = true
@export_range(1.0, 179.0, 1.0) var cone_half_angle_deg: float = 45.0

# ---- Motion ----
@export var align_time: float = 0.35
@export var ease_out: bool = true
@export var debug_log: bool = false

# ---- Signals (no coupling to other systems) ----
signal entered_fishing_view
signal exited_to_exploration_view
signal align_started(to_fishing: bool)

# ---- Internal state ----
var _in_fishing: bool = false
var _aligning: bool = false
var _align_to_exploration: bool = false

# spherical orbit
var _radius: float = 6.0
var _elev_phi: float = 0.0
var _theta: float = 0.0

# tween state
var _theta_start: float = 0.0
var _theta_goal: float = 0.0
var _t_elapsed: float = 0.0

# exploration yaw cached at ENTER (for symmetric EXIT)
var _exp_theta: float = 0.0

# remember ENTER arc direction: +1 (CW), -1 (CCW)
var _enter_direction: int = 0

func _ready() -> void:
	if player == null or pivot == null or exploration_camera == null or fishing_camera == null:
		push_error("FishingCameraController: assign player, pivot, exploration_camera, fishing_camera.")
		set_process(false)
		return
	_make_exploration_current()
	fishing_camera.current = false
	_sample_from_exploration()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("enter_fishing"):
		if _can_enter_fishing():
			_enter_fishing()
	elif event.is_action_pressed("exit_fishing"):
		if _in_fishing or (_aligning and not _align_to_exploration):
			_exit_fishing()

func _process(delta: float) -> void:
	var driving: bool = fishing_camera.current or (_aligning and _align_to_exploration)
	if not driving:
		return

	if _aligning:
		_t_elapsed += delta
		if _t_elapsed > align_time:
			_t_elapsed = align_time

		var t: float = 0.0
		if align_time > 0.0:
			t = _t_elapsed / align_time
		if ease_out:
			t = 1.0 - pow(1.0 - t, 3.0)  # cubic ease-out

		var dir_for_this_align: int = _enter_direction
		if _align_to_exploration:
			dir_for_this_align = -_enter_direction  # exit = reverse the enter arc

		var d_theta: float = _delta_with_dir(_theta_start, _theta_goal, dir_for_this_align)
		_theta = _theta_start + d_theta * t

		if _t_elapsed >= align_time:
			_aligning = false
			if _align_to_exploration:
				_make_exploration_current()
				fishing_camera.current = false
				_in_fishing = false
				exited_to_exploration_view.emit()
				if debug_log: print("[FCC] EXIT done (theta=", _theta, ")")
			else:
				_in_fishing = true
				entered_fishing_view.emit()
				if debug_log: print("[FCC] ENTER done (theta=", _theta, ")")

	_set_pos_from_angles(_theta, _elev_phi, _radius)
	fishing_camera.look_at(pivot.global_position, Vector3.UP)

# ---- Public toggles (optional) ----
func set_gate_enabled(enabled: bool) -> void:
	gate_by_zone = enabled

func set_water_facing(node: Node3D) -> void:
	water_facing = node

# ---- Gating ----
func _can_enter_fishing() -> bool:
	if not gate_by_zone:
		return true
	if player == null or water_facing == null:
		return false

	var pfwd: Vector3 = player.global_transform.basis.z
	var wfwd: Vector3 = water_facing.global_transform.basis.z
	pfwd.y = 0.0
	wfwd.y = 0.0
	if pfwd.length() == 0.0 or wfwd.length() == 0.0:
		return false

	pfwd = pfwd.normalized()
	wfwd = wfwd.normalized()

	var dot: float = clampf(pfwd.dot(wfwd), -1.0, 1.0)
	var ang_deg: float = rad_to_deg(acos(dot))
	return ang_deg <= cone_half_angle_deg

# ---- Enter / Exit ----
func _enter_fishing() -> void:
	_sample_from_exploration()  # sets _theta and caches _exp_theta

	var fwd: Vector3 = player.global_transform.basis.z
	var back2: Vector2 = Vector2(-fwd.x, -fwd.z)
	if back2.length() == 0.0:
		back2 = Vector2(0.0, 1.0)
	else:
		back2 = back2.normalized()

	_theta_goal = atan2(back2.x, back2.y)
	_theta_start = _theta
	_t_elapsed = 0.0
	_aligning = true
	_align_to_exploration = false
	align_started.emit(true)

	# record enter direction (sign of the shortest delta)
	var d_enter: float = _shortest_delta(_theta_start, _theta_goal)
	_enter_direction = _dir_sign(d_enter)

	_set_pos_from_angles(_theta, _elev_phi, _radius)
	fishing_camera.look_at(pivot.global_position, Vector3.UP)
	fishing_camera.current = true

	if debug_log: print("[FCC] ENTER → yaw_target:", _theta_goal, " dir:", _enter_direction)

func _exit_fishing() -> void:
	_aligning = true
	_align_to_exploration = true
	_theta_start = _theta
	_theta_goal = _exp_theta
	_t_elapsed = 0.0
	align_started.emit(false)

	if not fishing_camera.current:
		fishing_camera.current = true

	if debug_log: print("[FCC] EXIT → yaw_target:", _theta_goal)

# ---- Orbit math ----
func _sample_from_exploration() -> void:
	var rel: Vector3 = _exploration_rel()
	var xz_len: float = Vector2(rel.x, rel.z).length()
	if xz_len < 0.0001:
		xz_len = 0.0001

	_radius = rel.length()
	if _radius < 0.01:
		_radius = 6.0

	_elev_phi = atan2(rel.y, xz_len)
	_theta = atan2(rel.x, rel.z)
	_exp_theta = _theta

func _exploration_rel() -> Vector3:
	var pivot_pos: Vector3 = pivot.global_position
	var exp_node: Node3D = exploration_camera as Node3D
	return exp_node.global_position - pivot_pos

func _set_pos_from_angles(theta: float, phi: float, r: float) -> void:
	var P: Vector3 = pivot.global_position
	var cos_phi: float = cos(phi)
	var xz: float = cos_phi * r
	var x: float = sin(theta) * xz
	var z: float = cos(theta) * xz
	var y: float = sin(phi) * r
	fishing_camera.global_position = Vector3(P.x + x, P.y + y, P.z + z)

# ---- Direction helpers ----
func _dir_sign(x: float) -> int:
	if x > 0.0:
		return 1
	elif x < 0.0:
		return -1
	return 0

# delta from A to B, forced to travel in desired_dir (+1 or -1)
func _delta_with_dir(from_theta: float, to_theta: float, desired_dir: int) -> float:
	var raw_delta: float = _shortest_delta(from_theta, to_theta)  # (-PI, PI]
	if desired_dir == 0 or raw_delta == 0.0:
		return raw_delta
	# if shortest already goes in desired direction, keep it
	if (raw_delta > 0.0 and desired_dir > 0) or (raw_delta < 0.0 and desired_dir < 0):
		return raw_delta
	# otherwise, take the long way around in requested direction
	var dir_sign: float = 1.0
	if desired_dir < 0:
		dir_sign = -1.0
	return raw_delta + TAU * dir_sign

# ---- Utils ----
func _shortest_delta(a: float, b: float) -> float:
	var d: float = fmod(b - a + PI, TAU)
	if d < 0.0:
		d += TAU
	return d - PI

func _make_exploration_current() -> void:
	if exploration_camera is Camera3D:
		(exploration_camera as Camera3D).current = true
	elif exploration_camera.has_method("make_current"):
		exploration_camera.call("make_current")
