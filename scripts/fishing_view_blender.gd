extends Camera3D
## FishingViewBlender — tween the SAME camera into/out of BoFIV-style fishing view.

# Composition knobs
@export var back_distance: float = 8.0     # how far behind the player along the water direction
@export var height: float = 3.0            # lift camera up
@export var side_offset: float = 2.0       # + moves cam to player's right (player appears left)
@export var pitch_deg: float = -15.0       # look-down

# Timing
@export var enter_time: float = 0.35
@export var exit_time: float = 0.25

var _pre_fish_xform: Transform3D
var _tween: Tween
var _in_fishing := false

func _ready() -> void:
	_pre_fish_xform = global_transform

func enter_fishing_view(player: Node3D, water_forward: Vector3, anchor: Node3D=null) -> void:
	_in_fishing = true
	_pre_fish_xform = global_transform  # remember exploration pose

	var fwd := water_forward.normalized()
	if fwd == Vector3.ZERO:
		fwd = -global_basis.z
	var right := fwd.cross(Vector3.UP).normalized()

	# Base: anchor if provided, else player
	var base_pos: Vector3 = anchor.global_position if anchor != null else player.global_position

	# Target camera position
	var cam_pos := base_pos \
		- fwd * back_distance \
		+ Vector3.UP * height \
		+ right * side_offset

	# Target look point (slightly ahead toward water)
	var look_at := base_pos + fwd * 2.5

	# Build target transform
	var target_basis := Basis().looking_at((look_at - cam_pos).normalized(), Vector3.UP)
	var target_xform := Transform3D(target_basis, cam_pos)

	if _tween and _tween.is_running(): _tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_transform", target_xform, enter_time)

func exit_fishing_view() -> void:
	if not _in_fishing:
		return
	_in_fishing = false
	if _tween and _tween.is_running(): _tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "global_transform", _pre_fish_xform, exit_time)
