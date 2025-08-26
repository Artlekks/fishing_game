# player_8dir_controller.gd — Godot 4.4.1
extends CharacterBody3D

# -------- Movement / facing --------
@export var move_speed: float = 3.5
@export var snap_to_8_directions: bool = true

# -------- Fishing gating --------
@export var water_facing: Node3D                           # assign WaterFacing
@export_range(1.0, 179.0, 1.0) var half_angle_deg: float = 60.0

# Accept ANY camera node (Camera3D or PhantomCamera3D)
@export var exploration_camera: Node = null                # assign PCam_Exploration
@export var fishing_camera: Node = null                    # assign PCam_Fishing

# --- Fishing cam orbit ---
@export var fishcam_align_time: float = 0.35               # seconds for the orbit align
@export var fishcam_ease_out: bool = true                  # ease out tween
@export var camera_controller: Node = null

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var frames: SpriteFrames = sprite.sprite_frames

var original_offset: Vector2
var last_dir: String = "S"
var last_anim: String = ""
var movement_enabled: bool = true
var in_fishing_mode: bool = false
var _anim_lock: bool = false

# const FLIP_DIRS := {"W": true, "NW": true, "SW": true}
# const MIRROR_MAP := {"W": "E", "NW": "NE", "SW": "SE"}
const DIRS := ["S","SE","E","NE","N","NW","W","SW"]

# cached fishing-cam geometry (kept constant)
var _fishcam_radius: float = 0.0
var _fishcam_height: float = 0.0
var _fishcam_tween: Tween = null

func _ready() -> void:
	original_offset = sprite.offset
	_activate_cam(exploration_camera)
	_deactivate_cam(fishing_camera)
	
	if camera_controller != null:
			camera_controller.connect("align_started", Callable(self, "_on_cam_align_started"))
			camera_controller.connect("entered_fishing_view", Callable(self, "_on_cam_align_finished"))
			camera_controller.connect("exited_to_exploration_view", Callable(self, "_on_cam_align_finished"))

func set_movement_enabled(enabled: bool) -> void:
	movement_enabled = enabled
	if not enabled:
		velocity = Vector3.ZERO

func _on_cam_align_started(_to_fishing: bool) -> void:
	_anim_lock = true

func _on_cam_align_finished() -> void:
	_anim_lock = false
	
func _physics_process(_delta: float) -> void:
	if in_fishing_mode:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var iv := Input.get_vector("move_left","move_right","move_forward","move_back")

	if movement_enabled and iv.length_squared() > 0.0:
		var dir := Vector3(iv.x, 0.0, iv.y)
		var yaw := atan2(dir.x, dir.z)  # 0 → +Z
		if snap_to_8_directions:
			var step := PI / 4.0
			yaw = round(yaw / step) * step
		rotation.y = yaw

		last_dir = _yaw_to_dir(rotation.y)

		var mv := dir.normalized() * move_speed
		velocity.x = mv.x
		velocity.z = mv.z

		_play_8dir_animation("Walk", last_dir)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_play_8dir_animation("Idle", last_dir)

	move_and_slide()

func _process(_delta: float) -> void:
	# Keep the fishing camera centered on the player while in fishing mode
	if in_fishing_mode and fishing_camera != null:
		var cam_node := fishing_camera as Node3D
		if cam_node:
			cam_node.look_at(global_transform.origin, Vector3.UP)

func _yaw_to_dir(yaw: float) -> String:
	var step := PI / 4.0
	var idx: int = int(round(yaw / step))
	idx = wrapi(idx, 0, 8)   # instead of posmod() on floats
	return DIRS[idx]


func _play_8dir_animation(base: String, dir: String) -> void:
	# If fishing/stepper owns the sprite, don't touch anything.
	if _anim_lock:
		return

	if dir == "" or dir == null:
		dir = "S"

	# Direct mapping: "Idle_W" plays Idle_W (no mirroring).
	var anim_name: String = base + "_" + dir

	var have: bool = false
	if frames != null:
		have = frames.has_animation(anim_name)

	# Conservative fallback list (keeps same-side preference; no E↔W swapping)
	if not have:
		var fallbacks: PackedStringArray = []
		if base == "Walk":
			fallbacks = ["Walk_" + dir, "Walk_S", "Walk_N", "Walk_W", "Walk_E", "Walk"]
		else:
			fallbacks = ["Idle_" + dir, "Idle_S", "Idle_N", "Idle_W", "Idle_E", "Idle"]

		var i: int = 0
		while i < fallbacks.size():
			var cand: String = fallbacks[i]
			if frames != null and frames.has_animation(cand):
				anim_name = cand
				have = true
				break
			i += 1

	if not have:
		return

	# Force no mirroring for 8dir control.
	if sprite.flip_h:
		sprite.flip_h = false
	sprite.offset = original_offset

	if anim_name != last_anim:
		sprite.play(anim_name)
		last_anim = anim_name
		if print_debug:
			print("[8dir] ", anim_name, " (flip_h=false)")


