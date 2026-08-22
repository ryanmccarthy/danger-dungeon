@tool
class_name AreaData
extends Resource

## grid_layout: array of equal-length row strings. '#'=wall '.'=floor
## 'E'=encounter-eligible floor 'U'=return-to-university exit tile.
## encounter_table entries: {"enemy": EnemyData, "weight": float}

@export var area_id: StringName
@export var display_name: String
@export var distance_from_university: int = 1

@export_group("Layout")
@export var grid_layout: Array[String] = []
@export var spawn_coord: Vector2i = Vector2i.ZERO
@export var spawn_facing: Vector2i = Vector2i.UP

@export_group("Encounters")
@export var encounter_table: Array[Dictionary] = []
@export var encounter_rate: float = 0.15

@export_group("Presentation")
@export var visual_theme: DungeonVisualThemeData
