extends Node
## fishing_mode_controller.gd — Phantom Camera + sprite-facing gate

@export var fish_zone_group: StringName = &"fish_zone"
@export var debug_prints := true

# Player must face the zone's WaterFacing within this angle to allow switching
@export var facing_allow_deg := 35.0

# Optional stance snap (OFF by default)
@export var snap_feet_on_enter := false
@export var snap_threshold := 0.05
@export var stance_tween_time := 0.25

@onready var player: Node3D                 = get_parent() as Node3D
@onready var facing_root: Node3D            = player.get_node_or_null("FacingRoot") as Node3D
@onready var fsm: Node                      = player.get_node_or_null("FishingStateMachine")
@onready var sprite: AnimatedSprite3D       = player.get_node_or_null("AnimatedSprite3D") as AnimatedSprite3D

var _current_zone: Node = null
var _in_zone := false
var _in_fishing := false

func _ready() -> void:
    set_process_unhandled_input(true)
    for z in get_tree().get_nodes_in_group(fish_zone_group):
        if z.has_signal("player_entered_fish_zone") and not z.is_connected("player_entered_fish_zone", Callable(self, "_on_zone_entered")):
            z.connect("player_entered_fish_zone", Callable(self, "_on_zone_entered"))
        if z.has_signal("player_exited_fish_zone") and not z.is_connected("player_exited_fish_zone", Callable(self, "_on_zone_exited")):
            z.connect("player_exited_fish_zone", Callable(self, "_on_zone_exited"))
    _set_fishing_enabled(false)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("fish") and _in_zone and not _in_fishing:
        _try_start_fishing()
    elif event.is_action_pressed("cancel_fishing") and _in_fishing:
        _cancel_fishing()

# --- zone hooks ---
func _on_zone_entered(zone: Node) -> void:
    _in_zone = true
    _current_zone = zone
    if debug_prints: print("[FishingMode] ENTER ZONE:", zone.name)

func _on_zone_exited(zone: Node) -> void:
    if zone != _current_zone:
        return
    _in_zone = false
    if _in_fishing:
        _end_silent()
    _current_zone = null
    if debug_prints: print("[FishingMode] EXIT ZONE")

func _try_start_fishing() -> void:
    if _current_zone == null:
        return

    # >>> NEW: base water direction on player -> LookTarget (in XZ plane)
    var water_forward: Vector3 = _get_zone_look_forward(_current_zone)
    var face_forward:  Vector3 = _get_player_forward_from_sprite()

    var dot: float     = clamp(float(face_forward.dot(water_forward)), -1.0, 1.0)
    var ang_deg: float = rad_to_deg(acos(dot))

    if ang_deg > facing_allow_deg:
        if debug_prints:
            print("[FishingMode] Blocked: not facing water (", round(ang_deg), "° > ",
                facing_allow_deg, "°) anim='", (sprite.animation if sprite else ""),
                "' face=", face_forward, " water=", water_forward)
        return

    _start_fishing(water_forward)


func _start_fishing(water_forward: Vector3) -> void:
    _in_fishing = true
    _set_fishing_enabled(true)

    var stance_point := _get_zone_stance(_current_zone, player.global_position)

    # Lock mirroring and (optionally) hard-align to water for fishing set
    if sprite and sprite.has_method("set_fishing_flip_locked"):
        sprite.call("set_fishing_flip_locked", true)
    if facing_root and facing_root.has_method("align_to_forward"):
        facing_root.call("align_to_forward", water_forward)

    if snap_feet_on_enter:
        var d := player.global_position.distance_to(stance_point)
        if d > snap_threshold:
            var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
            t.tween_property(player, "global_position", stance_point, stance_tween_time)

    # Zone raises fishing PCam and slides gaze player->water (single PCam)
    if _current_zone and _current_zone.has_method("activate_fishing_view"):
        _current_zone.call("activate_fishing_view", player)

    _set_player_movement(false)
    if fsm and fsm.has_method("start_sequence"):
        fsm.call("start_sequence")
    if debug_prints: print("[FishingMode] START (K)")

func _cancel_fishing() -> void:
    if not _in_fishing: return
    _in_fishing = false

    if sprite and sprite.has_method("set_fishing_flip_locked"):
        sprite.call("set_fishing_flip_locked", false)
    if facing_root and facing_root.has_method("stop_align"):
        facing_root.call("stop_align")

    _set_player_movement(true)
    if fsm and fsm.has_method("force_cancel"):
        fsm.call("force_cancel")

    if _current_zone and _current_zone.has_method("deactivate_fishing_view"):
        _current_zone.call("deactivate_fishing_view")

    _set_fishing_enabled(false)
    if debug_prints: print("[FishingMode] CANCEL (I)")

