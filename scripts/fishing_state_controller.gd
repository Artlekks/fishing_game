# fishing_state_controller.gd
extends Node

signal animation_change(anim_name: StringName)
signal cancel_finished

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
var _intro_lock: bool = false  # true while Prep_Fishing (and Throw) are playing
var throw_power: float = 0.0    # 0..100 from the PowerMeter

func _pm_capture_power() -> float:
	var n := get_tree().get_first_node_in_group("hud_power_meter")
	if n:
		return n.call("capture_power") as float
	return 0.0

# -------- public API (called by controller) --------
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not _enabled:
		current_state = State.FISHING_NONE
		_intro_lock = false

func start_sequence() -> void:
	_enabled = true
	_intro_lock = true
	emit_anim("Prep_Fishing")
	current_state = State.FISHING_PREP

func force_cancel() -> void:
	# stay enabled + lock so we can receive the finish callback
	_enabled = true
	_intro_lock = true
	emit_anim("Cancel_Fishing")
	# do NOT disable here — we disable after the finish arrives


func soft_reset() -> void:
	current_state = State.FISHING_NONE
	_enabled = false
	_intro_lock = false


# -------- animation-finished based transitions --------
func on_animation_finished(anim_name: StringName) -> void:
	var s := String(anim_name)

	# Handle cancel FIRST (even if _enabled is false later)
	if s == "Cancel_Fishing":
		cancel_finished.emit()
		_enabled = false
		_intro_lock = false
		current_state = State.FISHING_NONE
		return

	# keep your normal gating for the other clips
	if not _enabled or current_state == State.FISHING_NONE:
		return

	match s:
		"Prep_Fishing":
			_intro_lock = false
			emit_anim("Fishing_Idle")
			current_state = State.FISHING_IDLE
		"Prep_Throw":
			_intro_lock = false
			emit_anim("Prep_Throw_Idle")
			current_state = State.FISHING_PRE_THROW_IDLE
		"Throw":
			_intro_lock = false
			emit_anim("Reel_Idle")
			current_state = State.FISHING_REEL_IDLE
		_:
			pass


	if anim_name == "Cancel_Fishing":
		cancel_finished.emit()

# -------- per-frame input (gated) --------
func _process(_delta: float) -> void:
	if not _enabled:
		return
	handle_input()

