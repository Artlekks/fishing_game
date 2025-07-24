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
var waiting_for_throw_finish = false
var has_moved_forward = false  # NEW

var bait_ref : Node2D = null

const THROW_BAIT_FRAME = 11

func _ready():
	anim.play("prep_fishing")
	anim.animation_finished.connect(_on_animation_finished)

func _process(_delta):
	if not ready_to_fish:
		return

	# Wait for second press to finish throw
	if waiting_for_throw_finish:
		if Input.is_action_just_pressed("throw_line"):
			waiting_for_throw_finish = false
			start_throw_finish()
		return

	# Wait for K release after throw
	if waiting_for_k_release_after_throw:
		if !Input.is_action_pressed("throw_line"):
			anim.play("reeling_static")
			waiting_for_k_release_after_throw = false
			if pending_forward_step:
				global_position += Vector2(12, 0)
				has_moved_forward = true
				pending_forward_step = false
		return

	# Press K: start throw or reeling
	if Input.is_action_just_pressed("throw_line"):
		if not bait_thrown and !is_throwing and !waiting_for_throw_finish:
			start_throw()
		elif bait_landed and !is_reeling:
			start_reeling()

	# Reeling (hold K)
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
			if is_reeling:
				is_reeling = false
				anim.play("reeling_static")
				if bait_ref and bait_ref.is_inside_tree():
					bait_ref.stop_reeling()
			else:
				if Input.is_action_pressed("reeling_left"):
					anim.play("reeling_idle_left")
				elif Input.is_action_pressed("reeling_right"):
					anim.play("reeling_idle_right")

func start_throw():
	is_throwing = true
	bait_spawned = false
	anim.play("throw_line")

func start_throw_finish():
	anim.play("throw_line_finish")
	if not bait_thrown:
		await get_tree().create_timer(0.2).timeout
		spawn_and_throw_bait()

func _on_animation_finished():
	if anim.animation == "prep_fishing":
		ready_to_fish = true

	elif anim.animation == "throw_line":
		is_throwing = false
		waiting_for_throw_finish = true
		anim.play("throw_line_idle")

	elif anim.animation == "throw_line_finish":
		bait_thrown = true
		if Input.is_action_pressed("throw_line"):
			anim.play("throw_idle")
			waiting_for_k_release_after_throw = true
			if not has_moved_forward:
				pending_forward_step = true
		else:
			anim.play("reeling_static")
			if not has_moved_forward:
				global_position += Vector2(12, 0)
				has_moved_forward = true

func spawn_and_throw_bait():
	bait_ref = bait_scene.instantiate()
	get_tree().current_scene.add_child(bait_ref)

	var start_pos = bait_spawn_point.global_position
	bait_ref.global_position = start_pos

	var end_pos = start_pos + Vector2(120, -80)
	bait_ref.throw_to(end_pos)
	bait_ref.bait_landed.connect(_on_bait_landed)
	bait_ref.bait_despawned.connect(_on_bait_despawned)

func _on_bait_landed():
	bait_landed = true
	print("🎣 Bait landed — hold K to reel.")

func _on_bait_despawned():
	bait_thrown = false
	bait_landed = false
	is_reeling = false
	bait_spawned = false
	anim.play("idle")

func start_reeling():
	is_reeling = true
	if bait_ref and bait_ref.is_inside_tree():
		bait_ref.reel_to(global_position + Vector2(0, -20))