func _end_silent() -> void:
    _in_fishing = false
    if sprite and sprite.has_method("set_fishing_flip_locked"):
        sprite.call("set_fishing_flip_locked", false)
    if facing_root and facing_root.has_method("stop_align"):
        facing_root.call("stop_align")

    _set_player_movement(true)
    if fsm:
        if fsm.has_method("soft_reset"): fsm.call("soft_reset")
        elif fsm.has_method("set_enabled"): fsm.call("set_enabled", false)

    if _current_zone and _current_zone.has_method("deactivate_fishing_view"):
        _current_zone.call("deactivate_fishing_view")

    _set_fishing_enabled(false)

# --- helpers ---
func _get_player_forward_from_sprite() -> Vector3:
    # Infer from AnimatedSprite3D.animation name (supports n/ne/e/se/s/sw/w/nw and long forms)
    if sprite:
        var dir := _infer_dir_from_anim(String(sprite.animation).to_lower())
        if dir != Vector3.ZERO:
            return dir
    # Fallback: FacingRoot or player -Z (billboarded, so only as last resort)
    if facing_root:
        return -facing_root.global_transform.basis.z.normalized()
    return -player.global_transform.basis.z.normalized()

func _get_zone_look_forward(zone: Node) -> Vector3:
    # Vector from player to the zone's water look point, flattened on XZ.
    var look_pos: Vector3
    if zone and zone.has_method("get_look_point"):
        look_pos = zone.call("get_look_point")
    else:
        var lt := (zone.get_node_or_null("LookTarget") as Node3D)
        look_pos = lt.global_position if lt else player.global_position + Vector3.FORWARD

    var v: Vector3 = look_pos - player.global_position
    v.y = 0.0
    var len := v.length()
    if len <= 0.0001:
        return _get_zone_forward(zone)  # fallback
    return (v / len)

func _infer_dir_from_anim(a: String) -> Vector3:
    # Normalize separators to "_" then scan tokens from the end.
    var s := a.to_lower()
    for sep in [" ", ".", "/", "\\", "-", "—"]:
        s = s.replace(sep, "_")
    # collapse repeats like "__"
    while s.find("__") != -1:
        s = s.replace("__", "_")
    var tokens: PackedStringArray = s.split("_", false) # skip_empty = false -> we handled above

    # Check tokens from the end (handles names like "idle_sw", "walk.north_west", etc.)
    for i in range(tokens.size() - 1, -1, -1):
        var v := _dir_from_token(tokens[i])
        if v != Vector3.ZERO:
            return v

    # Fallback: short compass tags anywhere in the string
    for tag in ["ne","se","sw","nw","n","e","s","w"]:
        if s.find("_" + tag + "_") != -1 or s.ends_with("_" + tag) or s.begins_with(tag + "_"):
            return _dir_from_token(tag)

    return Vector3.ZERO


func _dir_from_token(t: String) -> Vector3:
    match t:
        "n", "north":
            return Vector3(0, 0, 1)
        "ne", "northeast", "north_east":
            return Vector3(1, 0, 1).normalized()
        "e", "east":
            return Vector3(1, 0, 0)
        "se", "southeast", "south_east":
            return Vector3(1, 0, -1).normalized()
        "s", "south":
            return Vector3(0, 0, -1)
        "sw", "southwest", "south_west":
            return Vector3(-1, 0, -1).normalized()
        "w", "west":
            return Vector3(-1, 0, 0)
        "nw", "northwest", "north_west":
            return Vector3(-1, 0, 1).normalized()
        _:
            return Vector3.ZERO


func _get_zone_forward(zone: Node) -> Vector3:
    if zone and zone.has_method("get_water_forward"):
        return (zone.call("get_water_forward") as Vector3).normalized()
    return _get_player_forward_from_sprite()

func _get_zone_stance(zone: Node, player_pos: Vector3) -> Vector3:
    if zone and zone.has_method("get_stance_point"):
        return zone.call("get_stance_point", player_pos)
    return player_pos

func _set_fishing_enabled(enabled: bool) -> void:
    if fsm and fsm.has_method("set_enabled"):
        fsm.call("set_enabled", enabled)

func _set_player_movement(enabled: bool) -> void:
    if player and player.has_method("set_movement_enabled"):
        player.call("set_movement_enabled", enabled)
