# fishing_camera_controller.gd — Godot 4.4.1 (no ternary)
# - Locks K/I during align
# - ENTER forces CCW arc (optional)
# - EXIT reverses the exact ENTER arc, after Cancel_Fishing finishes
extends Node

@export var player: Node3D
@export var pivot: Node3D
@export var exploration_camera: Node3D
@export var fishing_camera: Camera3D
@export var water_facing: Node3D = null
@export var fishing_state_controller: Node   # assign FishingStateController here

@export var gate_by_zone: bool = true
@export_range(1.0, 179.0, 1.0) var cone_half_angle_deg: float = 45.0

@export var align_time: float = 0.35
@export var ease_out: bool = true
@export var debug_log: bool = false
@export var force_ccw_enter: bool = true

signal entered_fishing_view
signal exited_to_exploration_view
signal align_started(to_fishing: bool)

var _in_fishing := false
var _aligning := false
var _align_to_exploration := false

var _radius := 6.0
var _elev_phi := 0.0
var _theta := 0.0

var _theta_start := 0.0
var _theta_goal := 0.0
var _t_elapsed := 0.0

var _exp_theta := 0.0
var _enter_direction := 0       # +1 CCW, -1 CW
var _enter_arc_rad := 0.0       # |ENTER arc|
var _active_arc_rad := 0.0

func _ready() -> void:
	if player == null or pivot == null or exploration_camera == null or fishing_camera == null:
		push_error("FishingCameraController: assign player/pivot/exploration_camera/fishing_camera.")
		set_process(false)
		return
	_make_exploration_current()
	fishing_camera.current = false
	_sample_from_exploration()

func _unhandled_input(event: InputEvent) -> void:
	# While aligning, still allow EXIT (I). Block everything else.
	if _aligning:
		if (not _align_to_exploration) and event.is_action_pressed("exit_fishing"):
			_exit_fishing()
		return

	if event.is_action_pressed("enter_fishing"):
		if not _in_fishing and _can_enter_fishing():
			_enter_fishing()
	elif event.is_action_pressed("exit_fishing"):
		if _in_fishing:
			_exit_fishing()  # plays Cancel_Fishing, then exits

func _process(delta: float) -> void:
	var driving := fishing_camera.current or (_aligning and _align_to_exploration)
	if not driving:
		return

	if _aligning:
		_t_elapsed += delta
		if _t_elapsed > align_time:
			_t_elapsed = align_time

		var t := 1.0
		if align_time > 0.0:
			t = _t_elapsed / align_time
		if ease_out:
			t = 1.0 - pow(1.0 - t, 3.0)

		var d_theta := 0.0
		if _align_to_exploration:
			# EXIT: reverse the ENTER arc exactly
			d_theta = float(-_enter_direction) * _enter_arc_rad
		else:
			# ENTER: follow the chosen direction
			if force_ccw_enter:
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

	var pfwd := player.global_transform.basis.z
	var wfwd := water_facing.global_transform.basis.z
	pfwd.y = 0.0
	wfwd.y = 0.0
	if pfwd.length() == 0.0 or wfwd.length() == 0.0:
		return false

	pfwd = pfwd.normalized()
	wfwd = wfwd.normalized()
	var dotv := clampf(pfwd.dot(wfwd), -1.0, 1.0)
	var ang_deg := rad_to_deg(acos(dotv))
	return ang_deg <= cone_half_angle_deg

