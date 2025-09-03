# res://actors/FishingHUD.gd
extends CanvasLayer

@export var camera_controller_path: NodePath = NodePath("")  # FishingCameraController in your scene

@export var root_path: NodePath = NodePath("Root")
@export var compass_path: NodePath = NodePath("Root/Compass")
@export var location_path: NodePath = NodePath("Root/Location")
@export var menu_path: NodePath = NodePath("Root/Menu")

# On-screen local positions (relative to each control's anchors)
@export var compass_on: Vector2 = Vector2(12.0, 12.0)
@export var location_on: Vector2 = Vector2(0.0, 12.0)   # X is ignored if Location is top-wide and centered
@export var menu_on: Vector2 = Vector2(12.0, -12.0)     # Bottom-left; negative Y moves up from bottom

# Animation timing
@export var slide_out_time: float = 0.25
@export var slide_in_time: float = 0.30
@export var ease_out: bool = true

@export var compass_off_margin_px: float = 32.0
@export var location_off_margin_px: float = 32.0
@export var menu_off_margin_px: float = 32.0

# Internals
var _root: Control
var _compass: Control
var _location: Control
var _menu: Control
var _cam_ctrl: Node = null

var _tween: Tween = null
var _cached_vr: Rect2i = Rect2i()

func _ready() -> void:
	_root = get_node_or_null(root_path) as Control
	_compass = get_node_or_null(compass_path) as Control
	_location = get_node_or_null(location_path) as Control
	_menu = get_node_or_null(menu_path) as Control

	if _root == null or _compass == null or _location == null or _menu == null:
		push_error("FishingHUD: assign Root/Compass/Location/Menu properly.")
		set_process(false)
		return

	if camera_controller_path != NodePath(""):
		_cam_ctrl = get_node_or_null(camera_controller_path)
		if _cam_ctrl != null:
			_connect_cam_signals(_cam_ctrl)

	# Cache size to compute off-screen positions
	_cached_vr = get_viewport().get_visible_rect()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Put them on-screen immediately at game start (exploration)
	_place_on_screen_immediate()

	# React to window/resolution changes so off-screen math stays correct
	get_viewport().size_changed.connect(_on_viewport_resized)

func _connect_cam_signals(n: Node) -> void:
	if n.has_signal("align_started"):
		if not n.is_connected("align_started", Callable(self, "_on_align_started")):
			n.connect("align_started", Callable(self, "_on_align_started"))
	if n.has_signal("exited_to_exploration_view"):
		if not n.is_connected("exited_to_exploration_view", Callable(self, "_on_exited_to_exploration")):
			n.connect("exited_to_exploration_view", Callable(self, "_on_exited_to_exploration"))

func _on_viewport_resized() -> void:
	_cached_vr = get_viewport().get_visible_rect()
	# When resolution changes, snap to the correct on/off screen positions
	# If you want them to stay hidden during fishing, you can keep a small state flag.
	# For now, assume exploration (visible):
	_place_on_screen_immediate()

# --- Public API if you ever want to trigger manually ---
func show_exploration_hud() -> void:
	_slide_in()

func hide_for_fishing_hud() -> void:
	_slide_out()

# --- Camera controller callbacks ---
func _on_align_started(to_fishing: bool) -> void:
	if to_fishing:
		_slide_out()
	else:
		_slide_in()

func _on_exited_to_exploration() -> void:
	# Safety: ensure we’re back on-screen even if align callbacks were skipped.
	_slide_in()

# --- Animation helpers ---
func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

func _slide_out() -> void:
	_kill_tween()
	_tween = create_tween()
	if ease_out:
		_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var c_off := _off_up(_compass,  compass_on,  compass_off_margin_px)
	var l_off := _off_up(_location, location_on, location_off_margin_px)
	var m_off := _off_left(_menu,   menu_on,    menu_off_margin_px)

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

	_tween.tween_property(_compass, "position", compass_on, slide_in_time)
	_tween.set_parallel(true)
	_tween.tween_property(_location, "position", location_on, slide_in_time)
	_tween.set_parallel(true)
	_tween.tween_property(_menu, "position", menu_on, slide_in_time)

func _place_on_screen_immediate() -> void:
	_compass.position = compass_on
	_location.position = location_on
	_menu.position = menu_on

# --- Off-screen math (always leave screen fully) ---
func _off_up(ctrl: Control, on_pos: Vector2, margin: float) -> Vector2:
	var y: float = -ctrl.size.y - margin
	return Vector2(on_pos.x, y)

func _off_left(ctrl: Control, on_pos: Vector2, margin: float) -> Vector2:
	var x: float = -ctrl.size.x - margin
	return Vector2(x, on_pos.y)
