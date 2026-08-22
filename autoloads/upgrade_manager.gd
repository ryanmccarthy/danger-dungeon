extends Node

## Meta-progression: quest-gated, supply-purchased upgrades. Unlocked-state
## lives here at runtime — UpgradeData resources themselves stay immutable.

var unlocked_upgrade_ids: Array[StringName] = []

func can_unlock(upgrade_id: StringName) -> bool:
	var upgrade: UpgradeData = ContentDatabase.get_upgrade(upgrade_id)
	if upgrade == null or upgrade_id in unlocked_upgrade_ids:
		return false
	if upgrade.prerequisite_upgrade_id != StringName() and not (upgrade.prerequisite_upgrade_id in unlocked_upgrade_ids):
		return false
	if upgrade.requires_quest_id != StringName() and not QuestManager.is_quest_complete(upgrade.requires_quest_id):
		return false
	return InventoryManager.supplies >= upgrade.unlock_cost_supplies

func unlock(upgrade_id: StringName) -> bool:
	if not can_unlock(upgrade_id):
		return false
	var upgrade: UpgradeData = ContentDatabase.get_upgrade(upgrade_id)
	if not InventoryManager.spend_supplies(upgrade.unlock_cost_supplies):
		return false
	unlocked_upgrade_ids.append(upgrade_id)
	EventBus.upgrade_unlocked.emit(upgrade_id)
	return true

func get_bus_travel_discount() -> float:
	var total := 0.0
	for id in unlocked_upgrade_ids:
		var upgrade: UpgradeData = ContentDatabase.get_upgrade(id)
		if upgrade != null and upgrade.category == UpgradeData.Category.BUS and upgrade.effect_type == UpgradeData.EffectType.REDUCE_TRAVEL_SUPPLY_COST:
			total += upgrade.effect_value
	return min(total, 0.9)
