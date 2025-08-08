extends Node

@export var fish_zone_group: StringName = &"fish_zone"
@export var debug_prints: bool = true

@onready var player: Node3D      = get_parent() as Node3D
@onready var facing_root: Node3D = player.get_node_or_null("FacingRoot") as Node3D
@onready var fsm: Node           = player.get_node_or_null("FishingStateMachine")  # optional but recommended

var _current_zone: Node = null
var _in_zone: bool = false
var _in_fishing: bool = false

func _ready() -> void:
    # Be explicit: we want input and ticks no matter what.
    set_process(true)
    set_process_unhandled_input(true)

    if facing_root == null:
        push_warning("FishingModeController: FacingRoot not found under CharacterBody3D.")
    if fsm == null:
        push_warning("FishingModeController: FishingStateMachine not found (reset/enable hooks will be skipped).")

    # Wire existing zones (placed in the scene at load)
    for z in get_tree().get_nodes_in_group(fish_zone_group):
        if not z.is_connected("player_entered_fish_zone", Callable(self, "_on_zone_entered")):
            z.player_entered_fish_zone.connect(_on_zone_entered)
        if not z.is_connected("player_exited_fish_zone", Callable(self, "_on_zone_exited")):
            z.player_exited_fish_zone.connect(_on_zone_exited)

    # Disable FSM by default until we are inside a zone
    _set_fsm_enabled(false)
    
    var zs := get_tree().get_nodes_in_group(fish_zone_group)
    print("[FishingMode] wired zones:", zs.size(), " group=", fish_zone_group)
    for z in zs:
        print("  - ", z.name)

func _on_zone_entered(zone: Node) -> void:
    _in_zone = true
    _current_zone = zone
    # Fresh start every time you enter
    _reset_fsm()
    _set_fsm_enabled(true)
    if debug_prints: print("[FishingMode] ENTER ZONE:", zone.name)

func _on_zone_exited(zone: Node) -> void:
    if zone == _current_zone:
        _in_zone = false
        _current_zone = null
        # Hard stop and disable FSM when leaving the zone
        _exit_fishing(true)
        _set_fsm_enabled(false)
    if debug_prints: print("[FishingMode] EXIT ZONE")

# Robust input path (won't be swallowed by UI)
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("fish") and _in_zone and not _in_fishing:
        if debug_prints: print("[FishingMode] fish JUST PRESSED")
        _enter_fishing()
    elif event.is_action_released("fish") and _in_fishing:
        if debug_prints: print("[FishingMode] fish JUST RELEASED")
        _exit_fishing(false)

# Fallback polling (belt & suspenders)
func _process(_dt: float) -> void:
    if _in_zone and not _in_fishing and Input.is_action_just_pressed("fish"):
        if debug_prints: print("[FishingMode] POLL PRESSED")
        _enter_fishing()
    elif _in_fishing and Input.is_action_just_released("fish"):
        if debug_prints: print("[FishingMode] POLL RELEASED")
        _exit_fishing(false)

func _enter_fishing() -> void:
    _in_fishing = true
    if _current_zone == null:
        if debug_prints: print("[FishingMode] enter: NO ZONE")
        return
    var water_forward: Vector3 = _current_zone.call("get_water_forward") as Vector3
    if facing_root and facing_root.has_method("align_to_forward"):
        facing_root.call("align_to_forward", water_forward)
    if debug_prints: print("[FishingMode] ALIGN to", water_forward)

func _exit_fishing(force_cancel: bool = false) -> void:
    _in_fishing = false
    if facing_root and facing_root.has_method("stop_align"):
        facing_root.call("stop_align")
    if force_cancel:
        _reset_fsm()
    if debug_prints: print("[FishingMode] STOP ALIGN (force_cancel=", force_cancel, ")")

# ---------- FSM hooks (safe if FSM is missing) ----------

func _set_fsm_enabled(enabled: bool) -> void:
    if fsm and fsm.has_method("set_enabled"):
        fsm.call("set_enabled", enabled)

func _reset_fsm() -> void:
    if fsm == null:
        return
    if fsm.has_method("force_cancel"):
        fsm.call("force_cancel")
    elif fsm.has_method("reset_to_none"):
        fsm.call("reset_to_none")
