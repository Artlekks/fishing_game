extends Node
## FishingModeController — now also swaps cameras cleanly.

@export var fish_zone_group: StringName = &"fish_zone"
@export var debug_prints: bool = true
@export var fishing_camera_path: NodePath   # drag CameraRig_Fishing here (in the main scene instance)

@onready var player: Node3D       = get_parent() as Node3D
@onready var facing_root: Node3D  = player.get_node_or_null("FacingRoot") as Node3D
@onready var fsm: Node            = player.get_node_or_null("FishingStateMachine")

var _current_zone: Node = null
var _in_zone: bool = false
var _in_fishing: bool = false

var _fish_cam_rig: Node = null
var _exploration_cam: Camera3D = null   # camera that was current before switching

func _ready() -> void:
	set_process(true)
	set_process_unhandled_input(true)

	# Wire zones
	for z in get_tree().get_nodes_in_group(fish_zone_group):
		if not z.is_connected("player_entered_fish_zone", Callable(self, "_on_zone_entered")):
			z.player_entered_fish_zone.connect(_on_zone_entered)
		if not z.is_connected("player_exited_fish_zone", Callable(self, "_on_zone_exited")):
			z.player_exited_fish_zone.connect(_on_zone_exited)

	# Fishing camera rig (by path or by group)
	if fishing_camera_path != NodePath() and has_node(fishing_camera_path):
		_fish_cam_rig = get_node(fishing_camera_path)
	else:
		_fish_cam_rig = get_tree().get_first_node_in_group("camera_rig_fishing")

	_disable_fishing()  # silent

func _on_zone_entered(zone: Node) -> void:
	_in_zone = true
	_current_zone = zone
	if debug_prints: print("[FishingMode] ENTER ZONE:", zone.name)

func _on_zone_exited(zone: Node) -> void:
	if zone != _current_zone:
		return
	_in_zone = false
	_current_zone = null
	_end_silent()  # NO animation on zone exit
	if debug_prints: print("[FishingMode] EXIT ZONE")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fish") and _in_zone and not _in_fishing:
		_start_fishing()
	if event.is_action_pressed("cancel_fishing") and _in_fishing:
		_cancel_fishing()

func _process(_dt: float) -> void:
	if _in_zone and not _in_fishing and Input.is_action_just_pressed("fish"):
		_start_fishing()
	if _in_fishing and Input.is_action_just_pressed("cancel_fishing"):
		_cancel_fishing()

# ---------- Internals ----------

func _start_fishing() -> void:
	if _current_zone == null or fsm == null:
		return
	_in_fishing = true
	_enable_fishing()

	# Align facing
	var water_forward: Vector3 = _current_zone.call("get_water_forward") as Vector3
	if facing_root and facing_root.has_method("align_to_forward"):
		facing_root.call("align_to_forward", water_forward)

	# Freeze movement
	_set_player_movement(false)

	# Switch cameras: remember the current exploration camera, then enter fishing rig
	_exploration_cam = get_viewport().get_camera_3d()
	if _fish_cam_rig and _fish_cam_rig.has_method("enter_fishing"):
		var anchor := _current_zone.get_node_or_null("CameraAnchor") as Node3D
		_fish_cam_rig.call("enter_fishing", player, water_forward, anchor)

	# Kick FSM
	if fsm.has_method("start_sequence"):
		fsm.call("start_sequence")

	if debug_prints: print("[FishingMode] START (K)")
# Pause follow
	var rig := get_tree().get_first_node_in_group("camera_rig")  # or get_node("CameraRig")
	if rig and rig.has_method("set_follow_enabled"):
		rig.set_follow_enabled(false)

	# Blend same Camera3D into fishing view
	var cam := get_viewport().get_camera_3d()
	var anchor := _current_zone.get_node_or_null("CameraAnchor") as Node3D  # optional
	if cam and cam.has_method("enter_fishing_view"):
		cam.enter_fishing_view(player, water_forward, anchor)

func _cancel_fishing() -> void:
	_in_fishing = false

	if facing_root and facing_root.has_method("stop_align"):
		facing_root.call("stop_align")
	_set_player_movement(true)

	# Cancel FSM (plays Cancel_Fishing) and disable
	if fsm and fsm.has_method("force_cancel"):
		fsm.call("force_cancel")
	_disable_fishing()

	# Switch back to exploration camera
	_switch_back_camera()

	if _fish_cam_rig and _fish_cam_rig.has_method("exit_fishing"):
		_fish_cam_rig.call("exit_fishing")

	if debug_prints: print("[FishingMode] CANCEL (I)")
	# Blend back and resume follow
	
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("exit_fishing_view"):
		cam.exit_fishing_view()

	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig and rig.has_method("set_follow_enabled"):
		rig.set_follow_enabled(true)

func _end_silent() -> void:
	_in_fishing = false
	if facing_root and facing_root.has_method("stop_align"):
		facing_root.call("stop_align")
	_set_player_movement(true)

	# Silent reset FSM, no animation
	if fsm:
		if fsm.has_method("soft_reset"): fsm.call("soft_reset")
		elif fsm.has_method("set_enabled"): fsm.call("set_enabled", false)

	_switch_back_camera()
	if _fish_cam_rig and _fish_cam_rig.has_method("exit_fishing"):
		_fish_cam_rig.call("exit_fishing")
	# Blend back and resume follow
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("exit_fishing_view"):
		cam.exit_fishing_view()

	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig and rig.has_method("set_follow_enabled"):
		rig.set_follow_enabled(true)

	
func _switch_back_camera() -> void:
	# Restore whichever camera was current before we switched
	if _exploration_cam:
		_exploration_cam.make_current()
	_exploration_cam = null

func _enable_fishing() -> void:
	if fsm and fsm.has_method("set_enabled"):
		fsm.call("set_enabled", true)

func _disable_fishing() -> void:
	if fsm and fsm.has_method("set_enabled"):
		fsm.call("set_enabled", false)

func _set_player_movement(enabled: bool) -> void:
	if player and player.has_method("set_movement_enabled"):
		player.call("set_movement_enabled", enabled)