# ---------- Fishing mode helpers ----------

func _can_enter_fishing() -> bool:
	if water_facing == null:
		push_warning("water_facing not assigned; cannot test fishing cone.")
		return false

	var player_fwd: Vector3 = global_transform.basis.z.normalized()
	var water_fwd: Vector3 = water_facing.global_transform.basis.z.normalized()

	var d: float = clampf(player_fwd.dot(water_fwd), -1.0, 1.0)
	var angle_deg: float = rad_to_deg(acos(d))
	return angle_deg <= half_angle_deg

# func _enter_fishing() -> void:
	in_fishing_mode = true
	set_movement_enabled(false)
	velocity = Vector3.ZERO
	move_and_slide()

	_activate_cam(fishing_camera)
	_deactivate_cam(exploration_camera)

	_cache_fishcam_geometry()
	_align_fishcam_to_player_axis()

# func _exit_fishing() -> void:
	in_fishing_mode = false
	set_movement_enabled(true)

	if _fishcam_tween and _fishcam_tween.is_running():
		_fishcam_tween.kill()

	_activate_cam(exploration_camera)
	_deactivate_cam(fishing_camera)

# ---------- Camera utils (works for Camera3D and PhantomCamera3D) ----------

func _activate_cam(n: Node) -> void:
	if n == null: return
	if n is Camera3D:
		(n as Camera3D).current = true
		return
	if n.has_method("make_current"):
		n.call("make_current")
	elif _has_prop(n, "current"):
		n.set("current", true)
	elif _has_prop(n, "enabled"):
		n.set("enabled", true)
	elif _has_prop(n, "active"):
		n.set("active", true)
	if _has_prop(n, "priority"):
		n.set("priority", 1000)

func _deactivate_cam(n: Node) -> void:
	if n == null: return
	if n is Camera3D:
		(n as Camera3D).current = false
		return
	if n.has_method("deactivate"):
		n.call("deactivate")
	elif _has_prop(n, "current"):
		n.set("current", false)
	elif _has_prop(n, "enabled"):
		n.set("enabled", false)
	elif _has_prop(n, "active"):
		n.set("active", false)
	if _has_prop(n, "priority"):
		n.set("priority", 0)

func _has_prop(o: Object, prop_name: String) -> bool:
	for p in o.get_property_list():
		if p.name == prop_name:
			return true
	return false

# ---------- Orbit logic (keep distance & height; rotate to player yaw) ----------

func _cache_fishcam_geometry() -> void:
	if fishing_camera == null: return
	var cam := fishing_camera as Node3D
	if cam == null: return

	var offset: Vector3 = cam.global_position - global_position
	_fishcam_height = offset.y
	var xz := Vector2(offset.x, offset.z)
	_fishcam_radius = max(0.01, xz.length())

func _align_fishcam_to_player_axis() -> void:
	if fishing_camera == null: return
	var cam := fishing_camera as Node3D
	if cam == null: return

	# Desired position: behind player along -forward, same radius & height
	var fwd: Vector3 = global_transform.basis.z.normalized()
	var target_xz: Vector3 = (-fwd) * _fishcam_radius
	var target_pos: Vector3 = global_position + Vector3(target_xz.x, _fishcam_height, target_xz.z)

	# Smooth tween of global_position to target
	if _fishcam_tween and _fishcam_tween.is_running():
		_fishcam_tween.kill()

	_fishcam_tween = create_tween()
	if fishcam_ease_out:
		_fishcam_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_fishcam_tween.tween_property(cam, "global_position", target_pos, fishcam_align_time)
	# look_at is handled in _process to keep the player centered during the tween
