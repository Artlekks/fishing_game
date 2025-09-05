extends Node3D
signal orbit_step(sign: int)  # +1 = CCW (Q), -1 = CW (E)

@export var player_path: NodePath = ^"../ExplorationPlayer"
@export var cam_path: NodePath = ^"Cameras/PCam_Exploration"
@export var fishing_controller_path: NodePath = ^"FishingCameraController"

@export var step_degrees: float = 90.0
@export var rotate_time: float = 0.6  # your preferred camera tween time
@export_range(0.0, 1.0, 0.05) var sprite_switch_progress: float = 0.8

# Sprite switches after rotate_time * sprite_switch_progress seconds (e.g. 0.6 * 0.8 = 0.48s)

var _player: Node3D
var _cam: Node3D
var _enabled := true

var _radius := 0.0
var _height := 0.0
var _yaw_deg := 0.0
var _tween: Tween

var _act_left := "cam_orbit_left"
var _act_right := "cam_orbit_right"

var _sprite_timer: Timer
var _pending_sign := 0

func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_cam = get_node_or_null(cam_path) as Node3D
	if _player == null or _cam == null:
		push_error("exploration_orbit_driver: set 'player_path' and 'cam_path'.")
		set_process(false)
		return

	# Fallback to your existing action names if needed
	if not InputMap.has_action(_act_left):  _act_left  = "cam_left"
	if not InputMap.has_action(_act_right): _act_right = "cam_right"

	# Sample current distance/height and initial yaw
	var offset: Vector3 = _cam.global_position - _player.global_position
	_radius = Vector2(offset.x, offset.z).length()
	_height = offset.y
	_yaw_deg = rad_to_deg(atan2(offset.x, offset.z))

	# Gate input during fishing
	var fish := get_node_or_null(fishing_controller_path)
	if fish:
		if fish.has_signal("entered_fishing_view"):
			fish.connect("entered_fishing_view", Callable(self, "_on_entered_fishing_view"))
		if fish.has_signal("exited_to_exploration_view"):
			fish.connect("exited_to_exploration_view", Callable(self, "_on_exited_to_exploration_view"))

	# Timer to delay sprite switching
	_sprite_timer = Timer.new()
	_sprite_timer.one_shot = true
	add_child(_sprite_timer)
	_sprite_timer.timeout.connect(_on_sprite_timer_timeout)

	# Auto-connect orbit signal to the player sprite handler (safe if already connected)
	if _player and not is_connected("orbit_step", Callable(_player, "_on_exploration_orbit_step")):
		connect("orbit_step", Callable(_player, "_on_exploration_orbit_step"))

func _unhandled_input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event.is_action_pressed(_act_left):
		_schedule_sprite_switch(+1)
		_orbit_to(_yaw_deg + step_degrees)
	elif event.is_action_pressed(_act_right):
		_schedule_sprite_switch(-1)
		_orbit_to(_yaw_deg - step_degrees)

func _process(_dt: float) -> void:
	if _player == null or _cam == null:
		return
	# Keep camera locked to the same distance & height around player
	var yaw := deg_to_rad(_yaw_deg)
	var x := sin(yaw) * _radius
	var z := cos(yaw) * _radius
	_cam.global_position = _player.global_position + Vector3(x, _height, z)

func _orbit_to(target_deg: float) -> void:
	var from := _yaw_deg
	var to := target_deg               # keep yaw unbounded; no modulo
	if is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_yaw_immediate, from, to, rotate_time)

func _set_yaw_immediate(v: float) -> void:
	_yaw_deg = v

func _schedule_sprite_switch(dir_sign: int) -> void:
	_pending_sign = dir_sign
	if not _sprite_timer.is_stopped():
		_sprite_timer.stop()
	_sprite_timer.wait_time = max(0.0, rotate_time * clamp(sprite_switch_progress, 0.0, 1.0))
	_sprite_timer.start()

func _on_sprite_timer_timeout() -> void:
	if _enabled and _pending_sign != 0:
		orbit_step.emit(_pending_sign)
	_pending_sign = 0

func _on_entered_fishing_view() -> void:
	_enabled = false
	if _sprite_timer:
		_sprite_timer.stop()

func _on_exited_to_exploration_view() -> void:
	_enabled = true
