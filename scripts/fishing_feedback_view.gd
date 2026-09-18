extends CanvasLayer


enum FeedbackType {
	HIT,
	HOOK_OFF,
	MISS,
	LINE_BREAK,
	CATCH
}


@onready var feedback_texture: TextureRect = $FeedbackTexture


@export var encounter: Node

@export_category("Feedback Textures")
@export var hit_texture: Texture2D
@export var hook_off_texture: Texture2D
@export var miss_texture: Texture2D
@export var line_break_texture: Texture2D
@export var catch_texture: Texture2D

@export_category("Timing")
@export var display_time: float = 0.8
@export var fade_time: float = 0.15
@export var slide_time: float = 0.18
@export var slide_padding_px: float = 30.0
@export var screen_transition: Node

var _feedback_tween: Tween = null
var _rest_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	_rest_position = feedback_texture.position
	feedback_texture.visible = false
	screen_transition.covered.connect(clear)
	
	if encounter == null:
		push_warning("FishingFeedbackView: Encounter is not assigned.")
		return

	encounter.bite_triggered.connect(
		_on_bite_triggered
	)

	encounter.bite_missed.connect(
		_on_bite_missed
	)

	encounter.hook_off.connect(
		_on_hook_off
	)

	encounter.line_broken.connect(
		_on_line_broken
	)

	encounter.fish_caught.connect(
		_on_fish_caught
	)


func _on_bite_triggered() -> void:
	show_feedback(FeedbackType.HIT)


func _on_bite_missed() -> void:
	show_feedback(FeedbackType.MISS)


func _on_hook_off() -> void:
	show_feedback(FeedbackType.HOOK_OFF)


func _on_line_broken() -> void:
	show_feedback(FeedbackType.LINE_BREAK)


func _on_fish_caught(_fish: FishInstance) -> void:
	show_feedback(FeedbackType.CATCH)


func show_feedback(type: FeedbackType) -> void:
	var texture := _get_feedback_texture(type)

	if texture == null:
		return

	_kill_feedback_tween()

	feedback_texture.texture = texture
	feedback_texture.modulate.a = 1.0
	feedback_texture.position = _get_offscreen_right_position()
	feedback_texture.visible = true

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)

	# Every feedback enters from the right.
	tween.tween_property(
		feedback_texture,
		"position",
		_rest_position,
		slide_time
	)

	# Hook Off and Line Break stay in the middle.
	if (
		type == FeedbackType.HOOK_OFF
		or type == FeedbackType.LINE_BREAK
	):
		_feedback_tween = tween
		return

	# HIT / MISS / CATCH stay briefly...
	tween.tween_interval(display_time)

	# ...then leave through the left.
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(
		feedback_texture,
		"position",
		_get_offscreen_left_position(),
		slide_time
	)

	tween.tween_callback(_hide_feedback)

	_feedback_tween = tween

func _get_feedback_texture(type: FeedbackType) -> Texture2D:
	match type:
		FeedbackType.HIT:
			return hit_texture

		FeedbackType.HOOK_OFF:
			return hook_off_texture

		FeedbackType.MISS:
			return miss_texture

		FeedbackType.LINE_BREAK:
			return line_break_texture

		FeedbackType.CATCH:
			return catch_texture

	return null

func _hide_feedback() -> void:
	feedback_texture.visible = false
	feedback_texture.position = _rest_position
	feedback_texture.modulate.a = 1.0
	_feedback_tween = null

func _kill_feedback_tween() -> void:
	if (
		_feedback_tween != null
		and _feedback_tween.is_valid()
	):
		_feedback_tween.kill()

	_feedback_tween = null

func clear() -> void:
	_kill_feedback_tween()

	feedback_texture.visible = false
	feedback_texture.position = _rest_position
	feedback_texture.modulate.a = 1.0
	
func _get_offscreen_right_position() -> Vector2:
	var viewport_width := get_viewport().get_visible_rect().size.x

	return _rest_position + Vector2(
		viewport_width + feedback_texture.size.x + slide_padding_px,
		0.0
	)


func _get_offscreen_left_position() -> Vector2:
	var viewport_width := get_viewport().get_visible_rect().size.x

	return _rest_position - Vector2(
		viewport_width + feedback_texture.size.x + slide_padding_px,
		0.0
	)
