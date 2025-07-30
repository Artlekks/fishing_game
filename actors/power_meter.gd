extends CanvasLayer

@export var max_distance: float = 20.0
@export var charge_speed: float = 1.0
@export var fill_node: NodePath
@export var label_node: NodePath
@export var fill_max_width: float = 100.0  # adjust to match your bar sprite

var charging := false
var frozen := false
var power := 0.0
var distance := 0.0
var charge_direction_up := true

func _ready():
    set_process(false)
    hide()

func start_charge():
    charging = true
    frozen = false
    power = 0.0
    distance = 0.0
    set_process(true)
    show()

func freeze():
    charging = false
    frozen = true

func reset():
    set_process(false)
    hide()
    charging = false
    frozen = false
    power = 0.0
    distance = 0.0
    _update_ui()

func get_power_value() -> float:
    return power

func get_distance() -> float:
    return distance

func _process(delta):
    if charging:
        power += delta * charge_speed * (1 if charge_direction_up else -1)

    if power >= 1.0:
        power = 1.0
        charge_direction_up = false
    elif power <= 0.0:
        power = 0.0
        charge_direction_up = true

    _update_ui()

func _update_ui():
    var fill = get_node(fill_node) as Sprite2D
    var label = get_node(label_node) as Label

    # Use X scale ping-ponging from 0 → 1 → 0
    var full_width = fill.texture.get_width()
    fill.scale.x = power  # 0.0 to 1.0

    label.text = "%.1f m" % distance
