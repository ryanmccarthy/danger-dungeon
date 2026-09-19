extends HubRoomBase

## Departure Board: pick which known floor the bus drops the party on. Deeper
## floors show up once the party has walked down to them at least once — the gate
## is ExplorationManager.is_departure_unlocked, which is the only place that
## decides what "unlocked" means.

func _build() -> void:
	var blocker := _departure_blocker()
	if blocker != "":
		_add_header(blocker)

	var listed := 0
	for dungeon_id in ContentDatabase.get_dungeon_ids():
		var unlocked := ContentDatabase.get_dungeon_floors(dungeon_id).filter(
				func(a: AreaData) -> bool: return ExplorationManager.is_departure_unlocked(a))
		if unlocked.is_empty():
			continue

		_add_header(unlocked[0].dungeon_display_name)
		for a in unlocked:
			var cost := InventoryManager.get_travel_cost(a)
			_add_row("B%dF  %s — %d supplies" % [a.floor_number, a.display_name, cost],
					"Depart", func(): _on_depart(a),
					blocker == "" and InventoryManager.supplies >= cost)
			listed += 1

	if listed == 0:
		_add_row("(no route off campus is open)")

## Was inline in university_hub._on_depart_pressed(); now it gates every row at
## once instead of being re-checked per destination.
func _departure_blocker() -> String:
	if PartyManager.get_living_roster().is_empty():
		return "Game Over: all students have perished."
	if PartyManager.get_active_party().is_empty():
		return "Assign at least one student at the Dorm before departing."

	return ""

func _on_depart(area: AreaData) -> void:
	if GameState.depart_university(area):
		# GameRoot's mode transition frees this whole hub scene at its midpoint,
		# so this label is the last thing shown before the wipe.
		_status_label.text = "Departing for %s." % area.display_name
		return

	_status_label.text = "Not enough supplies (need %d)." % InventoryManager.get_travel_cost(area)
	_refresh()

func _refresh() -> void:
	super._refresh()
	_refresh_hud() # updates supplies display
