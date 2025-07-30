extends Area3D

@export var fishing_manager: Node

func _on_body_entered(body):
	if body.name.begins_with("Bait"):
		body.queue_free()
		if fishing_manager:
			fishing_manager._on_bait_despawned()
