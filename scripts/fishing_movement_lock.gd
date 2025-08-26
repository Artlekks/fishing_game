extends Node
@export var camera_controller: Node
@export var movement_controller: Node

func _ready() -> void:
	if camera_controller == null or movement_controller == null:
		push_warning("MovementLock: wire camera_controller and movement_controller.")
		return
	if camera_controller.has_signal("align_started"):
		camera_controller.connect("align_started", Callable(self, "_on_align_started"))
	if camera_controller.has_signal("exited_to_exploration_view"):
		camera_controller.connect("exited_to_exploration_view", Callable(self, "_on_exit_finished"))

func _on_align_started(to_fishing: bool) -> void:
	if to_fishing and movement_controller.has_method("set_movement_enabled"):
		movement_controller.call("set_movement_enabled", false)

func _on_exit_finished() -> void:
	if movement_controller.has_method("set_movement_enabled"):
		movement_controller.call("set_movement_enabled", true)
