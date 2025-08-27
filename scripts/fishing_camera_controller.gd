# fishing_camera_controller.gd — Godot 4.4.1 (no ternary)
# - Locks K/I during align
# - ENTER forces CCW arc (optional)
# - EXIT reverses the exact ENTER arc, but only after Prep_Fishing has finished
# - Plays Cancel_Fishing fully before rotating back

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

# --- Minimal focus after-rotation (projection shift) ---
@export var use_enter_focus_offset: bool = true
@export var focus_delay_frames: int = 5          # ~4–5 frames
@export var enter_h_offset: float = 1.5         # try +0.25 (horizontal)
@export var enter_v_offset: float = 0.8        # try -0.25 (vertical)

@export var enter_focus_tween_time: float = 0.25
@export var exit_focus_tween_time: float = 0.20
@export var focus_tween_ease_out: bool = true

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
var _can_exit := false          # becomes true after Prep_Fishing finished
var _focus_apply_token: int = 5
var _focus_offset_tween: Tween

func _ready() -> void:
	if player == null or pivot == null or exploration_camera == null or fishing_camera == null:
		push_error("FishingCameraController: assign player/pivot/exploration_camera/fishing_camera.")
		set_process(false)
		return

	# Listen for "ready_for_cancel" from the FSM (emitted after Prep_Fishing finishes)
	if fishing_state_controller and fishing_state_controller.has_signal("ready_for_cancel"):
		fishing_state_controller.ready_for_cancel.connect(_on_fsm_ready_for_cancel)

	_make_exploration_current()
	fishing_camera.current = false
	_sample_from_exploration()

func _unhandled_input(event: InputEvent) -> void:
	# While aligning, block input (prevents I from breaking the enter tween)
	if _aligning:
		return

	if event.is_action_pressed("enter_fishing"):
		if not _in_fishing and _can_enter_fishing():
			_enter_fishing()
	elif event.is_action_pressed("exit_fishing"):
		# Only allow exit after Prep_Fishing finished (FSM told us it's ready)
		if _in_fishing and _can_exit:
			_exit_fishing()

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
	_can_exit = false   # block I until FSM says ready
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
	_schedule_enter_focus_offset()

func _exit_fishing() -> void:
	# cancel any scheduled enter-offset job and tween back to center
	_focus_apply_token += 1
	await _tween_focus_offset_to(0.0, 0.0, exit_focus_tween_time)

	_can_exit = false  # lock out repeated presses

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

func _apply_focus_offset(h: float, v: float) -> void:
	if fishing_camera:
		fishing_camera.h_offset = h
		fishing_camera.v_offset = v

func _clear_focus_offset() -> void:
	_apply_focus_offset(0.0, 0.0)

func _tween_focus_offset_to(h: float, v: float, dur: float) -> void:
	if fishing_camera == null:
		return
	# kill any previous tween
	if _focus_offset_tween and _focus_offset_tween.is_valid():
		_focus_offset_tween.kill()
	_focus_offset_tween = null

	if dur <= 0.0:
		_apply_focus_offset(h, v)
		return

	_focus_offset_tween = create_tween()
	if focus_tween_ease_out:
		_focus_offset_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# run h & v in parallel
	_focus_offset_tween.tween_property(fishing_camera, "h_offset", h, dur)
	_focus_offset_tween.set_parallel(true)
	_focus_offset_tween.tween_property(fishing_camera, "v_offset", v, dur)
	await _focus_offset_tween.finished

# Wait until ENTER align is fully done, then N frames, then tween the offset.
func _schedule_enter_focus_offset() -> void:
	_focus_apply_token += 1
	var my_token: int = _focus_apply_token

	# start centered every time
	_clear_focus_offset()

	# wait while entering alignment is running
	while _aligning and not _align_to_exploration:
		await get_tree().process_frame
		if my_token != _focus_apply_token:
			return

	# extra delay frames
	var n: int = focus_delay_frames
	if n < 0:
		n = 0
	while n > 0:
		await get_tree().process_frame
		if my_token != _focus_apply_token:
			return
		n -= 1

	if use_enter_focus_offset and my_token == _focus_apply_token:
		await _tween_focus_offset_to(enter_h_offset, enter_v_offset, enter_focus_tween_time)

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

# --- FSM hooks ---
func _on_fsm_ready_for_cancel() -> void:
	_can_exit = true
