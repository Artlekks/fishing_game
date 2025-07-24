extends Area2D

signal bait_landed

var reeling_target: Vector2
var reeling = false
var reeling_speed = 30.0 # pixels per second

func _ready():
	connect("area_entered", Callable(self, "_on_area_entered"))

func throw_to(target: Vector2):
	var duration := 0.6
	var height := -60
	var start := global_position
	var end := target
	var tween := create_tween()

	tween.tween_method(func(t):
		position = Vector2(
			lerp(start.x, end.x, t),
			lerp(start.y, end.y, t) + sin(t * 1.2 * PI) * height
		)
	, 0.0, 1.0, duration)

	await tween.finished
	emit_signal("bait_landed")


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
			queue_free()


func reel_to(target: Vector2):
	reeling_target = target
	reeling = true

func stop_reeling():
	reeling = false
	
func _on_area_entered(area):
	if area.name == "DespawnZone":
		queue_free()
