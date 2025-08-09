extends Camera3D
## FishingCameraController — tween the SAME camera into/out of a BoFIV-style fishing view.

# Composition knobs (tune these to match your close exploration shot)
@export var back_distance: float = 5.0     # closer = smaller (try 4.5–5.5)
@export var height: float = 2.4            # camera lift
@export var side_offset: float = 1.8       # + moves cam to player's right → player appears more left
@export var look_ahead: float = 2.5        # how far into water the camera aims

# Timing
@export var enter_time: float = 0.7        # longer = more “real-time” swing
@export var exit_time: float = 0.25

var _pre_xform: Transform3D
var _tween: Tween
var _active := false

func _ready() -> void:
	_pre_xform = global_transform

func enter_fishing_view(player: Node3D, water_forward: Vector3, anchor: Node3D = null) -> void:
	_active = true
	_pre_xform = global_transform  # remember exploration pose

	var fwd := water_forward.normalized()
	if fwd == Vector3.ZERO:
		fwd = -global_basis.z
	var right := fwd.cross(Vector3.UP).normalized()

	var base_pos: Vector3 = anchor.global_position if anchor != null else player.global_position

	var cam_pos := base_pos \
		- fwd * back_distance \
		+ Vector3.UP * height \
		+ right * side_offset

	var focus := base_pos + fwd * look_ahead
	var dir := (focus - cam_pos).normalized()
	var target_basis := Basis.looking_at(dir, Vector3.UP)
	var target := Transform3D(target_basis, cam_pos)

	if _tween and _tween.is_running(): _tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_transform", target, enter_time)

func exit_fishing_view() -> void:
	_active = false
	if _tween and _tween.is_running(): _tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "global_transform", _pre_xform, exit_time)

# Backwards-compat aliases so older calls still work
func enter_fishing(player: Node3D, water_forward: Vector3, anchor: Node3D = null) -> void:
	enter_fishing_view(player, water_forward, anchor)

func exit_fishing() -> void:
	exit_fishing_view()
