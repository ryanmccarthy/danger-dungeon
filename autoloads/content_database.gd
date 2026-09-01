extends Node

## Loads and indexes all data-driven content by id. Other autoloads and
## scenes should reference content through this database, never by
## hardcoded res:// path.

var _students: Dictionary = {}
var _classes: Dictionary = {}
var _skills: Dictionary = {}
var _items: Dictionary = {}
var _enemies: Dictionary = {}
var _areas: Dictionary = {}
var _quests: Dictionary = {}
var _recipes: Dictionary = {}
var _upgrades: Dictionary = {}
var _equipment: Dictionary = {}
var _status_effects: Dictionary = {}

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	_index_dir("res://data/students", _students, "student_id")
	_index_dir("res://data/classes", _classes, "class_id")
	_index_dir("res://data/skills", _skills, "skill_id")
	_index_dir("res://data/items", _items, "id")
	_index_dir("res://data/enemies", _enemies, "enemy_id")
	_index_dir("res://data/areas", _areas, "area_id")
	_index_dir("res://data/quests", _quests, "quest_id")
	_index_dir("res://data/recipes", _recipes, "recipe_id")
	_index_dir("res://data/upgrades", _upgrades, "upgrade_id")
	_index_dir("res://data/equipment", _equipment, "id")
	_index_dir("res://data/status_effects", _status_effects, "status_id")

	# Items and equipment share one flat id namespace (both live in
	# InventoryManager.items), so a duplicate would silently shadow —
	# get_inventory_item resolves items first.
	for dup in _items.keys().filter(func(k): return _equipment.has(k)):
		push_warning("[ContentDatabase] id '%s' is both an item and equipment" % dup)

	print("[ContentDatabase] students=%d classes=%d skills=%d items=%d enemies=%d areas=%d quests=%d recipes=%d upgrades=%d equipment=%d status_effects=%d" % [
		_students.size(), _classes.size(), _skills.size(), _items.size(),
		_enemies.size(), _areas.size(), _quests.size(), _recipes.size(), _upgrades.size(),
		_equipment.size(), _status_effects.size()
	])

func _index_dir(dir_path: String, target: Dictionary, id_field: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("[ContentDatabase] missing content dir: %s" % dir_path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res: Resource = load(dir_path.path_join(file_name))
			if res != null:
				var id: StringName = res.get(id_field)
				if id == StringName():
					push_warning("[ContentDatabase] %s has empty %s" % [file_name, id_field])
				else:
					target[id] = res
		file_name = dir.get_next()
	dir.list_dir_end()

func get_actor(id: StringName) -> CharacterData:
	if id in _students.keys():
		return get_student(id)

	return get_enemy(id)

func get_student(id: StringName) -> StudentData:
	return _students.get(id)

func get_all_students() -> Array[StudentData]:
	var out: Array[StudentData] = []
	for v in _students.values():
		out.append(v)
	return out

func get_class_data(id: StringName) -> StudentClassData:
	return _classes.get(id)

func get_all_classes() -> Array[StudentClassData]:
	var out: Array[StudentClassData] = []
	for v in _upgrades.values():
		out.append(v)

	return out

func get_skill(id: StringName) -> SkillData:
	return _skills.get(id)

func get_all_skills() -> Array[SkillData]:
	var out: Array[SkillData] = []
	for v in _skills.values():
		out.append(v)

	return out

func get_item(id: StringName) -> ItemData:
	return _items.get(id)

func get_all_items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for v in _items.values():
		out.append(v)
	return out

func get_enemy(id: StringName) -> EnemyData:
	return _enemies.get(id)

func get_all_enemies() -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for v in _enemies.values():
		out.append(v)

	return out

func get_area(id: StringName) -> AreaData:
	return _areas.get(id)

func get_all_areas() -> Array[AreaData]:
	var out: Array[AreaData] = []
	for v in _areas.values():
		out.append(v)

	return out

func get_quest(id: StringName) -> QuestData:
	return _quests.get(id)

func get_all_quests() -> Array[QuestData]:
	var out: Array[QuestData] = []
	for v in _quests.values():
		out.append(v)

	return out

func get_recipe(id: StringName) -> RecipeData:
	return _recipes.get(id)

func get_all_recipes() -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	for v in _recipes.values():
		out.append(v)

	return out

func get_upgrade(id: StringName) -> UpgradeData:
	return _upgrades.get(id)

func get_all_upgrades() -> Array[UpgradeData]:
	var out: Array[UpgradeData] = []
	for v in _upgrades.values():
		out.append(v)

	return out

## Resolves any id that can occupy an InventoryManager stack, whichever kind
## it is. Use this instead of get_item() anywhere the id came from inventory,
## a shop list, or a drop table — those can all be gear.
func get_inventory_item(id: StringName) -> InventoryItemData:
	var item: InventoryItemData = _items.get(id)
	return item if item != null else _equipment.get(id)

func get_status_effect(id: StringName) -> StatusEffectData:
	return _status_effects.get(id)

func get_all_status_effects() -> Array[StatusEffectData]:
	var out: Array[StatusEffectData] = []
	for v in _status_effects.values():
		out.append(v)

	return out

func get_equipment(id: StringName) -> EquipmentData:
	return _equipment.get(id)

func get_all_equipment() -> Array[EquipmentData]:
	var out: Array[EquipmentData] = []
	for v in _equipment.values():
		out.append(v)

	return out
