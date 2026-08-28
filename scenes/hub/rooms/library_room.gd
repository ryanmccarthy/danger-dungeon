extends HubRoomBase

## Library: research unlocks new ways to survive the fog.

func _build() -> void:
	_add_header("Research unlocks new ways to survive the fog.")

	for upgrade: UpgradeData in [ContentDatabase.get_upgrade(&"bus_repair_tier1")]:
		if upgrade == null:
			continue

		var status := ""
		if upgrade.upgrade_id in UpgradeManager.unlocked_upgrade_ids:
			status = "Unlocked"
		elif upgrade.requires_quest_id != StringName() and not QuestManager.is_quest_complete(upgrade.requires_quest_id):
			status = "Locked — complete \"%s\" first" % ContentDatabase.get_quest(upgrade.requires_quest_id).display_name
		else:
			status = "%d supplies" % upgrade.unlock_cost_supplies

		var can := UpgradeManager.can_unlock(upgrade.upgrade_id)
		_add_row("%s (%s) — %s" % [upgrade.display_name, status, upgrade.description], "Unlock" if can else "", func(): _do_unlock(upgrade.upgrade_id), can)

func _do_unlock(id: StringName) -> void:
	if UpgradeManager.unlock(id):
		_status_label.text = "Unlocked upgrade."
		_refresh()
