extends Node

@onready var sprite: AnimatedSprite3D = get_parent().get_node("AnimatedSprite3D")
@onready var frames: SpriteFrames = sprite.sprite_frames
@onready var fsm: Node = get_parent().get_node("FishingStateMachine")

func _ready():
	# Validate sprite and FSM connection
	if not sprite:
		push_error("AnimatedSprite3D not found.")
		return

	if not frames:
		push_error("SpriteFrames resource not found.")
		return

	if not fsm or not fsm.has_signal("animation_change"):
		push_error("FishingStateMachine node missing or 'animation_change' signal not found.")
		return

	fsm.animation_change.connect(_on_animation_change)

func _on_animation_change(anim_name: String) -> void:
	if frames.has_animation(anim_name):
		sprite.play(anim_name)
	else:
		push_warning("Animation '%s' not found in SpriteFrames." % anim_name)
