extends Node3D

@onready var player := $GroundAnchor/Player3D
@onready var cam := $Pivot/Camera3D

func _unhandled_input(event):
	if event.is_action_pressed("reset_game"):
		reset_game()

func reset_game():
	print("🔁 World resetting...")

	# Fully reset player
	player.call_deferred("_reset_game")
	
func _ready():
	# Optionally pass camera to player if billboard logic needs it
	if player.has_method("set_camera"):
		player.set_camera(cam)