# ---------- enter / exit ----------
func _enter_fishing() -> void:
	_sample_from_exploration()  # sets _theta and _exp_theta

	# Target yaw = behind the player (+Z forward → camera at -Z)
	var fwd := player.global_transform.basis.z
	var back2 := Vector2(-fwd.x, -fwd.z)
	if back2.length() == 0.0:
		back2 = Vector2(0.0, 1.0)
	else:
		back2 = back2.normalized()

	_theta_goal = atan2(back2.x, back2.y)
	_theta_start = _theta

	if force_ccw_enter:
		# Positive modular delta [0..TAU)
		var ccw := fmod(_theta_goal - _theta_start + TAU, TAU)
		if abs(PI - ccw) < 0.01:
			ccw = PI
		_enter_direction = 1
		_enter_arc_rad = ccw
		_active_arc_rad = _enter_arc_rad
	else:
		var d_short := _shortest_delta(_theta_start, _theta_goal)
		_enter_direction = _dir_sign(d_short)
		var d_enter_signed := _delta_with_dir(_theta_start, _theta_goal, _enter_direction)
		_enter_arc_rad = abs(d_enter_signed)
		_active_arc_rad = _enter_arc_rad

	_t_elapsed = 0.0
	_aligning = true
	_align_to_exploration = false
	align_started.emit(true)

	fishing_camera.current = true

func _exit_fishing() -> void:
	# If we were still ENTER-aligning, stop that tween immediately.
	if _aligning and not _align_to_exploration:
		_aligning = false
		# Keep the fishing cam active at the current angle
		fishing_camera.current = true

	# 1) Play Cancel_Fishing fully
	if fishing_state_controller:
		if fishing_state_controller.has_method("force_cancel"):
			fishing_state_controller.call("force_cancel")
		if fishing_state_controller.has_signal("cancel_finished"):
			await fishing_state_controller.cancel_finished

	# 2) Start rotate-back alignment
	_start_exit_to_exploration_view()

func _start_exit_to_exploration_view() -> void:
	_theta_start = _theta
	_t_elapsed = 0.0
	_aligning = true
	_align_to_exploration = true
	_active_arc_rad = _enter_arc_rad
	align_started.emit(false)

# ---------- orbit ----------
func _sample_from_exploration() -> void:
	var rel := exploration_camera.global_position - pivot.global_position
	var xz_len := Vector2(rel.x, rel.z).length()
	if xz_len < 0.0001:
		xz_len = 0.0001

	_radius = rel.length()
	if _radius < 0.01:
		_radius = 6.0

	_elev_phi = atan2(rel.y, xz_len)
	_theta = atan2(rel.x, rel.z)
	_exp_theta = _theta

func _set_pos_from_angles(theta: float, phi: float, r: float) -> void:
	var P := pivot.global_position
	var cos_phi := cos(phi)
	var xz := cos_phi * r
	var x := sin(theta) * xz
	var z := cos(theta) * xz
	var y := sin(phi) * r
	fishing_camera.global_position = Vector3(P.x + x, P.y + y, P.z + z)

# ---------- helpers ----------
func _dir_sign(x: float) -> int:
	if x > 0.0:
		return 1
	elif x < 0.0:
		return -1
	return 0

func _delta_with_dir(from_theta: float, to_theta: float, desired_dir: int) -> float:
	var raw_delta := _shortest_delta(from_theta, to_theta)  # (-PI, PI]
	if desired_dir == 0 or raw_delta == 0.0:
		return raw_delta
	var same_dir := false
	if raw_delta > 0.0 and desired_dir > 0:
		same_dir = true
	elif raw_delta < 0.0 and desired_dir < 0:
		same_dir = true
	if same_dir:
		return raw_delta
	var dir_sign := 1.0
	if desired_dir < 0:
		dir_sign = -1.0
	return raw_delta + TAU * dir_sign

func _shortest_delta(a: float, b: float) -> float:
	var d := fmod(b - a + PI, TAU)
	if d < 0.0:
		d += TAU
	return d - PI

func _make_exploration_current() -> void:
	if exploration_camera is Camera3D:
		(exploration_camera as Camera3D).current = true
	elif exploration_camera.has_method("make_current"):
		exploration_camera.call("make_current")

# --- public getters for stepper / debug ---
func is_aligning() -> bool:
	return _aligning

func get_align_delta_rad() -> float:
	if not _aligning:
		return 0.0
	return _theta - _theta_start

func get_align_sign() -> int:
	if not _aligning:
		return 0
	var d := _theta - _theta_start
	if d > 0.0:
		return 1
	elif d < 0.0:
		return -1
	return 0

func get_align_total_rad() -> float:
	if not _aligning:
		return 0.0
	return _active_arc_rad
