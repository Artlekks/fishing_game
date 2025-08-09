extends Node
## FishingModeController — BoFIV flow using the SAME exploration camera.

@export var fish_zone_group: StringName = &"fish_zone"
@export var debug_prints: bool = true
@export var camera_rig_path: NodePath = ^""   # path to your CameraRig; if empty we try a "camera_rig" group

@onready var player: Node3D       = get_parent() as Node3D
@onready var facing_root: Node3D  = player.get_node_or_null("FacingRoot") as Node3D
@onready var fsm: Node            = player.get_node_or_null("FishingStateMachine")

var _current_zone: Node = null
var _in_zone := false
var _in_fishing := false
var _rig: Node = null

func _ready() -> void:
	set_process_unhandled_input(true)

	for z in get_tree().get_nodes_in_group(fish_zone_group):
		if not z.is_connected("player_entered_fish_zone", Callable(self, "_on_zone_entered")):
			z.player_entered_fish_zone.connect(_on_zone_entered)
		if not z.is_connected("player_exited_fish_zone", Callable(self, "_on_zone_exited")):
			z.player_exited_fish_zone.connect(_on_zone_exited)

	if camera_rig_path != NodePath("") and has_node(camera_rig_path):
		_rig = get_node(camera_rig_path)
	else:
		_rig = get_tree().get_first_node_in_group("camera_rig")  # put your CameraRig in this group once

	_set_fishing_enabled(false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fish") and _in_zone and not _in_fishing:
		_start_fishing()
	elif event.is_action_pressed("cancel_fishing") and _in_fishing:
		_cancel_fishing()

func _on_zone_entered(zone: Node) -> void:
	_in_zone = true
	_current_zone = zone
	if debug_prints: print("[FishingMode] ENTER ZONE:", zone.name)

func _on_zone_exited(zone: Node) -> void:
	if zone != _current_zone:
		return
	_in_zone = false
	_current_zone = null

	# Only end if we were in fishing mode
	if _in_fishing:
		_end_silent()

	if debug_prints:
		print("[FishingMode] EXIT ZONE")


# --- Internals -------------------------------------------------------------

func _start_fishing() -> void:
	if _current_zone == null: return
	_in_fishing = true
	_set_fishing_enabled(true)

	# Stop follow BEFORE we snapshot camera pose (prevents jump)
	if _rig and _rig.has_method("set_follow_enabled"):
		_rig.call("set_follow_enabled", false)
	await get_tree().process_frame  # let the camera settle one frame

	var water_forward: Vector3 = _current_zone.call("get_water_forward")
	var anchor := _current_zone.get_node_or_null("CameraAnchor") as Node3D
	var cam := get_viewport().get_camera_3d()

	# Blend same camera
	if cam:
		if cam.has_method("enter_fishing_view"):
			cam.call("enter_fishing_view", player, water_forward, anchor)
		elif cam.has_method("enter_fishing"): # compat
			cam.call("enter_fishing", player, water_forward, anchor)

	# Lock facing & block movement
	if facing_root and facing_root.has_method("align_to_forward"):
		facing_root.call("align_to_forward", water_forward)
	_set_player_movement(false)

	# Kick FSM (plays Prep_Fishing → Fishing_Idle)
	if fsm and fsm.has_method("start_sequence"):
		fsm.call("start_sequence")

	if debug_prints: print("[FishingMode] START (K)")

func _cancel_fishing() -> void:
	if not _in_fishing: return
	_in_fishing = false

	if facing_root and facing_root.has_method("stop_align"):
		facing_root.call("stop_align")
	_set_player_movement(true)

	if fsm and fsm.has_method("force_cancel"):
		fsm.call("force_cancel")

	var cam := get_viewport().get_camera_3d()
	if cam:
		if cam.has_method("exit_fishing_view"):
			cam.call("exit_fishing_view")
		elif cam.has_method("exit_fishing"): # compat
			cam.call("exit_fishing")

	if _rig and _rig.has_method("set_follow_enabled"):
		_rig.call("set_follow_enabled", true)

	_set_fishing_enabled(false)

	if debug_prints: print("[FishingMode] CANCEL (I)")

func _end_silent() -> void:
	if not _in_fishing:
		# Not in fishing → do not touch camera or FSM
		return

	_in_fishing = false

	if facing_root and facing_root.has_method("stop_align"):
		facing_root.call("stop_align")
	_set_player_movement(true)

	# Silent FSM reset — no animations
	if fsm:
		if fsm.has_method("soft_reset"):
			fsm.call("soft_reset")
		elif fsm.has_method("set_enabled"):
			fsm.call("set_enabled", false)

	# Blend back and resume follow
	var cam := get_viewport().get_camera_3d()
	if cam:
		if cam.has_method("exit_fishing_view"):
			cam.call("exit_fishing_view")
		elif cam.has_method("exit_fishing"):
			cam.call("exit_fishing")

	if _rig and _rig.has_method("set_follow_enabled"):
		_rig.call("set_follow_enabled", true)

	_set_fishing_enabled(false)


# --- Helpers ---------------------------------------------------------------

func _set_fishing_enabled(enabled: bool) -> void:
	if fsm and fsm.has_method("set_enabled"):
		fsm.call("set_enabled", enabled)

func _set_player_movement(enabled: bool) -> void:
	if player and player.has_method("set_movement_enabled"):
		player.call("set_movement_enabled", enabled)
