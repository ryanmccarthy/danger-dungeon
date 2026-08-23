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
			if ch == "#":
				_add_wall(parent, world_pos, tile_size, theme)
			else:
				_add_floor(parent, world_pos, tile_size, theme)
				_add_ceiling(parent, world_pos, tile_size, theme)
				if ch == "R":
					_add_exit_marker(parent, world_pos, tile_size, theme)

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
