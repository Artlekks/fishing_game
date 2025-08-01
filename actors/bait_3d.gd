extends Node3D

signal hit_water
signal reel_back_finished

@export var gravity := -9.8
@export var flight_duration := 1.2
@export var curve_height := 2.5
@export var curve_amount := 3.0  # how wide the arc is when reeling

var velocity: Vector3
var direction: Vector3
var travel_time := 0.0
var total_time := 0.0
var is_flying := false
var is_reeling := false
var reeling_mode := "straight"  # "straight", "left", "right"
var start_position: Vector3
var reel_target: Node3D  # assigned by controller
var reel_speed := 1.6  # default speed, slower by default
var is_reeling_active := true  # controlled by controller

func _ready():
	visible = false

func start_fly(dir: Vector3, power: float):
	direction = dir.normalized()
	start_position = global_transform.origin
	total_time = flight_duration * power
	travel_time = 0.0
	is_flying = true
	is_reeling = false
	visible = true

func start_reel_back(mode: String, target: Node3D):
	reeling_mode = mode
	reel_target = target
	is_flying = false
	is_reeling = true

func _process(delta):
	if is_flying:
		_update_flight(delta)
	elif is_reeling:
		_update_reel(delta)

func _update_flight(delta):
	travel_time += delta
	var t := travel_time / total_time
	if t > 1.0:
		t = 1.0

	var horizontal = direction * t * total_time * 5.0
	var vertical = curve_height * 4 * (t - t * t)

	global_transform.origin = start_position + horizontal + Vector3.UP * vertical

	if travel_time >= total_time:
		emit_signal("hit_water")
		is_flying = false

func _update_reel(delta):
	if not is_reeling_active or reel_target == null:
		return

	var to_target = reel_target.global_transform.origin - global_transform.origin
	var dist = to_target.length()

	if dist < 0.3:
		queue_free()
		emit_signal("reel_back_finished")
		return

	var move_dir = to_target.normalized()

	match reeling_mode:
		"left":
			move_dir = _apply_curve(move_dir, -1, clamp(dist / 5.0, 0.3, 1.0))
		"right":
			move_dir = _apply_curve(move_dir, 1, clamp(dist / 5.0, 0.3, 1.0))

		_:
			pass  # straight

	global_translate(move_dir * reel_speed * delta)
	print("Mode:", reeling_mode, "Dir:", move_dir)


func _apply_curve(dir: Vector3, side: int, strength: float = 1.0) -> Vector3:
	var side_vector = Vector3.UP.cross(dir) * side
	var curve_dir = (dir + side_vector * 2 * strength).normalized()
	return curve_dir

	
func set_reel_speed(speed: float):
	reel_speed = speed
