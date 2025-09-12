extends Node
class_name DepthMeterGate

@export var caster_path: NodePath
@export var depth_meter_path: NodePath
@export var bait_group: String = "bait"
@export var exit_action: String = "fishing_exit"

@export var appear_time: float = 0.25
@export var disappear_time: float = 0.20

@onready var _caster: Node = get_node_or_null(caster_path)
@onready var _meter: DepthMeter = get_node_or_null(depth_meter_path) as DepthMeter

var _bait: Node3D = null
var _active: bool = false
var _dst_local_pos: Vector2 = Vector2.ZERO
var _dst_global_pos: Vector2 = Vector2.ZERO
var _use_global: bool = false
var _slide: Tween = null
var _reseek_timer: float = 0.0

func _ready() -> void:
	if _meter != null:
		_meter.visible = false

	if not InputMap.has_action(exit_action):
		InputMap.add_action(exit_action)
		var ev: InputEventKey = InputEventKey.new()
		ev.physical_keycode = KEY_I
		InputMap.action_add_event(exit_action, ev)

	if _caster != null:
		if _caster.has_signal("bait_landed") and not _caster.is_connected("bait_landed", Callable(self, "_on_landed")):
			_caster.connect("bait_landed", Callable(self, "_on_landed"))
		if _caster.has_signal("bait_returned") and not _caster.is_connected("bait_returned", Callable(self, "_on_ended")):
			_caster.connect("bait_returned", Callable(self, "_on_ended"))
		if _caster.has_signal("bait_despawned") and not _caster.is_connected("bait_despawned", Callable(self, "_on_ended")):
			_caster.connect("bait_despawned", Callable(self, "_on_ended"))

	set_physics_process(true)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed(exit_action):
		_on_ended()

func _physics_process(dt: float) -> void:
	if not _active or _meter == null:
		return

	# Fallback polling: keep arrow moving even if signals drop once.
	if _bait != null and is_instance_valid(_bait):
		_meter.set_bait_y(_bait.global_position.y)
	else:
		_reseek_timer -= dt
		if _reseek_timer <= 0.0:
			_bait = _pick_bait()
			_connect_bait_depth_signal()
			_reseek_timer = 0.25

func _on_landed(surface_y: float, bottom_y: float, bait_y: float) -> void:
	_active = true

	_bait = _pick_bait()
	_connect_bait_depth_signal()

	if _meter == null:
		return

	# remember editor placement
	var parent_node: Node = _meter.get_parent()
	_use_global = not (parent_node is CanvasItem)
	if _use_global:
		_dst_global_pos = _meter.global_position
	else:
		_dst_local_pos = _meter.position

	# initial configure + place
	_meter.show_with_bounds(surface_y, bottom_y)
	_meter.set_bait_y(bait_y)

	# slide in from the right to saved position
	_kill_slide()
	var vr: Rect2i = get_viewport().get_visible_rect()
	var right_px: float = float(vr.position.x + vr.size.x) + 24.0
	_meter.visible = true

	if _use_global:
		var start_g: Vector2 = Vector2(right_px, _dst_global_pos.y)
		_meter.global_position = start_g
		_slide = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_slide.tween_property(_meter, "global_position", _dst_global_pos, appear_time)
	else:
		var parent_ci: CanvasItem = parent_node as CanvasItem
		var start_g2: Vector2 = Vector2(right_px, parent_ci.to_global(_dst_local_pos).y)
		var start_l: Vector2 = parent_ci.to_local(start_g2)
		_meter.position = start_l
		_slide = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_slide.tween_property(_meter, "position", _dst_local_pos, appear_time)

func _on_ended() -> void:
	_active = false

	if _bait != null and _bait.has_signal("depth_y_changed") and _bait.is_connected("depth_y_changed", Callable(self, "_on_bait_depth_y")):
		_bait.disconnect("depth_y_changed", Callable(self, "_on_bait_depth_y"))
	_bait = null

	if _meter != null:
		_meter.hide_meter()

	# slide out to the right
	_kill_slide()
	var vr: Rect2i = get_viewport().get_visible_rect()
	var right_px: float = float(vr.position.x + vr.size.x) + 24.0

	if _use_global:
		var end_g: Vector2 = Vector2(right_px, _dst_global_pos.y)
		_slide = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_slide.tween_property(_meter, "global_position", end_g, disappear_time)
	else:
		var parent_ci: CanvasItem = (_meter.get_parent() as CanvasItem)
		var end_g2: Vector2 = Vector2(right_px, parent_ci.to_global(_dst_local_pos).y)
		var end_l: Vector2 = parent_ci.to_local(end_g2)
		_slide = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_slide.tween_property(_meter, "position", end_l, disappear_time)

# signal once connected to the bait
func _on_bait_depth_y(y: float) -> void:
	if _active:
		_meter.set_bait_y(y)

# fallback polling in _physics_process
	if _bait != null and is_instance_valid(_bait):
		_meter.set_bait_y(_bait.global_position.y)


func _connect_bait_depth_signal() -> void:
	if _bait == null:
		return
	if _bait.has_signal("depth_y_changed") and not _bait.is_connected("depth_y_changed", Callable(self, "_on_bait_depth_y")):
		_bait.connect("depth_y_changed", Callable(self, "_on_bait_depth_y"))

func _pick_bait() -> Node3D:
	var out: Node3D = null
	var list: Array = get_tree().get_nodes_in_group(bait_group)
	var i: int = 0
	while i < list.size():
		var n: Object = list[i]
		if n is Node3D:
			out = n as Node3D
		i += 1
	return out

func _kill_slide() -> void:
	if _slide != null and _slide.is_valid():
		_slide.kill()
	_slide = null
