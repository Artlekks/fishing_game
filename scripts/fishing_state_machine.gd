extends Node

@export var controller: Node          # fishing_state_controller.gd is attached here (or elsewhere)
@export var sprite: AnimatedSprite3D  # your player AnimatedSprite3D

func _ready() -> void:
	if controller == null or sprite == null:
		push_error("Assign 'controller' (FishingStateController) and 'sprite' (AnimatedSprite3D).")
		return

	# Connect controller -> sprite (play animations)
	if not controller.is_connected("animation_change", Callable(self, "_on_controller_animation_change")):
		controller.connect("animation_change", Callable(self, "_on_controller_animation_change"))

	# Connect sprite -> controller (notify finished)
	if not sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		sprite.animation_finished.connect(_on_sprite_animation_finished)

func _on_controller_animation_change(anim_name: StringName) -> void:
	# Play only if it exists; otherwise surface a clear error
	var frames := sprite.sprite_frames
	if frames != null and frames.has_animation(String(anim_name)):
		sprite.play(String(anim_name))
	else:
		push_error("AnimatedSprite3D is missing animation: " + String(anim_name))

func _on_sprite_animation_finished() -> void:
	# Pass the finished name back to the controller
	if controller != null:
		var finished_name: StringName = StringName(sprite.animation)
		controller.call("on_animation_finished", finished_name)
