extends Node3D

@onready var anim := $Billboard/AnimatedSprite3D
@onready var bait_spawn_point := $BaitSpawn
@onready var bait_scene := preload("res://scenes/bait_3d.tscn")

var bait_thrown := false
var bait_ref: Node3D = null

var ready_to_fish := false
var is_throwing := false
var waiting_for_throw_finish := false
var in_reeling_mode := false

func _ready():
	anim.play("prep_fishing")
	anim.animation_finished.connect(_on_animation_finished)

func _process(_delta):
	if not ready_to_fish:
		return

	# Press K to throw or start reeling
	if Input.is_action_just_pressed("throw_line"):
		if not is_throwing and not waiting_for_throw_finish and not in_reeling_mode:
			start_throw()
		elif waiting_for_throw_finish:
			waiting_for_throw_finish = false
			start_throw_finish()
		elif in_reeling_mode:
			anim.play("reeling_idle")

	# Hold K while reeling
	if in_reeling_mode and Input.is_action_pressed("throw_line"):
		if Input.is_action_pressed("reeling_left"):
			anim.play("reeling_left")
		elif Input.is_action_pressed("reeling_right"):
			anim.play("reeling_right")
		else:
			anim.play("reeling_idle")

	elif in_reeling_mode and !Input.is_action_pressed("throw_line"):
		anim.play("reeling_static")

	# R to reset the scene
	if Input.is_action_just_pressed("reset_game"):
		get_tree().reload_current_scene()

func start_throw():
	is_throwing = true
	anim.play("throw_line")

func start_throw_finish():
	anim.play("throw_line_finish")
	await get_tree().create_timer(0.25).timeout
	spawn_and_throw_bait()

func _on_animation_finished():
	match anim.animation:
		"prep_fishing":
			ready_to_fish = true
			anim.play("idle")

		"throw_line":
			is_throwing = false
			waiting_for_throw_finish = true
			anim.play("throw_line_idle")

		"throw_line_finish":
			if Input.is_action_pressed("throw_line"):
				anim.play("throw_idle")
			else:
				anim.play("reeling_static")
			in_reeling_mode = true

func spawn_and_throw_bait():
	if bait_thrown:
		return

	bait_ref = bait_scene.instantiate()
	get_tree().current_scene.add_child(bait_ref)

	bait_ref.global_position = bait_spawn_point.global_position
	var end_pos = bait_ref.global_position + Vector3(0, 0, -2.5)  # cast forward (Z axis)
	bait_ref.throw_to(end_pos)

	bait_thrown = true
