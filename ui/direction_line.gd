extends Node3D

@export var build_delay := 0.1
@export var hold_time := 0.5
@export var fade_delay := 0.1

var dots := []
var looping := false

func _ready():
	for i in range(8):
		var dot = get_node("dot_%d" % i)
		dot.visible = false
		dots.append(dot)

func start_loop():
	looping = true
	_hide_all_dots()
	call_deferred("_run_loop")

func stop_loop():
	looping = false
	_hide_all_dots()

func _run_loop():
	while looping:
		for dot in dots:
			if not looping:
				return
			dot.visible = true
			await get_tree().create_timer(build_delay).timeout
		if not looping:
			return
		await get_tree().create_timer(hold_time).timeout
		_hide_all_dots()
		await get_tree().create_timer(fade_delay).timeout

func _hide_all_dots():
	for dot in dots:
		dot.visible = false
