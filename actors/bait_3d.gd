extends Node3D

signal hit_water
signal reel_back_finished

@export var max_cast_distance: float = 9
@export var flight_duration: float = 0.5
@export var arc_height: float = 0.9
@export var curve_amount: float = 2.0
@export var reel_blend_speed: float = 4.5
@export var reel_speed: float = 1.6

@onready var debug_line: ImmediateMesh = $DebugLine.mesh

# Internal state
var direction: Vector3
var start_position: Vector3
var target_position: Vector3
var throw_power: float = 1.0
var travel_time: float = 0.0
var is_flying: bool = false
var is_reeling: bool = false
var is_reeling_active: bool = true
var reel_target: Node3D
var reeling_mode: String = "straight" # "straight", "left", "right"
var blended_dir: Vector3 = Vector3.ZERO
var arc_blend_factor: float = 0.0
var reel_elapsed_time: float = 0.0

# ---------------------
# Life cycle
# ---------------------
func _ready():
	visible = false

func _process(delta):
	if is_flying:
		_update_flight(delta)
	elif is_reeling:
		_update_reel(delta)
		reel_elapsed_time += delta

# ---------------------
# Cast
# ---------------------
func start_fly(dir: Vector3, power: float):
	direction = dir.normalized()
	start_position = global_transform.origin
	throw_power = clamp(power, 0.0, 1.0)
	travel_time = 0.0
	is_flying = true
	is_reeling = false
	visible = true

	var distance: float = throw_power * max_cast_distance
	target_position = start_position + direction * distance

func _update_flight(delta: float):
	travel_time += delta
	var t: float = clamp(travel_time / flight_duration, 0.0, 1.0)

	var horizontal: Vector3 = start_position.lerp(target_position, t)
	var vertical: float = arc_height * sin(t * PI) * pow(1.0 - t, 0.5)

	global_transform.origin = horizontal + Vector3.UP * vertical

	if travel_time >= flight_duration:
		emit_signal("hit_water")
		is_flying = false

# ---------------------
# Reel
# ---------------------
func start_reel_back(mode: String, target: Node3D):
	reeling_mode = mode
	reel_target = target
	is_flying = false
	is_reeling = true
	reel_elapsed_time = 0.0
	blended_dir = (reel_target.global_transform.origin - global_transform.origin).normalized()

func _update_reel(delta: float):
	if not is_reeling_active or reel_target == null:
		return

	var to_target: Vector3 = reel_target.global_transform.origin - global_transform.origin
	var dist: float = to_target.length()

	if dist < 0.3:
		queue_free()
		emit_signal("reel_back_finished")
		return

	var base_dir: Vector3 = to_target.normalized()

	# Blend strength based on input mode
	var target_blend: float = 0.0
	var side: int = 0

	match reeling_mode:
		"left":
			target_blend = 1.0
			side = -1
		"right":
			target_blend = 1.0
			side = 1

	# Smooth transition toward curved influence
	arc_blend_factor = move_toward(arc_blend_factor, target_blend, reel_blend_speed * delta)

	var curved_dir: Vector3 = base_dir
	if side != 0:
		var curve_strength: float = clamp(dist / 6.0, 0.2, 1.0)
		curved_dir = _apply_curve(base_dir, side, curve_strength)

	var final_dir: Vector3 = base_dir.lerp(curved_dir, arc_blend_factor).normalized()
	blended_dir = blended_dir.move_toward(final_dir, reel_blend_speed * delta)

	global_translate(blended_dir * reel_speed * delta)

	# Debug
	debug_line.clear_surfaces()
	debug_line.surface_begin(Mesh.PRIMITIVE_LINES)
	debug_line.surface_add_vertex(global_transform.origin)
	debug_line.surface_add_vertex(global_transform.origin + blended_dir * 2.0)
	debug_line.surface_end()

# ---------------------
# Helpers
# ---------------------
func _apply_curve(dir: Vector3, side: int, strength: float = 1.0) -> Vector3:
	var side_vector = Vector3.UP.cross(dir) * side
	return (dir + side_vector * curve_amount * strength).normalized()

func set_reel_speed(speed: float):
	reel_speed = speed
