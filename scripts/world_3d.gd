extends Node3D

@onready var player := $GroundAnchor/Player3D
@onready var cam := $Pivot/Camera3D

func _ready():
	# Optionally pass camera to player if billboard logic needs it
	if player.has_method("set_camera"):
		player.set_camera(cam)
