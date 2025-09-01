extends Node3D
class_name DirectionSelector

# ---- Paths ----
@export var player_path: NodePath
@export var camera_controller_path: NodePath
@export var facing_source_path: NodePath         # optional (e.g. WaterFacing)
@export_enum("+X","-X","+Z","-Z") var facing_axis: String = "-X"

# ---- Dots (drag in order: dot_0..dot_7) ----
@export var dots: Array[Node3D] = []
@export var frame_hold_time: float = 1.0 / 60.0  # 1 frame at 60 FPS
@export var pause_frames: int = 6                # all dots on for ~6 frames

# ---- Placement (player-local) ----
@export var local_offset: Vector3 = Vector3(0.0, 0.8, 0.6)

# ---- Aim ----
@export var max_local_deg: float = 30.0          # DS local swing
@export var yaw_speed_deg: float = 180.0         # deg/sec to reach edge

# ---- Camera continuous orbit (after 30°) ----
@export var stream_speed_deg: float = 90.0       # deg/sec while held at edge
@export var extra_cap_deg: float = 60.0          # extra beyond ±30° (→ total ±90°)

# ---- Input ----
const ACT_LEFT  := "ds_left"
const ACT_RIGHT := "ds_right"

# ---- State ----
var _player: Node3D = null
var _cam_ctrl: Node = null
var _facing_src: Node3D = null

var _base_yaw: float = 0.0            # world yaw baseline
var _local_yaw: float = 0.0           # ±30°
var _extra_deg: float = 0.0           # camera extra from center (−60..+60)
var _edge_pause: float = 0.0
var _was_at_edge: bool = false

# dot cycle state
var _phase: String = "grow"           # "grow" → "pause"
var _idx: int = -1
var _t: float = 0.0

func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_cam_ctrl = get_node_or_null(camera_controller_path)
	_facing_src = get_node_or_null(facing_source_path) as Node3D

	_set_all(false)
	visible = false
	set_process(false)

func show_for_fishing(origin: Node3D = null) -> void:
	if origin != null:
		_player = origin
	if _player == null:
		_player = get_node_or_null(player_path) as Node3D
	_facing_src = get_node_or_null(facing_source_path) as Node3D

	_base_yaw = _compute_start_yaw()
	_local_yaw = 0.0
	_extra_deg = 0.0
	_edge_pause = 0.0
	_was_at_edge = false

	_restart_dots()

	visible = true
	set_process(true)
	_update_pose()

func hide_for_fishing() -> void:
	visible = false
	set_process(false)
	_set_all(false)

func _process(delta: float) -> void:
	if _player == null or _cam_ctrl == null:
		_update_pose()
		_step_dots(delta)
		return

	# input
	var dir: float = 0.0
	if Input.is_action_pressed(ACT_LEFT):
		dir -= 1.0
	if Input.is_action_pressed(ACT_RIGHT):
		dir += 1.0

	# 1) glide to ±30°
	var max_local: float = deg_to_rad(max_local_deg)
	if dir != 0.0:
		_local_yaw += deg_to_rad(yaw_speed_deg) * dir * delta
		_local_yaw = clampf(_local_yaw, -max_local, max_local)

	# just reached edge?
	var at_edge: bool = absf(_local_yaw) >= max_local - 0.0001
	if at_edge and not _was_at_edge:
		_edge_pause = 0.12  # brief dwell

	# 2) while at edge and key held → continuous camera orbit
	if at_edge and dir != 0.0:
		if _edge_pause > 0.0:
			_edge_pause -= delta
			if _edge_pause < 0.0:
				_edge_pause = 0.0
		else:
			var edge_sign: int = 1
			if _local_yaw < 0.0:
				edge_sign = -1
			_stream_camera(delta, edge_sign)

	_update_pose()
	_step_dots(delta)
	_was_at_edge = at_edge

# ---- continuous camera orbit after 30° ----
func _stream_camera(delta: float, edge_sign: int) -> void:
	var cap: float = extra_cap_deg
	var step: float = stream_speed_deg * delta

	var delta_deg: float = 0.0
	var same_side: bool = (_extra_deg == 0.0) or (signf(_extra_deg) == float(edge_sign))

	if same_side:
		var remaining_up: float = cap - absf(_extra_deg)
		if remaining_up <= 0.0:
			return
		delta_deg = minf(step, remaining_up) * float(edge_sign)
	else:
		var remaining_down: float = absf(_extra_deg)
		if remaining_down <= 0.0:
			return
		delta_deg = minf(step, remaining_down) * float(-signf(_extra_deg))

	_apply_camera_delta(delta_deg)

	_extra_deg += delta_deg
	_base_yaw += deg_to_rad(delta_deg)
	_local_yaw = float(edge_sign) * deg_to_rad(max_local_deg)

func _apply_camera_delta(delta_deg: float) -> void:
	if _cam_ctrl == null:
		return
	if _cam_ctrl.has_method("orbit_apply_delta_immediate"):
		_cam_ctrl.call("orbit_apply_delta_immediate", delta_deg)
		return
	if _cam_ctrl.has_method("orbit_around_player"):
		_cam_ctrl.call("orbit_around_player", delta_deg) # step/tween fallback
		return
	# last-resort (only if your controller has neither API):
	var cam := _cam_ctrl.get("fishing_camera") as Camera3D
	if cam != null and _player != null:
		var ang := deg_to_rad(delta_deg)
		var piv := _player.global_transform.origin
		var rel := cam.global_transform.origin - piv
		rel = Basis(Vector3.UP, ang) * rel
		var nb := cam.global_transform.basis.rotated(Vector3.UP, ang)
		cam.global_transform = Transform3D(nb, piv + rel)
		cam.look_at(piv, Vector3.UP)


# ---- starting yaw from WaterFacing (optional) or player forward ----
func _compute_start_yaw() -> float:
	if _facing_src != null:
		var b: Basis = _facing_src.global_transform.basis
		var v: Vector3 = Vector3.ZERO
		if facing_axis == "+X":
			v = b.x
		elif facing_axis == "-X":
			v = -b.x
		elif facing_axis == "+Z":
			v = b.z
		else:
			v = -b.z
		v.y = 0.0
		if v.length() > 0.0001:
			v = v.normalized()
			return atan2(v.x, v.z)
	# fallback = player forward
	var fwd: Vector3 = -_player.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() > 0.0001:
		fwd = fwd.normalized()
		return atan2(fwd.x, fwd.z)
	return 0.0

# ---- pose ----
func _update_pose() -> void:
	if _player != null:
		var xf: Transform3D = _player.global_transform
		global_position = xf.origin + xf.basis * local_offset
	rotation.y = _base_yaw + _local_yaw

# ---- dots: 0..7 grow, hold all, reset (time-based) ----
func _step_dots(delta: float) -> void:
	_t += delta
	if _t < frame_hold_time:
		return
	_t = 0.0

	if _phase == "grow":
		_idx += 1
		if _idx < dots.size():
			var d := dots[_idx]
			if d: d.visible = true
			if _idx == dots.size() - 1:
				_phase = "pause"
				_idx = pause_frames
		else:
			_phase = "pause"
			_idx = pause_frames
	elif _phase == "pause":
		_idx -= 1
		if _idx <= 0:
			_restart_dots()

func _restart_dots() -> void:
	_set_all(false)
	_phase = "grow"
	_idx = -1
	_t = 0.0

func _set_all(state: bool) -> void:
	for d in dots:
		if d:
			d.visible = state
