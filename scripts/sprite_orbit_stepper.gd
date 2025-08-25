# sprite_orbit_stepper.gd — v10 (explicit anim map; force flip_h=false while stepping)
extends Node

@export var sprite: AnimatedSprite3D
@export var camera_controller: Node
@export var step_deg: float = 30.0
@export var debug_log: bool = false
@export var restore_entry_idle_on_exit: bool = true
@export var forward_source: Node3D = null     # Player or Axis gizmo (+Z forward)
@export var use_forward_for_start: bool = false

# CCW order around the ring (must match your art’s logical order)
@export var dir_order_ccw: PackedStringArray = ["N","NW","W","SW","S","SE","E","NE"]

# If true, sprite turns opposite the camera yaw sign. If false, same direction.
@export var sprite_opposes_camera: bool = true
# replace the dictionary with a typed array (edit in Inspector if you like)
@export var anim_map: PackedStringArray = [
"Idle_N","Idle_NW","Idle_W","Idle_SW","Idle_S","Idle_SE","Idle_E","Idle_NE"
]


const EPS: float = 0.000001
const DIR_COUNT: int = 8

var _active: bool = false
var _tick_rad: float = PI / 6.0
var _start_idx: int = 0
var _target_idx: int = 0
var _entry_idx: int = 0

var _applied_steps: int = 0
var _planned_sectors: int = 0
var _dir_step: int = 0                  # +1 CCW, -1 CW

# restore exactly on exit
var _entry_anim_name: String = ""
var _entry_flip_h: bool = false

func _ready() -> void:
	if camera_controller == null:
		return
	if camera_controller.has_signal("align_started"):
		camera_controller.connect("align_started", Callable(self, "_on_align_started"))
	if camera_controller.has_signal("entered_fishing_view"):
		camera_controller.connect("entered_fishing_view", Callable(self, "_on_enter_finished"))
	if camera_controller.has_signal("exited_to_exploration_view"):
		camera_controller.connect("exited_to_exploration_view", Callable(self, "_on_exit_finished"))

func _process(_delta: float) -> void:
	if not _active or sprite == null or camera_controller == null:
		return
	if not camera_controller.has_method("is_aligning") or not bool(camera_controller.call("is_aligning")):
		return

	# latch sprite direction once from camera yaw sign
	if _dir_step == 0:
		var sign_cam: int = _sign(float(camera_controller.call("get_align_delta_rad")))
		if sign_cam != 0:
			var s: int = sign_cam
			if sprite_opposes_camera:
				s = -sign_cam
			_dir_step = s
			_planned_sectors = _distance_along_dir(_start_idx, _target_idx, _dir_step, DIR_COUNT)
			if _planned_sectors < 0:
				_planned_sectors = 0
			if debug_log:
				print("[SpriteStepper] dir_step=", _dir_step, " planned_sectors=", _planned_sectors)

	if _dir_step == 0:
		return

	if step_deg > 0.0:
		_tick_rad = deg_to_rad(step_deg)
	else:
		_tick_rad = PI / 6.0

	var d_abs: float = abs(float(camera_controller.call("get_align_delta_rad")))
	var desired_steps: int = int(floor((d_abs + EPS) / _tick_rad))
	if desired_steps > _planned_sectors:
		desired_steps = _planned_sectors
	if desired_steps < 0:
		desired_steps = 0

	while _applied_steps < desired_steps:
		_apply_one_step()
		_applied_steps += 1

