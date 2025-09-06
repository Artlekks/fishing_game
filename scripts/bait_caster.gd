extends Node3D

signal bait_returned   # fired after a successful reel-in & despawn

@export var bait_scene: PackedScene
@export var player_path: NodePath = ^".."
@export var spawn_marker_path: NodePath = ^"../BaitSpawn"
@export var water_y_node_path: NodePath = NodePath("")
@export var direction_selector_path: NodePath = NodePath("")  # Player/DirectionSelector
@export var power_max_value: float = 100.0

@export var min_speed: float = 8.0
@export var max_speed: float = 22.0
@export var launch_angle_deg: float = 45.0
@export var fallback_water_y: float = 0.0
@export var reel_speed: float = 12.0
@export var reel_kill_radius: float = 0.7

var _player: Node3D
var _spawn: Node3D
var _water_node: Node3D
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
		push_error("BaitCaster: assign 'bait_scene' and ensure 'BaitSpawn' exists.")
		set_process(false)

func _water_y() -> float:
	if _water_node != null:
		return _water_node.global_position.y
	return fallback_water_y

# --- API called by FSM when PowerMeter is committed (K while bar visible) ---
func perform_cast(power: float, dir_world: Vector3 = Vector3(0,0,1)) -> void:
	# 1) Direction to throw (already world-space from FSM/DS)
	var dir := dir_world
	dir.y = 0.0
	if dir == Vector3.ZERO:
		dir = Vector3(0,0,1)
	else:
		var mag := dir.length()
		if mag > 0.0:
			dir /= mag

	# 2) Power → initial speed
	var t: float = clampf(power / max(1.0, power_max_value), 0.0, 1.0)
	var speed: float = lerpf(min_speed, max_speed, t)

	# 3) Launch angle pitch (degrees up)
	var ang: float = deg_to_rad(launch_angle_deg)

	# 4) Build velocity from horizontal dir + pitch
	var v := Vector3(
		dir.x * speed * cos(ang),
		speed * sin(ang),
		dir.z * speed * cos(ang)
	)

	# 5) Spawn & start (keep your existing code below)
	_cleanup_bait()
	if bait_scene == null or _spawn == null:
		return
	var inst := bait_scene.instantiate() as Node3D
	add_child(inst)
	_bait = inst
	var start_pos := _spawn.global_position
	if _bait.has_method("start"):
		_bait.call("start", start_pos, v, _water_y())
	if _bait.has_signal("landed"):
		_bait.connect("landed", Callable(self, "_on_bait_landed"))

# After you instantiate the bait in perform_cast(...)
# (right after: var inst := bait_scene.instantiate() as Node3D)
	_bait = inst
	if _bait.has_method("set_kill_radius"):
		_bait.call("set_kill_radius", reel_kill_radius)

func _on_bait_landed(_point: Vector3) -> void:
	# Reel will be added later.
	pass

func _cleanup_bait() -> void:
	if is_instance_valid(_bait):
		_bait.queue_free()
	_bait = null

# Pulls toward the spawn marker; change to _player if you prefer
func start_reel() -> void:
	if not is_instance_valid(_bait):
		return
	# push current Inspector value every time we begin reeling
	if _bait.has_method("set_kill_radius"):
		_bait.call("set_kill_radius", reel_kill_radius)

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

func despawn() -> void:
	_cleanup_bait()
