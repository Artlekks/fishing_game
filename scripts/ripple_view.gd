extends Node3D


@onready var ripple_sprite: AnimatedSprite3D = $RippleSprite

@export var surface_offset: float = 0.02


var follow_target: Node3D = null
var surface_y: float = 0.0
var active: bool = false


func _ready() -> void:
	top_level = true
	visible = false
	set_process(false)


func configure(
	target: Node3D,
	water_surface_y: float
) -> void:
	follow_target = target
	surface_y = water_surface_y

	_update_position()


func show_ripple() -> void:
	if not is_instance_valid(follow_target):
		return

	active = true
	visible = true
	set_process(true)

	_update_position()
	ripple_sprite.play(&"Ripple")


func hide_ripple() -> void:
	active = false
	visible = false
	set_process(false)

	ripple_sprite.stop()


func _process(_delta: float) -> void:
	if not active:
		return

	if not is_instance_valid(follow_target):
		hide_ripple()
		return

	_update_position()


func _update_position() -> void:
	if not is_instance_valid(follow_target):
		return

	global_position = Vector3(
		follow_target.global_position.x,
		surface_y + surface_offset,
		follow_target.global_position.z
	)
