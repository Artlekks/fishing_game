# player_8dir_controller.gd — Godot 4.4.1
extends CharacterBody3D

# -------- Movement / facing --------
@export var move_speed: float = 3.5
@export var snap_to_8_directions: bool = true

# -------- Fishing gating --------
@export var water_facing: Node3D                           # assign your WaterFacing
@export_range(1.0, 179.0, 1.0) var half_angle_deg: float = 60.0

# Accept ANY camera node (Camera3D or PhantomCamera3D)
@export var exploration_camera: Node = null                # assign PCam_Exploration
@export var fishing_camera: Node = null                    # assign PCam_Fishing

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var frames: SpriteFrames = sprite.sprite_frames

var original_offset: Vector2
var last_dir: String = "S"
var last_anim: String = ""
var movement_enabled: bool = true
var in_fishing_mode: bool = false

const FLIP_DIRS := {"W": true, "NW": true, "SW": true}
const MIRROR_MAP := {"W": "E", "NW": "NE", "SW": "SE"}
const DIRS := ["S","SE","E","NE","N","NW","W","SW"]

func _ready() -> void:
    original_offset = sprite.offset
    _activate_cam(exploration_camera)
    _deactivate_cam(fishing_camera)

func set_movement_enabled(enabled: bool) -> void:
    movement_enabled = enabled
    if not enabled:
        velocity = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("enter_fishing"):
        if _can_enter_fishing():
            _enter_fishing()
    elif event.is_action_pressed("exit_fishing"):
        if in_fishing_mode:
            _exit_fishing()

func _physics_process(delta: float) -> void:
    if in_fishing_mode:
        velocity = Vector3.ZERO
        move_and_slide()
        return

    var iv := Input.get_vector("move_left","move_right","move_forward","move_back")

    if movement_enabled and iv.length_squared() > 0.0:
        var dir := Vector3(iv.x, 0.0, iv.y)

        var yaw := atan2(dir.x, dir.z)  # 0 → +Z
        if snap_to_8_directions:
            var step := PI / 4.0
            yaw = round(yaw / step) * step
        rotation.y = yaw

        last_dir = _yaw_to_dir(rotation.y)

        var mv := dir.normalized() * move_speed
        velocity.x = mv.x
        velocity.z = mv.z

        _play_8dir_animation("Walk", last_dir)
    else:
        velocity.x = 0.0
        velocity.z = 0.0
        _play_8dir_animation("Idle", last_dir)

    move_and_slide()

func _yaw_to_dir(yaw: float) -> String:
    var step := PI / 4.0
    var idx := int(round(yaw / step))
    idx = int(posmod(idx, 8))
    return DIRS[idx]

func _play_8dir_animation(base: String, dir: String) -> void:
    if dir == null or dir == "":
        dir = "S"

    var flip: bool = FLIP_DIRS.has(dir)
    var token: String = MIRROR_MAP.get(dir, dir) if flip else dir
    var anim := "%s_%s" % [base, token]

    if frames == null or not frames.has_animation(anim):
        var candidates: PackedStringArray = (
            ["Walk_S","Walk_E","Walk_N","Walk_NE","Walk_SE","Walk"]
            if base == "Walk"
            else ["Idle_S","Idle_E","Idle_N","Idle_NE","Idle_SE","Idle","Walk_S"]
        )
        for c in candidates:
            if frames != null and frames.has_animation(c):
                anim = c
                break

    sprite.flip_h = flip
    sprite.offset = Vector2(-original_offset.x, original_offset.y) if flip else original_offset

    if frames != null and frames.has_animation(anim) and anim != last_anim:
        sprite.play(anim)
        last_anim = anim

# ---------- Fishing mode helpers ----------

func _can_enter_fishing() -> bool:
    if water_facing == null:
        push_warning("water_facing not assigned; cannot test fishing cone.")
        return false

    var player_fwd: Vector3 = global_transform.basis.z.normalized()
    var water_fwd: Vector3 = water_facing.global_transform.basis.z.normalized()

    var d: float = clampf(player_fwd.dot(water_fwd), -1.0, 1.0)
    var angle_deg: float = rad_to_deg(acos(d))  # 0 = perfectly aligned

    return angle_deg <= half_angle_deg

func _enter_fishing() -> void:
    in_fishing_mode = true
    set_movement_enabled(false)
    velocity = Vector3.ZERO
    move_and_slide()
    _activate_cam(fishing_camera)
    _deactivate_cam(exploration_camera)

func _exit_fishing() -> void:
    in_fishing_mode = false
    set_movement_enabled(true)
    _activate_cam(exploration_camera)
    _deactivate_cam(fishing_camera)

# ---------- Camera utils (works for Camera3D and PhantomCamera3D) ----------

func _activate_cam(n: Node) -> void:
    if n == null: return
    if n is Camera3D:
        (n as Camera3D).current = true
        return
    if n.has_method("make_current"):
        n.call("make_current")
    elif _has_prop(n, "current"):
        n.set("current", true)
    elif _has_prop(n, "enabled"):
        n.set("enabled", true)
    elif _has_prop(n, "active"):
        n.set("active", true)
    if _has_prop(n, "priority"):
        n.set("priority", 1000)  # give active cam a high priority

func _deactivate_cam(n: Node) -> void:
    if n == null: return
    if n is Camera3D:
        (n as Camera3D).current = false
        return
    if n.has_method("deactivate"):
        n.call("deactivate")
    elif _has_prop(n, "current"):
        n.set("current", false)
    elif _has_prop(n, "enabled"):
        n.set("enabled", false)
    elif _has_prop(n, "active"):
        n.set("active", false)
    if _has_prop(n, "priority"):
        n.set("priority", 0)

func _has_prop(o: Object, name: String) -> bool:
    for p in o.get_property_list():
        if p.name == name:
            return true
    return false
