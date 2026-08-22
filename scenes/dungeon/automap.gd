extends Control

## Fog-of-war minimap. dungeon_crawl.gd pushes state in via set_state();
## this is a pure _draw() readout, nothing interactive.

var area: AreaData
var visited: Dictionary = {}
var player_coord: Vector2i
var player_facing: Vector2i

const CELL := 14.0

func set_state(p_area: AreaData, p_visited: Dictionary, p_coord: Vector2i, p_facing: Vector2i) -> void:
	area = p_area
	visited = p_visited
	player_coord = p_coord
	player_facing = p_facing
	queue_redraw()

func _draw() -> void:
	if area == null:
		return
	var rows := area.grid_layout
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var coord := Vector2i(x, y)
			if not visited.has(coord):
				continue
			var ch := row[x]
			var color := Color("#2a2733") if ch == "#" else Color("#5c5468")
			if ch == "U":
				color = Color("#e0c14a")
			elif ch == "E":
				color = Color("#7a4a4a")
			draw_rect(Rect2(x * CELL + 8, y * CELL + 8, CELL - 1, CELL - 1), color)
	if visited.has(player_coord):
		var center := Vector2(player_coord.x * CELL + 8 + CELL * 0.5, player_coord.y * CELL + 8 + CELL * 0.5)
		draw_circle(center, CELL * 0.35, Color("#4ac9ff"))
		var tip := center + Vector2(player_facing.x, player_facing.y) * CELL * 0.7
		draw_line(center, tip, Color("#4ac9ff"), 2.0)
