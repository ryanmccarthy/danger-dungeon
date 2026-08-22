@tool
class_name QuestData
extends Resource

enum QuestType { MAIN, SIDE }
enum ObjectiveType { DEFEAT_ENEMY, REACH_TILE, COLLECT_ITEM }

@export var quest_id: StringName
@export var display_name: String
@export_multiline var description: String = ""
@export var quest_type: QuestType = QuestType.MAIN
@export var objective_type: ObjectiveType = ObjectiveType.DEFEAT_ENEMY
@export var objective_target_id: StringName
@export var objective_count: int = 1
@export var reward_supplies: int = 0
@export var reward_items: Array[ItemData] = []
@export var prerequisite_quest_id: StringName
