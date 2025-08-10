extends Node
## FishingModeController — symmetric enter/exit camera timing via direct camera tween on exit.

@export var fish_zone_group: StringName = &"fish_zone"
@export var debug_prints: bool = true
@export var camera_rig_path: NodePath = ^""            # exploration follow rig (Node3D) with set_follow_enabled(bool)
@export var exploration_camera_path: NodePath = ^""     # Camera3D under the exploration rig
@export var stance_tween_time: float = 0.25

@export var snap_feet_on_enter: bool = false
@export var snap_threshold: float = 0.05

@export var exit_blend_fallback: float = 0.35          # used if we can’t discover enter duration
@export var exit_time_override: float = -1.0           # set >0 (e.g. 2.0) to hard-match enter speed

@onready var player: Node3D       = get_parent() as Node3D
@onready var facing_root: Node3D  = player.get_node_or_null("FacingRoot") as Node3D
@onready var fsm: Node            = player.get_node_or_null("FishingStateMachine")
@onready var anim_ctrl: Node      = player.get_node_or_null("AnimatedSprite3D")

var _current_zone: Node = null
var _in_zone: bool = false
var _in_fishing: bool = false
var _rig: Node3D = null
var _exploration_cam: Camera3D = null

func _ready() -> void:
    set_process_unhandled_input(true)

    for z in get_tree().get_nodes_in_group(fish_zone_group):
        if not z.is_connected("player_entered_fish_zone", Callable(self, "_on_zone_entered")):
            z.player_entered_fish_zone.connect(_on_zone_entered)
        if not z.is_connected("player_exited_fish_zone", Callable(self, "_on_zone_exited")):
            z.player_exited_fish_zone.connect(_on_zone_exited)

    if camera_rig_path != NodePath("") and has_node(camera_rig_path):
        _rig = get_node(camera_rig_path) as Node3D
    else:
        _rig = get_tree().get_first_node_in_group("camera_rig") as Node3D

    if exploration_camera_path != NodePath("") and has_node(exploration_camera_path):
        _exploration_cam = get_node(exploration_camera_path) as Camera3D

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

    # Pause follow BEFORE any camera work
    if _rig and _rig.has_method("set_follow_enabled"):
        _rig.call("set_follow_enabled", false)
    await get_tree().process_frame

    var water_forward: Vector3 = _get_zone_forward(_current_zone)
    var stance_point: Vector3 = _get_zone_stance(_current_zone, player.global_position)

    if anim_ctrl and anim_ctrl.has_method("set_fishing_flip_locked"):
        anim_ctrl.call("set_fishing_flip_locked", true)
    if facing_root and facing_root.has_method("align_to_forward"):
        facing_root.call("align_to_forward", water_forward)

    # Optional snap (default off)
    var dist: float = player.global_position.distance_to(stance_point)
    if snap_feet_on_enter and dist > snap_threshold:
        var t: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        t.tween_property(player, "global_position", stance_point, stance_tween_time)

    # Enter fishing view on active camera (3 args only)
    var cam: Object = get_viewport().get_camera_3d()
    var anchor: Node3D = _current_zone.get_node_or_null("CameraAnchor") as Node3D
    if cam:
        if cam.has_method("enter_fishing_view"):
            cam.call("enter_fishing_view", player, water_forward, anchor)
        elif cam.has_method("enter_fishing"):
            cam.call("enter_fishing", player, water_forward, anchor)

    _set_player_movement(false)
    if fsm and fsm.has_method("start_sequence"):
        fsm.call("start_sequence")

    if debug_prints: print("[FishingMode] START (K)")

func _cancel_fishing() -> void:
    if not _in_fishing:
        return
    _in_fishing = false

    if anim_ctrl and anim_ctrl.has_method("set_fishing_flip_locked"):
        anim_ctrl.call("set_fishing_flip_locked", false)
    if facing_root and facing_root.has_method("stop_align"):
        facing_root.call("stop_align")

    _set_player_movement(true)

    if fsm and fsm.has_method("force_cancel"):
        fsm.call("force_cancel")

    await _exit_camera_and_blend_follow()
    _set_fishing_enabled(false)
    if debug_prints: print("[FishingMode] CANCEL (I)")

