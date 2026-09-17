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


var _feedback_tween: Tween = null


func _ready() -> void:
	feedback_texture.visible = false

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


func _on_fish_caught() -> void:
	show_feedback(FeedbackType.CATCH)


func show_feedback(type: FeedbackType) -> void:
	var texture := _get_feedback_texture(type)

	if texture == null:
		return

	_kill_feedback_tween()

	feedback_texture.texture = texture
	feedback_texture.modulate.a = 1.0
	feedback_texture.visible = true

	var tween := create_tween()

	tween.tween_interval(display_time)

	tween.tween_property(
		feedback_texture,
		"modulate:a",
		0.0,
		fade_time
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
	feedback_texture.modulate.a = 1.0
	_feedback_tween = null


func _kill_feedback_tween() -> void:
	if (
		_feedback_tween != null
		and _feedback_tween.is_valid()
	):
		_feedback_tween.kill()

	_feedback_tween = null
