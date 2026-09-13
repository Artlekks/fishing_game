extends CanvasLayer

@onready var cast_ready_overlay: TextureRect = $Root/Compass/CastReadyOverlay
@onready var cast_ready_animation: AnimationPlayer = $Root/Compass/AnimationPlayer
@onready var menu: TextureRect = $Root/HelpPanel/Menu
@onready var menu_cast: TextureRect = $Root/HelpPanel/Menu_Cast
@onready var compass: Control = $Root/Compass
@onready var location: Control = $Root/Location
@onready var help_panel: Control = $Root/HelpPanel

@export_category("References")
@export var exploration: Node

@onready var compass_needle: TextureRect = $Root/Compass/CompassNeedle

@export_category("Compass")
@export var needle_rotation_offset: float = 0.0
@export var camera_rig: Node3D
@export_category("Transitions")
@export var hide_duration: float = 0.35
@export var show_duration: float = 0.35
@export var offscreen_margin: float = 20.0
@export var game_mode: Node
@export var show_delay: float = 0.15

var compass_home: Vector2
var location_home: Vector2
var help_panel_home: Vector2

var hud_tween: Tween

func _ready() -> void:
	set_cast_available(false)

	if exploration == null:
		push_warning("ExplorationHud: Exploration is not assigned.")
		return

	exploration.cast_availability_changed.connect(
		_on_cast_availability_changed
	)

	if camera_rig == null:
		push_warning("ExplorationHud: CameraRig is not assigned.")
		return

	camera_rig.heading_changed.connect(_on_camera_heading_changed)
	_on_camera_heading_changed(camera_rig.rotation.y)
	
	compass_home = compass.position
	location_home = location.position
	help_panel_home = help_panel.position

	camera_rig.exploration_view_started.connect(_show_exploration_hud)

	if game_mode != null:
		game_mode.mode_changed.connect(_on_mode_changed)
		
func _on_cast_availability_changed(available: bool) -> void:
	set_cast_available(available)
	
func set_cast_available(available: bool) -> void:
	menu.visible = not available
	menu_cast.visible = available

	if available:
		cast_ready_overlay.visible = true

		if not cast_ready_animation.is_playing():
			cast_ready_animation.play("cast_ready")
	else:
		cast_ready_animation.stop()
		cast_ready_overlay.visible = false

func _on_camera_heading_changed(yaw: float) -> void:
	compass_needle.rotation_degrees = (
		-rad_to_deg(yaw)
		+ needle_rotation_offset
	)

func _on_mode_changed(new_mode: int) -> void:
	if new_mode == game_mode.Mode.FISHING:
		_hide_exploration_hud()
		
func _hide_exploration_hud() -> void:
	if hud_tween != null and hud_tween.is_valid():
		hud_tween.kill()

	var compass_target := Vector2(
		compass_home.x,
		-compass.size.y - offscreen_margin
	)

	var location_target := Vector2(
		location_home.x,
		-location.size.y - offscreen_margin
	)

	var viewport_width := get_viewport().get_visible_rect().size.x

	var help_target := Vector2(
		help_panel_home.x - viewport_width - offscreen_margin,
		help_panel_home.y
	)

	hud_tween = create_tween()
	hud_tween.set_trans(Tween.TRANS_CUBIC)
	hud_tween.set_ease(Tween.EASE_IN_OUT)

	hud_tween.parallel().tween_property(
		compass,
		"position",
		compass_target,
		hide_duration
	)

	hud_tween.parallel().tween_property(
		location,
		"position",
		location_target,
		hide_duration
	)

	hud_tween.parallel().tween_property(
		help_panel,
		"position",
		help_target,
		hide_duration
	)

func _show_exploration_hud() -> void:
	if show_delay > 0.0:
		await get_tree().create_timer(show_delay).timeout
		
	if hud_tween != null and hud_tween.is_valid():
		hud_tween.kill()

	hud_tween = create_tween()
	hud_tween.set_trans(Tween.TRANS_CUBIC)
	hud_tween.set_ease(Tween.EASE_IN_OUT)

	hud_tween.parallel().tween_property(
		compass,
		"position",
		compass_home,
		show_duration
	)

	hud_tween.parallel().tween_property(
		location,
		"position",
		location_home,
		show_duration
	)

	hud_tween.parallel().tween_property(
		help_panel,
		"position",
		help_panel_home,
		show_duration
	)
