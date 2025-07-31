extends Node3D

@export var dot_nodes: Array[NodePath] = []
@export var frame_hold_time: float = 0.1  # Seconds per step (~6fps = 0.166)

var _timer := 0.0
var _frame := 0
var _active := false

func _ready():
	_set_all_dots_visible(false)

func _process(delta):
	if not _active:
		return

	_timer += delta
	if _timer >= frame_hold_time:
		_timer = 0.0
		_frame += 1

		if _frame <= dot_nodes.size():
			# turn on next dot
			for i in range(_frame):
				var dot = get_node(dot_nodes[i])
				dot.visible = true
		else:
			# reset cycle
			_set_all_dots_visible(false)
			_frame = 0

func start_looping():
	_frame = 0
	_timer = 0.0
	_active = true
	_set_all_dots_visible(false)

func stop_looping():
	_active = false
	_set_all_dots_visible(false)

func get_direction_vector() -> Vector3:
	var forward := -global_transform.basis.z
	forward.y = 0
	return forward.normalized()

func _set_all_dots_visible(state: bool):
	for path in dot_nodes:
		var dot = get_node(path)
		if dot:
			dot.visible = state
