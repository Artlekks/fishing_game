extends CharacterBody2D

@onready var anim = $AnimatedSprite2D
@onready var bait_scene = preload("res://scenes/Bait.tscn") # Adjust path if needed

var ready_to_fish = false
var is_throwing = false
var is_reeling = false
var bait_thrown = false
var bait_landed = false
var bait_spawned = false
var waiting_for_k_release_after_throw = false
var pending_forward_step = false  # NEW: move player only after release

const THROW_BAIT_FRAME = 11

func _ready():
	anim.play("prep_fishing")
	anim.animation_finished.connect(_on_animation_finished)

func _process(_delta):
	if not ready_to_fish:
		return

	# 🧠 After throw: hold throw_idle while K is held
	if waiting_for_k_release_after_throw:
		if !Input.is_action_pressed("throw_line"):
			anim.play("reeling_static")
			waiting_for_k_release_after_throw = false
			if pending_forward_step:
				global_position += Vector2(12, 0)
				pending_forward_step = false
		return  # ⛔ Block reeling logic while waiting for release

	# 🧠 Spawn bait at frame 11
	if is_throwing and anim.animation == "throw_line" and anim.frame == THROW_BAIT_FRAME and !bait_spawned:
		spawn_and_throw_bait()
		bait_spawned = true

	# 🎯 K pressed: throw or reel
	if Input.is_action_just_pressed("throw_line"):
		if not bait_thrown:
			start_throw()
		elif bait_landed and !is_reeling:
			start_reeling()

	# 🎣 Reeling logic
	if bait_landed:
		if Input.is_action_pressed("throw_line"):
			if not is_reeling:
				start_reeling()

			if Input.is_action_pressed("reeling_left"):
				anim.play("reeling_left")
			elif Input.is_action_pressed("reeling_right"):
				anim.play("reeling_right")
			else:
				anim.play("reeling_idle")
		else:
			is_reeling = false
			anim.play("reeling_static")

func start_throw():
	is_throwing = true
	bait_spawned = false
	anim.play("throw_line")

func _on_animation_finished():
	if anim.animation == "prep_fishing":
		ready_to_fish = true

	elif anim.animation == "throw_line":
		is_throwing = false

		if Input.is_action_pressed("throw_line"):
			anim.play("throw_idle")
			waiting_for_k_release_after_throw = true
			pending_forward_step = true  # mark for later movement
		else:
			anim.play("reeling_static")
			global_position += Vector2(12, 0)

func spawn_and_throw_bait():
	var bait = bait_scene.instantiate()
	get_parent().add_child(bait)

	var start_pos = global_position + Vector2(0, -20)
	var end_pos = global_position + Vector2(30, -10)

	bait.global_position = start_pos
	bait.throw_to(end_pos)
	bait.bait_landed.connect(_on_bait_landed)

	bait_thrown = true

func _on_bait_landed():
	bait_landed = true
	print("🎣 Bait landed — hold K to reel.")

func start_reeling():
	is_reeling = true
