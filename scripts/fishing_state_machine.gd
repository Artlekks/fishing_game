extends Node

@export var controller: Node
@export var sprite: AnimatedSprite3D
@export var enforce_every_frame: bool = true  # keeps fishing anims unflipped even if other code flips

	  # AnimatedSprite3D
@export var direction_selector: Node3D = null  # assign DirectionSelector
@export var player: Node3D = null              # assign ExplorationPlayer (for facing)
@export var fishing_camera: Camera3D = null


const FISHING_ANIMS: PackedStringArray = [
	"Cancel_Fishing",
	"Fishing_Catch",
	"Fishing_Idle",
	"Prep_Fishing",
	"Prep_Throw",
	"Prep_Throw_Idle",
	"Reel",
	"Reel_Back",
	"Reel_Back_Strong",
	"Reel_Bite",
	"Reel_Bite_Strong",
	"Reel_Broken_Rod",
	"Reel_Front",
	"Reel_Idle",
	"Reel_Left",
	"Reel_Left_Idle",
	"Reel_Right_Idle",
	"Throw",
	"Throw_Idle"
]

func _ready() -> void:
	if controller == null or sprite == null:
		push_error("Assign 'controller' (FishingStateController) and 'sprite' (AnimatedSprite3D).")
		return
	if not controller.is_connected("animation_change", Callable(self, "_on_controller_animation_change")):
		controller.connect("animation_change", Callable(self, "_on_controller_animation_change"))
	if not sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		sprite.animation_finished.connect(_on_sprite_animation_finished)

func _process(_delta: float) -> void:
	# Safety net: if some other script flips the sprite while a fishing anim is playing, force it back.
	if enforce_every_frame:
		_force_no_flip_if_fishing(sprite.animation)

func _on_controller_animation_change(anim_name: StringName) -> void:
	var anim := String(anim_name)
	_force_no_flip_if_fishing(anim)
# Direction line visibility control
	if direction_selector != null:
		if anim == "Fishing_Idle":
			if player != null:
				direction_selector.call("lock_to_player_neg_x", player)
			direction_selector.call("start_looping")
		elif anim == "Prep_Throw" or anim == "Cancel_Fishing":
			direction_selector.call("stop_looping")
			
	if direction_selector != null:
		if anim == "Prep_Fishing":
			# lock once, before we go into Fishing_Idle
			if player != null:
				direction_selector.call("lock_to_player_axis", player)

		elif anim == "Fishing_Idle":
			direction_selector.call("start_looping")

		elif anim == "Prep_Throw":
			direction_selector.call("stop_looping")
# --- DirectionSelector visibility ---
	if anim == "Fishing_Idle":
		_dir_show()
	elif anim == "Prep_Throw" or anim == "Cancel_Fishing":
		_dir_hide()
	if direction_selector != null:
		if anim == "Fishing_Idle":
			direction_selector.call("start_looping")
			if player != null:
				var fwd: Vector3 = player.global_transform.basis.z
				fwd.y = 0.0
				direction_selector.call("set_yaw_from_direction", fwd)
		elif anim == "Prep_Throw":
			direction_selector.call("stop_looping")
	var frames := sprite.sprite_frames
	if frames != null and frames.has_animation(anim):
		sprite.play(anim)
	else:
		push_error("AnimatedSprite3D is missing animation: " + anim)

	# --- Direction line control (lock to screen-right) ---
	if direction_selector != null:
		if anim == "Fishing_Idle":
			if fishing_camera != null:
				var cam_right: Vector3 = fishing_camera.global_transform.basis.x
				direction_selector.call("lock_to_world_dir", cam_right)  # lock to screen-right
			direction_selector.call("start_looping")
		elif anim == "Prep_Throw":
			direction_selector.call("stop_looping")

	# … existing code that plays sprite animations, etc.
func _on_sprite_animation_finished() -> void:
	if controller != null:
		controller.call("on_animation_finished", StringName(sprite.animation))

func _force_no_flip_if_fishing(anim: String) -> void:
	if FISHING_ANIMS.has(anim):
		# Never mirror fishing animations
		if sprite.flip_h:
			sprite.flip_h = false
		var s := sprite.scale
		if s.x < 0.0:
			s.x = -s.x
			sprite.scale = s

func _dir_show() -> void:
	if direction_selector != null:
		direction_selector.call("lock_to_world_dir", Vector3.LEFT) # or your lock method
		direction_selector.call("start_looping")

func _dir_hide() -> void:
	if direction_selector != null:
		direction_selector.call("stop_looping")
