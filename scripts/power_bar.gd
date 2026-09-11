extends ProgressBar

@export var power: Node


func _ready() -> void:
	if power == null:
		return

	power.power_changed.connect(_on_power_changed)
	power.started.connect(_on_power_started)
	power.stopped.connect(_on_power_stopped)

	visible = false


func _on_power_changed(value: float) -> void:
	self.value = value * 100.0


func _on_power_started() -> void:
	visible = true


func _on_power_stopped() -> void:
	visible = false
