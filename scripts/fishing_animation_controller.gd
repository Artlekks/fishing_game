extends AnimatedSprite3D
## Listens to the FishingStateMachine and plays clips.
## Also supports a "flip lock" so fishing is always un-mirrored.

@onready var fsm: Node = get_parent().get_node_or_null("FishingStateMachine")

var _frames: SpriteFrames
var _flip_locked: bool = false

func _ready() -> void:
	_frames = sprite_frames
	if _frames == null:
		push_error("SpriteFrames resource not found on AnimatedSprite3D.")
	
	if fsm and fsm.has_signal("animation_change"):
		# Avoid double-connect across reloads
		if not fsm.is_connected("animation_change", Callable(self, "_on_animation_change")):
			fsm.animation_change.connect(_on_animation_change)
	else:
		push_error("FishingStateMachine not found or signal missing.")
	
	# Propagate finished clips back to the FSM so it can progress states
	if not is_connected("animation_finished", Callable(self, "_on_anim_finished")):
		animation_finished.connect(_on_anim_finished)

func set_fishing_flip_locked(locked: bool) -> void:
	_flip_locked = locked
	if _flip_locked:
		flip_h = false  # enforce immediately

func _on_animation_change(anim_name: StringName) -> void:
	if _frames and _frames.has_animation(anim_name):
		if _flip_locked:
			flip_h = false
		play(anim_name)
	else:
		push_warning("Animation '%s' not found." % String(anim_name))

func _on_anim_finished() -> void:
	# AnimatedSprite3D exposes the current clip via `animation`
	if fsm and fsm.has_method("on_animation_finished"):
		fsm.call("on_animation_finished", animation as StringName)
