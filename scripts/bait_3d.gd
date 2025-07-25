extends Node3D

@onready var sprite := $AnimatedSprite3D

var start_pos: Vector3
var end_pos: Vector3
var t := 0.0
var duration := 0.5  # seconds
var height := 1.5  # peak arc height
var throwing := false

func throw_to(target: Vector3):
	start_pos = global_position
	end_pos = target
	t = 0.0
	throwing = true

func _process(delta):
	if throwing:
		t += delta / duration
		if t >= 1.0:
			t = 1.0
			throwing = false

		# Linear horizontal move
		var flat = start_pos.lerp(end_pos, t)

		# Arc in Y axis (parabola)
		var arc_y = -4 * height * (t - 0.5) * (t - 0.5) + height
		flat.y += arc_y

		global_position = flat
