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

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	_index_dir("res://data/students", _students, "student_id")
	_index_dir("res://data/classes", _classes, "class_id")
	_index_dir("res://data/skills", _skills, "skill_id")
	_index_dir("res://data/items", _items, "item_id")
	_index_dir("res://data/enemies", _enemies, "enemy_id")
	_index_dir("res://data/areas", _areas, "area_id")
	_index_dir("res://data/quests", _quests, "quest_id")
	_index_dir("res://data/recipes", _recipes, "recipe_id")
	_index_dir("res://data/upgrades", _upgrades, "upgrade_id")
	print("[ContentDatabase] students=%d classes=%d skills=%d items=%d enemies=%d areas=%d quests=%d recipes=%d upgrades=%d" % [
		_students.size(), _classes.size(), _skills.size(), _items.size(),
		_enemies.size(), _areas.size(), _quests.size(), _recipes.size(), _upgrades.size()
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

func get_student(id: StringName) -> StudentData:
	return _students.get(id)

func get_all_students() -> Array[StudentData]:
	var out: Array[StudentData] = []
	for v in _students.values():
		out.append(v)
	return out

func get_class_data(id: StringName) -> StudentClassData:
	return _classes.get(id)

func get_skill(id: StringName) -> SkillData:
	return _skills.get(id)

func get_item(id: StringName) -> ItemData:
	return _items.get(id)

func get_enemy(id: StringName) -> EnemyData:
	return _enemies.get(id)

func get_area(id: StringName) -> AreaData:
	return _areas.get(id)

func get_quest(id: StringName) -> QuestData:
	return _quests.get(id)

func get_recipe(id: StringName) -> RecipeData:
	return _recipes.get(id)

func get_upgrade(id: StringName) -> UpgradeData:
	return _upgrades.get(id)
