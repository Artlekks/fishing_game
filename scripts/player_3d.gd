extends Node3D

@onready var billboard := $Billboard
@onready var anim := $Billboard/AnimatedSprite3D

var ready_to_fish := false
var is_throwing := false
var waiting_for_throw_finish := false
var has_moved_forward := false
var in_reeling_mode := false

func _ready():
	anim.play("prep_fishing")
	anim.animation_finished.connect(_on_animation_finished)

func _process(_delta):
	var cam := get_viewport().get_camera_3d()
	if cam:
		billboard.look_at(cam.global_position, Vector3.UP)
		billboard.rotate_y(PI)

	if not ready_to_fish:
		return

	# Step 1 — Press K: throw logic
	if Input.is_action_just_pressed("throw_line"):
		if not is_throwing and not waiting_for_throw_finish and not in_reeling_mode:
			start_throw()

		elif waiting_for_throw_finish:
			waiting_for_throw_finish = false
			start_throw_finish()

		elif in_reeling_mode:
			anim.play("reeling_idle")

	# Step 2 — Reeling variations while holding K
	if in_reeling_mode and Input.is_action_pressed("throw_line"):
		if Input.is_action_pressed("reeling_left"):
			anim.play("reeling_left")
		elif Input.is_action_pressed("reeling_right"):
			anim.play("reeling_right")
		else:
			anim.play("reeling_idle")

	# Step 3 — Release K to stop reeling
	elif in_reeling_mode and !Input.is_action_pressed("throw_line"):
		anim.play("reeling_static")

	# R to restart the scene
	if Input.is_action_just_pressed("reset_game"):
		get_tree().reload_current_scene()

func start_throw():
	is_throwing = true
	anim.play("throw_line")

func start_throw_finish():
	anim.play("throw_line_finish")

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
