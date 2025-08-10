extends Node3D

@export var resume_blend_time: float = 0.35   # set this to MATCH your fishing enter time (yours looks ~2.0)
var _follow_enabled := true
var _resume_tween: Tween

@export var target_path: NodePath
@export var offset: Vector3 = Vector3(0, 6, -9)   # keep YOUR values
@onready var target: Node3D = get_node_or_null(target_path)

func set_follow_enabled(enabled: bool) -> void:
	_follow_enabled = enabled
	if not enabled and _resume_tween and _resume_tween.is_running():
		_resume_tween.kill()

func blend_back_to_follow(duration: float = -1.0) -> void:
	if duration <= 0.0:
		duration = resume_blend_time
	if not target:
		_follow_enabled = true
		return

	# compute your normal follow pose (use your real math here if it’s more than +offset)
	var desired_pos: Vector3 = target.global_position + offset

	_follow_enabled = false
	if _resume_tween and _resume_tween.is_running():
		_resume_tween.kill()
	_resume_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_resume_tween.tween_property(self, "global_position", desired_pos, duration)
	_resume_tween.tween_callback(Callable(self, "_finish_resume_blend"))

func _finish_resume_blend() -> void:
	_follow_enabled = true

func _process(_dt: float) -> void:
	if _follow_enabled and target:
		global_position = target.global_position + offset
