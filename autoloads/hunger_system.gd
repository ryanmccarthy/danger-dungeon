extends Node

## Hunger depletes with every dungeon tile step. At 0 the student takes
## repeated damage each further step until they die (permanent DEAD).

var hunger_depletion_per_tile: int = 1
var dot_damage_per_tile: int = 4

func tick_step(active_party_ids: Array) -> void:
	for id in active_party_ids:
		var s: StudentData = PartyManager.get_student(id)
		if s == null or s.status == StudentData.Status.DEAD:
			continue

		if s.current_hunger > 0.0:
			reduce_hunger(id, hunger_depletion_per_tile)
		else:
			PartyManager.apply_damage(id, dot_damage_per_tile, true)

func restore_hunger(id: StringName, amount: int) -> void:
	var s: StudentData = PartyManager.get_student(id)
	if s == null:
		return

	s.current_hunger = min(s.max_hunger, s.current_hunger + amount)
	EventBus.hunger_changed.emit(id, s.current_hunger)

func reduce_hunger(id: StringName, amount: int) -> void:
	var s: StudentData = PartyManager.get_student(id)
	if s == null:
		return

	s.current_hunger = max(0.0, s.current_hunger - amount)
	EventBus.hunger_changed.emit(id, s.current_hunger)
	if s.current_hunger == 0.0:
		EventBus.hunger_hit_zero.emit(id)

func get_hunger_ratio(id: StringName) -> float:
	var s: StudentData = PartyManager.get_student(id)
	if s == null or s.max_hunger <= 0.0:
		return 0.0
	return s.current_hunger / s.max_hunger
