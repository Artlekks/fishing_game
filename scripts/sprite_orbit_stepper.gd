# sprite_orbit_stepper.gd — v8 (reads facing from +Z, mirrors east, 1 step per 30°)
extends Node

@export var sprite: AnimatedSprite3D
@export var camera_controller: Node
@export var forward_source: Node3D         # node whose +Z is the character facing (Player / AxisGizmo)

@export var step_deg: float = 30.0
@export var debug_log: bool = false
@export var restore_entry_idle_on_exit: bool = true

# CCW around the circle starting at North (must match your art order)
@export var dir_order_ccw: PackedStringArray = ["N","NW","W","SW","S","SE","E","NE"]

# With this camera controller, +yaw is CCW. We want sprites to turn opposite the camera.
const SPRITE_OPPOSES_CAMERA: bool = true

const EPS: float = 0.000001
const DIR_COUNT: int = 8

# runtime
var _active: bool = false
var _tick_rad: float = PI / 6.0             # 30°
var _start_idx: int = 0
var _target_idx: int = 0
var _entry_idx: int = 0
var _applied_steps: int = 0
var _planned_sectors: int = 0               # how many 45° sectors to traverse
var _dir_step: int = 0                      # +1 = CCW along order, -1 = CW

# for exact restoration
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

	# latch sprite turn direction once, from camera yaw sign
	if _dir_step == 0:
		var sign_cam: int = _sign(float(camera_controller.call("get_align_delta_rad")))
		if sign_cam != 0:
			var s: int = sign_cam
			if SPRITE_OPPOSES_CAMERA:
				s = -sign_cam
			_dir_step = s
			_planned_sectors = _distance_along_dir(_start_idx, _target_idx, _dir_step, DIR_COUNT)
			if _planned_sectors < 0:
				_planned_sectors = 0
			if debug_log:
				print("[SpriteStepper] dir_step=", _dir_step, " planned_sectors=", _planned_sectors)

	if _dir_step == 0:
		return

	# one visual step per step_deg of camera yaw
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

# ---------------- signals ----------------
func _on_align_started(to_fishing: bool) -> void:
	_active = true
	_applied_steps = 0
	_dir_step = 0

	_start_idx = _dir_index_from_forward()
	if to_fishing:
		_entry_idx = _start_idx
		_entry_anim_name = sprite.animation
		_entry_flip_h = sprite.flip_h
		_target_idx = _index_of_token("N")
		if _target_idx < 0:
			_target_idx = 0
	else:
		_target_idx = _entry_idx

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

# ---------------- helpers ----------------
func _apply_one_step() -> void:
	var next_idx: int = _wrap(_start_idx + (_applied_steps + 1) * _dir_step, DIR_COUNT)
	_play_token(dir_order_ccw[next_idx])

# Read facing from +Z of forward_source to avoid sprite-name ambiguity
func _dir_index_from_forward() -> int:
	if forward_source == null:
		# fallback: try current sprite/flip
		return _dir_index_from_sprite()
	var f: Vector3 = forward_source.global_transform.basis.z
	f.y = 0.0
	if f.length() == 0.0:
		return _dir_index_from_sprite()
	f = f.normalized()
	# yaw from +Z: atan2(x, z), CCW positive
	var yaw: float = atan2(f.x, f.z)
	# map yaw into [0..TAU) and to nearest of 8 sectors (every 45°)
	if yaw < 0.0:
		yaw += TAU
	var sector_size: float = TAU / float(DIR_COUNT)      # 45°
	var idx: int = int(floor((yaw + sector_size * 0.5) / sector_size)) % DIR_COUNT
	return idx

func _dir_index_from_sprite() -> int:
	var anim: String = sprite.animation
	var pos: int = anim.rfind("_")
	if pos == -1:
		return 0
	var token: String = anim.substr(pos + 1, anim.length() - (pos + 1))
	# if we mirrored a west clip, report the east token
	if sprite.flip_h:
		if token == "NW":
			token = "NE"
		elif token == "W":
			token = "E"
		elif token == "SW":
			token = "SE"
	return _index_of_token(token)

func _index_of_token(token: String) -> int:
	var i: int = 0
	while i < DIR_COUNT:
		if dir_order_ccw[i] == token:
			return i
		i += 1
	return 0

# Map tokens to base west-side clips + flip for east-side
func _play_token(token: String) -> void:
	var name: String = "Idle_N"
	var flip: bool = false

	if token == "N":
		name = "Idle_N";  flip = false
	elif token == "NW":
		name = "Idle_NW"; flip = false
	elif token == "W":
		name = "Idle_W";  flip = false
	elif token == "SW":
		name = "Idle_SW"; flip = false
	elif token == "S":
		name = "Idle_S";  flip = false
	elif token == "NE":
		name = "Idle_NW"; flip = true
	elif token == "E":
		name = "Idle_W";  flip = true
	elif token == "SE":
		name = "Idle_SW"; flip = true

	var frames: SpriteFrames = sprite.sprite_frames
	if frames != null and frames.has_animation(name):
		sprite.flip_h = flip
		sprite.play(name)
		if debug_log:
			print("[SpriteStepper] -> ", token, " (", name, ", flip_h=", flip, ")")

# distance along ring from 'from_idx' to 'to_idx' stepping dir_step (+1 CCW, -1 CW)
func _distance_along_dir(from_idx: int, to_idx: int, dir_step: int, n: int) -> int:
	var dist: int = 0
	if n <= 0:
		return 0
	if dir_step > 0:
		dist = (to_idx - from_idx) % n            # CCW
		if dist < 0:
			dist += n
	else:
		dist = (from_idx - to_idx) % n            # CW
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
