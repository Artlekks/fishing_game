extends Area3D

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))
	print("🟢 Killzone active")

func _on_body_entered(body):
	print("🟠 Entered:", body.name)

	if body.name.begins_with("Bait"):
		print("🔴 Bait hit killzone → removing")
		body.queue_free()

		var player = get_parent()
		if player.has_method("_reset_after_reeling"):
			player._reset_after_reeling()
