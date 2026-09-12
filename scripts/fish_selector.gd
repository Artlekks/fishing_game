extends Node
class_name FishSelector


func choose(
	entries: Array[FishSpawnEntry],
	bait: BaitData,
	current_depth: float,
	total_depth: float
) -> FishSpawnEntry:
			var total_weight := 0.0

			for entry in entries:
				if entry == null:
					continue

				if entry.fish == null:
					continue

				if entry.weight <= 0.0:
					continue

				var lure_multiplier := entry.fish.get_lure_match_multiplier(bait)

				var depth_multiplier := entry.fish.get_depth_match_multiplier(
					current_depth,
					total_depth
				)

				var effective_weight := (
					entry.weight
					* lure_multiplier
					* depth_multiplier
				)

				total_weight += effective_weight

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

				var lure_multiplier := entry.fish.get_lure_match_multiplier(bait)

				var depth_multiplier := entry.fish.get_depth_match_multiplier(
					current_depth,
					total_depth
				)

				var effective_weight := (
					entry.weight
					* lure_multiplier
					* depth_multiplier
				)

				roll -= effective_weight

				if roll <= 0.0:
					return entry

			return null
