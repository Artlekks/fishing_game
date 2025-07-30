extends Node

@onready var anim_tree: AnimationTree = get_parent().get_node("AnimationTree")
@onready var anim_player: AnimationPlayer = get_parent().get_node("AnimationPlayer")
@onready var playback: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")

func _ready():
	anim_tree.active = true

func _process(delta):
	anim_tree.advance(delta)

func play(state_name: String) -> void:
	if not playback:
		push_error("❌ AnimationTree.playback is null")
		return

	print("▶ Switching to animation state: %s" % state_name)
	playback.travel(state_name)

func play_and_wait(state_name: String) -> void:
	play(state_name)

	var anim = anim_player.get_animation(state_name)
	if anim:
		await get_tree().create_timer(anim.length).timeout
	else:
		print("⚠️ No AnimationPlayer animation found for: %s" % state_name)
