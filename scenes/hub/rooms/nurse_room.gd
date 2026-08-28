extends HubRoomBase

## Nurse's Office: heal, revive, and feed party members.

const REVIVE_COST := 15
const REVIVE_HP_FRACTION := 0.5
const HEAL_COST := 8
const FEED_COST := 6

func _build() -> void:
	_add_header("Heal, revive, and feed your students.")

	for id in PartyManager.get_active_party_ids():
		var s: StudentData = PartyManager.get_student(id)
		if s == null:
			continue

		if s.status == StudentData.Status.DOWNED:
			_add_row("%s is down." % s.display_name, "Revive (%d)" % REVIVE_COST, func(): _do_revive(id), InventoryManager.supplies >= REVIVE_COST)
		else:
			if s.current_hp < s.max_hp:
				_add_row("%s: %d / %d HP" % [s.display_name, s.current_hp, s.max_hp], "Heal (%d)" % HEAL_COST, func(): _do_heal(id), InventoryManager.supplies >= HEAL_COST)
			if s.current_hunger < s.max_hunger:
				_add_row("%s: %d / %d hunger" % [s.display_name, int(s.current_hunger), int(s.max_hunger)], "Feed (%d)" % FEED_COST, func(): _do_feed(id), InventoryManager.supplies >= FEED_COST)

func _do_revive(id: StringName) -> void:
	var s := PartyManager.get_student(id)
	if s == null or not InventoryManager.spend_supplies(REVIVE_COST):
		return

	PartyManager.revive_student(id, int(s.max_hp * REVIVE_HP_FRACTION))
	_refresh()

func _do_heal(id: StringName) -> void:
	if not InventoryManager.spend_supplies(HEAL_COST):
		return

	var s := PartyManager.get_student(id)
	PartyManager.heal_student(id, s.max_hp)
	_refresh()

func _do_feed(id: StringName) -> void:
	if not InventoryManager.spend_supplies(FEED_COST):
		return

	var s := PartyManager.get_student(id)
	HungerSystem.restore_hunger(id, int(s.max_hunger))
	_refresh()
