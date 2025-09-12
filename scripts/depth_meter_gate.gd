extends Node

@export var caster_path: NodePath
@export var depth_meter_path: NodePath
@export var exit_action: String = "fishing_exit"

# Slide to match your power bar
@export var appear_time: float = 0.20
@export var disappear_time: float = 0.18
@export var slide_dx_px: float = 260.0  # start this many pixels to the right

var _caster: Node = null
var _meter: Control = null
var _bait: Node3D = null

var _dst_local_pos: Vector2 = Vector2.ZERO
var _slide: Tween = null
var _active: bool = false

func _ready() -> void:
	_caster = get_node_or_null(caster_path)
	_meter  = get_node_or_null(depth_meter_path) as Control
	if _meter != null:
		_dst_local_pos = _meter.position
		_meter.visible = false

	# signals
	if _caster != null:
		if _caster.has_signal("bait_landed"):
			_caster.connect("bait_landed", Callable(self, "_on_landed"))
		if _caster.has_signal("bait_returned"):
			_caster.connect("bait_returned", Callable(self, "_on_ended"))
		if _caster.has_signal("fishing_ended"):
			_caster.connect("fishing_ended", Callable(self, "_on_ended"))
		if _caster.has_signal("bait_despawned"):
			_caster.connect("bait_despawned", Callable(self, "_on_ended"))

	# ensure I is mapped for exit (optional safety)
	if not InputMap.has_action(exit_action):
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_I
		InputMap.add_action(exit_action)
		InputMap.action_add_event(exit_action, ev)

	set_process(true)

func _process(_dt: float) -> void:
	if _active and Input.is_action_just_pressed(exit_action):
		_on_ended()

func _on_landed(sy: float, by: float, _yy: float) -> void:
	_active = true
	_pick_bait()
	if _meter != null:
		_meter.position = _dst_local_pos + Vector2(slide_dx_px, 0.0)
		_meter.show_with_bounds(sy, by)

		_kill_slide()
		_slide = create_tween()
		_slide.set_trans(Tween.TRANS_SINE)
		_slide.set_ease(Tween.EASE_OUT)
		_slide.tween_property(_meter, "position", _dst_local_pos, appear_time)

func _on_ended() -> void:
	_active = false
	if _bait != null and _bait.has_signal("depth_y_changed"):
		_bait.disconnect("depth_y_changed", Callable(self, "_on_bait_depth_y"))
	_bait = null

	if _meter != null:
		_kill_slide()
		var off: Vector2 = _dst_local_pos + Vector2(slide_dx_px, 0.0)
		_slide = create_tween()
		_slide.set_trans(Tween.TRANS_SINE)
		_slide.set_ease(Tween.EASE_IN)
		_slide.tween_property(_meter, "position", off, disappear_time)
		_slide.tween_callback(Callable(_meter, "hide_meter"))

# ---- helpers ----
func _pick_bait() -> void:
	_bait = null

	# get_nodes_in_group() returns Array[Node]
	var list: Array[Node] = get_tree().get_nodes_in_group("bait")

	for i in range(list.size()):
		var n: Node = list[i]
		if n is Node3D:
			_bait = n as Node3D

	if _bait != null and _bait.has_signal("depth_y_changed"):
		if not _bait.is_connected("depth_y_changed", Callable(self, "_on_bait_depth_y")):
			_bait.connect("depth_y_changed", Callable(self, "_on_bait_depth_y"))

func _on_bait_depth_y(y: float) -> void:
	if _meter != null:
		_meter.set_bait_y(y)

func _kill_slide() -> void:
	if _slide != null and _slide.is_valid():
		_slide.kill()
	_slide = null
