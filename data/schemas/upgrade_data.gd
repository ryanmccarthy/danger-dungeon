@tool
class_name UpgradeData
extends Resource

## Meta-progression tree node (bus repair, facility upgrades). Unlocked-state
## is tracked at runtime by UpgradeManager, never mutated on this shared resource.

enum Category { BUS, CAFETERIA, NURSE, LIBRARY, SHOP, DORM }
enum EffectType { REDUCE_TRAVEL_SUPPLY_COST, INCREASE_HEAL_AMOUNT, UNLOCK_RECIPE }

@export var upgrade_id: StringName
@export var display_name: String
@export_multiline var description: String = ""
@export var category: Category = Category.BUS
@export var tier: int = 1
@export var prerequisite_upgrade_id: StringName
@export var requires_quest_id: StringName
@export var effect_type: EffectType = EffectType.REDUCE_TRAVEL_SUPPLY_COST
@export var effect_value: float = 0.0
@export var unlock_cost_supplies: int = 0
