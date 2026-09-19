extends Node

## Which dungeon floors the party knows how to reach — the hub's departure board
## is exactly this set. A floor is discovered by setting foot on it (see
## GameState._set_dungeon_location). Every dungeon's first floor is reachable by
## bus unconditionally, so this array needs no seeding and saves written before
## it existed still show an entrance.

var discovered_area_ids: Array[StringName] = []

func discover(area_id: StringName) -> void:
	if area_id == StringName() or area_id in discovered_area_ids:
		return

	discovered_area_ids.append(area_id)
	EventBus.area_discovered.emit(area_id)

func is_discovered(area_id: StringName) -> bool:
	return area_id in discovered_area_ids

## The one gate the departure board reads. Change what "unlocked" means here
## (e.g. cleared rather than merely visited) without touching any UI; a future
## per-dungeon story gate on first floors belongs in this function too.
func is_departure_unlocked(area: AreaData) -> bool:
	if area == null:
		return false
	if area.floor_number <= 1:
		return true

	return is_discovered(area.area_id)
