extends HubRoomBase

## Quest Board: read-only list of active and completed quests.

func _build() -> void:
	_add_header("Active")

	for id in QuestManager.active_quest_ids:
		var q: QuestData = ContentDatabase.get_quest(id)
		_add_row("%s — %d / %d — %s" % [q.display_name, QuestManager.get_quest_progress(id), q.objective_count, q.description])

	if QuestManager.active_quest_ids.is_empty():
		_add_row("(none active)")

	_add_header("Completed")

	for id in QuestManager.completed_quest_ids:
		var q: QuestData = ContentDatabase.get_quest(id)
		_add_row("%s — done" % q.display_name)

	if QuestManager.completed_quest_ids.is_empty():
		_add_row("(none yet)")