func _end_silent() -> void:
    if not _in_fishing:
        return
    _in_fishing = false

    if anim_ctrl and anim_ctrl.has_method("set_fishing_flip_locked"):
        anim_ctrl.call("set_fishing_flip_locked", false)
    if facing_root and facing_root.has_method("stop_align"):
        facing_root.call("stop_align")

    _set_player_movement(true)

    if fsm:
        if fsm.has_method("soft_reset"):
            fsm.call("soft_reset")
        elif fsm.has_method("set_enabled"):
            fsm.call("set_enabled", false)

    await _exit_camera_and_blend_follow()
    _set_fishing_enabled(false)

# ------------------------------------------------------------------------------
func _exit_camera_and_blend_follow() -> void:
    var active_cam: Camera3D = get_viewport().get_camera_3d()

    # Let the fishing camera clean up (no-op if not implemented)
    if active_cam:
        if active_cam.has_method("exit_fishing_view"):
            active_cam.call("exit_fishing_view")
        elif active_cam.has_method("exit_fishing"):
            active_cam.call("exit_fishing")

    # Duration (override wins, else fallback)
    var duration: float = exit_time_override if exit_time_override > 0.0 else exit_blend_fallback
    if duration <= 0.0:
        duration = 0.35

    # Need both the exploration camera and rig for a clean return
    if _exploration_cam == null or _rig == null:
        if _rig and _rig.has_method("set_follow_enabled"):
            _rig.call("set_follow_enabled", true)
        return

    # Freeze follow so it can't fight the tween
    if _rig.has_method("set_follow_enabled"):
        _rig.call("set_follow_enabled", false)

    # Seamless handoff: match transforms and switch current camera
    if active_cam:
        _exploration_cam.global_transform = active_cam.global_transform
    _exploration_cam.make_current()

    # Tween the EXPLORATION RIG back to its normal follow pose
    var desired_pos: Vector3 = _compute_follow_position_safely(_rig)
    var t: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    t.tween_property(_rig, "global_position", desired_pos, duration)
    await t.finished

    # Re-enable hard follow
    if _rig.has_method("set_follow_enabled"):
        _rig.call("set_follow_enabled", true)

# Compute where the exploration rig would place the camera, without knowing its internals.
func _compute_follow_position_safely(rig: Node) -> Vector3:
    # If the rig exposes a helper, use it.
    if rig.has_method("get_follow_position"):
        return rig.call("get_follow_position") as Vector3

    # Common pattern: target_path/target + offset
    var target_pos: Vector3 = Vector3.ZERO
    var got_target: bool = false

    # target_path on the rig?
    var tp: NodePath = rig.get("target_path") as NodePath
    if tp != NodePath("") and rig.has_node(tp):
        var target_node: Node3D = rig.get_node(tp) as Node3D
        if target_node:
            target_pos = target_node.global_position
            got_target = true

    # or a direct 'target' property?
    if not got_target:
        var tnode: Node3D = rig.get("target") as Node3D
        if tnode:
            target_pos = tnode.global_position
            got_target = true

    # optional 'offset' on the rig
    var offset: Vector3 = Vector3.ZERO
    var off: Vector3 = rig.get("offset") as Vector3
    offset = off

    if got_target:
        return target_pos + offset

    # Fallback: keep current rig position (typed)
    return (rig as Node3D).global_position



# ------------------------------------------------------------------------------

func _set_fishing_enabled(enabled: bool) -> void:
    if fsm and fsm.has_method("set_enabled"):
        fsm.call("set_enabled", enabled)

func _set_player_movement(enabled: bool) -> void:
    if player and player.has_method("set_movement_enabled"):
        player.call("set_movement_enabled", enabled)

func _get_zone_forward(zone: Node) -> Vector3:
    if zone and zone.has_method("get_water_forward"):
        var v: Vector3 = zone.call("get_water_forward") as Vector3
        return v.normalized()
    return -player.global_transform.basis.z.normalized()

func _get_zone_stance(zone: Node, player_pos: Vector3) -> Vector3:
    if zone and zone.has_method("get_stance_point"):
        return zone.call("get_stance_point", player_pos) as Vector3
    return player_pos
