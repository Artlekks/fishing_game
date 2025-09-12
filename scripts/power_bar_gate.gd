extends Node
class_name PowerBarGate

@export var caster_path: NodePath
@export var power_meter_path: NodePath          # CanvasLayer with power_meter.gd
@export var power_root_path: NodePath           # Control: PowerMeter/Root
@export var exit_action: String = "fishing_exit" # key I

@onready var _caster: Node = get_node_or_null(caster_path)
@onready var _bar: Node = get_node_or_null(power_meter_path)
@onready var _bar_root: CanvasItem = get_node_or_null(power_root_path) as CanvasItem

func _ready() -> void:
	# Map I -> exit action if missing
	if not InputMap.has_action(exit_action):
		InputMap.add_action(exit_action)
		var ev: InputEventKey = InputEventKey.new()
		ev.physical_keycode = KEY_I
		InputMap.action_add_event(exit_action, ev)

	if _caster != null:
		if _caster.has_signal("cast_started") and not _caster.is_connected("cast_started", Callable(self, "_on_cast_started")):
			_caster.connect("cast_started", Callable(self, "_on_cast_started"))
		if _caster.has_signal("bait_returned") and not _caster.is_connected("bait_returned", Callable(self, "_on_cast_ended")):
			_caster.connect("bait_returned", Callable(self, "_on_cast_ended"))
		if _caster.has_signal("bait_despawned") and not _caster.is_connected("bait_despawned", Callable(self, "_on_cast_ended")):
			_caster.connect("bait_despawned", Callable(self, "_on_cast_ended"))

	set_process(true)

func _process(_dt: float) -> void:
	# Keep the whole chain visible; if anything hides it, we re-show
	_force_visible_chain(_bar)
	_force_visible_chain(_bar_root)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed(exit_action):
		_end_bar()

func _on_cast_started() -> void:
	_force_visible_chain(_bar)
	_force_visible_chain(_bar_root)
	if _bar != null:
		_bar.set("auto_hide_on_capture", false)   # stop auto-hide flicker
		if _bar.has_method("lock_on"):
			_bar.call("lock_on")
		# start at end-of-frame so we win any race with other HUD tweens
		call_deferred("_deferred_start")

func _deferred_start() -> void:
	_force_visible_chain(_bar)
	_force_visible_chain(_bar_root)
	if _bar != null and _bar.has_method("start"):
		_bar.call("start")

func _on_cast_ended() -> void:
	_end_bar()

func _end_bar() -> void:
	if _bar != null and _bar.has_method("unlock"):
		_bar.call("unlock")
	if _bar != null and _bar.has_method("cancel"):
		_bar.call("cancel")

func _force_visible_chain(n: Node) -> void:
	if n == null:
		return
	var cur: Node = n
	while cur != null:
		if cur is CanvasItem:
			var ci: CanvasItem = cur as CanvasItem
			if not ci.visible:
				ci.visible = true
			var m: Color = ci.modulate
			if m.a < 1.0:
				m.a = 1.0
				ci.modulate = m
		elif cur is CanvasLayer:
			(cur as CanvasLayer).visible = true
		cur = cur.get_parent()
