extends Node3D

enum State {
	PREP,
	FISHING_IDLE,
	DIRECTION_SELECT,
	THROW_LINE,
	THROW_IDLE,
}

@onready var anim_tree: AnimationTree = $"../AnimationTree"
@onready var direction_selector: Node = $"../Node3D/DirectionSelector"
@onready var power_meter: Node = get_tree().current_scene.get_node("PowerMeter")

var state: State = State.PREP

func _ready() -> void:
	anim_tree.active = true
	_enter_prep()

func _process(_delta: float) -> void:
	match state:
		State.DIRECTION_SELECT:
			if Input.is_action_just_pressed("ui_accept"):
				_enter_throw_line()
		_:
			pass

# ------------------------------------------
# STATE HANDLERS
# ------------------------------------------

func _enter_prep():
	state = State.PREP
	anim_tree["parameters/playback"].travel("prep_fishing")
	await get_tree().create_timer(2.2).timeout  # match anim duration
	_enter_fishing_idle()

func _enter_fishing_idle():
	state = State.FISHING_IDLE
	anim_tree["parameters/playback"].travel("fishing_idle")
	_enter_direction_select()

func _enter_direction_select():
	state = State.DIRECTION_SELECT
	direction_selector.call("start_looping")

func _enter_throw_line():
	state = State.THROW_LINE
	direction_selector.call("stop_looping")
	anim_tree["parameters/playback"].travel("throw_line")
	power_meter.call("start_charge")
	await get_tree().create_timer(0.6).timeout
	_enter_throw_idle()

func _enter_throw_idle():
	state = State.THROW_IDLE
	anim_tree["parameters/playback"].travel("throw_line_idle")
