extends Node

## Supplies (travel/economy currency) and item stacks. Travel cost scales
## with an area's distance from the university and is discounted by any
## unlocked bus-repair upgrades.

const DISTANCE_MULT := 4.0

var supplies: int = 50
var items: Dictionary = {}

func add_supplies(amount: int) -> void:
	supplies += amount
	EventBus.supplies_changed.emit(supplies)

func spend_supplies(amount: int) -> bool:
	if supplies < amount:
		return false
	supplies -= amount
	EventBus.supplies_changed.emit(supplies)
	return true

func add_item(id: StringName, count: int = 1) -> void:
	items[id] = items.get(id, 0) + count
	EventBus.inventory_changed.emit(id, items[id])

func remove_item(id: StringName, count: int = 1) -> bool:
	var have: int = items.get(id, 0)
	if have < count:
		return false
	items[id] = have - count
	if items[id] <= 0:
		items.erase(id)
	EventBus.inventory_changed.emit(id, items.get(id, 0))
	return true

func has_item(id: StringName, count: int = 1) -> bool:
	return items.get(id, 0) >= count

func get_travel_cost(area: AreaData) -> int:
	if area == null:
		return 0

	var discount: float = 1.0 - UpgradeManager.get_bus_travel_discount()
	return int(ceil(area.distance_from_university * discount))
