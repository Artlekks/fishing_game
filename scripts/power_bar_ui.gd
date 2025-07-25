extends Control

@onready var bar := $Bar

var power := 0.0
var direction := 1.0
var speed := 0.75  # ← adjust this to slow it down
var active := false

func _ready():
	hide()
	reset()

func _process(delta):
	if active:
		power += speed * delta * direction

		if power >= 1.0:
			power = 1.0
			direction = -1.0
		elif power <= 0.0:
			power = 0.0
			direction = 1.0

		update_bar()

func update_bar():
	bar.scale.x = max(power, 0.001) if active else 0.0

func reset():
	power = 0.0
	direction = 1.0
	update_bar()
	active = false

func start():
	reset()
	show()
	active = true

func stop():
	active = false

func get_power():
	return power
