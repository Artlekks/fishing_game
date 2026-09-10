extends CharacterBody3D

@export var move_speed: float = 3.5
@export var camera_reference: Node3D
@export var movement_enabled: bool = true

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D

const DIRS := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]

var last_dir: String = "S"
var last_anim: String = ""

func _physics_process(_delta: float) -> void:
	if not movement_enabled:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var input_vector := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)

	if input_vector.length_squared() == 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		_play_animation("Idle", last_dir)
		move_and_slide()
		return

	var camera_basis := Basis()

	if camera_reference != null:
		camera_basis = camera_reference.global_transform.basis

	var camera_forward := -camera_basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()

	var camera_right := camera_basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()

	var move_direction := (
		camera_right * input_vector.x +
		camera_forward * -input_vector.y
	).normalized()

	var yaw := atan2(move_direction.x, move_direction.z)
	var step := PI / 4.0

	yaw = round(yaw / step) * step

	move_direction.x = sin(yaw)
	move_direction.z = cos(yaw)

	rotation.y = yaw

	var camera_down := camera_basis.z
	camera_down.y = 0.0
	camera_down = camera_down.normalized()

	var screen_x := camera_right.dot(move_direction)
	var screen_y := camera_down.dot(move_direction)
	var screen_angle := atan2(screen_x, screen_y)

	screen_angle = round(screen_angle / step) * step

	var index := wrapi(
		int(round(screen_angle / step)),
		0,
		DIRS.size()
	)

	last_dir = DIRS[index]

	velocity.x = move_direction.x * move_speed
	velocity.z = move_direction.z * move_speed

	_play_animation("Walk", last_dir)

	move_and_slide()


func _play_animation(base_name: String, direction: String) -> void:
	var animation_name := base_name + "_" + direction

	if not sprite.sprite_frames.has_animation(animation_name):
		return

	if animation_name == last_anim:
		return

	sprite.flip_h = false
	sprite.play(animation_name)
	last_anim = animation_name
	
func camera_quarter_turned(direction: int) -> void:
	var steps := -direction * 2
	var index := DIRS.find(last_dir)

	if index == -1:
		index = 0

	index = wrapi(index + steps, 0, DIRS.size())
	last_dir = DIRS[index]

	var input_vector := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)

	if input_vector.length_squared() == 0.0:
		_play_animation("Idle", last_dir)
