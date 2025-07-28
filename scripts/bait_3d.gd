extends Node3D

signal bait_landed
signal bait_despawned

@export var reeling_speed := 0.8

# Throw arc state
var _throwing := false
var _throw_elapsed := 0.0
var _throw_duration := 0.6
var _throw_height := 1.5
var _throw_start: Vector3
var _throw_end: Vector3

# Reeling state
var reeling := false
var reeling_target: Vector3

func _ready():
	$ReelDetector.body_entered.connect(_on_reel_detector_body_entered)

func _on_reel_detector_body_entered(body: Node) -> void:
	if body.name == "Killzone":
		global_position = body.global_position  # Snap to Killzone center (or offset manually)
		print("🎯 Bait entered Killzone — despawning.")
		emit_signal("bait_despawned")
		queue_free()
		
		print("⚠ ENTERED:", body.name)


func throw_to(end_pos: Vector3, height := 1.5, duration := 0.6):
	_throw_start = global_position
	_throw_end = end_pos
	_throw_duration = duration
	_throw_height = height
	_throw_elapsed = 0.0
	_throwing = true

func reel_to(target: Vector3):
	reeling_target = target
	reeling = true

func stop_reeling():
	reeling = false

func _process(delta):
	if _throwing:
		_throw_elapsed += delta
		var t = clamp(_throw_elapsed / _throw_duration, 0.0, 1.0)

		var pos = Vector3()
		pos.x = lerp(_throw_start.x, _throw_end.x, t)
		pos.y = lerp(_throw_start.y, _throw_end.y, t) + sin(t * PI) * _throw_height
		pos.z = lerp(_throw_start.z, _throw_end.z, t)
		global_position = pos

		if t >= 1.0:
			_throwing = false
			emit_signal("bait_landed")

	elif reeling:
		var direction = reeling_target - global_position
		var distance = direction.length()

		if distance > 0.01:
			var move = direction.normalized() * reeling_speed * delta
			global_position += move
			
		print("🎣 Bait pos:", global_position, "→ target:", reeling_target)
		
		if reeling and (global_position - reeling_target).length() < 0.1:
			print("💥 Failsafe despawn")
			emit_signal("bait_despawned")
			queue_free()
