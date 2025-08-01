extends Node3D

enum State {
    PREP,
    FISHING_IDLE,
    DIRECTION_SELECT,
    THROW_LINE,
    THROW_IDLE,
    THROW_FINISH,
    BAIT_IN_WATER,
    REELING
}

@onready var anim_tree: AnimationTree = $"../AnimationTree"
@onready var direction_selector: Node = $"../Node3D/DirectionSelector"
@onready var power_meter: Node = get_tree().current_scene.get_node("PowerMeter")
@onready var bait_spawn: Node3D = $"../BaitSpawn"

var state: State = State.PREP
var current_bait = null
var bait_scene := preload("res://actors/bait_3d.tscn")

func _ready():
    anim_tree.active = true
    print("✅ Controller Ready")
    _enter_prep()

func _process(_delta):
    match state:
        State.DIRECTION_SELECT:
            if Input.is_action_just_pressed("throw_line"):
                print("K → throw_line")
                _enter_throw_line()

        State.THROW_IDLE:
            if Input.is_action_just_pressed("throw_line"):
                print("K → throw_line_finish")
                _enter_throw_finish()

        State.BAIT_IN_WATER:
            var pressing_a := Input.is_action_pressed("reeling_left")
            var pressing_d := Input.is_action_pressed("reeling_right")
            var pressing_k := Input.is_action_pressed("throw_line")

            if pressing_k:
                print("K held → reeling_idle")
                _enter_reeling_idle()

            # Let A or D animate reeling direction even when K not held
            elif pressing_a:
                anim_tree["parameters/playback"].travel("reeling_idle_left")
            elif pressing_d:
                anim_tree["parameters/playback"].travel("reeling_idle_right")
            else:
                anim_tree["parameters/playback"].travel("reeling_static")



        State.REELING:
            var pressing_k := Input.is_action_pressed("throw_line")
            var pressing_a := Input.is_action_pressed("reeling_left")
            var pressing_d := Input.is_action_pressed("reeling_right")

            # Animation
            if pressing_k and pressing_a:
                anim_tree["parameters/playback"].travel("reeling_left")
            elif pressing_k and pressing_d:
                anim_tree["parameters/playback"].travel("reeling_right")
            elif pressing_a:
                anim_tree["parameters/playback"].travel("reeling_idle_left")
            elif pressing_d:
                anim_tree["parameters/playback"].travel("reeling_idle_right")
            elif pressing_k:
                anim_tree["parameters/playback"].travel("reeling_idle")
            else:
                anim_tree["parameters/playback"].travel("reeling_static")

            # Bait motion control
            if current_bait:
                current_bait.set("is_reeling_active", pressing_k)

                # ✅ LIVE UPDATE REELING MODE
                if pressing_k and pressing_a:
                    current_bait.set("reeling_mode", "left")
                elif pressing_k and pressing_d:
                    current_bait.set("reeling_mode", "right")
                elif pressing_k:
                    current_bait.set("reeling_mode", "straight")



# -------------------------
# STATE TRANSITIONS
# -------------------------

func _enter_prep():
    state = State.PREP
    print("→ prep_fishing")
    anim_tree["parameters/playback"].travel("prep_fishing")
    await get_tree().create_timer(2.2).timeout
    _enter_fishing_idle()

func _enter_fishing_idle():
    state = State.FISHING_IDLE
    print("→ fishing_idle")
    anim_tree["parameters/playback"].travel("fishing_idle")
    _enter_direction_select()

func _enter_direction_select():
    state = State.DIRECTION_SELECT
    print("→ direction_select")
    direction_selector.call("start_looping")

func _enter_throw_line():
    state = State.THROW_LINE
    print("→ throw_line")
    direction_selector.call("stop_looping")
    anim_tree["parameters/playback"].travel("throw_line")
    power_meter.call("start_charge")
    await get_tree().create_timer(0.6).timeout
    _enter_throw_idle()

func _enter_throw_idle():
    state = State.THROW_IDLE
    print("→ throw_line_idle")
    anim_tree["parameters/playback"].travel("throw_line_idle")

func _enter_throw_finish():
    state = State.THROW_FINISH
    power_meter.call("freeze")
    power_meter.visible = true  # ✅ Show power meter again
    print("→ throw_line_finish")
    power_meter.call("freeze")
    anim_tree["parameters/playback"].travel("throw_line_finish")

    await get_tree().create_timer(0.25).timeout  # frame 5–6
    _spawn_bait()

    # Immediately enter throw_idle, player holds pose
    anim_tree["parameters/playback"].travel("throw_idle")
    state = State.THROW_IDLE  # Temporary state while bait travels

func _enter_reeling_static():
    state = State.BAIT_IN_WATER
    anim_tree["parameters/playback"].travel("reeling_static")

func _enter_reeling_idle():
    state = State.REELING
    anim_tree["parameters/playback"].travel("reeling_idle")

    if current_bait:
        var mode := "straight"
        if Input.is_action_pressed("reeling_left"):
            mode = "left"
        elif Input.is_action_pressed("reeling_right"):
            mode = "right"

        var anim_fps := 8.0
        var move_per_frame := 0.15  # tuned visually
        var reel_speed := anim_fps * move_per_frame  # = 1.2 units/sec

        current_bait.call("set_reel_speed", reel_speed)
        current_bait.call("start_reel_back", mode, $"../BaitTarget")
        current_bait.connect("reel_back_finished", Callable(self, "_on_reel_back_finished"))



func _on_reel_back_finished():
    print("✅ Reel complete")
    power_meter.visible = false  # ✅ Hide after bait returns
    _enter_fishing_idle()


# -------------------------
# HELPERS
# -------------------------

func _spawn_bait():
    if current_bait and current_bait.is_inside_tree():
        print("⚠️ Bait already exists, ignoring new throw.")
        return

    var direction = direction_selector.get_direction_vector()
    var power = power_meter.call("get_power_value")
    print("🎯 Spawning bait — power:", power)
    current_bait = bait_scene.instantiate()
    get_tree().current_scene.add_child(current_bait)
    current_bait.global_transform.origin = bait_spawn.global_transform.origin
    current_bait.call("start_fly", direction, power)
    current_bait.connect("hit_water", Callable(self, "_on_bait_hit_water"))

func _on_bait_hit_water():
    print("🌊 Bait hit water")
    _enter_reeling_static()
