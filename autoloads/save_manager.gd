extends Node

## Id-keyed persistence. Scaffolded (JSON to user://saves/) so the shape
## of everything else doesn't have to change later; not required for the
## vertical-slice loop to be demonstrated in a single play session.

const SAVE_DIR := "user://saves/"

func save_game(slot: int = 0) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var data := {
		"supplies": InventoryManager.supplies,
		"items": InventoryManager.items,
		"front_row": PartyManager.front_row_ids,
		"back_row": PartyManager.back_row_ids,
		"completed_quests": QuestManager.completed_quest_ids,
		"unlocked_upgrades": UpgradeManager.unlocked_upgrade_ids,
		"equipment": EquipmentManager.loadouts,
		"students": {},
	}

	for s in PartyManager.roster:
		data["students"][s.student_id] = {
			"level": s.level, "hp": s.current_hp, "max_hp": s.max_hp,
			"mp": s.current_mp, "max_mp": s.max_mp,
			"hunger": s.current_hunger, "status": s.status,
			"learned_skills": s.learned_skill_ids,
			"statuses": s.status_effects,
			"status_durations": PartyManager.status_durations.get(s.student_id, {}),
		}

	var f := FileAccess.open(SAVE_DIR + "slot_%d.json" % slot, FileAccess.WRITE)
	if f == null:
		return false

	f.store_string(JSON.stringify(data))
	return true

func load_game(slot: int = 0) -> bool:
	var path := SAVE_DIR + "slot_%d.json" % slot
	if not FileAccess.file_exists(path):
		return false

	var f := FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if data == null:
		return false

	InventoryManager.supplies = data.get("supplies", InventoryManager.supplies)
	InventoryManager.items = data.get("items", {})
	PartyManager.front_row_ids.assign(data.get("front_row", []))
	PartyManager.back_row_ids.assign(data.get("back_row", []))
	QuestManager.completed_quest_ids.assign(data.get("completed_quests", []))
	UpgradeManager.unlocked_upgrade_ids.assign(data.get("unlocked_upgrades", []))

	# Dictionary keys/values come back from JSON as plain Strings —
	# convert explicitly so EquipmentManager's &"" comparisons keep working.
	EquipmentManager.loadouts.clear()
	for id in data.get("equipment", {}).keys():
		var slots: Dictionary = data["equipment"][id]
		EquipmentManager.loadouts[StringName(id)] = {
			"weapon": StringName(slots.get("weapon", "")),
			"armor": StringName(slots.get("armor", "")),
			"accessory_1": StringName(slots.get("accessory_1", "")),
			"accessory_2": StringName(slots.get("accessory_2", "")),
		}

	for id in data.get("students", {}).keys():
		var s: StudentData = PartyManager.get_student(id)
		if s == null:
			continue

		var sd: Dictionary = data["students"][id]
		s.level = sd.get("level", s.level)
		s.current_hp = sd.get("hp", s.current_hp)
		s.max_hp = sd.get("max_hp", s.max_hp)
		s.current_mp = sd.get("mp", s.current_mp)
		s.max_mp = sd.get("max_mp", s.max_mp)
		s.current_hunger = sd.get("hunger", s.current_hunger)
		s.status = sd.get("status", s.status)
		s.learned_skill_ids.assign(sd.get("learned_skills", []))

		# Same JSON caveat as the equipment loadouts above: both the
		# array entries and the duration keys come back as plain Strings.
		s.status_effects.assign(sd.get("statuses", []))
		var clocks: Dictionary = {}
		for status_id in sd.get("status_durations", {}).keys():
			clocks[StringName(status_id)] = int(sd["status_durations"][status_id])

		if clocks.is_empty():
			PartyManager.status_durations.erase(s.student_id)
		else:
			PartyManager.status_durations[s.student_id] = clocks
			
	return true
