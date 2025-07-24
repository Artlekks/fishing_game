extends Node2D

signal bait_landed

func throw_to(target: Vector2):
	var duration := 0.6
	var height := -20  # arc height

	var start := global_position
	var end := target

	var tween := create_tween()

	tween.tween_method(func(t):
		position = Vector2(
			lerp(start.x, end.x, t),
			lerp(start.y, end.y, t) + sin(t * PI) * height
		)
	, 0.0, 1.0, duration)

	await tween.finished
	emit_signal("bait_landed")
