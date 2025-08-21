extends CharacterBody3D

@export var speed: float = 4.0
@export var accel: float = 12.0
@export var friction: float = 10.0
@export var camera: Camera3D    # leave null for world-aligned controls

const A_LEFT := "move_left"
const A_RIGHT := "move_right"
const A_FWD := "move_forward"
const A_BACK := "move_back"

func _physics_process(delta: float) -> void:
	# 1) Read input as Vector2 (normalized by Godot).
	var in2 := Input.get_vector(A_LEFT, A_RIGHT, A_FWD, A_BACK)

	# 2) Build desired 3D direction (camera-relative if provided).
	var dir3 := Vector3.ZERO
	if in2 != Vector2.ZERO:
		if camera:
			var f := -camera.global_transform.basis.z   # forward
			var r :=  camera.global_transform.basis.x   # right
			dir3 = (r * in2.x + f * in2.y).normalized()
		else:
			dir3 = Vector3(in2.x, 0.0, in2.y)

	# 3) Smooth acceleration / deceleration on the XZ plane.
	if dir3 != Vector3.ZERO:
		var target: Vector2 = Vector2(dir3.x, dir3.z) * speed
		var current: Vector2 = Vector2(velocity.x, velocity.z)
		var new_vel: Vector2 = current.lerp(target, accel * delta)
		velocity.x = new_vel.x
		velocity.z = new_vel.y
	else:
		var current: Vector2 = Vector2(velocity.x, velocity.z)
		var new_vel: Vector2 = current.move_toward(Vector2.ZERO, friction * delta)
		velocity.x = new_vel.x
		velocity.z = new_vel.y
