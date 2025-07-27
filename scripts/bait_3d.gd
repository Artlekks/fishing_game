extends Node3D

signal bait_landed
signal bait_despawned

var reeling_target: Vector3
var reeling = false
var reeling_speed = 3.0

func throw_to(end_pos: Vector3, height := 1.0, duration := 0.6):
	var start = global_position
	var tween = create_tween()
	
	tween.tween_method(func(t):
		var pos = Vector3()
		pos.x = lerp(start.x, end_pos.x, t)
		pos.y = lerp(start.y, end_pos.y, t) + sin(t * PI) * height
		pos.z = lerp(start.z, end_pos.z, t)

		global_position = pos
	, 0.0, 1.0, duration)

	await tween.finished
	emit_signal("bait_landed")

func reel_to(target: Vector3):
	reeling_target = target
	reeling = true

func stop_reeling():
	reeling = false

func _process(delta):
	if reeling:
		var direction = (reeling_target - global_position).normalized()
		var step = reeling_speed * delta
		var distance = global_position.distance_to(reeling_target)

		if distance > step:
			global_position += direction * step
		else:
			global_position = reeling_target
			reeling = false
			emit_signal("bait_despawned")
			queue_free()
