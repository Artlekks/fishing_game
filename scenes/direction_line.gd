extends Node3D

@export var build_delay := 0.1
@export var hold_time := 0.5
@export var fade_time := 0.05

var dots := []
var loop_dots := true
var has_played_once := false

func _ready():
    for i in 8:
        var dot = get_node("dot_%d" % i)
        if dot:
            dots.append(dot)
            dot.visible = false
    start_loop()

func start_loop():
    loop_dots = true

    # Immediately hide everything before starting
    _hide_all_dots()

    # Run first buildup cleanly, only once
    if not has_played_once:
        has_played_once = true
        await _show_dots_one_by_one()
        await get_tree().create_timer(hold_time).timeout
        _hide_all_dots()
        await get_tree().create_timer(fade_time).timeout

    # Start clean looping after first time
    animate_dots_loop()


func _start_fresh_once() -> void:
    await _show_dots_one_by_one()
    await get_tree().create_timer(hold_time).timeout
    _hide_all_dots()
    await get_tree().create_timer(fade_time).timeout

    if loop_dots:
        animate_dots_loop()

func stop_loop():
    loop_dots = false

func animate_dots_loop() -> void:
    await _show_dots_one_by_one()
    await get_tree().create_timer(hold_time).timeout
    _hide_all_dots()
    await get_tree().create_timer(fade_time).timeout

    if loop_dots:
        animate_dots_loop()

func _show_dots_one_by_one() -> void:
    for dot in dots:
        dot.visible = true
        await get_tree().create_timer(build_delay).timeout

func _hide_all_dots():
    for dot in dots:
        dot.visible = false
