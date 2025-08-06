extends CharacterBody3D

@export var step_distance: float = 0.15
@export var speed_scale: float = 1.5

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var frames: SpriteFrames = sprite.get_sprite_frames()
@onready var camera: Camera3D = get_viewport().get_camera_3d()

var last_dir: String = "S"
var last_anim: String = "Idle"
var flip: bool = false
var original_offset: Vector2

const FLIP_DIRS := ["NW", "W", "SW"]

const DIR_MAP := {
	"NW": "NE", "W": "E", "SW": "SE",
	"NE": "NE", "E": "E", "SE": "SE",
	"N": "N", "S": "S"
}

const DIR_LOOKUP := {
	0: "N", 45: "NE", 90: "E", 135: "SE",
	180: "S", 225: "SW", 270: "W", 315: "NW"
}

func _ready() -> void:
	original_offset = sprite.offset

func _physics_process(_delta: float) -> void:
	var input_vec := _get_input_vector()

	if input_vec != Vector2.ZERO:
		_update_direction(input_vec)
		_move_player(input_vec)
		_play_animation("Walk")
	else:
		velocity = Vector3.ZERO
		_play_animation("Idle")

	move_and_slide()

func _get_input_vector() -> Vector2:
	return Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	).normalized()

func _move_player(input_vec: Vector2) -> void:
	var world_vec = _input_to_world_direction(input_vec)
	var anim_name = "Walk_" + _get_anim_key(last_dir)

	var fps := 5.0
	if frames.has_animation(anim_name):
		fps = frames.get_animation_speed(anim_name)

	var speed = fps * step_distance * speed_scale
	velocity.x = world_vec.x * speed
	velocity.z = world_vec.z * speed

func _update_direction(input_vec: Vector2) -> void:
	var cam_forward = -camera.global_transform.basis.z
	var cam_right = camera.global_transform.basis.x
	var world_dir = (cam_right * input_vec.x + cam_forward * input_vec.y).normalized()

	var angle := fposmod(rad_to_deg(atan2(world_dir.x, world_dir.z)) + 360.0, 360.0)
	var snapped_angle := int(round(angle / 45.0)) * 45 % 360
	last_dir = DIR_LOOKUP.get(snapped_angle, "S")
	flip = last_dir in FLIP_DIRS

func _input_to_world_direction(input_vec: Vector2) -> Vector3:
	var fwd := camera.global_transform.basis.z
	var right := camera.global_transform.basis.x
	return (right * input_vec.x + fwd * input_vec.y).normalized()

func _get_anim_key(dir: String) -> String:
	return DIR_MAP.get(dir, dir)

func _play_animation(base_name: String) -> void:
	var anim_key := base_name + "_" + _get_anim_key(last_dir)
	
	if anim_key != last_anim and frames.has_animation(anim_key):
		sprite.flip_h = flip
		
		if flip:
			sprite.offset = Vector2(-original_offset.x, original_offset.y)
		else:
			sprite.offset = original_offset
		
		sprite.play(anim_key)
		last_anim = anim_key
