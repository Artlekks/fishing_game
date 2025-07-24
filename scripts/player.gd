extends CharacterBody2D

@onready var anim = $AnimatedSprite2D
@onready var bait_scene = preload("res://scenes/Bait.tscn")
@onready var bait_spawn_point = $BaitSpawn

var ready_to_fish = false
var is_throwing = false
var is_reeling = false
var bait_thrown = false
var bait_landed = false
var bait_spawned = false
var waiting_for_k_release_after_throw = false
var pending_forward_step = false

var bait_ref : Node2D = null

const THROW_BAIT_FRAME = 11

func _ready():
	anim.play("prep_fishing")
	anim.animation_finished.connect(_on_animation_finished)

func _process(_delta):
	if not ready_to_fish:
		return

	# Wait for K release after throw
	if waiting_for_k_release_after_throw:
		if !Input.is_action_pressed("throw_line"):
			anim.play("reeling_static")
			waiting_for_k_release_after_throw = false
			if pending_forward_step:
				global_position += Vector2(12, 0)
				pending_forward_step = false
		return

	# Spawn bait at key frame
	if is_throwing and anim.animation == "throw_line" and anim.frame == THROW_BAIT_FRAME and !bait_spawned:
		spawn_and_throw_bait()
		bait_spawned = true

	# Press K (throw or start reeling)
	if Input.is_action_just_pressed("throw_line"):
		if not bait_thrown:
			start_throw()
		elif bait_landed and !is_reeling:
			start_reeling()

	# Reeling hold/release logic
	if bait_landed:
		if Input.is_action_pressed("throw_line"):
			if not is_reeling:
				start_reeling()

			# Handle left/right reel animation
			if Input.is_action_pressed("reeling_left"):
				anim.play("reeling_left")
			elif Input.is_action_pressed("reeling_right"):
				anim.play("reeling_right")
			else:
				anim.play("reeling_idle")
		else:
			if is_reeling:
				is_reeling = false
				anim.play("reeling_static")
				if bait_ref and bait_ref.is_inside_tree():
					bait_ref.stop_reeling()

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
			pending_forward_step = true
		else:
			anim.play("reeling_static")
			global_position += Vector2(12, 0)

func spawn_and_throw_bait():
	bait_ref = bait_scene.instantiate()
	get_tree().current_scene.add_child(bait_ref)

	var start_pos = bait_spawn_point.global_position
	bait_ref.global_position = start_pos

	var end_pos = start_pos + Vector2(120, -80)
	bait_ref.throw_to(end_pos)
	bait_ref.bait_landed.connect(_on_bait_landed)

	bait_thrown = true

func _on_bait_landed():
	bait_landed = true
	print("🎣 Bait landed — hold K to reel.")

func start_reeling():
	is_reeling = true
	if bait_ref and bait_ref.is_inside_tree():
		bait_ref.reel_to(global_position + Vector2(0, -20))
