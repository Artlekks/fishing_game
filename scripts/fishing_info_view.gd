extends CanvasLayer
class_name FishingInfoView

enum Priority {
	NORMAL,
	IMPORTANT,
	CRITICAL
}


@onready var root: Control = $Root
@onready var message_label: Label = $Root/MessageLabel


@export_category("Timing")
@export var default_duration: float = 2.0


var _message_queue: Array[Dictionary] = []
var _current_priority: int = -1
var _message_tween: Tween = null
var _showing_message: bool = false


func _ready() -> void:
	root.visible = false
	
func show_message(
	text: String,
	duration: float = -1.0,
	priority: Priority = Priority.NORMAL
) -> void:
	var actual_duration := duration

	if actual_duration <= 0.0:
		actual_duration = default_duration

	var message := {
		"text": text,
		"duration": actual_duration,
		"priority": int(priority)
	}

	# Important messages can interrupt less-important ones.
	if _showing_message and int(priority) > _current_priority:
		_interrupt_with_message(message)
		return

	_message_queue.append(message)

	if not _showing_message:
		_show_next_message()


func clear() -> void:
	_kill_message_tween()

	_message_queue.clear()
	_current_priority = -1
	_showing_message = false

	root.visible = false


func _show_next_message() -> void:
	if _message_queue.is_empty():
		_current_priority = -1
		_showing_message = false
		root.visible = false
		return

	var message: Dictionary = _message_queue.pop_front()

	_display_message(message)


func _display_message(message: Dictionary) -> void:
	_kill_message_tween()

	_showing_message = true
	_current_priority = message["priority"]

	message_label.text = message["text"]
	root.visible = true

	var tween := create_tween()

	tween.tween_interval(message["duration"])
	tween.tween_callback(_on_message_finished)

	_message_tween = tween


func _interrupt_with_message(message: Dictionary) -> void:
	_kill_message_tween()
	_display_message(message)


func _on_message_finished() -> void:
	_message_tween = null
	_showing_message = false
	_current_priority = -1

	_show_next_message()


func _kill_message_tween() -> void:
	if _message_tween != null and _message_tween.is_valid():
		_message_tween.kill()

	_message_tween = null
