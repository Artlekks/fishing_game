# Player.gd — Godot 4.4.1
# 8-way movement + octant animation for AnimatedSprite3D
extends CharacterBody3D

@export var speed: float = 4.0
@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D

var _last_dir2: Vector2 = Vector2(0, 1) # default face North
var _current_anim: StringName = &""

# Octant order: [E, NE, N, NW, W, SW, S, SE]
const _WALK_NAMES: Array[StringName] = [
	&"Walk_E",  &"Walk_NE", &"Walk_N",  &"Walk_NE",
	&"Walk_E",  &"Walk_SE", &"Walk_S",  &"Walk_SE"
]
const _IDLE_NAMES: Array[StringName] = [
	&"Idle_E",  &"Idle_NE", &"Idle_N",  &"Idle_NE",
	&"Idle_E",  &"Idle_SE", &"Idle_S",  &"Idle_SE"
]
const _FLIP_H: Array[bool] = [
	false, false, false,  true,
	true,  true,  false,  false
]

func _ready() -> void:
	if sprite == null or sprite.sprite_frames == null:
		push_error("AnimatedSprite3D or SpriteFrames missing.")
		return
	for anim in [&"Walk_E",&"Walk_NE",&"Walk_N",&"Walk_SE",&"Walk_S",
				 &"Idle_E",&"Idle_NE",&"Idle_N",&"Idle_SE",&"Idle_S"]:
		if not sprite.sprite_frames.has_animation(anim):
			push_error("Missing SpriteFrames animation: %s" % anim)

	sprite.flip_h = false
	_current_anim = &"Idle_N"
	sprite.play(_current_anim)

func _physics_process(_dt: float) -> void:
	# Input: y = back - forward (W gives -1)
	var v2: Vector2 = Input.get_vector(&"move_left", &"move_right",
									   &"move_forward", &"move_back")
	var moving := v2.length_squared() > 0.0
	if moving:
		v2 = v2.normalized()

	# Movement: forward (W) should be -Z  → use v2.y (no minus)
	velocity.x = v2.x * speed
	velocity.z = v2.y * speed
	move_and_slide()

	# Facing: make North correspond to forward (-Z) → flip Y
	if moving:
		_last_dir2 = Vector2(v2.x, -v2.y)

	var oct := _octant_index(_last_dir2) # 0..7
	var next_anim: StringName = (_WALK_NAMES[oct] if moving else _IDLE_NAMES[oct])
	var flip_h: bool = _FLIP_H[oct]
	_play_if_changed(next_anim, flip_h)

func _octant_index(v: Vector2) -> int:
	var angle := atan2(v.y, v.x)       # radians
	var step := PI / 4.0               # 45°
	var idx := int(round(angle / step)) % 8
	if idx < 0:
		idx += 8
	return idx

func _play_if_changed(anim_name: StringName, flip_h: bool) -> void:
	if anim_name == _current_anim and sprite.flip_h == flip_h:
		return
	_current_anim = anim_name
	sprite.flip_h = flip_h
	sprite.play(anim_name)
