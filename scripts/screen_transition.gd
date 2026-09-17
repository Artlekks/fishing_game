extends CanvasLayer

signal covered
signal revealed

@onready var overlay: ColorRect = $BlackOverlay

@export var fade_time: float = 0.2

var _fade_tween: Tween = null


func _ready() -> void:
	overlay.modulate.a = 0.0
	overlay.visible = true


func fade_to_black() -> void:
	_kill_fade()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		overlay,
		"modulate:a",
		1.0,
		fade_time
	)

	tween.tween_callback(_on_covered)

	_fade_tween = tween


func fade_from_black() -> void:
	_kill_fade()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		overlay,
		"modulate:a",
		0.0,
		fade_time
	)

	tween.tween_callback(_on_revealed)

	_fade_tween = tween


func _on_covered() -> void:
	_fade_tween = null
	covered.emit()


func _on_revealed() -> void:
	_fade_tween = null
	revealed.emit()


func _kill_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = null
