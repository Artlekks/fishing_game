extends Node
class_name FishSelector


func choose(entries: Array[FishSpawnEntry]) -> FishSpawnEntry:
	var total_weight := 0.0

	for entry in entries:
		if entry == null:
			continue

		if entry.fish == null:
			continue

		if entry.weight <= 0.0:
			continue

		total_weight += entry.weight

	if total_weight <= 0.0:
		return null

	var roll := randf() * total_weight

	for entry in entries:
		if entry == null:
			continue

		if entry.fish == null:
			continue

		if entry.weight <= 0.0:
			continue

		roll -= entry.weight

		if roll <= 0.0:
			return entry

	return null
