extends Node3D

## First-person tile-stepped grid crawler. Wall checks are authoritative
## against AreaData.grid_layout (colliders from DungeonBuilder are a
## physical backstop, not the source of truth). Hooks HungerSystem and
## encounter rolls on every successful move.

const MOVE_TIME := 0.18
const TURN_TIME := 0.13

@onready var _player: CharacterBody3D = $Player
@onready var _camera: Camera3D = $Player/Camera3D
@onready var _geometry_root: Node3D = $GeometryRoot
@onready var _info_label: Label = $UILayer/HUD/InfoLabel
@onready var _automap: Control = $UILayer/HUD/AutoMapPanel

var area: AreaData
var grid_position: Vector2i
var facing: Vector2i
var visited: Dictionary = {}
var _busy: bool = false
var _tile_size: float = 4.0

func enter_state(_context: Dictionary = {}) -> void:
	area = GameState.current_area
	if area == null:
		push_warning("[DungeonCrawl] entered with no current_area set")
		return
	_tile_size = area.visual_theme.tile_size if area.visual_theme else 4.0
	DungeonBuilder.build(_geometry_root, area)
	grid_position = GameState.current_dungeon_position
	facing = GameState.current_dungeon_facing
	if facing == Vector2i.ZERO:
		facing = Vector2i(0, -1)
	visited[grid_position] = true
	_place_player_instant()
	_refresh_hud()
	_refresh_automap()

func _process(_delta: float) -> void:
	if _busy or area == null:
		return
	if Input.is_action_just_pressed("move_forward"):
		_try_move(facing)
	elif Input.is_action_just_pressed("move_back"):
		_try_move(-facing)
	elif Input.is_action_just_pressed("turn_left"):
		_turn(_turn_left(facing))
	elif Input.is_action_just_pressed("turn_right"):
		_turn(_turn_right(facing))

func _is_walkable(coord: Vector2i) -> bool:
	if coord.y < 0 or coord.y >= area.grid_layout.size():
		return false
	var row: String = area.grid_layout[coord.y]
	if coord.x < 0 or coord.x >= row.length():
		return false
	return row[coord.x] != TileTypes.WALL

func _tile_char(coord: Vector2i) -> String:
	if coord.y < 0 or coord.y >= area.grid_layout.size():
		return TileTypes.WALL
	var row: String = area.grid_layout[coord.y]
	if coord.x < 0 or coord.x >= row.length():
		return TileTypes.WALL
	return row[coord.x]

func _try_move(direction: Vector2i) -> void:
	var target := grid_position + direction
	if not _is_walkable(target):
		return
	_busy = true
	grid_position = target
	visited[grid_position] = true
	GameState.current_dungeon_position = grid_position
	var tween := create_tween()
	tween.tween_property(_player, "position", _world_pos(grid_position), MOVE_TIME)
	await tween.finished
	_busy = false
	HungerSystem.tick_step(PartyManager.get_active_party_ids())
	_refresh_hud()
	_refresh_automap()
	if PartyManager.is_party_wiped():
		return # GameState's own listener handles the forced switch to Hub.
	var ch := _tile_char(grid_position)
	if ch == TileTypes.RETURN:
		GameState.return_to_university()
		return
	if ch == TileTypes.ENCOUNTER and randf() < area.encounter_rate:
		_start_encounter()

func _turn(new_facing: Vector2i) -> void:
	_busy = true
	facing = new_facing
	GameState.current_dungeon_facing = facing
	var current_yaw := _player.rotation.y
	var target_yaw := current_yaw + wrapf(_facing_to_yaw(facing) - current_yaw, -PI, PI)
	var tween := create_tween()
	tween.tween_property(_player, "rotation:y", target_yaw, TURN_TIME)
	await tween.finished
	_busy = false
	_refresh_automap()

func _start_encounter() -> void:
	var enemy_id := _pick_weighted_enemy()
	if enemy_id == StringName():
		return
	GameState.request_battle([enemy_id], {"position": grid_position, "facing": facing})

func _pick_weighted_enemy() -> StringName:
	var total := 0.0
	for entry in area.encounter_table:
		total += float(entry["weight"])
	if total <= 0.0:
		return StringName()
	var roll := randf() * total
	for entry in area.encounter_table:
		roll -= float(entry["weight"])
		if roll <= 0.0:
			return entry["enemy_id"]
	return area.encounter_table[-1]["enemy_id"]

func _world_pos(coord: Vector2i) -> Vector3:
	return Vector3(coord.x * _tile_size, 0.0, coord.y * _tile_size)

func _facing_to_yaw(dir: Vector2i) -> float:
	if dir == CompassDirection.NORTH:
		return 0.0
	if dir == CompassDirection.WEST:
		return PI / 2.0
	if dir == CompassDirection.SOUTH:
		return PI

	return -PI / 2.0 # EAST

func _turn_right(dir: Vector2i) -> Vector2i:
	if dir == CompassDirection.NORTH:
		return CompassDirection.EAST
	if dir == CompassDirection.EAST:
		return CompassDirection.SOUTH
	if dir == CompassDirection.SOUTH:
		return CompassDirection.WEST

	return CompassDirection.NORTH

func _turn_left(dir: Vector2i) -> Vector2i:
	if dir == CompassDirection.NORTH:
		return CompassDirection.WEST
	if dir == CompassDirection.WEST:
		return CompassDirection.SOUTH
	if dir == CompassDirection.SOUTH:
		return CompassDirection.EAST

	return CompassDirection.NORTH

func _place_player_instant() -> void:
	_player.position = _world_pos(grid_position)
	_player.rotation.y = _facing_to_yaw(facing)

func _refresh_hud() -> void:
	var hunger_text := ""
	for id in PartyManager.get_active_party_ids():
		var s := PartyManager.get_student(id)
		if s != null:
			hunger_text += "%s: %d\n" % [s.display_name, int(s.current_hunger)]
	_info_label.text = "%s\nSupplies: %d\n%s" % [area.display_name, InventoryManager.supplies, hunger_text]

func _refresh_automap() -> void:
	if _automap.has_method("set_state"):
		_automap.set_state(area, visited, grid_position, facing)
