extends Node2D

signal bait_landed

func _ready():
	# This line will test movement by throwing upward when scene runs
	throw_to(global_position + Vector2(0, -100))

func throw_to(target_position: Vector2):
	var tween = create_tween()
	tween.tween_property(self, "position", target_position, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	print("Bait landed!")
	emit_signal("bait_landed")
