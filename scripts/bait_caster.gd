extends Node3D

signal bait_returned
signal cast_started
signal bait_despawned
signal bait_landed(surface_y: float, bottom_y: float, bait_y: float)

@export var bait_scene: PackedScene
@export var player_path: NodePath = ^".."
@export var spawn_marker_path: NodePath = ^"../BaitSpawner"
@export var water_y_node_path: NodePath = NodePath("")
@export var direction_selector_path: NodePath = NodePath("")
@export var power_max_value: float = 100.0

@export var min_speed: float = 8.0
@export var max_speed: float = 22.0
@export var launch_angle_deg: float = 45.0
@export var fallback_water_y: float = 0.0
@export var reel_speed: float = 12.0
@export var reel_kill_radius: float = 0.7
@export var cast_yaw_trim_deg: float = 0.0   # +CCW around +Y; small values like -10..+10

var _player: Node3D = null
var _spawn: Node3D = null
var _water_node: Node3D = null
var _ds: Node = null
var _bait: Node3D = null

func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_spawn = get_node_or_null(spawn_marker_path) as Node3D
	if water_y_node_path != NodePath(""):
		_water_node = get_node_or_null(water_y_node_path) as Node3D
	if direction_selector_path != NodePath(""):
		_ds = get_node_or_null(direction_selector_path)
	if bait_scene == null or _spawn == null:
		push_error("BaitCaster: assign 'bait_scene' and ensure 'BaitSpawner' exists.")
		set_process(false)

func _water_y() -> float:
	if _water_node != null:
		return _water_node.global_position.y
	return fallback_water_y

func _yaw_rotate_y(dir: Vector3, degrees: float) -> Vector3:
	var ang := deg_to_rad(degrees)
	var R := Basis(Vector3.UP, ang)
	var h := Vector3(dir.x, 0.0, dir.z)
	var out := R * h
	if out.length() > 0.0:
		out = out.normalized()
	return out

func perform_cast(power: float, dir_world: Vector3) -> void:
	cast_started.emit()
	var dir := dir_world
	dir.y = 0.0
	if dir.length() > 0.0:
		dir = dir.normalized()
	else:
		dir = Vector3(0, 0, 1)
	
	if cast_yaw_trim_deg != 0.0:
		dir = _yaw_rotate_y(dir, cast_yaw_trim_deg)

	var t := clampf(power / max(1.0, power_max_value), 0.0, 1.0)
	var speed := lerpf(min_speed, max_speed, t)

	var ang := deg_to_rad(launch_angle_deg)
	var v := Vector3(
		dir.x * speed * cos(ang),
		speed * sin(ang),
		dir.z * speed * cos(ang)
	)

	_cleanup_bait()
	if bait_scene == null or _spawn == null:
		return

	var inst := bait_scene.instantiate() as Node3D
	add_child(inst)
	_bait = inst

	if _bait.has_method("set_kill_radius"):
		_bait.call("set_kill_radius", reel_kill_radius)

	var start_pos := _spawn.global_position
	if _bait.has_method("start"):
		_bait.call("start", start_pos, v, _water_y())
	if _bait.has_signal("landed"):
		_bait.connect("landed", Callable(self, "_on_bait_landed"))

func _on_bait_landed(point: Vector3) -> void:
	var sy: float = _water_y()
	var by: float = sy - 3.0        # use your real bottom if you have it
	var yy: float = point.y
	bait_landed.emit(sy, by, yy)

func _cleanup_bait() -> void:
	if is_instance_valid(_bait):
		_bait.queue_free()
	_bait = null

func start_reel() -> void:
	if not is_instance_valid(_bait):
		return

	if _bait.has_method("set_kill_radius"):
		_bait.call("set_kill_radius", reel_kill_radius)
	if _bait.has_method("set_reel_speed_per_sec"):
		_bait.call("set_reel_speed_per_sec", reel_speed)

	var target: Node3D = _player
	if _bait.has_method("start_reel"):
		_bait.call("start_reel", target)

	if _bait.has_signal("reeled_in") and not _bait.is_connected("reeled_in", Callable(self, "_on_bait_reeled_in")):
		_bait.connect("reeled_in", Callable(self, "_on_bait_reeled_in"))

func set_reel_active(active: bool) -> void:
	if is_instance_valid(_bait) and _bait.has_method("set_reel_active"):
		_bait.call("set_reel_active", active)

func _on_bait_reeled_in() -> void:
	despawn()
	bait_returned.emit()

func set_curve_input(curve_sign: int) -> void:
	if is_instance_valid(_bait) and _bait.has_method("set_curve_input"):
		_bait.call("set_curve_input", curve_sign)

func despawn() -> void:
	_cleanup_bait()
	bait_despawned.emit()
