extends Control

@export var source_sprite: AnimatedSprite3D
@export var caster: Node
@export var player_screen_notifier: VisibleOnScreenNotifier3D

@export_category("Transition")
@export var slide_in_time: float = 0.30
@export var slide_out_time: float = 0.12
@export var slide_distance: float = 220.0

@onready var character: AnimatedSprite2D = $Character

var rest_position: Vector2
var slide_tween: Tween
var bait_in_water: bool = false


func _ready() -> void:
	rest_position = position
	visible = false

	if source_sprite != null:
		character.sprite_frames = source_sprite.sprite_frames

	if caster != null:
		caster.bait_landed.connect(_on_bait_landed)
		caster.bait_returned.connect(_on_bait_returned)

	if player_screen_notifier != null:
		player_screen_notifier.screen_entered.connect(
			_on_player_screen_entered
		)
		player_screen_notifier.screen_exited.connect(
			_on_player_screen_exited
		)


func _process(_delta: float) -> void:
	if source_sprite == null:
		return

	if character.animation != source_sprite.animation:
		character.animation = source_sprite.animation

	character.set_frame_and_progress(
		source_sprite.frame,
		source_sprite.frame_progress
	)

	character.flip_h = source_sprite.flip_h


func _on_bait_landed(_point: Vector3) -> void:
	bait_in_water = true
	_refresh_character_visibility()


func _on_bait_returned() -> void:
	bait_in_water = false
	hide_character()


func _on_player_screen_entered() -> void:
	# The real world-space Ryu is coming back into frame.
	# Remove the HUD copy before the two can overlap visibly.
	hide_character()


func _on_player_screen_exited() -> void:
	# If the bait is already in the water, this is the moment
	# the HUD copy is allowed to appear.
	_refresh_character_visibility()


func _refresh_character_visibility() -> void:
	if not bait_in_water:
		return

	if player_screen_notifier == null:
		return

	if not player_screen_notifier.is_on_screen():
		show_character()


func show_character() -> void:
	if visible:
		return

	_kill_tween()

	position = rest_position + Vector2(-slide_distance, 0.0)
	visible = true

	slide_tween = create_tween()
	slide_tween.set_trans(Tween.TRANS_SINE)
	slide_tween.set_ease(Tween.EASE_OUT)
	slide_tween.tween_property(
		self,
		"position",
		rest_position,
		slide_in_time
	)


func hide_character() -> void:
	if not visible:
		return

	_kill_tween()

	slide_tween = create_tween()
	slide_tween.set_trans(Tween.TRANS_SINE)
	slide_tween.set_ease(Tween.EASE_IN)
	slide_tween.tween_property(
		self,
		"position",
		rest_position + Vector2(-slide_distance, 0.0),
		slide_out_time
	)

	slide_tween.tween_callback(_finish_hide)


func _finish_hide() -> void:
	visible = false
	position = rest_position
	slide_tween = null


func _kill_tween() -> void:
	if slide_tween != null and slide_tween.is_valid():
		slide_tween.kill()

	slide_tween = null
