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

var current_state: State = State.FISHING_NONE
var _enabled: bool = false

# --- public API used by the controller ---

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not _enabled:
		current_state = State.FISHING_NONE

func start_sequence() -> void:
	# Called by controller on K
	_enabled = true
	emit_anim("Prep_Fishing")
	current_state = State.FISHING_PREP

func force_cancel() -> void:
	emit_anim("Cancel_Fishing")
	current_state = State.FISHING_NONE
	_enabled = false

# --- per-frame ---

func _process(_delta: float) -> void:
	if not _enabled:
		return
	handle_input()

func handle_input() -> void:
	match current_state:
		State.FISHING_PREP:
			if Input.is_action_just_released("fish"):
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
				emit_anim("Reel")
			else:
				emit_anim("Reel_Idle")
				current_state = State.FISHING_REEL_IDLE

		State.FISHING_REEL_LEFT_IDLE:
			if Input.is_action_pressed("fish") and Input.is_action_pressed("ui_left"):
				emit_anim("Reel_Left")
				current_state = State.FISHING_REEL_LEFT
			elif Input.is_action_pressed("ui_right"):
				emit_anim("Reel_Right_Idle")
				current_state = State.FISHING_REEL_RIGHT_IDLE

		State.FISHING_REEL_LEFT:
			if Input.is_action_pressed("fish"):
				if Input.is_action_pressed("ui_right"):
					emit_anim("Reel_Right")
					current_state = State.FISHING_REEL_RIGHT
				elif Input.is_action_pressed("ui_left"):
					emit_anim("Reel") # smooth return to center pull
					current_state = State.FISHING_REEL
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
			elif Input.is_action_pressed("ui_left"):
				emit_anim("Reel_Left_Idle")
				current_state = State.FISHING_REEL_LEFT_IDLE

		State.FISHING_REEL_RIGHT:
			if Input.is_action_pressed("fish"):
				if Input.is_action_pressed("ui_left"):
					emit_anim("Reel_Left")
					current_state = State.FISHING_REEL_LEFT
				elif Input.is_action_pressed("ui_right"):
					emit_anim("Reel_Right")
				else:
					emit_anim("Reel")
					current_state = State.FISHING_REEL
			else:
				emit_anim("Reel_Right_Idle")
				current_state = State.FISHING_REEL_RIGHT_IDLE

func emit_anim(anim_name: String) -> void:
	emit_signal("animation_change", anim_name)
