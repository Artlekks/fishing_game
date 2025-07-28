extends Node3D

signal bait_landed
signal bait_despawned

@export var reeling_speed := 1.5
@export var killzone_radius := 0.5

var reeling_target: Vector3
var reeling := false

func throw_to(end_pos: Vector3, height := 1.0, duration := 0.6):
    var start = global_position

    var tween = create_tween()
    tween.tween_method(
    func(t):
        var pos = Vector3()
        pos.x = lerp(start.x, end_pos.x, t)
        pos.y = lerp(start.y, end_pos.y, t) + sin(t * PI) * height
        pos.z = lerp(start.z, end_pos.z, t)
        global_position = pos
    , 0.0, 1.0, duration
    )

    await tween.finished
    emit_signal("bait_landed")

func reel_to(target: Vector3):
    reeling_target = target
    reeling = true

func stop_reeling():
    reeling = false

func _process(delta):
    if reeling:
        var direction = (reeling_target - global_position)
        direction.y = 0  # flatten to horizontal plane
        var distance = direction.length()

        if distance > 0.01:
            var move = direction.normalized() * reeling_speed * delta
            if move.length() < distance:
                global_position += move
            else:
                global_position = reeling_target
                reeling = false
                _check_killzone()
        else:
            reeling = false
            _check_killzone()

func _check_killzone():
    var player = get_tree().current_scene.get_node("GroundAnchor/Player3D")
    var flat_dist = global_position.distance_to(player.global_position)
    if flat_dist <= killzone_radius:
        emit_signal("bait_despawned")
        queue_free()
