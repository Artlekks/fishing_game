extends CharacterBody3D

@export var speed = 1

func get_input():
	var input_direction = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	velocity.x = input_direction.x * speed
	velocity.z = input_direction.y * speed

func _physics_process(delta):
	get_input()
	move_and_slide()
