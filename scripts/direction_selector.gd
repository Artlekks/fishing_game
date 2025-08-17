extends Node3D

@export var dots: Array[Node3D] = []        # assign dot_0 .. dot_7 directly
@export var frame_hold_time: float = 0.10    # seconds between steps
@export var pause_frames: int = 6            # hold after all dots lit
@export var blank_frames: int = 0            # optional gap before restart

var _timer: float = 0.0
var _index: int = -1                         # -1 = none lit yet
var _active: bool = false
var _phase: String = "grow"                  # "grow" -> "pause" -> "blank"

func _ready() -> void:
	_set_all(false)

func _process(delta: float) -> void:
	if not _active:
		return

	_timer += delta
	if _timer < frame_hold_time:
		return
	_timer = 0.0

	if _phase == "grow":
		_index += 1
		if _index < dots.size():
			var d := dots[_index]
			if d: d.visible = true            # new dot turns on; previous stay on
			if _index == dots.size() - 1:
				_phase = "pause"
				_index = pause_frames
		else:
			_phase = "pause"
			_index = pause_frames

	elif _phase == "pause":
		_index -= 1
		if _index <= 0:
			if blank_frames > 0:
				_phase = "blank"
				_index = blank_frames
			else:
				_restart_cycle()

	elif _phase == "blank":
		_index -= 1
		if _index <= 0:
			_restart_cycle()

func start_looping() -> void:
	_active = true
	_restart_cycle()

func stop_looping() -> void:
	_active = false
	_set_all(false)

func set_yaw_from_direction(dir: Vector3) -> void:
	# Align to desired XZ direction (e.g., player's forward)
	var d := dir
	d.y = 0.0
	if d.length() == 0.0:
		return
	d = d.normalized()
	rotation.y = atan2(d.x, d.z)  # yaw

func get_direction_vector() -> Vector3:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	return forward.normalized()

func lock_to_player_axis(player: Node3D) -> void:
	# Capture player forward at lock time
	var fwd: Vector3 = player.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() == 0.0:
		return
	fwd = fwd.normalized()
	rotation.y = atan2(fwd.x, fwd.z)  # yaw only

# direction_selector.gd  (add this function)
func lock_to_player_neg_x(player: Node3D) -> void:
	var dir := -player.global_transform.basis.x   # player's -X in world
	dir.y = 0.0
	if dir.length() < 0.0001:
		return
	dir = dir.normalized()

	var up := Vector3.UP
	var right := up.cross(dir).normalized()       # world right perpendicular to dir

	# Build a world-space basis whose columns are X,Y,Z = right, up, dir
	var t := global_transform
	t.basis = Basis(right, up, dir)
	global_transform = t                           # world yaw now correct

func lock_to_world_dir(dir: Vector3) -> void:
	# Yaw so that local +Z points along 'dir' in world space
	var d := dir
	d.y = 0.0
	if d.length() == 0.0:
		return
	d = d.normalized()
	rotation.y = atan2(d.x, d.z)  # yaw
	
func _restart_cycle() -> void:
	_set_all(false)
	_index = -1
	_phase = "grow"
	_timer = 0.0

func _set_all(state: bool) -> void:
	for d in dots:
		if d:
			d.visible = state
