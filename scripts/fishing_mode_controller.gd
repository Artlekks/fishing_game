extends Node
## FishingModeController — glue between FishZone, FacingRoot, FSM, and movement.

@export var fish_zone_group: StringName = &"fish_zone"
@export var debug_prints: bool = true

@onready var player: Node3D       = get_parent() as Node3D
@onready var facing_root: Node3D  = player.get_node_or_null("FacingRoot") as Node3D
@onready var fsm: Node            = player.get_node_or_null("FishingStateMachine")  # expects set_enabled(), start_sequence(), force_cancel(), soft_reset()

var _current_zone: Node = null
var _in_zone: bool = false
var _in_fishing: bool = false

func _ready() -> void:
    set_process(true)
    set_process_unhandled_input(true)

    # Wire all existing zones in the scene
    for z in get_tree().get_nodes_in_group(fish_zone_group):
        if not z.is_connected("player_entered_fish_zone", Callable(self, "_on_zone_entered")):
            z.player_entered_fish_zone.connect(_on_zone_entered)
        if not z.is_connected("player_exited_fish_zone", Callable(self, "_on_zone_exited")):
            z.player_exited_fish_zone.connect(_on_zone_exited)

    # Start fully idle
    _disable_fishing() # silent (no animation)

    if debug_prints:
        var zs := get_tree().get_nodes_in_group(fish_zone_group)
        print("[FishingMode] wired zones:", zs.size(), " group=", fish_zone_group)

# ---------- Zone events ----------

func _on_zone_entered(zone: Node) -> void:
    _in_zone = true
    _current_zone = zone
    if debug_prints: print("[FishingMode] ENTER ZONE:", zone.name)
    # Do NOT auto-start. Stay armed only.

func _on_zone_exited(zone: Node) -> void:
    if zone != _current_zone:
        return
    _in_zone = false
    _current_zone = null
    _end_silent()               # stop align + soft reset; NO animation
    if debug_prints: print("[FishingMode] EXIT ZONE")

# ---------- Input ----------

func _unhandled_input(event: InputEvent) -> void:
    # Start (K) only when in a zone and not already fishing
    if event.is_action_pressed("fish") and _in_zone and not _in_fishing:
        _start_fishing()

    # Cancel (I) works anytime while fishing
    if event.is_action_pressed("cancel_fishing") and _in_fishing:
        _cancel_fishing()

# Fallback polling (in case something swallows input)
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
    _enable_fishing()                  # allow FSM to run

    # Align player logic-facing toward the zone's water
    var water_forward: Vector3 = _current_zone.call("get_water_forward") as Vector3
    if facing_root and facing_root.has_method("align_to_forward"):
        facing_root.call("align_to_forward", water_forward)

    # Freeze player movement
    _set_player_movement(false)

    # Kick FSM from the very beginning (Prep_Fishing)
    if fsm.has_method("start_sequence"):
        fsm.call("start_sequence")

    if debug_prints: print("[FishingMode] START (K)")

func _cancel_fishing() -> void:
    _in_fishing = false

    # Stop alignment + unfreeze movement
    if facing_root and facing_root.has_method("stop_align"):
        facing_root.call("stop_align")
    _set_player_movement(true)

    # Hard cancel: plays Cancel_Fishing and disables
    if fsm:
        if fsm.has_method("force_cancel"):
            fsm.call("force_cancel")
        _disable_fishing()

    if debug_prints: print("[FishingMode] CANCEL (I)")

func _end_silent() -> void:
    # Called on zone exit: NO animation should play.
    _in_fishing = false
    if facing_root and facing_root.has_method("stop_align"):
        facing_root.call("stop_align")
    _set_player_movement(true)

    if fsm:
        if fsm.has_method("soft_reset"):
            fsm.call("soft_reset")       # silent reset to NONE + disabled
        elif fsm.has_method("set_enabled"):
            fsm.call("set_enabled", false)

func _enable_fishing() -> void:
    if fsm and fsm.has_method("set_enabled"):
        fsm.call("set_enabled", true)

func _disable_fishing() -> void:
    if fsm and fsm.has_method("set_enabled"):
        fsm.call("set_enabled", false)

# Movement toggle on the player (your CharacterBody3D script should expose set_movement_enabled(bool))
func _set_player_movement(enabled: bool) -> void:
    if player and player.has_method("set_movement_enabled"):
        player.call("set_movement_enabled", enabled)
