# fishing_animation_controller.gd
extends AnimatedSprite3D

@onready var fsm: Node = get_parent().get_node_or_null("FishingStateMachine")

func _ready() -> void:
	if fsm and fsm.has_signal("animation_change"):
		fsm.animation_change.connect(_on_animation_change)
	else:
		push_error("FishingStateMachine not found or signal missing.")

	# Forward the name of the clip that just finished.
	if not is_connected("animation_finished", Callable(self, "_on_anim_finished")):
		animation_finished.connect(_on_anim_finished)

func _on_animation_change(anim_name: StringName) -> void:
	if sprite_frames and sprite_frames.has_animation(anim_name):
		play(anim_name)
	else:
		push_warning("Animation '%s' not found." % anim_name)

func _on_anim_finished() -> void:
	# AnimatedSprite3D exposes the current clip via `animation`
	if fsm and fsm.has_method("on_animation_finished"):
		fsm.call("on_animation_finished", animation as StringName)
