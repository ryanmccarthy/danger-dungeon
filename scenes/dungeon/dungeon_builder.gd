class_name DungeonBuilder
extends RefCounted

## Procedurally builds primitive CSG geometry + wall colliders from an
## AreaData's grid_layout. The only thing that changes per visual theme is
## which materials get applied — gameplay code never touches meshes.

static func build(parent: Node3D, area: AreaData) -> void:
	for child in parent.get_children():
		child.queue_free()
	var theme: DungeonVisualThemeData = area.visual_theme
	var tile_size: float = theme.tile_size if theme else 4.0
	var rows := area.grid_layout
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			var world_pos := Vector3(x * tile_size, 0.0, y * tile_size)
			if ch == TileTypes.WALL:
				_add_wall(parent, world_pos, tile_size, theme)
			else:
				_add_floor(parent, world_pos, tile_size, theme)
				if not theme or theme.has_ceiling:
					_add_ceiling(parent, world_pos, tile_size, theme)
				if ch == TileTypes.SAFE:
					_add_safe_zone(parent, world_pos, tile_size, theme)
				if ch == TileTypes.EVENT:
					_add_event_marker(parent, world_pos, tile_size, theme)
				if ch == TileTypes.RETURN:
					_add_exit_marker(parent, world_pos, tile_size, theme)
				if ch == TileTypes.STAIR_UP:
					_add_stair_up(parent, world_pos, tile_size, theme)
				if ch == TileTypes.STAIR_DOWN:
					_add_stair_down(parent, world_pos, tile_size, theme)

static func _add_wall(parent: Node3D, pos: Vector3, size: float, theme: DungeonVisualThemeData) -> void:
	var box := CSGBox3D.new()
	box.size = Vector3(size, size * 1.2, size)
	box.position = pos + Vector3(0, size * 0.6, 0)
	if theme and theme.wall_material:
		box.material = theme.wall_material
	parent.add_child(box)
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)
	var coll := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size, size * 1.2, size)
	coll.shape = shape
	coll.position = Vector3(0, size * 0.6, 0)
	body.add_child(coll)

static func _add_floor(parent: Node3D, pos: Vector3, size: float, theme: DungeonVisualThemeData) -> void:
	var box := CSGBox3D.new()
	box.size = Vector3(size, 0.2, size)
	box.position = pos + Vector3(0, -0.1, 0)
	if theme and theme.floor_material:
		box.material = theme.floor_material
	parent.add_child(box)

static func _add_ceiling(parent: Node3D, pos: Vector3, size: float, theme: DungeonVisualThemeData) -> void:
	var box := CSGBox3D.new()
	box.size = Vector3(size, 0.2, size)
	box.position = pos + Vector3(0, size * 1.2 + 0.1, 0)
	if theme and theme.ceiling_material:
		box.material = theme.ceiling_material
	parent.add_child(box)

static func _add_safe_zone(_parent: Node3D, _pos: Vector3, _size: float, _theme: DungeonVisualThemeData) -> void:
	"""
	A tile on which no encounters can occur
	"""

static func _add_event_marker(_parent: Node3D, _pos: Vector3, _size: float, _theme: DungeonVisualThemeData) -> void:
	"""
	A tile that triggers a scripted event or story encounter
	"""

static func _add_exit_marker(parent: Node3D, pos: Vector3, size: float, theme: DungeonVisualThemeData) -> void:
	var marker := CSGCylinder3D.new()
	marker.radius = size * 0.3
	marker.height = 0.12
	marker.position = pos + Vector3(0, 0.06, 0)
	var mat := StandardMaterial3D.new()
	var col: Color = theme.exit_marker_color if theme else Color.YELLOW
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.5
	marker.material = mat
	parent.add_child(marker)

## Stairs deliberately get no StaticBody3D: grid_layout is the authority on
## walkability, and the party has to be able to stand on the tile for the stair to
## fire. Nothing here rises above ~0.6 either, so it can't climb into the view of
## a party standing on it — the camera sits at y = 1.6.
static func _add_stair_up(parent: Node3D, pos: Vector3, size: float, theme: DungeonVisualThemeData) -> void:
	var col: Color = theme.stair_up_color if theme else Color(0.42, 0.78, 1.0)
	# Footprint narrows as it rises: a small ziggurat that reads as climbing.
	_add_stair_step(parent, pos, size * 0.80, 0.30, 0.15, col, 1.2)
	_add_stair_step(parent, pos, size * 0.55, 0.30, 0.30, col, 1.2)
	_add_stair_step(parent, pos, size * 0.30, 0.30, 0.45, col, 1.2)

static func _add_stair_down(parent: Node3D, pos: Vector3, size: float, theme: DungeonVisualThemeData) -> void:
	var col: Color = theme.stair_down_color if theme else Color(0.95, 0.45, 0.3)
	# Flat concentric rings darkening to black at the centre, so it reads as a
	# shaft rather than a mound. The widest, brightest plate sits lowest and each
	# smaller/darker one stacks on top, which is what keeps all three visible —
	# a wide plate on top would simply hide the rest (true CSG subtraction would
	# need a CSGCombiner3D, which isn't worth it for primitive art).
	_add_stair_step(parent, pos, size * 0.80, 0.06, 0.03, col, 1.5)
	_add_stair_step(parent, pos, size * 0.55, 0.06, 0.06, col.darkened(0.6), 0.4)
	_add_stair_step(parent, pos, size * 0.30, 0.06, 0.09, Color.BLACK, 0.0)

static func _add_stair_step(parent: Node3D, pos: Vector3, footprint: float, height: float, y: float, col: Color, glow: float) -> void:
	var box := CSGBox3D.new()
	box.size = Vector3(footprint, height, footprint)
	box.position = pos + Vector3(0, y, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = glow

	box.material = mat
	parent.add_child(box)
