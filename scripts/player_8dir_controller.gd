# player_8dir_controller.gd  — Godot 4.4.1
extends CharacterBody3D

@export var move_speed: float = 3.5
@export var snap_to_8_directions: bool = true

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var frames: SpriteFrames = sprite.sprite_frames

var original_offset: Vector2
var last_dir: String = "S"        # never null
var last_anim: String = ""
var movement_enabled: bool = true

# Mirror left-side directions to reuse right-side animations
const FLIP_DIRS := {"W": true, "NW": true, "SW": true}
const MIRROR_MAP := {"W": "E", "NW": "NE", "SW": "SE"}
const DIRS := ["S","SE","E","NE","N","NW","W","SW"]  # yaw index mapping

func _ready() -> void:
    original_offset = sprite.offset

func set_movement_enabled(enabled: bool) -> void:
    movement_enabled = enabled
    if not enabled:
        velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
    var iv := Input.get_vector("move_left","move_right","move_forward","move_back")

    if movement_enabled and iv.length_squared() > 0.0:
        # Input in XZ (Godot: +X right, -Z forward; iv.y is negative when pressing "forward")
        var dir := Vector3(iv.x, 0.0, iv.y)

        # Face movement direction
        var yaw := atan2(dir.x, dir.z)  # 0 rad faces +Z ("S")
        if snap_to_8_directions:
            var step := PI / 4.0
            yaw = round(yaw / step) * step
        rotation.y = yaw

        last_dir = _yaw_to_dir(rotation.y)

        # Move
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
    var token: String
    if flip:
        token = MIRROR_MAP.get(dir, dir)   # safe lookup
    else:
        token = dir

    var anim := "%s_%s" % [base, token]


    # Robust fallbacks — keeps running even if a clip is missing
    if frames == null or not frames.has_animation(anim):
        var candidates := PackedStringArray()
        if base == "Walk":
            candidates = ["Walk_S","Walk_E","Walk_N","Walk_NE","Walk_SE","Walk"]
        else:
            candidates = ["Idle_S","Idle_E","Idle_N","Idle_NE","Idle_SE","Idle","Walk_S"]
        for c in candidates:
            if frames != null and frames.has_animation(c):
                anim = c
                break

    # Mirror horizontally for W/NW/SW, adjust offset so anchor stays correct
    sprite.flip_h = flip
    sprite.offset = Vector2(-original_offset.x, original_offset.y) if flip else original_offset

    if frames != null and frames.has_animation(anim) and anim != last_anim:
        sprite.play(anim)
        last_anim = anim
