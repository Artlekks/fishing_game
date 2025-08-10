extends Node
## FishingModeController — BoFIV flow on the SAME exploration camera.
## - K inside a FishZone -> snap to stance, lock flip, align to water, camera blends.
## - I cancels -> unlock flip, restore movement, camera resumes follow.

@export var fish_zone_group: StringName = &"fish_zone"
@export var debug_prints: bool = true
@export var camera_rig_path: NodePath = ^""       # your follow rig (has set_follow_enabled(bool))
@export var stance_tween_time: float = 0.25       # feet snap time along StandA->StandB

@onready var player: Node3D       = get_parent() as Node3D
@onready var facing_root: Node3D  = player.get_node_or_null("FacingRoot") as Node3D
@onready var fsm: Node            = player.get_node_or_null("FishingStateMachine")
@onready var anim_ctrl: Node      = player.get_node_or_null("AnimatedSprite3D")  # fishing_animation_controller.gd

var _current_zone: Node = null
var _in_zone := false
var _in_fishing := false
var _rig: Node = null

func _ready() -> void:
	set_process_unhandled_input(true)

	# Wire all zones present at load
	for z in get_tree().get_nodes_in_group(fish_zone_group):
		if not z.is_connected("player_entered_fish_zone", Callable(self, "_on_zone_entered")):
			z.player_entered_fish_zone.connect(_on_zone_entered)
		if not z.is_connected("player_exited_fish_zone", Callable(self, "_on_zone_exited")):
			z.player_exited_fish_zone.connect(_on_zone_exited)

	# Follow rig (to pause/resume follow)
	if camera_rig_path != NodePath("") and has_node(camera_rig_path):
		_rig = get_node(camera_rig_path)
	else:
		_rig = get_tree().get_first_node_in_group("camera_rig")

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
	if _in_fishing:
		_end_silent()
	if debug_prints: print("[FishingMode] EXIT ZONE")

# ------------------------------------------------------------------------------

func _start_fishing() -> void:
	if _current_zone == null:
		return
	_in_fishing = true
	_set_fishing_enabled(true)

	# Pause follow BEFORE sampling camera
	if _rig and _rig.has_method("set_follow_enabled"):
		_rig.call("set_follow_enabled", false)
	await get_tree().process_frame

	# Direction & stance
	var water_forward: Vector3 = _get_zone_forward(_current_zone)
	var stance_point: Vector3 = _get_zone_stance(_current_zone, player.global_position)

	# Lock out mirroring and start turning toward water
	if anim_ctrl and anim_ctrl.has_method("set_fishing_flip_locked"):
		anim_ctrl.call("set_fishing_flip_locked", true)
	if facing_root and facing_root.has_method("align_to_forward"):
		facing_root.call("align_to_forward", water_forward)

	# Snap feet to stance line (short tween)
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(player, "global_position", stance_point, stance_tween_time)

	# Tell the active Camera3D to enter fishing view (same camera, different framing)
	var cam := get_viewport().get_camera_3d()
	var anchor := _current_zone.get_node_or_null("CameraAnchor") as Node3D
	if cam:
		if cam.has_method("enter_fishing_view"):
			cam.call("enter_fishing_view", player, water_forward, anchor)
		elif cam.has_method("enter_fishing"):
			cam.call("enter_fishing", player, water_forward, anchor)


	# Movement off; FSM kicks (Prep_Fishing -> Fishing_Idle)
	_set_player_movement(false)
	if fsm and fsm.has_method("start_sequence"):
		fsm.call("start_sequence")

	if debug_prints: print("[FishingMode] START (K)")

func _cancel_fishing() -> void:
	if not _in_fishing:
		return
	_in_fishing = false

	# Unlock + stop facing alignment
	if anim_ctrl and anim_ctrl.has_method("set_fishing_flip_locked"):
		anim_ctrl.call("set_fishing_flip_locked", false)
	if facing_root and facing_root.has_method("stop_align"):
		facing_root.call("stop_align")

	# Player regains control
	_set_player_movement(true)

	# Cancel FSM with animation
	if fsm and fsm.has_method("force_cancel"):
		fsm.call("force_cancel")

	# Camera exits fishing view; resume follow
	var cam := get_viewport().get_camera_3d()
	if cam:
		if cam.has_method("exit_fishing_view"):
			cam.call("exit_fishing_view")
		elif cam.has_method("exit_fishing"):
			cam.call("exit_fishing")
	if _rig and _rig.has_method("set_follow_enabled"):
		_rig.call("set_follow_enabled", true)

	_set_fishing_enabled(false)

	if debug_prints: print("[FishingMode] CANCEL (I)")

func _end_silent() -> void:
	# Only if we were actually in fishing mode
	if not _in_fishing:
		return
	_in_fishing = false

	# Unlock + stop facing alignment
	if anim_ctrl and anim_ctrl.has_method("set_fishing_flip_locked"):
		anim_ctrl.call("set_fishing_flip_locked", false)
	if facing_root and facing_root.has_method("stop_align"):
		facing_root.call("stop_align")

	# Restore control
	_set_player_movement(true)

	# Silent FSM reset (no cancel animation)
	if fsm:
		if fsm.has_method("soft_reset"):
			fsm.call("soft_reset")
		elif fsm.has_method("set_enabled"):
			fsm.call("set_enabled", false)

	# Camera exits fishing view; resume follow
	var cam := get_viewport().get_camera_3d()
	if cam:
		if cam.has_method("exit_fishing_view"):
			cam.call("exit_fishing_view")
		elif cam.has_method("exit_fishing"):
			cam.call("exit_fishing")
	if _rig and _rig.has_method("set_follow_enabled"):
		_rig.call("set_follow_enabled", true)

	_set_fishing_enabled(false)

# ------------------------------------------------------------------------------

func _set_fishing_enabled(enabled: bool) -> void:
	if fsm and fsm.has_method("set_enabled"):
		fsm.call("set_enabled", enabled)

func _set_player_movement(enabled: bool) -> void:
	if player and player.has_method("set_movement_enabled"):
		player.call("set_movement_enabled", enabled)

func _get_zone_forward(zone: Node) -> Vector3:
	if zone and zone.has_method("get_water_forward"):
		var v := zone.call("get_water_forward") as Vector3
		return v.normalized()
	return -player.global_transform.basis.z.normalized()

func _get_zone_stance(zone: Node, player_pos: Vector3) -> Vector3:
	if zone and zone.has_method("get_stance_point"):
		return zone.call("get_stance_point", player_pos) as Vector3
	return player_pos

# Tiny reflection helper: does enter_fishing_view accept 4 args?
