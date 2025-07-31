extends Node3D

signal hit_water

@export var gravity := -9.8
@export var flight_duration := 1.2  # seconds to reach peak arc
@export var curve_height := 2.5

var velocity: Vector3
var direction: Vector3
var travel_time := 0.0
var total_time := 0.0
var is_flying := false
var start_position: Vector3

func _ready():
	visible = false  # hidden until launch

func start_fly(dir: Vector3, power: float):
	direction = dir.normalized()
	start_position = global_transform.origin
	total_time = flight_duration * power
	travel_time = 0.0
	is_flying = true
	visible = true

func _process(delta):
	if not is_flying:
		return

	travel_time += delta
	var t := travel_time / total_time
	if t > 1.0:
		t = 1.0

	# Simulate parabolic arc
	var horizontal = direction * t * total_time * 5.0
	var vertical = curve_height * 4 * (t - t * t)  # parabola peak at t=0.5

	global_transform.origin = start_position + horizontal + Vector3.UP * vertical

	if travel_time >= total_time:
		emit_signal("hit_water")
		is_flying = false
