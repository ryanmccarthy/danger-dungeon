@tool
class_name AreaData
extends Resource

## grid_layout: array of equal-length row strings.
## See TileTypes for possible values
## encounter_table entries: {"enemy_id": StringName, "weight": float}
## A battle draws randi_range(1, max_enemy_count) enemies, each an
## independent weighted pick from this table (see _pick_weighted_enemy_id
## in dungeon_crawl.gd) — so entries can repeat within one encounter.

@export var area_id: StringName
@export var display_name: String
@export var distance_from_university: int = 1

@export_group("Layout")
@export var grid_layout: Array[String] = [] # see above
@export var spawn_coord: Vector2i = Vector2i.ZERO
@export var spawn_facing: Vector2i = Vector2i.UP

@export_group("Encounters")
@export var encounter_table: Array[Dictionary] = []
@export var encounter_rate: float = 0.15
@export var max_enemy_count: int = 3

@export_group("Presentation")
@export var visual_theme: DungeonVisualThemeData
