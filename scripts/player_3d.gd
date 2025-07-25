extends Node3D

@onready var billboard := $Billboard
@onready var sprite := $Billboard/AnimatedSprite3D

func _ready():
	sprite.play("prep_fishing")  # Your animation name here

func _process(_delta):
	var cam = get_viewport().get_camera_3d()
	if cam:
		billboard.look_at(cam.global_position, Vector3.UP)
		billboard.rotate_y(PI)  # Needed because sprite is backward by default
