extends Node3D

@export var dots: Array[Node3D] = []          # assign dot_0 .. dot_7 in order
@export var frame_hold_time: float = 0.10     # seconds between steps
@export var pause_frames: int = 6             # hold after all dots lit
@export var blank_frames: int = 0             # optional gap before restart

var _timer: float = 0.0
var _index: int = -1                          # -1 = none lit yet
var _active: bool = false
var _phase: String = "grow"                   # "grow" -> "pause" -> "blank"

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
			if d != null:
				d.visible = true                   # new dot turns on; previous stay on
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

# --------------------------------------------------------------------
# Public API used by your bridge

func show_for_fishing(player: Node3D) -> void:
	_lock_to_player_neg_z(player)   # ALWAYS align to player's local -Z
	start_looping()

func hide_for_fishing() -> void:
	stop_looping()

# --------------------------------------------------------------------
# Internals

func start_looping() -> void:
	_active = true
	_restart_cycle()

func stop_looping() -> void:
	_active = false
	_set_all(false)

# Align this node so its LOCAL +Z points along the PLAYER'S local -Z in WORLD space.
func _lock_to_player_neg_z(player: Node3D) -> void:
	var dir := -player.global_transform.basis.z
	dir.y = 0.0
	if dir.length() < 0.0001:
		return
	dir = dir.normalized()

	var up := Vector3.UP
	var right := up.cross(dir).normalized()

	# Local axes become: X = right, Y = up, Z = dir (dots are along local +Z)
	var t := global_transform
	t.basis = Basis(right, up, dir)
	global_transform = t

func _restart_cycle() -> void:
	_set_all(false)
	_index = -1
	_phase = "grow"
	_timer = 0.0

func _set_all(state: bool) -> void:
	for d in dots:
		if d != null:
			d.visible = state
