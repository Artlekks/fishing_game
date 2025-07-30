extends Node3D

@export var dot_nodes: Array[NodePath] = []
@export var loop_delay: float = 0.05  # seconds between dots
@export var loop_pause: float = 0.2   # pause after all dots visible before reset

var current_index := 4
var active := false
var loop_mode := false

var loop_timer := 0.0
var dot_show_index := 0
var pause_timer := 0.0
var showing_dots := true

func _ready():
    set_process(false)
    _reset_dots()

func start_looping_animation():
    active = false
    loop_mode = true
    dot_show_index = 0
    loop_timer = 0.0
    pause_timer = 0.0
    showing_dots = true
    _reset_dots()
    visible = true
    set_process(true)

func stop_looping():
    loop_mode = false
    active = true
    _update_dot_visibility()

func hide_selector():
    loop_mode = false
    active = false
    set_process(false)
    _reset_dots()
    visible = false

func _process(delta):
    if loop_mode:
        if showing_dots:
            loop_timer += delta
            if loop_timer >= loop_delay:
                loop_timer = 0.0
                dot_show_index += 1
                _update_dot_loop()
        else:
            pause_timer += delta
            if pause_timer >= loop_pause:
                pause_timer = 0.0
                dot_show_index = 0
                showing_dots = true
                _reset_dots()
    elif active:
        if Input.is_action_just_pressed("reeling_left"):
            _move_left()
        elif Input.is_action_just_pressed("reeling_right"):
            _move_right()

func _update_dot_loop():
    if dot_show_index <= dot_nodes.size():
        for i in range(dot_nodes.size()):
            var dot = get_node(dot_nodes[i])
            dot.visible = i <= dot_show_index
    else:
        showing_dots = false
        for path in dot_nodes:
            var dot = get_node(path)
            dot.visible = false

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
        dot.visible = true
        var color = dot.modulate
        color.a = 1.0 if i == current_index else 0.3
        dot.modulate = color

func _reset_dots():
    for path in dot_nodes:
        var dot = get_node(path)
        dot.visible = false
        dot.modulate.a = 1.0

func get_direction_vector() -> Vector3:
    if dot_nodes.is_empty():
        return Vector3.FORWARD
    var dot = get_node(dot_nodes[current_index])
    return (dot.global_transform.origin - global_transform.origin).normalized()
