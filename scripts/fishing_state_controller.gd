extends Node

signal animation_change(anim_name: String)

enum State {
	FISHING_NONE,
	FISHING_PREP,
	FISHING_IDLE,
	FISHING_PRE_THROW,
	FISHING_PRE_THROW_IDLE,
	FISHING_THROW,
	FISHING_REEL_IDLE,
	FISHING_REEL,
	FISHING_REEL_LEFT_IDLE,
	FISHING_REEL_LEFT,
	FISHING_REEL_RIGHT_IDLE,
	FISHING_REEL_RIGHT
}

var current_state = State.FISHING_NONE

func _process(_delta):
	handle_input()

func handle_input():
	match current_state:
		State.FISHING_NONE:
			if Input.is_action_just_pressed("fish"):
				emit_anim("Prep_Fishing")
				current_state = State.FISHING_PREP

		State.FISHING_PREP:
			if Input.is_action_just_released("fish"):  # TODO: replace with signal if needed
				emit_anim("Fishing_Idle")
				current_state = State.FISHING_IDLE

		State.FISHING_IDLE:
			if Input.is_action_just_pressed("fish"):
				emit_anim("Prep_Throw")
				current_state = State.FISHING_PRE_THROW

		State.FISHING_PRE_THROW:
			if Input.is_action_just_released("fish"):
				emit_anim("Prep_Throw_Idle")
				current_state = State.FISHING_PRE_THROW_IDLE

		State.FISHING_PRE_THROW_IDLE:
			if Input.is_action_just_pressed("fish"):
				emit_anim("Throw")
				current_state = State.FISHING_THROW

		State.FISHING_THROW:
			if Input.is_action_just_released("fish"):
				emit_anim("Reel_Idle")
				current_state = State.FISHING_REEL_IDLE

		State.FISHING_REEL_IDLE:
			if Input.is_action_pressed("fish"):
				if Input.is_action_pressed("ui_left"):
					emit_anim("Reel_Left")
					current_state = State.FISHING_REEL_LEFT
				elif Input.is_action_pressed("ui_right"):
					emit_anim("Reel_Right")
					current_state = State.FISHING_REEL_RIGHT
				else:
					emit_anim("Reel")
					current_state = State.FISHING_REEL

			elif Input.is_action_just_pressed("ui_left"):
				emit_anim("Reel_Left_Idle")
				current_state = State.FISHING_REEL_LEFT_IDLE

			elif Input.is_action_just_pressed("ui_right"):
				emit_anim("Reel_Right_Idle")
				current_state = State.FISHING_REEL_RIGHT_IDLE

		State.FISHING_REEL:
			if Input.is_action_pressed("fish") and not Input.is_action_pressed("ui_left") and not Input.is_action_pressed("ui_right"):
				emit_anim("Reel")  # replay every frame
			else:
				emit_anim("Reel_Idle")
				current_state = State.FISHING_REEL_IDLE

		State.FISHING_REEL_LEFT_IDLE:
			if Input.is_action_pressed("fish") and Input.is_action_pressed("ui_left"):
				emit_anim("Reel_Left")
				current_state = State.FISHING_REEL_LEFT

		State.FISHING_REEL_LEFT:
			if Input.is_action_pressed("fish"):
				if Input.is_action_pressed("ui_right"):
					emit_anim("Reel_Right")
					current_state = State.FISHING_REEL_RIGHT
				elif Input.is_action_pressed("ui_left"):
					emit_anim("Reel_Left")  # replay every frame
				else:
					emit_anim("Reel")
					current_state = State.FISHING_REEL
			else:
				emit_anim("Reel_Left_Idle")
				current_state = State.FISHING_REEL_LEFT_IDLE


		State.FISHING_REEL_RIGHT_IDLE:
			if Input.is_action_pressed("fish") and Input.is_action_pressed("ui_right"):
				emit_anim("Reel_Right")
				current_state = State.FISHING_REEL_RIGHT

		State.FISHING_REEL_RIGHT:
			if Input.is_action_pressed("fish"):
				if Input.is_action_pressed("ui_left"):
					emit_anim("Reel_Left")
					current_state = State.FISHING_REEL_LEFT
				elif Input.is_action_pressed("ui_right"):
					emit_anim("Reel_Right")  # replay every frame
				else:
					emit_anim("Reel")
					current_state = State.FISHING_REEL
			else:
				emit_anim("Reel_Right_Idle")
				current_state = State.FISHING_REEL_RIGHT_IDLE



func emit_anim(anim_name: String) -> void:
	emit_signal("animation_change", anim_name)
