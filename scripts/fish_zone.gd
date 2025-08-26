# fish_zone.gd — Godot 4.4.1
extends Area3D

signal player_entered(player: Node3D, water_facing: Node3D)
signal player_exited(player: Node3D)

@export var water_facing: Node3D   # assign the child WaterFacing in Inspector
@export var player_group: StringName = &"player"

func _ready() -> void:
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body is Node3D and body.is_in_group(player_group):
		player_entered.emit(body, water_facing)

func _on_body_exited(body: Node) -> void:
	if body is Node3D and body.is_in_group(player_group):
		player_exited.emit(body)
