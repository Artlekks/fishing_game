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
# --- PowerMeter access helpers ---
var _pm_cache: Node = null
func _pm() -> Node:
	if _pm_cache == null or not is_instance_valid(_pm_cache):
		_pm_cache = get_tree().get_first_node_in_group("hud_power_meter")
	return _pm_cache

# --- PowerMeter helpers (HUD) ---
func _pm_start() -> void:
	var n := get_tree().get_first_node_in_group("hud_power_meter")
	if n: n.call("start")

func _pm_cancel() -> void:
	var n := get_tree().get_first_node_in_group("hud_power_meter")
	if n: n.call("cancel")


func _on_controller_animation_change(anim_name: StringName) -> void:
	var anim := String(anim_name)

	# Force no flip for fishing anims (keep your existing helper if you use it)
	_force_no_flip_if_fishing(anim)

	# DirectionSelector visibility + alignment
	if anim == "Fishing_Idle":
		direction_selector.call("show_for_fishing")

	elif anim == "Prep_Throw" or anim == "Cancel_Fishing":
		direction_selector.call("hide_for_fishing")
	
	# Power bar visibility (appears only during Prep_Throw / Prep_Throw_Idle)
	if anim == "Prep_Throw":
		_pm_start()
	elif anim == "Cancel_Fishing" or anim == "Throw":
		# Safety: hide if we exit/throw without confirming
		_pm_cancel()

	# PowerMeter visibility (HUD)
	if anim == "Prep_Throw":
		_pm_start()
	elif anim == "Throw" or anim == "Cancel_Fishing":
		_pm_cancel()

	# Play the animation on the sprite (your existing code)
	var frames := sprite.sprite_frames
	if frames != null and frames.has_animation(anim):
		sprite.play(anim)
	else:
		push_error("AnimatedSprite3D missing animation: " + anim)


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
