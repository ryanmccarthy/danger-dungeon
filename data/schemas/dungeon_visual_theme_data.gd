@tool
class_name DungeonVisualThemeData
extends Resource

## The one seam between dungeon gameplay logic and its look. Swap materials
## here to reskin an area without touching DungeonBuilder or grid_controller.

@export var wall_material: Material
@export var floor_material: Material
@export var ceiling_material: Material
@export var exit_marker_color: Color = Color.YELLOW
## Stair markers. Defaults are deliberate so existing themes need no edit.
@export var stair_up_color: Color = Color(0.42, 0.78, 1.0)
@export var stair_down_color: Color = Color(0.95, 0.45, 0.3)
@export var tile_size: float = 4.0
@export var has_ceiling: bool = true
