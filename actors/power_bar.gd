extends Node

@onready var ui := $power_bar_ui
@onready var fill := $power_bar_ui/PowerBarFill

var tween: Tween
var final_pos := Vector2.ZERO

func _ready():
	final_pos = ui.position
	reset()

func reset():
	if tween:
		tween.kill()
	fill.scale.x = 0.0
	ui.visible = false
	ui.position.y = 800

func show_bar():
	ui.visible = true
	tween = create_tween()
	tween.tween_property(ui, "position", final_pos, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func set_fill(value: float):
	fill.scale.x = clamp(value, 0.0, 1.0)
