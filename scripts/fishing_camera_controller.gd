# fishing_camera_controller.gd — v4.1 (locks K/I during align, symmetric EXIT)
extends Node

@export var player: Node3D
@export var pivot: Node3D
@export var exploration_camera: Node3D
@export var fishing_camera: Camera3D
@export var water_facing: Node3D = null

@export var gate_by_zone: bool = true
@export_range(1.0, 179.0, 1.0) var cone_half_angle_deg: float = 45.0

@export var align_time: float = 0.35
@export var ease_out: bool = true
@export var debug_log: bool = false
@export var force_ccw_enter: bool = true

signal entered_fishing_view
signal exited_to_exploration_view
signal align_started(to_fishing: bool)

var _in_fishing: bool = false
var _aligning: bool = false
var _align_to_exploration: bool = false

var _radius: float = 6.0
var _elev_phi: float = 0.0
var _theta: float = 0.0

var _theta_start: float = 0.0
var _theta_goal: float = 0.0
var _t_elapsed: float = 0.0

var _exp_theta: float = 0.0
var _enter_direction: int = 0                 # +1 CCW, -1 CW
var _enter_arc_rad: float = 0.0               # |ENTER arc|
var _active_arc_rad: float = 0.0

func _ready() -> void:
	if player == null or pivot == null or exploration_camera == null or fishing_camera == null:
		push_error("FishingCameraController: assign player/pivot/exploration_camera/fishing_camera.")
		set_process(false)
		return
	_make_exploration_current()
	fishing_camera.current = false
	_sample_from_exploration()

func _unhandled_input(event: InputEvent) -> void:
	# LOCK INPUT while aligning so K/I cannot be spammed.
	if _aligning:
		return

	if event.is_action_pressed("enter_fishing"):
		if not _in_fishing and _can_enter_fishing():
			_enter_fishing()
	elif event.is_action_pressed("exit_fishing"):
		if _in_fishing:
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
			t = 1.0 - pow(1.0 - t, 3.0)

		var d_theta: float = 0.0
		if _align_to_exploration:
			# EXIT: always reverse the ENTER arc (CW if ENTER was CCW)
			d_theta = float(-_enter_direction) * _enter_arc_rad
		else:
			if force_ccw_enter:
				# ENTER: always CCW by the precomputed arc
				d_theta = float(_enter_direction) * _enter_arc_rad
			else:
				d_theta = _delta_with_dir(_theta_start, _theta_goal, _enter_direction)

		_theta = _theta_start + d_theta * t

		if _t_elapsed >= align_time:
			_aligning = false
			if _align_to_exploration:
				_theta = _exp_theta
				_make_exploration_current()
				fishing_camera.current = false
				_in_fishing = false
				exited_to_exploration_view.emit()
			else:
				_in_fishing = true
				entered_fishing_view.emit()

	_set_pos_from_angles(_theta, _elev_phi, _radius)
	fishing_camera.look_at(pivot.global_position, Vector3.UP)

# ---------- gating ----------
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
	var dotv: float = clampf(pfwd.dot(wfwd), -1.0, 1.0)
	var ang_deg: float = rad_to_deg(acos(dotv))
	return ang_deg <= cone_half_angle_deg

# ---------- enter / exit ----------
func _enter_fishing() -> void:
	_sample_from_exploration()  # sets _theta and _exp_theta

	# Target yaw = behind the player (+Z forward → camera looks at -Z)
	var fwd: Vector3 = player.global_transform.basis.z
	var back2: Vector2 = Vector2(-fwd.x, -fwd.z)
	if back2.length() == 0.0:
		back2 = Vector2(0.0, 1.0)
	else:
		back2 = back2.normalized()

	_theta_goal = atan2(back2.x, back2.y)
	_theta_start = _theta

	if force_ccw_enter:
		# FORCE CCW on ENTER: arc is the positive (CCW) modular delta [0..TAU)
		var ccw: float = fmod(_theta_goal - _theta_start + TAU, TAU)
		# Pin exact 180° to PI to avoid rounding choosing the other side
		if abs(PI - ccw) < 0.01:
			ccw = PI
		_enter_direction = 1         # CCW
		_enter_arc_rad = ccw         # amount to travel on ENTER (CCW)
		_active_arc_rad = _enter_arc_rad
	else:
		# Fallback to previous shortest-path logic (not used when force_ccw_enter = true)
		var d_short: float = _shortest_delta(_theta_start, _theta_goal)
		_enter_direction = _dir_sign(d_short)
		var d_enter_signed: float = _delta_with_dir(_theta_start, _theta_goal, _enter_direction)
		_enter_arc_rad = abs(d_enter_signed)
		_active_arc_rad = _enter_arc_rad

	_t_elapsed = 0.0
	_aligning = true
	_align_to_exploration = false
	align_started.emit(true)

	fishing_camera.current = true


func _exit_fishing() -> void:
	_theta_start = _theta
	_theta_goal = _exp_theta
	_active_arc_rad = _enter_arc_rad
	_t_elapsed = 0.0
	_aligning = true
	_align_to_exploration = true
	align_started.emit(false)

	if not fishing_camera.current:
		fishing_camera.current = true

# ---------- orbit ----------
func _sample_from_exploration() -> void:
	var rel: Vector3 = exploration_camera.global_position - pivot.global_position
	var xz_len: float = Vector2(rel.x, rel.z).length()
	if xz_len < 0.0001:
		xz_len = 0.0001

	_radius = rel.length()
	if _radius < 0.01:
		_radius = 6.0

	_elev_phi = atan2(rel.y, xz_len)
	_theta = atan2(rel.x, rel.z)
	_exp_theta = _theta

func _set_pos_from_angles(theta: float, phi: float, r: float) -> void:
	var P: Vector3 = pivot.global_position
	var cos_phi: float = cos(phi)
	var xz: float = cos_phi * r
	var x: float = sin(theta) * xz
	var z: float = cos(theta) * xz
	var y: float = sin(phi) * r
	fishing_camera.global_position = Vector3(P.x + x, P.y + y, P.z + z)

# ---------- helpers ----------
func _dir_sign(x: float) -> int:
	if x > 0.0:
		return 1
	elif x < 0.0:
		return -1
	return 0

func _delta_with_dir(from_theta: float, to_theta: float, desired_dir: int) -> float:
	var raw_delta: float = _shortest_delta(from_theta, to_theta)  # (-PI, PI]
	if desired_dir == 0 or raw_delta == 0.0:
		return raw_delta
	var same_dir: bool = false
	if raw_delta > 0.0 and desired_dir > 0:
		same_dir = true
	elif raw_delta < 0.0 and desired_dir < 0:
		same_dir = true
	if same_dir:
		return raw_delta
	var dir_sign: float = 1.0
	if desired_dir < 0:
		dir_sign = -1.0
	return raw_delta + TAU * dir_sign

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

# --- public getters for stepper ---
func is_aligning() -> bool:
	return _aligning

func get_align_delta_rad() -> float:
	if not _aligning:
		return 0.0
	return _theta - _theta_start

func get_align_sign() -> int:
	if not _aligning:
		return 0
	var d: float = _theta - _theta_start
	if d > 0.0:
		return 1
	if d < 0.0:
		return -1
	return 0

func get_align_total_rad() -> float:
	if not _aligning:
		return 0.0
	return _active_arc_rad
