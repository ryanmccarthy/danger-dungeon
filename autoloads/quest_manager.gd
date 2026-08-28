extends Node

var active_quest_ids: Array[StringName] = []
var completed_quest_ids: Array[StringName] = []
var _progress: Dictionary = {}

func _ready() -> void:
	start_quest(&"main_001_first_contact")

func start_quest(id: StringName) -> void:
	if id in active_quest_ids or id in completed_quest_ids:
		return
	active_quest_ids.append(id)
	_progress[id] = 0
	EventBus.quest_started.emit(id)

func report_progress(objective_type: int, target_id: StringName, amount: int = 1) -> void:
	for id in active_quest_ids.duplicate():
		var quest: QuestData = ContentDatabase.get_quest(id)
		if quest == null:
			continue
		if quest.objective_type != objective_type or quest.objective_target_id != target_id:
			continue
		_progress[id] = _progress.get(id, 0) + amount
		EventBus.quest_progress_updated.emit(id)
		if _progress[id] >= quest.objective_count:
			_complete_quest(id, quest)

func _complete_quest(id: StringName, quest: QuestData) -> void:
	active_quest_ids.erase(id)
	completed_quest_ids.append(id)
	InventoryManager.add_supplies(quest.reward_supplies)
	for item in quest.reward_items:
		InventoryManager.add_item(item.id)
	EventBus.quest_completed.emit(id)

func is_quest_complete(id: StringName) -> bool:
	return id in completed_quest_ids

func get_quest_progress(id: StringName) -> int:
	return _progress.get(id, 0)
