extends Node3D

func _on_fish_zone_entered(zone):
	print("Entered fish zone:", zone.zone_id)
	# TODO: show "Press K to start fishing"

func _on_fish_zone_exited(zone):
	print("Exited fish zone:", zone.zone_id)
	# TODO: maybe hide prompt or cancel prep
