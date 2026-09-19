extends Node

## Central mode switch (Hub/Dungeon/Battle) and the depart/return/battle
## round-trip flow. GameRoot listens to mode_changed to swap scenes.

enum GameMode { TITLE, HUB, DUNGEON, BATTLE }

signal mode_changed(old_mode: GameMode, new_mode: GameMode, context: Dictionary)

var current_mode: GameMode = GameMode.TITLE
var current_area: AreaData
var current_dungeon_position: Vector2i
var current_dungeon_facing: Vector2i
var pending_encounter: Dictionary = {}
## Automap fog-of-war per floor, area_id -> {Vector2i: true}, so walking down
## and back up doesn't wipe the map you just made (the dungeon scene is rebuilt
## from scratch on every floor change and every battle return). Session-only:
## Vector2i keys don't survive JSON, so SaveManager doesn't carry this.
var visited_by_area: Dictionary = {}

func _ready() -> void:
	EventBus.party_wiped.connect(_on_party_wiped)

func _on_party_wiped() -> void:
	if current_mode != GameMode.HUB:
		change_mode(GameMode.HUB, {"forced": true})

func change_mode(new_mode: GameMode, context: Dictionary = {}) -> void:
	var old := current_mode
	current_mode = new_mode
	mode_changed.emit(old, new_mode, context)

func request_battle(enemy_ids: Array, return_context: Dictionary = {}) -> void:
	pending_encounter = {
		"enemy_ids": enemy_ids,
		"return_context": return_context,
	}
	EventBus.encounter_triggered.emit(enemy_ids, return_context.get("is_fixed", false))
	change_mode(GameMode.BATTLE, pending_encounter)

func resolve_battle(result: String, rewards: Dictionary = {}) -> void:
	match result:
		"WON":
			EventBus.battle_won.emit(rewards)
			for id in pending_encounter.get("enemy_ids", []):
				QuestManager.report_progress(QuestData.ObjectiveType.DEFEAT_ENEMY, id)
			_return_from_battle()
		"LOST":
			EventBus.battle_lost.emit()
			if PartyManager.is_party_wiped():
				PartyManager.resolve_field_wipe()
			else:
				_return_from_battle()
		"FLED":
			EventBus.battle_fled.emit()
			_return_from_battle()

func _return_from_battle() -> void:
	var ctx: Dictionary = pending_encounter.get("return_context", {})
	change_mode(GameMode.DUNGEON, ctx)

func depart_university(area: AreaData) -> bool:
	if area == null:
		return false
	var cost := InventoryManager.get_travel_cost(area)
	if not InventoryManager.spend_supplies(cost):
		return false
	_set_dungeon_location(area, area.spawn_coord, area.spawn_facing)
	EventBus.player_departed_university.emit(area.area_id)
	change_mode(GameMode.DUNGEON)
	return true

## Stair traversal. Charges nothing on purpose: descending already raises the
## eventual return_to_university() bill through the deeper floor's
## distance_from_university, so depth pays for itself on the way home. Facing is
## preserved; arrival is the mirrored stair on the target floor.
func travel_to_floor(target: AreaData, arrival_char: String) -> bool:
	if target == null:
		return false

	var coord := target.find_tile(arrival_char)
	if coord == Vector2i(-1, -1):
		push_warning("[GameState] %s has no '%s' tile; arriving at spawn_coord" % [target.area_id, arrival_char])
		coord = target.spawn_coord

	var from_id: StringName = current_area.area_id if current_area else StringName()
	_set_dungeon_location(target, coord, current_dungeon_facing)
	EventBus.dungeon_floor_changed.emit(target.area_id, from_id)
	change_mode(GameMode.DUNGEON, {"floor_change": true, "from_area_id": from_id})
	return true

## Discovery lives here rather than in dungeon_crawl.enter_state() so the dungeon
## scene stays out of the persistence business, and so merely returning from a
## battle can't re-fire it.
func _set_dungeon_location(area: AreaData, coord: Vector2i, facing: Vector2i) -> void:
	current_area = area
	current_dungeon_position = coord
	current_dungeon_facing = facing if facing != Vector2i.ZERO else area.spawn_facing
	ExplorationManager.discover(area.area_id)

func return_to_university() -> bool:
	if current_area == null:
		return false
	var cost := InventoryManager.get_travel_cost(current_area)
	if not InventoryManager.spend_supplies(cost):
		return false
	# Getting back inside is the reliable cure for anything that followed the
	# party out of the dungeon; without it persistent poison has no way out.
	for id in PartyManager.get_active_party_ids():
		PartyManager.clear_statuses(id)

	EventBus.player_returned_to_university.emit()
	change_mode(GameMode.HUB)
	return true
