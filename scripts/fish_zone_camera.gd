extends Area3D
## Drives Phantom priorities + gaze slide (player -> water) using a single PCam_Fishing.

signal player_entered_fish_zone(zone)
signal player_exited_fish_zone(zone)

@export var exploration_pcam_path: NodePath = ^"../../Cameras/PCam_Exploration"
@export var fishing_pcam_path: NodePath = ^"WaterFacing/CamPivot/PCam_Fishing"
@export var look_target_path: NodePath  = ^"LookTarget"
@export var look_driver_path: NodePath  = ^"LookDriver"

@export var exploration_priority := 10
@export var fishing_priority := 100
@export var gaze_handoff_time := 0.30  # seconds to slide gaze from player to water

@onready var _pcam_exploration := get_node_or_null(exploration_pcam_path)
@onready var _pcam_fishing     := get_node_or_null(fishing_pcam_path)
@onready var _look_target      := get_node_or_null(look_target_path) as Node3D
@onready var _look_driver      := get_node_or_null(look_driver_path) as Node3D
@onready var water_facing: Node3D  = $WaterFacing
@onready var camera_anchor: Node3D = $CameraAnchor

var _inside := false
var _gaze_tween: Tween

func _ready() -> void:
	add_to_group("fish_zone")
	monitoring = true
	monitorable = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	# Default ownership
	_set_priority(_pcam_fishing, 0)
	_set_priority(_pcam_exploration, exploration_priority)

func activate_fishing_view(player: Node3D) -> void:
	if _pcam_fishing == null or _look_driver == null:
		return
	# 1) Gaze starts on the player so they never leave frame during the swing
	_look_driver.global_position = player.global_position
	# 2) Give control to the fishing PCam
	_set_priority(_pcam_exploration, 0)
	_set_priority(_pcam_fishing, fishing_priority)
	# 3) Slide gaze to the water look target
	if _gaze_tween and _gaze_tween.is_running():
		_gaze_tween.kill()
	if _look_target:
		_gaze_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_gaze_tween.tween_property(_look_driver, "global_position",
			_look_target.global_position, max(0.0, gaze_handoff_time))

func deactivate_fishing_view() -> void:
	# Return control to exploration PCam
	_set_priority(_pcam_fishing, 0)
	_set_priority(_pcam_exploration, exploration_priority)

# --- helpers used by controller ---
func get_water_forward() -> Vector3:
	var f := water_facing.global_transform.basis.z if water_facing else Vector3.FORWARD
	return f.normalized()

func get_stance_point(default_pos: Vector3) -> Vector3:
	return camera_anchor.global_position if camera_anchor else default_pos

# --- internal ---
func _set_priority(n: Node, p: int) -> void:
	if n: n.set("priority", p)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_inside = true
		player_entered_fish_zone.emit(self)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_inside = false
		player_exited_fish_zone.emit(self)

func get_look_point() -> Vector3:
	# Expose the water look point for the controller gate.
	if _look_target:
		return _look_target.global_position
	return camera_anchor.global_position if camera_anchor else global_position
