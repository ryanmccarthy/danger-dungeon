extends Node3D

## Wall checks are authoritative against AreaData.grid_layout
## (colliders from DungeonBuilder are a physical backstop,
## not the source of truth). Hooks HungerSystem and
## encounter rolls on every successful move.

const MOVE_TIME := 0.18
const TURN_TIME := 0.13
## Footsteps get a small random pitch shift so repeated steps do not sound looped.
const FOOTSTEP_PITCH_RANGE := Vector2(0.92, 1.08)

## Assigned in dungeon_crawl.tscn; one is picked at random per step.
@export var footstep_sounds: Array[AudioStream] = []

@onready var _music: AudioStreamPlayer = $MusicPlayer
@onready var _footsteps: AudioStreamPlayer = $FootstepPlayer
@onready var _player: CharacterBody3D = $Player
@onready var _geometry_root: Node3D = $GeometryRoot
@onready var _info_label: Label = $UILayer/HUD/InfoLabel
@onready var _automap: Control = $UILayer/HUD/AutoMapPanel

var area: AreaData
var grid_position: Vector2i
var facing: Vector2i
var visited: Dictionary = {}
var _busy: bool = false
var _tile_size: float = 4.0
var _last_footstep_index: int = -1
## One-line feedback for a tile that did nothing (a caved-in stair, an
## unaffordable trip home). Shown on the HUD until the party moves again.
var _note_text: String = ""

# Adjustable weight for random encounter start event
# Currently just prevents edge cases like successive encounters or zero encounters
var _encounter_weight: float = 1.0

func _ready() -> void:
	_music.finished.connect(func(): _music.play())
	_music.play()

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

	# Fog of war is kept per floor on GameState, since this whole scene is rebuilt
	# from scratch on every floor change and every battle return.
	visited = GameState.visited_by_area.get(area.area_id, {})
	visited[grid_position] = true
	GameState.visited_by_area[area.area_id] = visited
	_place_player_instant()
	_refresh_hud()
	_refresh_automap()

func _process(_delta: float) -> void:
	# ScreenTransition check keeps steps (and their hunger ticks / encounter
	# rolls) from landing during a transition — _busy is already false by the
	# time an encounter hands off to the battle scene.
	if _busy or area == null or ScreenTransition.is_busy:
		return

	if Input.is_action_just_pressed("move_forward"):
		_try_move(facing)
	elif Input.is_action_just_pressed("move_back"):
		_try_move(-facing)
	elif Input.is_action_just_pressed("turn_left"):
		_turn(_turn_left(facing))
	elif Input.is_action_just_pressed("turn_right"):
		_turn(_turn_right(facing))
	elif Input.is_action_just_pressed("strafe_left"):
		_try_move(_turn_left(facing))
	elif Input.is_action_just_pressed("strafe_right"):
		_try_move(_turn_right(facing))

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
	_note_text = ""

	grid_position = target
	visited[grid_position] = true
	GameState.current_dungeon_position = grid_position

	var tween := create_tween()
	tween.tween_property(_player, "position", _world_pos(grid_position), MOVE_TIME)
	_play_footstep() # Play before awaiting so sound about matches with movement
	await tween.finished

	_busy = false

	HungerSystem.tick_step(PartyManager.get_active_party_ids())
	# Statuses flagged persists_after_battle (poison) bleed and decay per
	# tile step out here, the way they do per round inside a battle.
	PartyManager.tick_persistent_statuses()
	_refresh_hud()
	_refresh_automap()

	if PartyManager.is_party_wiped():
		PartyManager.resolve_field_wipe()
		return # GameState's own listener (on party_wiped) handles the forced switch to Hub.

	var ch := _tile_char(grid_position)
	if ch == TileTypes.RETURN:
		_leave_dungeon()
		return

	if ch == TileTypes.STAIR_UP or ch == TileTypes.STAIR_DOWN:
		_take_stairs(ch)
		return

	if ch == TileTypes.ENCOUNTER and _check_for_encounter():
		_start_encounter()

## You arrive on the destination floor's mirrored stair, so the tile you left is
## the tile you come back to. Tile effects only ever fire from _try_move, never
## from enter_state() — that is what stops an arrival bouncing straight back.
## Returning right after the call matters: the node is freed at the transition's
## midpoint, exactly as on the RETURN path.
func _take_stairs(stair_char: String) -> void:
	var target := ContentDatabase.get_stair_target(area, stair_char)
	if target == null:
		# Stairs are strictly floor-to-floor; R is the only way back to campus.
		push_warning("[DungeonCrawl] %s has a '%s' with no floor on the other side" % [area.area_id, stair_char])
		_note("The stairway is caved in.")
		return

	var arrival := TileTypes.STAIR_DOWN if stair_char == TileTypes.STAIR_UP else TileTypes.STAIR_UP
	GameState.travel_to_floor(target, arrival)

## return_to_university() spends supplies scaled by how deep the party is and can
## simply fail. Unreported, as it was, the exit tile just reads as broken.
func _leave_dungeon() -> void:
	if not GameState.return_to_university():
		_note("Not enough supplies for the trip home (need %d)." % InventoryManager.get_travel_cost(area))

func _note(text: String) -> void:
	_note_text = text
	_refresh_hud()

func _play_footstep() -> void:
	if footstep_sounds.is_empty():
		return

	var index := randi() % footstep_sounds.size()
	if footstep_sounds.size() > 1 and index == _last_footstep_index:
		# avoid playing same sound twice in a row
		index = (index + 1) % footstep_sounds.size()

	_last_footstep_index = index
	_footsteps.stream = footstep_sounds[index]
	_footsteps.pitch_scale = randf_range(FOOTSTEP_PITCH_RANGE.x, FOOTSTEP_PITCH_RANGE.y)
	_footsteps.play()

func _check_for_encounter() -> bool:
	_encounter_weight -= 0.1
	if randf() + _encounter_weight <= area.encounter_rate:
		_encounter_weight = randf() - 0.1
		return true

	return false

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
	var enemy_ids := _pick_weighted_encounter()
	if enemy_ids.is_empty():
		return

	GameState.request_battle(enemy_ids, {"position": grid_position, "facing": facing})

func _pick_weighted_encounter() -> Array:
	var enemies = []
	var total := randi_range(1, area.max_enemy_count) # how many enemies in the fight
	for i in range(total):
		enemies.append(_pick_weighted_enemy_id())

	return enemies

func _pick_weighted_enemy_id() -> StringName:
	var weight_total := 0.0
	for entry in area.encounter_table:
		weight_total += float(entry["weight"])

	if weight_total <= 0.0:
		return area.encounter_table[-1]["enemy_id"]

	var roll := randf() * weight_total
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
	if _note_text != "":
		_info_label.text += "\n" + _note_text

func _refresh_automap() -> void:
	if _automap.has_method("set_state"):
		_automap.set_state(area, visited, grid_position, facing)
