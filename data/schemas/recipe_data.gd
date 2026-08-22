@tool
class_name RecipeData
extends Resource

## ingredients entries: {"item": ItemData, "count": int}

enum RecipeType { COOKING, LIBRARY_UNLOCK }

@export var recipe_id: StringName
@export var display_name: String
@export var recipe_type: RecipeType = RecipeType.COOKING
@export var ingredients: Array[Dictionary] = []
@export var result_item: ItemData
@export var result_upgrade: UpgradeData
@export var research_cost_supplies: int = 0
