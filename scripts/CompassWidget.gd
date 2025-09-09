# res://actors/ui/CompassWidget.gd
extends Control

@export var player_path: NodePath
@export var water_facing_path: NodePath
@export var needle_path: NodePath = NodePath("CompassNeedle")
@export var fish_icon_path: NodePath = NodePath("FishIcon")
@export var blink_timer_path: NodePath = NodePath("BlinkTimer")

@export var needle_up_is_deg: float = 0.0        # how many degrees your "up" on the face equals
@export var cone_half_angle_deg: float = 60.0    # gate angle for fishing-ready

@export var blink_period_sec: float = 0.5
@export var fish_icon_grey: Texture2D
@export var fish_icon_purple: Texture2D
@export var use_blink_when_ready: bool = true    # false = solid purple when ready

var _player: Node3D = null
var _water: Node3D = null
var _needle: TextureRect = null
var _fish_icon: TextureRect = null
var _blink_timer: Timer = null
var _blink_on: bool = false

func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_water  = get_node_or_null(water_facing_path) as Node3D
	_needle = get_node_or_null(needle_path) as TextureRect
	_fish_icon = get_node_or_null(fish_icon_path) as TextureRect
	_blink_timer = get_node_or_null(blink_timer_path) as Timer

	if _fish_icon != null and fish_icon_grey != null:
		_fish_icon.texture = fish_icon_grey

	if _blink_timer != null:
		_blink_timer.stop()
		_blink_timer.wait_time = max(0.05, blink_period_sec)
		if not _blink_timer.timeout.is_connected(_on_blink_timeout):
			_blink_timer.timeout.connect(_on_blink_timeout)

	# One immediate update so the needle is correct on frame 1
	_update_compass()
	_update_ready_icon()

func _process(_delta: float) -> void:
	_update_compass()
	_update_ready_icon()

# -------------------- compass needle --------------------

func _update_compass() -> void:
	if _needle == null or _player == null:
		return
	var f: Vector3 = _player.global_transform.basis.z
	f.y = 0.0
	if f.length() < 0.0001:
		return
	f = f.normalized()
	var degs: float = rad_to_deg(atan2(f.x, f.z))
	degs -= needle_up_is_deg
	_needle.rotation_degrees = degs

# -------------------- fishing-ready gate + blink --------------------

func _update_ready_icon() -> void:
	if _fish_icon == null or _player == null or _water == null:
		_stop_blink_set_grey()
		return

	var pf: Vector3 = _player.global_transform.basis.z
	var wf: Vector3 = _water.global_transform.basis.z
	pf.y = 0.0
	wf.y = 0.0
	if pf.length() == 0.0 or wf.length() == 0.0:
		_stop_blink_set_grey()
		return

	pf = pf.normalized()
	wf = wf.normalized()
	var dotv: float = clamp(pf.dot(wf), -1.0, 1.0)
	var ang: float = rad_to_deg(acos(dotv))
	var is_ready: bool = ang <= cone_half_angle_deg
	if is_ready:
		if use_blink_when_ready and _blink_timer != null:
			if _blink_timer.is_stopped():
				_blink_on = false
				_blink_timer.wait_time = max(0.05, blink_period_sec)
				_blink_timer.start()
				_on_blink_timeout()  # apply first frame
		else:
			_stop_blink()
			if fish_icon_purple != null:
				_fish_icon.texture = fish_icon_purple
	else:
		_stop_blink_set_grey()

func _stop_blink_set_grey() -> void:
	_stop_blink()
	if _fish_icon != null and fish_icon_grey != null:
		_fish_icon.texture = fish_icon_grey

func _stop_blink() -> void:
	if _blink_timer != null:
		_blink_timer.stop()
	_blink_on = false

func _on_blink_timeout() -> void:
	_blink_on = not _blink_on
	if _fish_icon == null:
		return
	if _blink_on:
		if fish_icon_purple != null:
			_fish_icon.texture = fish_icon_purple
	else:
		if fish_icon_grey != null:
			_fish_icon.texture = fish_icon_grey
