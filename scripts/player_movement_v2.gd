extends CharacterBody3D

@export var speed: float = 1.0

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D

var _last_dir2 := Vector2(0, 1)   # default facing North (for idle)
var _current_anim: StringName = ""

# Only define the base keys (E, NE, N, SE, S).
# W, NW, SW are mirrored versions of these.
const _OCTANT_KEYS := ["E","NE","N","NW","W","SW","S","SE"]

func _physics_process(_dt: float) -> void:
	# 1) INPUT (XZ plane)
	var dir := Vector3.ZERO
	if Input.is_action_pressed("move_right"):
		dir.x += 1.0
	if Input.is_action_pressed("move_left"):
		dir.x -= 1.0
	if Input.is_action_pressed("move_back"):
		dir.z += 1.0
	if Input.is_action_pressed("move_forward"):
		dir.z -= 1.0

	if dir != Vector3.ZERO:
		dir = dir.normalized()

	# 2) MOVEMENT
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()

	# 3) ANIMATION
	var dir2 := Vector2(dir.x, -dir.z)
	if dir2.length_squared() > 0.0001:
		_last_dir2 = dir2

	var key := _octant_key_from_vec(_last_dir2)  # N, NE, E, SE, S, SW, W, NW
	var next_anim := ("Walk_" if dir != Vector3.ZERO else "Idle_") + key
	_play_if_changed(next_anim)

func _octant_key_from_vec(v: Vector2) -> String:
	var angle := atan2(v.y, v.x)
	var step := PI / 4.0
	var idx := int(round(angle / step)) % 8
	if idx < 0: idx += 8
	return _OCTANT_KEYS[idx]

func _play_if_changed(name: StringName) -> void:
	if name == _current_anim:
		return
	_current_anim = name

	var flip_h := false
	var anim_to_play := name

	# Handle mirrored directions
	match name:
		"Walk_W":
			anim_to_play = "Walk_E"
			flip_h = true
		"Walk_NW":
			anim_to_play = "Walk_NE"
			flip_h = true
		"Walk_SW":
			anim_to_play = "Walk_SE"
			flip_h = true
		"Idle_W":
			anim_to_play = "Idle_E"
			flip_h = true
		"Idle_NW":
			anim_to_play = "Idle_NE"
			flip_h = true
		"Idle_SW":
			anim_to_play = "Idle_SE"
			flip_h = true

	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_to_play):
		sprite.play(anim_to_play)
		sprite.flip_h = flip_h