# ---------- signals ----------
func _on_align_started(to_fishing: bool) -> void:
	_active = true
	_applied_steps = 0
	_dir_step = 0

	_start_idx = _current_dir_index_normalized()
	if to_fishing:
		_entry_idx = _start_idx
		_entry_anim_name = sprite.animation
		_entry_flip_h = sprite.flip_h
		_target_idx = _index_of_token("N")
		if _target_idx < 0:
			_target_idx = 0
	else:
		_target_idx = _entry_idx

	# while stepping, disable mirroring so NW can never look like NE
	if sprite != null:
		sprite.flip_h = false

	if step_deg > 0.0:
		_tick_rad = deg_to_rad(step_deg)
	else:
		_tick_rad = PI / 6.0

	if debug_log:
		print("[SpriteStepper] start=", dir_order_ccw[_start_idx],
			" target=", dir_order_ccw[_target_idx],
			" to_fishing=", to_fishing, " tick_deg=", step_deg)

func _on_enter_finished() -> void:
	_active = false

func _on_exit_finished() -> void:
	_active = false
	if restore_entry_idle_on_exit and sprite != null and _entry_anim_name != "":
		var frames: SpriteFrames = sprite.sprite_frames
		if frames != null and frames.has_animation(_entry_anim_name):
			sprite.flip_h = _entry_flip_h
			sprite.play(_entry_anim_name)

# ---------- helpers ----------
func _apply_one_step() -> void:
	var next_idx: int = _wrap(_start_idx + (_applied_steps + 1) * _dir_step, DIR_COUNT)
	var token: String = dir_order_ccw[next_idx]
	var name: String = _anim_for(token)

	var frames: SpriteFrames = sprite.sprite_frames
	if frames != null and frames.has_animation(name):
		sprite.flip_h = false   # guarantee no mirroring during stepping
		sprite.play(name)
		if debug_log:
			print("[SpriteStepper] -> ", name, " (flip_h=false)")

func _current_dir_index_normalized() -> int:
	# Prefer world +Z (more reliable than reading the current clip name)
	if use_forward_for_start and forward_source != null:
		var f: Vector3 = forward_source.global_transform.basis.z
		f.y = 0.0
		if f.length() > 0.0:
			f = f.normalized()
			var yaw: float = atan2(f.x, f.z)
			if yaw < 0.0:
				yaw += TAU
			var sector: float = TAU / float(DIR_COUNT)    # 45°
			var idx: int = int(floor((yaw + sector * 0.5) / sector)) % DIR_COUNT
			return idx
	# Fallback: parse current animation name
	return _current_dir_index_from_anim()


func _anim_for(token: String) -> String:
	var idx: int = _index_of_token(token)
	if idx >= 0 and idx < anim_map.size():
		return anim_map[idx]
	return "Idle_" + token



func _index_of_token(token: String) -> int:
	var i: int = 0
	while i < DIR_COUNT:
		if dir_order_ccw[i] == token:
			return i
		i += 1
	return -1

func _distance_along_dir(from_idx: int, to_idx: int, dir_step: int, n: int) -> int:
	if n <= 0:
		return 0
	var dist: int = 0
	if dir_step > 0:
		dist = (to_idx - from_idx) % n
		if dist < 0:
			dist += n
	else:
		dist = (from_idx - to_idx) % n
		if dist < 0:
			dist += n
	return dist

func _wrap(i: int, n: int) -> int:
	return wrapi(i, 0, n)

func _sign(x: float) -> int:
	if x > 0.0:
		return 1
	elif x < 0.0:
		return -1
	return 0

func _current_dir_index_from_anim() -> int:
	if sprite == null:
		return 0

	var anim: String = sprite.animation
	var pos: int = anim.rfind("_")
	if pos == -1:
		return 0
	var token: String = anim.substr(pos + 1, anim.length() - (pos + 1))

	# Your rule: for Idle_* only, treat east as west on START detection
	var under: int = anim.find("_")
	var prefix: String = ""
	if under != -1:
		prefix = anim.substr(0, under)
	if prefix == "Idle":
		if token == "E":
			token = "W"
		elif token == "NE":
			token = "NW"
		elif token == "SE":
			token = "SW"

	var i: int = 0
	while i < DIR_COUNT:
		if dir_order_ccw[i] == token:
			return i
		i += 1
	return 0
