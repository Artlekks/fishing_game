extends Node3D
## CameraRig_Fishing — BoFIV-style fishing camera.
## - Faces the zone's water direction
## - Offsets so the player sits bottom-left
## - Copies render settings from the exploration camera (no "gray screen")
## - Optional tween; safe debug toggles

signal camera_settled()

# --- Composition / Pose ---
@export var back_distance: float = 8.0     # pull back from base (anchor or player)
@export var height: float = 3.0            # raise camera
@export var side_offset: float = 2.0       # + moves cam to player's right (player appears further left)
@export var pitch_deg: float = -15.0       # look-down angle

# --- Timing ---
@export var enter_time: float = 0.35
@export var exit_time: float = 0.25

# --- Debug / Safety ---
@export var debug_force_current: bool = true   # force camera current immediately (handy while tuning)
@export var debug_no_tween: bool = true        # skip tween while tuning
@export var debug_force_all_layers: bool = true  # turn on all cull layers to avoid gray screens

@onready var orbit: Node3D  = get_node_or_null("OrbitPivot") as Node3D
@onready var pitch: Node3D  = get_node_or_null("OrbitPivot/PitchPivot") as Node3D
@onready var cam:   Camera3D = get_node_or_null("OrbitPivot/PitchPivot/Camera3D") as Camera3D

var _tween: Tween
var _mode := "idle"

func _ready() -> void:
	if cam:
		cam.current = false
		# sane defaults in case the camera was created blank
		cam.near = max(0.01, cam.near)
		cam.far  = max(200.0, cam.far)
	if orbit == null: orbit = self
	if pitch == null: pitch = self

# Public API
func enter_fishing(player: Node3D, water_forward: Vector3, anchor: Node3D) -> void:
	if cam == null:
		push_error("Fishing camera missing Camera3D child.")
		return

	# Inherit render settings from whatever camera is active (prevents gray/black screens)
	_inherit_from(get_viewport().get_camera_3d())

	var fwd   := water_forward.normalized()
	if fwd == Vector3.ZERO:
		fwd = -global_basis.z
	var right := fwd.cross(Vector3.UP).normalized()
	var up    := Vector3.UP

	# Use anchor as base if provided, then APPLY OFFSETS
	var base_pos: Vector3 = (anchor.global_position) if anchor != null else player.global_position

	var target_pos: Vector3 = (
		base_pos
		- fwd * back_distance
		+ up * height
		+ right * side_offset
	)

	var yaw_deg := rad_to_deg(atan2(fwd.x, fwd.z))


	# Debug: show where we’re going
	print("[FishCam] base=", base_pos, " target=", target_pos, " yaw=", yaw_deg)

	if _tween and _tween.is_running(): _tween.kill()

	if debug_no_tween:
		global_position = target_pos
		orbit.rotation_degrees.y = yaw_deg
		pitch.rotation_degrees.x = pitch_deg
		if debug_force_current: cam.current = true
		print("[FishCam] current=", cam.is_current(), " cull=0x%X" % cam.cull_mask)
		_mode = "fishing"
		emit_signal("camera_settled")
		return

	_mode = "transition_in"
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_position", target_pos, enter_time)
	_tween.parallel().tween_property(orbit, "rotation_degrees:y", yaw_deg, enter_time)
	_tween.parallel().tween_property(pitch, "rotation_degrees:x", pitch_deg, enter_time)
	_tween.finished.connect(func ():
		_mode = "fishing"
		cam.make_current()
		emit_signal("camera_settled")
	)

func exit_fishing() -> void:
	if _tween and _tween.is_running(): _tween.kill()
	_mode = "transition_out"
	# small ease; controller will restore exploration camera
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(pitch, "rotation_degrees:x", 0.0, exit_time)
	t.finished.connect(func ():
		_mode = "idle"
		if cam: cam.current = false
	)

# --- Helpers ---------------------------------------------------------------

func _inherit_from(src: Camera3D) -> void:
	if src == null or cam == null:
		return
	# copy critical visibility/look settings
	cam.cull_mask    = src.cull_mask
	cam.environment  = src.environment
	cam.keep_aspect  = src.keep_aspect
	cam.fov          = src.fov
	cam.near         = src.near if src.near > 0.0 else cam.near
	cam.far          = max(cam.far, src.far)


	# Safety for debugging: see everything
	if debug_force_all_layers:
		cam.cull_mask = 0xFFFFF  # all 20 layers
