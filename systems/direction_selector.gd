extends Node3D

@export var dot_nodes: Array[NodePath] = []
var current_index := 4  # Start centered
var active := false

func _ready():
	_update_dot_visibility()
	set_process(false)

func show_selector():
	active = true
	visible = true
	set_process(true)
	_update_dot_visibility()

func hide_selector():
	active = false
	visible = false
	set_process(false)

func _process(_delta):
	if not active:
		return
	if Input.is_action_just_pressed("reeling_left"):
		_move_left()
	elif Input.is_action_just_pressed("reeling_right"):
		_move_right()

func _move_left():
	if current_index > 0:
		current_index -= 1
		_update_dot_visibility()

func _move_right():
	if current_index < dot_nodes.size() - 1:
		current_index += 1
		_update_dot_visibility()

func _update_dot_visibility():
	for i in range(dot_nodes.size()):
		var dot = get_node(dot_nodes[i])
		dot.modulate.a = 1.0 if i == current_index else 0.3

func get_direction_vector() -> Vector3:
	var dot = get_node(dot_nodes[current_index])
	return (dot.global_transform.origin - global_transform.origin).normalized()
