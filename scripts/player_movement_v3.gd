# Player.gd — attach to CharacterBody3D
# Responsibility: 8-way movement on XZ + AnimatedSprite3D octant playback (no camera/fishing)

extends CharacterBody3D

# --- Tuning ---
@export var speed: float = 4.0                     # units/sec on XZ
@export var start_facing_octant: int = 2           # 0..7 -> [E,NE,N,NW,W,SW,S,SE]; default N

# --- Node deps ---
@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D

# --- Input actions (use StringName to avoid per-frame allocations) ---
const ACT_LEFT:  StringName = &"move_left"
const ACT_RIGHT: StringName = &"move_right"
const ACT_FWD:   StringName = &"move_forward"
const ACT_BACK:  StringName = &"move_back"

# --- Visual state (no physics writes here) ---
var _last_dir2: Vector2        # remembered facing on XZ as 2D
var _current_anim: StringName = &""

# Octant order produced by _octant_index(): [E, NE, N, NW, W, SW, S, SE]
const _WALK: Array[StringName] = [
	&"Walk_E",  &"Walk_NE", &"Walk_N",  &"Walk_NE",
	&"Walk_E",  &"Walk_SE", &"Walk_S",  &"Walk_SE"
]
const _IDLE: Array[StringName] = [
	&"Idle_E",  &"Idle_NE", &"Idle_N",  &"Idle_NE",
	&"Idle_E",  &"Idle_SE", &"Idle_S",  &"Idle_SE"
]
# Mirror flags for the 8 octants (W/NW/SW mirror their eastern counterparts)
const _FLIP_H: Array[bool] = [
	false, false, false,  true,
	true,  true,  false,  false
]

func _ready() -> void:
	# ---- Fail-fast validation per Godot docs patterns ----
	if sprite == null:
		push_error("Player.gd: Missing child AnimatedSprite3D.")
		return
	var sf := sprite.sprite_frames
	if sf == null:
		push_error("Player.gd: AnimatedSprite3D lacks a SpriteFrames resource.")
		return

	for anim in [&"Walk_E",&"Walk_NE",&"Walk_N",&"Walk_SE",&"Walk_S",
				 &"Idle_E",&"Idle_NE",&"Idle_N",&"Idle_SE",&"Idle_S"]:
		if not sf.has_animation(anim):
			push_error("Player.gd: Missing SpriteFrames animation: %s" % anim)

	# Deterministic startup pose (face the chosen octant’s idle)
	_last_dir2 = _octant_dir2(start_facing_octant)
	sprite.flip_h = _FLIP_H[start_facing_octant]
	_current_anim = _IDLE[start_facing_octant]
	sprite.play(_current_anim)

func _physics_process(_dt: float) -> void:
	# 1) INPUT (canonical): v2.y = back - forward, so W => -1
	var v2 := Input.get_vector(ACT_LEFT, ACT_RIGHT, ACT_FWD, ACT_BACK)
	var moving := v2.length_squared() > 0.0
	if moving:
		v2 = v2.normalized()

	# 2) MOVEMENT: forward (-Z) uses v2.y directly (no minus), per docs
	velocity.x = v2.x * speed
	velocity.z = v2.y * speed
	move_and_slide()

	# 3) VISUALS: project to XZ as 2D where North = forward(-Z) => flip Y
	if moving:
		_last_dir2 = Vector2(v2.x, -v2.y)

	var oct := _octant_index(_last_dir2)              # 0..7
	var next := (_WALK[oct] if moving else _IDLE[oct])
	var flip := _FLIP_H[oct]
	_play_if_changed(next, flip)

# --- Helpers (pure) ---

func _octant_index(v: Vector2) -> int:
	# Map atan2 to nearest 45° sector; stable index 0..7 (E..SE).
	# Using round keeps direction snappy for animation selection.
	var angle := atan2(v.y, v.x)      # radians
	var step := PI / 4.0              # 45°
	var idx := int(round(angle / step)) % 8
	if idx < 0:
		idx += 8
	return idx

func _octant_dir2(idx: int) -> Vector2:
	# Return a unit vector roughly pointing to the octant center (for startup idle)
	match idx & 7:
		0: return Vector2(1, 0)        # E
		1: return Vector2(1, 1).normalized()  # NE
		2: return Vector2(0, 1)        # N
		3: return Vector2(-1, 1).normalized() # NW
		4: return Vector2(-1, 0)       # W
		5: return Vector2(-1, -1).normalized()# SW
		6: return Vector2(0, -1)       # S
		_: return Vector2(1, -1).normalized() # SE

func _play_if_changed(anim_name: StringName, flip_h: bool) -> void:
	# Avoid redundant state churn; per docs, play() is cheap but don’t spam it.
	if anim_name == _current_anim and sprite.flip_h == flip_h:
		return
	_current_anim = anim_name
	sprite.flip_h = flip_h
	sprite.play(anim_name)
