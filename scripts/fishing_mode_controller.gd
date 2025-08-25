# fishing_mode_controller.gd — Godot 4.4.1
extends Node

@export var player_body: Node3D
@export var water_facing: Node3D
@export var exploration_camera: Node        # Camera3D or PhantomCamera3D
@export var fishing_camera: Node            # must be a Camera3D (will be made current)

# Optional: hook into your exploration mover to lock input in fishing
@export var exploration_controller: Node = null  # expects set_movement_enabled(bool)

@export_range(1.0, 179.0, 1.0) var cone_half_angle_deg: float = 45.0   # 90° total
@export var align_time: float = 0.35
@export var ease_out: bool = true
@export var print_debug: bool = false

var _in_fishing: bool = false
var _tween: Tween = null

# Cached geometry for orbit (keep radius & height constant)
var _radius: float = 0.0
var _height: float = 0.0

func _ready() -> void:
	# Ensure exploration is active at start
	_activate_cam(exploration_camera)
	_deactivate_cam(fishing_camera)
	_cache_fishcam_geometry()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("enter_fishing"):
		if _can_enter_fishing():
			_enter_fishing()
		elif print_debug:
			print("[FMC] K pressed but facing test failed.")
	elif event.is_action_pressed("exit_fishing"):
		if _in_fishing:
			_exit_fishing()

func _process(_delta: float) -> void:
	# Keep fish cam looking at player while tweening
	if _in_fishing and fishing_camera is Node3D:
		(fishing_camera as Node3D).look_at(player_body.global_position, Vector3.UP)

# ---------- Facing gate (player +Z vs WaterFacing +Z) ----------
func _can_enter_fishing() -> bool:
	if player_body == null or water_facing == null:
		return false
	var pfwd: Vector3 = player_body.global_transform.basis.z
	var wfwd: Vector3 = water_facing.global_transform.basis.z
	pfwd.y = 0.0
	wfwd.y = 0.0
	if pfwd.length() == 0.0 or wfwd.length() == 0.0:
		return false
	pfwd = pfwd.normalized()
	wfwd = wfwd.normalized()
	var d: float = clampf(pfwd.dot(wfwd), -1.0, 1.0)  # 1 = perfectly aligned
	var angle_deg: float = rad_to_deg(acos(d))
	return angle_deg <= cone_half_angle_deg

# ---------- Enter / Exit ----------
func _enter_fishing() -> void:
	_in_fishing = true
	if exploration_controller and exploration_controller.has_method("set_movement_enabled"):
		exploration_controller.call("set_movement_enabled", false)

	# Activate fishing camera first to avoid pop
	_activate_cam(fishing_camera)
	_deactivate_cam(exploration_camera)

	_cache_fishcam_geometry()
	_align_fishcam_to_player_plus_z(align_time)

	if print_debug: print("[FMC] ENTER → tweening to +Z alignment")

func _exit_fishing() -> void:
	_in_fishing = false
	if exploration_controller and exploration_controller.has_method("set_movement_enabled"):
		exploration_controller.call("set_movement_enabled", true)

	# Rotate fishing cam back to the exploration view direction using SAME align_time, then switch cams
	_align_fishcam_back_to_exploration(align_time)

	if print_debug: print("[FMC] EXIT → tweening back to exploration")

# ---------- Camera math ----------
func _cache_fishcam_geometry() -> void:
	if player_body == null or fishing_camera == null: return
	var cam := fishing_camera as Node3D
	if cam == null: return
	var off: Vector3 = cam.global_position - player_body.global_position
	_height = off.y
	var xz := Vector2(off.x, off.z)
	_radius = max(0.01, xz.length())

func _align_fishcam_to_player_plus_z(duration: float) -> void:
	if player_body == null or fishing_camera == null: return
	var cam := fishing_camera as Node3D
	var fwd_plus_z: Vector3 = player_body.global_transform.basis.z.normalized()
	# Camera should sit ALONG the player's +Z direction, preserving radius & height
	var target_xz: Vector3 = fwd_plus_z * _radius
	var target_pos: Vector3 = player_body.global_position + Vector3(target_xz.x, _height, target_xz.z)
	_start_pos_tween(cam, target_pos, duration)

func _align_fishcam_back_to_exploration(duration: float) -> void:
	if player_body == null or fishing_camera == null or exploration_camera == null: return
	var cam := fishing_camera as Node3D
	var target_pos: Vector3
	if exploration_camera is Node3D:
		# Mirror the exploration camera’s relative position around the player (preserve look)
		var exp := exploration_camera as Node3D
		var off: Vector3 = exp.global_position - player_body.global_position
		# keep same radius/height we cached
		var xz := Vector2(off.x, off.z)
		var dir: Vector3
		if xz.length() > 0.0:
			dir = Vector3(xz.x, 0.0, xz.y).normalized()
		else:
			dir = Vector3.BACK
		target_pos = player_body.global_position + Vector3(dir.x * _radius, _height, dir.z * _radius)
	else:
		target_pos = player_body.global_position + Vector3(0.0, _height, -_radius)

	_start_pos_tween(cam, target_pos, duration, func ():
		# Switch cameras ONLY after the tween completes
		_activate_cam(exploration_camera)
		_deactivate_cam(fishing_camera)
	)

func _start_pos_tween(cam: Node3D, target_pos: Vector3, duration: float, on_done: Callable = Callable()) -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	if ease_out:
		_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(cam, "global_position", target_pos, max(0.0, duration))
	if on_done.is_valid():
		_tween.finished.connect(on_done)

# ---------- Generic cam helpers (Camera3D or Phantom) ----------
func _activate_cam(n: Node) -> void:
	if n == null: return
	if n is Camera3D:
		(n as Camera3D).current = true
		return
	if n.has_method("make_current"):
		n.call("make_current")
	elif _has_prop(n, "current"):
		n.set("current", true)
	elif _has_prop(n, "enabled"):
		n.set("enabled", true)
	elif _has_prop(n, "active"):
		n.set("active", true)
	if _has_prop(n, "priority"):
		n.set("priority", 1000)

func _deactivate_cam(n: Node) -> void:
	if n == null: return
	if n is Camera3D:
		(n as Camera3D).current = false
		return
	if n.has_method("deactivate"):
		n.call("deactivate")
	elif _has_prop(n, "current"):
		n.set("current", false)
	elif _has_prop(n, "enabled"):
		n.set("enabled", false)
	elif _has_prop(n, "active"):
		n.set("active", false)
	if _has_prop(n, "priority"):
		n.set("priority", 0)

func _has_prop(o: Object, name: String) -> bool:
	for p in o.get_property_list():
		if p.name == name:
			return true
	return false
