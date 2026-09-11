extends Control

@export var caster: Node
@export var top_y: float = 0.0
@export var pixels_per_depth_unit: float = 40.0
@export var max_display_depth: float = 4.0

@onready var depth_anim: AnimatedSprite2D = $DepthAnim
@onready var arrow: Control = $Arrow


func _ready() -> void:
	if caster == null:
		return

	caster.bait_depth_changed.connect(_on_depth_changed)

	depth_anim.animation = &"Depth"
	depth_anim.stop()

	visible = false


func _on_depth_changed(
	current_depth: float,
	total_depth: float
) -> void:
	visible = true

	current_depth = maxf(current_depth, 0.0)
	total_depth = maxf(total_depth, 0.0)

	# Move the bait arrow according to its current depth.
	arrow.position.y = (
		top_y
		+ current_depth * pixels_per_depth_unit
	)

	# Choose the ground frame according to the detected bottom depth.
	var ground_ratio := clampf(
		total_depth / max_display_depth,
		0.0,
		1.0
	)

	var frame_count := depth_anim.sprite_frames.get_frame_count(&"Depth")

	if frame_count <= 0:
		return

	# The artwork is ordered deep -> shallow.
	depth_anim.frame = int(round(
		lerpf(
			float(frame_count - 1),
			0.0,
			ground_ratio
		)
	))
