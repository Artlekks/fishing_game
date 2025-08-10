# fishing_camera_rig.gd
extends Node3D

@export var camera_path: NodePath
@export var back_distance: float = 9.0
@export var height: float = 6.0
@export var side_offset: float = 6.0        # desired lateral offset (+), we flip it to bottom-left
@export var side_ratio_cap: float = 0.45     # <-- NEW: max lateral as fraction of back_distance
@export var look_ahead: float = 3.0
@export var blend_time: float = 0.35

var cam: Camera3D
var _tween: Tween

func _ready() -> void:
    # Resolve the Camera3D
    if camera_path != NodePath("") and has_node(camera_path):
        cam = get_node(camera_path) as Camera3D
    else:
        for c in get_children():
            if c is Camera3D:
                cam = c
                break
    if cam == null:
        push_error("FishingCameraRig: Camera3D child not found. Set 'camera_path' or add a Camera3D as a child.")
        set_process(false)

func enter_fishing(player: Node3D, water_forward: Vector3, _anchor: Node3D = null, stance_point: Vector3 = Vector3()) -> void:
    if cam == null:
        return

    var P: Vector3 = stance_point
    if P == Vector3.ZERO:
        P = player.global_position

    var fwd: Vector3 = water_forward.normalized()
    if fwd == Vector3.ZERO:
        fwd = -global_transform.basis.z.normalized()
    var right: Vector3 = fwd.cross(Vector3.UP).normalized()

    # --- lateral safety: cap sideways push relative to distance ---
    var desired_side: float = abs(side_offset)
    var max_side: float = max(0.0, back_distance * side_ratio_cap)   # e.g. 45% of back distance
    var side_mag: float = min(desired_side, max_side)
    # always bottom-left framing (negative along 'right')
    var lateral := right * (-side_mag)

    var cam_pos: Vector3 = P - fwd * back_distance + Vector3.UP * height + lateral
    var look_point: Vector3 = P + fwd * look_ahead

    if _tween and _tween.is_running():
        _tween.kill()
    _tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _tween.tween_property(self, "global_position", cam_pos, blend_time)
    _tween.tween_callback(Callable(self, "_look_at_safely").bind(look_point))

    cam.make_current()

func exit_fishing() -> void:
    pass

func _look_at_safely(target: Vector3) -> void:
    var to := (target - global_position)
    if to.length() < 0.001:
        return
    look_at(target, Vector3.UP, true)
