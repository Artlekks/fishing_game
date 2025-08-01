extends Node3D

signal hit_water
signal reel_back_finished

@export var gravity := -7
@export var flight_duration := 0.65
@export var curve_height := 1.5
@export var curve_amount := 2.5  # how wide the arc is when reeling
@export var reel_blend_speed := 4.5
@onready var debug_line: ImmediateMesh = $DebugLine.mesh
@export var cast_speed := 6  # how fast bait moves (units/sec)
@export var arc_peak_scale := 0.3  # how tall the arc is (0.3–0.6 is good)
@export var distance_multiplier := 6.0  # how far bait goes per unit of power

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
var blended_dir: Vector3 = Vector3.ZERO  # current smooth direction
var throw_power: float = 1.0  # default fallback value

func _ready():
	visible = false

func start_fly(dir: Vector3, power: float):
	direction = dir.normalized()
	start_position = global_transform.origin
	throw_power = power
	travel_time = 0.0
	is_flying = true
	is_reeling = false
	visible = true


func start_reel_back(mode: String, target: Node3D):
	reeling_mode = mode
	reel_target = target
	is_flying = false
	is_reeling = true
	blended_dir = (reel_target.global_transform.origin - global_transform.origin).normalized()


func _process(delta):
	if is_flying:
		_update_flight(delta)
	elif is_reeling:
		_update_reel(delta)

func _update_flight(delta):
	travel_time += delta
	var t := travel_time / flight_duration
	if t > 1.0:
		t = 1.0

	var distance = throw_power * distance_multiplier
	var horizontal = direction * distance * t

	var peak_height = arc_peak_scale * distance
	var vertical = peak_height * sin(PI * t)

	global_transform.origin = start_position + horizontal + Vector3.UP * vertical

	if travel_time >= flight_duration:
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

	var desired_dir = to_target.normalized()

	match reeling_mode:
		"left":
			desired_dir = _apply_curve(desired_dir, -1, clamp(dist / 5.0, 0.3, 1.0))
		"right":
			desired_dir = _apply_curve(desired_dir, 1, clamp(dist / 5.0, 0.3, 1.0))
		_:
			pass  # straight

	# ✅ Ease into curved direction over time — this is key
	blended_dir = blended_dir.move_toward(desired_dir, reel_blend_speed * delta)

	global_translate(blended_dir.normalized() * reel_speed * delta)

	# Debug line
	debug_line.clear_surfaces()
	debug_line.surface_begin(Mesh.PRIMITIVE_LINES)
	debug_line.surface_add_vertex(global_transform.origin)
	debug_line.surface_add_vertex(global_transform.origin + blended_dir * 2.0)
	debug_line.surface_end()


func _apply_curve(dir: Vector3, side: int, strength: float = 1.0) -> Vector3:
	var side_vector = Vector3.UP.cross(dir) * side
	var curve_dir = (dir + side_vector * 2 * strength).normalized()
	return curve_dir

	
func set_reel_speed(speed: float):
	reel_speed = speed
