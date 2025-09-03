# fishing_state_machine.gd
# Godot 4.4.x
# Responsibilities:
# - Relay animation changes from FishingStateController to AnimatedSprite3D
# - Start/stop the PowerMeter at the right moments
# - (Optionally) tell DirectionSelector to show/hide on specific fishing anims
# - Never touch camera exit or sprite restore logic (that stays in your stepper)

extends Node
@export var direction_selector: DirectionSelector

@export var controller: Node                              # FishingStateController (emits `animation_change(anim: StringName)`)
@export var sprite: AnimatedSprite3D
@export var player: Node3D = null                         # Optional. Passed to DS.show_for_fishing()
@export var fishing_camera: Camera3D = null               # Optional, not used by this script (kept for modularity)
@export var enforce_every_frame: bool = true
@export var fishing_camera_controller: Node = null  # drag your FishingCameraController here

# PowerMeter group (HUD node looked up dynamically so there's no hard reference)
@export var power_meter_group: StringName = &"hud_power_meter"

const FISHING_ANIMS: PackedStringArray = [
	"Cancel_Fishing","Fishing_Catch","Fishing_Idle","Prep_Fishing",
	"Prep_Throw","Prep_Throw_Idle","Reel","Reel_Back","Reel_Back_Strong",
	"Reel_Bite","Reel_Bite_Strong","Reel_Broken_Rod","Reel_Front","Reel_Idle",
	"Reel_Left","Reel_Left_Idle","Reel_Right","Reel_Right_Idle","Throw","Throw_Idle"
]

func _ready() -> void:
	if controller == null or sprite == null:
		push_error("Assign 'controller' (FishingStateController) and 'sprite' (AnimatedSprite3D).")
		return

	# Controller → FSM
	if not controller.is_connected("animation_change", Callable(self, "_on_controller_animation_change")):
		controller.connect("animation_change", Callable(self, "_on_controller_animation_change"))

	# Sprite → FSM (animation finished)
	if not sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		sprite.animation_finished.connect(_on_sprite_animation_finished)
	
	# connect once
	if fishing_camera and fishing_camera.has_signal("entered_fishing_view"):
		fishing_camera.entered_fishing_view.connect(_on_cam_ready_for_ds)
	
	if fishing_camera_controller != null and fishing_camera_controller.has_signal("entered_fishing_view"):
		fishing_camera_controller.entered_fishing_view.connect(_on_cam_ready_for_ds)
		# remove any old call that showed DS on "Fishing_Idle"
func _process(_delta: float) -> void:
	if not enforce_every_frame:
		return
	if sprite == null:
		return
	_force_no_flip_if_fishing(String(sprite.animation))

# ---------------- PowerMeter (looked up by group) ----------------
var _pm_cache: Node = null

func _pm() -> Node:
	if _pm_cache == null or not is_instance_valid(_pm_cache):
		_pm_cache = get_tree().get_first_node_in_group(StringName(power_meter_group))
	return _pm_cache

func _pm_start() -> void:
	var n := _pm()
	if n != null:
		n.call("start")

func _pm_cancel() -> void:
	var n := _pm()
	if n != null:
		n.call("cancel")

# ---------------- Animation flow ----------------
func _on_controller_animation_change(anim_name: StringName) -> void:
	var anim := String(anim_name)

	# DS visibility
	if direction_selector != null:
		if anim == "Fishing_Idle":
			if direction_selector.has_method("show_for_fishing"):
				direction_selector.call("show_for_fishing", player)
		elif anim == "Prep_Throw" or anim == "Cancel_Fishing":
			if direction_selector.has_method("hide_for_fishing"):
				direction_selector.call("hide_for_fishing")

	# Power bar
	if anim == "Prep_Throw":
		_pm_start()
	elif anim == "Cancel_Fishing" or anim == "Throw":
		_pm_cancel()


	# 3) Play the sprite animation safely
	_play_sprite_anim(anim)

func _on_sprite_animation_finished() -> void:
	if controller != null:
		controller.call("on_animation_finished", StringName(sprite.animation))

func _on_cam_ready_for_ds() -> void:
	if direction_selector:
		direction_selector.show_for_fishing(player)  # pass your player/anchor
	# Run next frame so the camera's last look_at/transform is already applied.
	call_deferred("_deferred_show_ds")
	
func _deferred_show_ds() -> void:
	if direction_selector != null and direction_selector.has_method("show_for_fishing"):
		direction_selector.call("show_for_fishing")  # pass player if your DS expects it

# ---------------- Helpers ----------------
func _play_sprite_anim(anim: String) -> void:
	if sprite == null:
		return
	var frames := sprite.sprite_frames
	if frames == null:
		push_error("AnimatedSprite3D is missing SpriteFrames.")
		return
	if not frames.has_animation(anim):
		push_error("AnimatedSprite3D missing animation: " + anim)
		return
	# Ensure horizontal flip/scale are sane for fishing anims
	_force_no_flip_if_fishing(anim)
	sprite.play(anim)

func _force_no_flip_if_fishing(anim: String) -> void:
	if sprite == null:
		return
	if FISHING_ANIMS.has(anim):
		if sprite.flip_h:
			sprite.flip_h = false
		var s := sprite.scale
		if s.x < 0.0:
			s.x = -s.x
			sprite.scale = s
