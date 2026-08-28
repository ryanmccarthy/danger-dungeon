extends Node

## Permanent equipment loadouts: four fixed slots per student (weapon, armor,
## accessory_1, accessory_2). Equipping "reserves" the physical copy out of
## InventoryManager.items (remove_item) so it can't simultaneously be used or
## sold while worn; unequipping returns it (add_item). No per-instance rolls,
## so ownership is just a StringName id — the same flat-dict model
## InventoryManager already uses for every other stackable id.

const SLOT_KEYS: Array[String] = ["weapon", "armor", "accessory_1", "accessory_2"]

var loadouts: Dictionary = {} # student_id -> {slot_key: StringName id (&"" = empty)}

func get_loadout(student_id: StringName) -> Dictionary:
	if not loadouts.has(student_id):
		loadouts[student_id] = {"weapon": &"", "armor": &"", "accessory_1": &"", "accessory_2": &""}
	return loadouts[student_id]

func get_equipped(student_id: StringName, slot_key: String) -> EquipmentData:
	var id: StringName = get_loadout(student_id).get(slot_key, &"")
	return ContentDatabase.get_equipment(id) if id != &"" else null

func can_equip(student_id: StringName, equipment_id: StringName, slot_key: String) -> bool:
	if not slot_key in SLOT_KEYS or PartyManager.get_student(student_id) == null:
		return false

	var eq := ContentDatabase.get_equipment(equipment_id)
	return eq != null and eq.fits_slot_key(slot_key) and InventoryManager.has_item(equipment_id, 1)

func equip(student_id: StringName, equipment_id: StringName, slot_key: String) -> bool:
	if not can_equip(student_id, equipment_id, slot_key):
		return false

	if not InventoryManager.remove_item(equipment_id, 1):
		return false

	unequip(student_id, slot_key) # return any previous occupant to inventory first
	get_loadout(student_id)[slot_key] = equipment_id
	_clamp_current_to_effective_max(student_id)
	EventBus.equipment_changed.emit(student_id)
	return true

func unequip(student_id: StringName, slot_key: String) -> bool:
	var loadout := get_loadout(student_id)
	var current: StringName = loadout.get(slot_key, &"")
	if current == &"":
		return false

	loadout[slot_key] = &""
	InventoryManager.add_item(current, 1)
	_clamp_current_to_effective_max(student_id)
	EventBus.equipment_changed.emit(student_id)
	return true

func _clamp_current_to_effective_max(student_id: StringName) -> void:
	# Unequipping max-HP/MP gear can leave current above the new ceiling.
	var s := PartyManager.get_student(student_id)
	if s == null:
		return

	s.current_hp = min(s.current_hp, PartyManager.get_effective_max_hp(student_id))
	s.current_mp = min(s.current_mp, PartyManager.get_effective_max_mp(student_id))

func get_stat_bonus(student_id: StringName, stat: String) -> float:
	var total := 0.0
	var loadout := get_loadout(student_id)
	for slot_key in SLOT_KEYS:
		var id: StringName = loadout.get(slot_key, &"")
		if id == &"":
			continue

		var eq := ContentDatabase.get_equipment(id)
		if eq != null:
			total += eq.get_stat_bonus(stat)

	return total

func get_passive_value(student_id: StringName, passive: EquipmentData.PassiveEffect) -> float:
	var total := 0.0
	var loadout := get_loadout(student_id)
	for slot_key in SLOT_KEYS:
		var id: StringName = loadout.get(slot_key, &"")
		if id == &"":
			continue

		var eq := ContentDatabase.get_equipment(id)
		if eq != null and eq.passive_effect == passive:
			total += eq.passive_value

	return total
