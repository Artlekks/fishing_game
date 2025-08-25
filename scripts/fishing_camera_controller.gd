# fishing_camera_controller.gd — Godot 4.4.1
extends Node

@export var player: Node3D
@export var pivot: Node3D                   # orbit center; usually CamFocus (or the Player)
@export var exploration_camera: Node        # Camera3D or Phantom-like
@export var fishing_camera: Camera3D        # plain Camera3D
@export var water_facing: Node3D            # its +Z points toward the water

@export var gate_by_zone: bool = true       # require facing-cone vs WaterFacing
@export_range(1.0, 179.0, 1.0) var cone_half_angle_deg: float = 45.0

@export var align_time: float = 0.35
@export var ease_out: bool = true
@export var print_debug: bool = false

var _in_fishing: bool = false
var _aligning: bool = false
var _align_to_exploration: bool = false

# spherical orbit params (about pivot)
var _radius: float = 6.0
var _elev_phi: float = 0.0                  # elevation (radians)
var _theta: float = 0.0                     # azimuth (radians)

# tween state
var _theta_start: float = 0.0
var _theta_goal: float = 0.0
var _t_elapsed: float = 0.0

# cached exploration yaw for perfectly symmetric exit
var _exp_theta: float = 0.0

func _ready() -> void:
	if player == null or pivot == null or exploration_camera == null or fishing_camera == null:
		push_error("Assign player, pivot, exploration_camera, fishing_camera.")
		return
	_make_exploration_current()
	fishing_camera.current = false
	_sample_from_exploration()  # initialize radius/elev/theta so we have sane numbers

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("enter_fishing"):
		if _can_enter_fishing():
			_enter_fishing()
	elif event.is_action_pressed("exit_fishing"):
		if _in_fishing or (_aligning and not _align_to_exploration):
			_exit_fishing()

func _process(delta: float) -> void:
	# drive fishing cam while current, or while aligning back to exploration
	var drive := fishing_camera.current or (_aligning and _align_to_exploration)
	if not drive:
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

		_theta = _theta_start + _shortest_delta(_theta_start, _theta_goal) * t

		if _t_elapsed >= align_time:
			_aligning = false
			if _align_to_exploration:
				_make_exploration_current()
				fishing_camera.current = false
				_in_fishing = false
				if print_debug:
					print("[FCC] EXIT done; theta=", _theta)
			else:
				_in_fishing = true
				if print_debug:
					print("[FCC] ENTER done; theta=", _theta)

	_set_pos_from_angles(_theta, _elev_phi, _radius)
	fishing_camera.look_at(pivot.global_position, Vector3.UP)

# ---------------- gating (player +Z vs WaterFacing +Z, on XZ) ----------------
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
	var ang_deg: float = rad_to_deg(acos(dot))  # 0 = perfectly aligned
	return ang_deg <= cone_half_angle_deg

# ---------------- enter / exit ----------------
func _enter_fishing() -> void:
	# cache exploration pose so exit is perfectly symmetric
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

	# goal = camera behind player (–player +Z), so player +Z faces forward
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

	# place fish cam at exploration yaw to avoid any pop, then make it current
	_set_pos_from_angles(_theta, _elev_phi, _radius)
	fishing_camera.look_at(pivot.global_position, Vector3.UP)
	fishing_camera.current = true

	if print_debug:
		print("[FCC] ENTER tween → yaw:", _theta_goal)

func _exit_fishing() -> void:
	_aligning = true
	_align_to_exploration = true
	_theta_start = _theta
	_theta_goal = _exp_theta
	_t_elapsed = 0.0

	# keep fishing cam current until the tween lands, then switch
	if not fishing_camera.current:
		fishing_camera.current = true

	if print_debug:
		print("[FCC] EXIT tween → yaw:", _theta_goal)

# ---------------- orbit math ----------------
func _sample_from_exploration() -> void:
	var rel: Vector3 = _exploration_rel()
	_radius = rel.length()
	if _radius < 0.01:
		_radius = 6.0
	var xz_len: float = Vector2(rel.x, rel.z).length()
	if xz_len < 0.0001:
		xz_len = 0.0001
	_elev_phi = atan2(rel.y, xz_len)
	_theta = atan2(rel.x, rel.z)
	_exp_theta = _theta

func _exploration_rel() -> Vector3:
	var pivot_pos: Vector3 = pivot.global_position
	var exp_node: Node3D = exploration_camera as Node3D
	return exp_node.global_position - pivot_pos

func _set_pos_from_angles(theta: float, phi: float, r: float) -> void:
	var pivot_pos: Vector3 = pivot.global_position
	var cos_phi: float = cos(phi)
	var xz: float = cos_phi * r
	var x: float = sin(theta) * xz
	var z: float = cos(theta) * xz
	var y: float = sin(phi) * r
	fishing_camera.global_position = Vector3(pivot_pos.x + x, pivot_pos.y + y, pivot_pos.z + z)

# ---------------- utils ----------------
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
