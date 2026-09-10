extends Node3D

@export var target: Node3D

func _process(_delta: float) -> void:
	if target == null:
		return

	global_position = target.global_position

signal quarter_turned(direction: int)

var is_rotating := false

func rotate_quarter_turn(direction: int) -> void:
	if is_rotating:
		return

	is_rotating = true
	quarter_turned.emit(direction)

	var target_rotation := rotation.y + deg_to_rad(90.0 * direction)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation:y", target_rotation, 0.3)

	await tween.finished
	is_rotating = false

func enter_fishing_view() -> void:
	print("CameraRig: enter fishing view")