func handle_input() -> void:
	
	# Global hard cancel from any state
	if Input.is_action_just_pressed("cancel_fishing"):
		force_cancel()           # plays Cancel_Fishing and disables
		return

	if _intro_lock:
		return
	# ...rest of your match current_state...

	# while intro clips run, ignore input so they can't be skipped
	if _intro_lock:
		return

	match current_state:
		State.FISHING_PREP:
			# wait for on_animation_finished("Prep_Fishing")
			pass

		State.FISHING_IDLE:
			if Input.is_action_just_pressed("fish"):
				_intro_lock = true
				emit_anim("Prep_Throw")
				current_state = State.FISHING_PRE_THROW

		State.FISHING_PRE_THROW:
			# wait for on_animation_finished("Prep_Throw")
			pass

		State.FISHING_PRE_THROW_IDLE:
			if Input.is_action_just_pressed("fish"):
				# <<< add this line
				throw_power = _pm_capture_power()   # 0..100, also hides the HUD meter
				_intro_lock = true
				emit_anim("Throw")
				current_state = State.FISHING_THROW

		State.FISHING_THROW:
			# wait for on_animation_finished("Throw")
			pass

		# --- REEL CORE -------------------------------------------------------------

		State.FISHING_REEL_IDLE:
			# Start (or continue) reeling when K is pressed
			if Input.is_action_just_pressed("fish") or Input.is_action_pressed("fish"):
				if Input.is_action_pressed("ui_left"):
					emit_anim("Reel_Left")
					current_state = State.FISHING_REEL_LEFT
				elif Input.is_action_pressed("ui_right"):
					emit_anim("Reel_Right")
					current_state = State.FISHING_REEL_RIGHT
				else:
					emit_anim("Reel")
					current_state = State.FISHING_REEL
			# Side idles while NOT holding K
			elif Input.is_action_just_pressed("ui_left"):
				emit_anim("Reel_Left_Idle")
				current_state = State.FISHING_REEL_LEFT_IDLE
			elif Input.is_action_just_pressed("ui_right"):
				emit_anim("Reel_Right_Idle")
				current_state = State.FISHING_REEL_RIGHT_IDLE

		State.FISHING_REEL_LEFT_IDLE:
			# Re-pressing K should re-enter a reel immediately
			if Input.is_action_just_pressed("fish") or Input.is_action_pressed("fish"):
				if Input.is_action_pressed("ui_left"):
					emit_anim("Reel_Left")
					current_state = State.FISHING_REEL_LEFT
				elif Input.is_action_pressed("ui_right"):
					emit_anim("Reel_Right")
					current_state = State.FISHING_REEL_RIGHT
				else:
					emit_anim("Reel")
					current_state = State.FISHING_REEL
			# Switch idle facing with arrows while NOT holding K
			elif Input.is_action_just_pressed("ui_right"):
				emit_anim("Reel_Right_Idle")
				current_state = State.FISHING_REEL_RIGHT_IDLE

		State.FISHING_REEL_RIGHT_IDLE:
			if Input.is_action_just_pressed("fish") or Input.is_action_pressed("fish"):
				if Input.is_action_pressed("ui_right"):
					emit_anim("Reel_Right")
					current_state = State.FISHING_REEL_RIGHT
				elif Input.is_action_pressed("ui_left"):
					emit_anim("Reel_Left")
					current_state = State.FISHING_REEL_LEFT
				else:
					emit_anim("Reel")
					current_state = State.FISHING_REEL
			elif Input.is_action_just_pressed("ui_left"):
				emit_anim("Reel_Left_Idle")
				current_state = State.FISHING_REEL_LEFT_IDLE

		State.FISHING_REEL:
			# Hold K: keep playing the correct loop
			if Input.is_action_pressed("fish"):
				if Input.is_action_pressed("ui_left"):
					emit_anim("Reel_Left")
					current_state = State.FISHING_REEL_LEFT
				elif Input.is_action_pressed("ui_right"):
					emit_anim("Reel_Right")
					current_state = State.FISHING_REEL_RIGHT
				else:
					emit_anim("Reel")  # keep looping center reel
			else:
				emit_anim("Reel_Idle")
				current_state = State.FISHING_REEL_IDLE

		State.FISHING_REEL_LEFT:
			if Input.is_action_pressed("fish"):
				if Input.is_action_pressed("ui_right"):
					emit_anim("Reel_Right")
					current_state = State.FISHING_REEL_RIGHT
				elif Input.is_action_pressed("ui_left"):
					emit_anim("Reel_Left")  # keep looping
				else:
					emit_anim("Reel")
					current_state = State.FISHING_REEL
			else:
				emit_anim("Reel_Left_Idle")
				current_state = State.FISHING_REEL_LEFT_IDLE

		State.FISHING_REEL_RIGHT:
			if Input.is_action_pressed("fish"):
				if Input.is_action_pressed("ui_left"):
					emit_anim("Reel_Left")
					current_state = State.FISHING_REEL_LEFT
				elif Input.is_action_pressed("ui_right"):
					emit_anim("Reel_Right")  # keep looping
				else:
					emit_anim("Reel")
					current_state = State.FISHING_REEL
			else:
				emit_anim("Reel_Right_Idle")
				current_state = State.FISHING_REEL_RIGHT_IDLE

func emit_anim(anim_name: StringName) -> void:
	emit_signal("animation_change", anim_name)
	
	


func _on_fishing_camera_controller_entered_fishing_view() -> void:
	pass # Replace with function body.


func _on_fishing_camera_controller_exited_to_exploration_view() -> void:
	pass # Replace with function body.
