extends Control

@export_category("References")
@export var caster: Node
@export var power_meter_root: Control

@export_category("Placement")
@export var screen_offset: Vector2 = Vector2(-38.0, 0)

@export_category("Arrow Track")
@export var arrow_top_y: float = 18.0
@export var arrow_bottom_y: float = 250.0

@export_category("Depth Artwork")
@export var max_display_depth: float = 4.0

@onready var depth_anim: AnimatedSprite2D = $DepthAnim
@onready var arrow: Control = $Arrow


func _ready() -> void:
	if caster == null:
		push_warning("DepthMeter_V2: Caster is not assigned.")
		return

	caster.bait_depth_changed.connect(_on_depth_changed)
	caster.bait_returned.connect(_on_bait_returned)

	depth_anim.animation = &"Depth"
	depth_anim.stop()

	visible = false


func _process(_delta: float) -> void:
	if power_meter_root == null:
		return

	position = power_meter_root.position + screen_offset


func _on_depth_changed(
	current_depth: float,
	total_depth: float
) -> void:
	visible = true

	current_depth = maxf(current_depth, 0.0)
	total_depth = maxf(total_depth, 0.0)

	_update_arrow(current_depth, total_depth)
	_update_ground(total_depth)


func _update_arrow(
	current_depth: float,
	total_depth: float
) -> void:
	if total_depth <= 0.0:
		arrow.position.y = arrow_top_y
		return

	var depth_ratio := clampf(
		current_depth / total_depth,
		0.0,
		1.0
	)

	arrow.position.y = lerpf(
		arrow_top_y,
		arrow_bottom_y,
		depth_ratio
	)


func _update_ground(total_depth: float) -> void:
	var frame_count := depth_anim.sprite_frames.get_frame_count(&"Depth")

	if frame_count <= 0:
		return

	var ground_ratio := clampf(
		total_depth / max_display_depth,
		0.0,
		1.0
	)

	# Artwork is ordered deep -> shallow.
	depth_anim.frame = int(round(
		lerpf(
			float(frame_count - 1),
			0.0,
			ground_ratio
		)
	))


func _on_bait_returned() -> void:
	visible = false
