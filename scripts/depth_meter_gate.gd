extends Node
class_name DepthMeterGate

@export var caster_path: NodePath                 # BaitCaster
@export var depth_meter_path: NodePath            # UI/DepthMeter (Control)
@export var power_meter_path: NodePath            # UI/PowerMeter (CanvasLayer)
@export var bait_group: String = "bait"
@export var exit_action: String = "fishing_exit"
@export var use_editor_position: bool = true      # keep your manual placement

# Slide timing (we’ll copy from PowerMeter if it exposes getters)
@export var appear_time: float = 0.25
@export var disappear_time: float = 0.20

@onready var _caster: Node = get_node_or_null(caster_path)
@onready var _meter: Control = get_node_or_null(depth_meter_path) as Control
@onready var _power_meter: Node = get_node_or_null(power_meter_path)

var _bait: Node = null
var _sy: float = 0.0
var _by: float = 0.0
var _yy: float = 0.0
var _active: bool = false

# Remember editor placement
var _use_global: bool = false                     # true if parent is not CanvasItem (e.g. CanvasLayer)
var _dst_local_pos: Vector2 = Vector2.ZERO
var _dst_global_pos: Vector2 = Vector2.ZERO

var _slide: Tween = null

func _ready() -> void:
	# Hide in exploration
	if _meter != null:
		_meter.visible = false

	# Map I -> exit if not present
	if not InputMap.has_action(exit_action):
		InputMap.add_action(exit_action)
		var ev: InputEventKey = InputEventKey.new()
		ev.physical_keycode = KEY_I
		InputMap.action_add_event(exit_action, ev)

	_copy_times_from_power_meter()

	if _caster != null:
		if _caster.has_signal("bait_landed") and not _caster.is_connected("bait_landed", Callable(self, "_on_landed")):
			_caster.connect("bait_landed", Callable(self, "_on_landed"))
		if _caster.has_signal("bait_returned") and not _caster.is_connected("bait_returned", Callable(self, "_on_ended")):
			_caster.connect("bait_returned", Callable(self, "_on_ended"))
		if _caster.has_signal("bait_despawned") and not _caster.is_connected("bait_despawned", Callable(self, "_on_ended")):
			_caster.connect("bait_despawned", Callable(self, "_on_ended"))

	set_process(true)

func _copy_times_from_power_meter() -> void:
	if _power_meter == null:
		return
	# Add these tiny getters in power_meter.gd (see note below).
	if _power_meter.has_method("get_appear_time"):
		appear_time = float(_power_meter.call("get_appear_time"))
	if _power_meter.has_method("get_disappear_time"):
		disappear_time = float(_power_meter.call("get_disappear_time"))

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed(exit_action):
		_on_ended()

func _process(_dt: float) -> void:
	if not _active or _meter == null:
		return
	if not is_instance_valid(_bait):
		_refresh_bait()
		return
	if _meter.has_method("set_bait_y") and _bait is Node3D:
		var y: float = (_bait as Node3D).global_position.y
		_meter.call("set_bait_y", y)

func _on_landed(sy: float, by: float, yy: float) -> void:
	_active = true
	_sy = sy
	_by = by
	_yy = yy
	_refresh_bait()
	if _meter == null:
		return

	# decide coord space
	var parent_node: Node = _meter.get_parent()
	_use_global = not (parent_node is CanvasItem)

	# remember exact editor spot
	if _use_global:
		_dst_global_pos = _meter.global_position
	else:
		_dst_local_pos = _meter.position

	# configure widget (this also enables the strip + arrow)
	if _meter.has_method("show_with_bounds"):
		_meter.call("show_with_bounds", _sy, _by)
	if _meter.has_method("set_bait_y"):
		_meter.call("set_bait_y", _yy)

	# ---- slide IN from the right, using the DESTINATION Y ----
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
		var start_g2: Vector2 = Vector2(right_px, _meter.get_global_position().y)
		# IMPORTANT: use destination Y so direction is right -> left
		start_g2.y = parent_ci.to_global(_dst_local_pos).y
		var start_l: Vector2 = parent_ci.to_local(start_g2)
		_meter.position = start_l
		_slide = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_slide.tween_property(_meter, "position", _dst_local_pos, appear_time)

func _on_ended() -> void:
	_active = false
	_bait = null
	if _meter == null:
		return

	# ---- slide OUT to the right, using the DESTINATION Y ----
	_kill_slide()
	var vr: Rect2i = get_viewport().get_visible_rect()
	var right_px: float = float(vr.position.x + vr.size.x) + 24.0

	if _use_global:
		var end_g: Vector2 = Vector2(right_px, _dst_global_pos.y)
		_slide = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_slide.tween_property(_meter, "global_position", end_g, disappear_time)
		_slide.tween_callback(Callable(self, "_hide_meter_global"))
	else:
		var parent_ci: CanvasItem = (_meter.get_parent() as CanvasItem)
		var end_g2: Vector2 = Vector2(right_px, parent_ci.to_global(_dst_local_pos).y)
		var end_l: Vector2 = parent_ci.to_local(end_g2)
		_slide = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_slide.tween_property(_meter, "position", end_l, disappear_time)
		_slide.tween_callback(Callable(self, "_hide_meter_local"))

func _hide_meter_global() -> void:
	if _meter != null:
		_meter.visible = false
		_meter.global_position = _dst_global_pos

func _hide_meter_local() -> void:
	if _meter != null:
		_meter.visible = false
		_meter.position = _dst_local_pos

func _kill_slide() -> void:
	if _slide != null and _slide.is_valid():
		_slide.kill()
	_slide = null

func _refresh_bait() -> void:
	var list: Array = get_tree().get_nodes_in_group(bait_group)
	if list.size() > 0:
		_bait = list[0]
	else:
		_bait = null
