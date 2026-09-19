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

@export_group("Dungeon")
## Floors of one dungeon share dungeon_id; floor_number is 1-based counting
## downward (B1F, B2F...). A stair leads to floor_number -/+ 1 within the same
## dungeon_id unless the matching override below is set. Only the shallowest
## listed floor's dungeon_display_name is read by the departure board.
## Author one '<' and at most one '>' per floor; R stays the way back to campus.
@export var dungeon_id: StringName
@export var dungeon_display_name: String
@export var floor_number: int = 1
@export var stair_up_target_id: StringName
@export var stair_down_target_id: StringName

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

## First match in scan order; Vector2i(-1, -1) when the char is absent.
func find_tile(ch: String) -> Vector2i:
	for y in grid_layout.size():
		var x := grid_layout[y].find(ch)
		if x != -1:
			return Vector2i(x, y)

	return Vector2i(-1, -1)
