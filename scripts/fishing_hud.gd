# res://actors/FishingHUD.gd
extends CanvasLayer

# --- Scene paths (override in Inspector if different) ---
@export var camera_controller_path: NodePath = NodePath("")   # FishingCameraController
@export var root_path:       NodePath = NodePath("HUDRoot")
@export var compass_path:    NodePath = NodePath("HUDRoot/Compass")
@export var location_path:   NodePath = NodePath("HUDRoot/Location")
@export var menu_path:       NodePath = NodePath("HUDRoot/Menu")
@export var menu_cast_path:  NodePath = NodePath("HUDRoot/Menu_Cast")

# Optional direct refs (used if set)
@export var fishing_camera_controller: Node = null            # drag your FishingCameraController here
@export var exploration_player: Node = null                   # drag ExplorationPlayer here (fallback)

# On-screen local positions (relative to each control's anchors)
@export var compass_on:  Vector2 = Vector2(12.0, 12.0)
@export var location_on: Vector2 = Vector2(0.0, 12.0)         # X ignored if centered, keep for flexibility
@export var menu_on:     Vector2 = Vector2(12.0, -12.0)

# Animation timing
@export var slide_out_time: float = 0.25
@export var slide_in_time:  float = 0.30
@export var ease_out:       bool  = true

# Off-screen travel margins (pixels)
@export var compass_off_margin_px:  float = 32.0
@export var location_off_margin_px: float = 32.0
@export var menu_off_margin_px:     float = 32.0

# --- Internals ---
var _root:     Control
var _compass:  Control
var _location: Control
var _menu:     Control
var _menu_cast: Control
var _cam_ctrl: Node = null

var _tween: Tween = null
var _cached_vr: Rect2i = Rect2i()
var _cast_prev: bool = false

func _ready() -> void:
	_root     = get_node_or_null(root_path)    as Control
	_compass  = get_node_or_null(compass_path) as Control
	_location = get_node_or_null(location_path) as Control
	_menu     = get_node_or_null(menu_path)    as Control
	_menu_cast = get_node_or_null(menu_cast_path) as Control

	if _root == null or _compass == null or _location == null or _menu == null:
		push_error("FishingHUD: assign HUDRoot/Compass/Location/Menu properly.")
		set_process(false)
		return

	if _menu_cast != null:
		_menu_cast.visible = false

	# Camera controller (prefer explicit export, else path)
	if fishing_camera_controller != null:
		_cam_ctrl = fishing_camera_controller
	elif camera_controller_path != NodePath(""):
		_cam_ctrl = get_node_or_null(camera_controller_path)

	_connect_cam_signals(_cam_ctrl)

	# Layout cache and anchors
	_cached_vr = get_viewport().get_visible_rect()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Start on-screen (exploration)
	_place_on_screen_immediate()

	# React to resolution changes
	get_viewport().size_changed.connect(_on_viewport_resized)

func _process(_dt: float) -> void:
	# Toggle the “Menu_Cast” icon based on the same rule as K-gate
	if _menu_cast != null:
		var allowed: bool = _is_cast_allowed_now()
		if allowed != _cast_prev:
			_menu_cast.visible = allowed
			_cast_prev = allowed

# --- Public API ---
func show_exploration_hud() -> void:
	_slide_in()

func hide_for_fishing_hud() -> void:
	_slide_out()

# --- Camera controller callbacks ---
func _connect_cam_signals(n: Node) -> void:
	if n == null:
		return
	if n.has_signal("align_started"):
		if not n.is_connected("align_started", Callable(self, "_on_align_started")):
			n.connect("align_started", Callable(self, "_on_align_started"))
	if n.has_signal("exited_to_exploration_view"):
		if not n.is_connected("exited_to_exploration_view", Callable(self, "_on_exited_to_exploration")):
			n.connect("exited_to_exploration_view", Callable(self, "_on_exited_to_exploration"))

func _on_align_started(to_fishing: bool) -> void:
	if to_fishing:
		_slide_out()
	else:
		_slide_in()

func _on_exited_to_exploration() -> void:
	_slide_in()  # safety

# --- Window resize ---
func _on_viewport_resized() -> void:
	_cached_vr = get_viewport().get_visible_rect()
	_place_on_screen_immediate()

# --- Animation helpers ---
func _kill_tween() -> void:
	if is_instance_valid(_tween):
		_tween.kill()
	_tween = null


func _slide_out() -> void:
	_kill_tween()
	_tween = create_tween()
	if ease_out:
		_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var c_off: Vector2 = _off_up(_compass,  compass_on,  compass_off_margin_px)
	var l_off: Vector2 = _off_up(_location, location_on, location_off_margin_px)
	var m_off: Vector2 = _off_left(_menu,   menu_on,     menu_off_margin_px)

	_tween.tween_property(_compass,  "position", c_off, slide_out_time)
	_tween.set_parallel(true)
	_tween.tween_property(_location, "position", l_off, slide_out_time)
	_tween.set_parallel(true)
	_tween.tween_property(_menu,     "position", m_off, slide_out_time)

func _slide_in() -> void:
	_kill_tween()
	_tween = create_tween()
	if ease_out:
		_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_tween.tween_property(_compass,  "position", compass_on,  slide_in_time)
	_tween.set_parallel(true)
	_tween.tween_property(_location, "position", location_on, slide_in_time)
	_tween.set_parallel(true)
	_tween.tween_property(_menu,     "position", menu_on,     slide_in_time)

func _place_on_screen_immediate() -> void:
	_compass.position  = compass_on
	_location.position = location_on
	_menu.position     = menu_on

# --- Off-screen helpers ---
func _off_up(_ctrl: Control, on_pos: Vector2, travel_px: float) -> Vector2:
	return Vector2(on_pos.x, on_pos.y - travel_px)

func _off_left(_ctrl: Control, on_pos: Vector2, travel_px: float) -> Vector2:
	return Vector2(on_pos.x - travel_px, on_pos.y)

# --- Cast gating (same as “press K allowed?”) ---
func _is_cast_allowed_now() -> bool:
	# 1) Preferred: controller helper
	if _cam_ctrl != null and _cam_ctrl.has_method("is_cast_allowed"):
		var v1 = _cam_ctrl.is_cast_allowed()
		return v1 == true

	# 2) Legacy: some projects still expose _can_enter_fishing on controller
	if _cam_ctrl != null and _cam_ctrl.has_method("_can_enter_fishing"):
		var v2 = _cam_ctrl._can_enter_fishing()
		return v2 == true

	# 3) Fallback: ask the player directly
	if exploration_player != null and exploration_player.has_method("_can_enter_fishing"):
		var in_fish: bool = false
		if exploration_player.has_variable("in_fishing_mode"):
			# property read is safe; if not bool, the comparison below will handle it
			in_fish = exploration_player.get("in_fishing_mode") == true
		if in_fish:
			return false
		var v3 = exploration_player._can_enter_fishing()
		return v3 == true

	return false
