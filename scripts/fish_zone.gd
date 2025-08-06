extends Area3D

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	if body.name == "CharacterBody3D":
		print("Entered fishing zone — press K to start fishing.")
