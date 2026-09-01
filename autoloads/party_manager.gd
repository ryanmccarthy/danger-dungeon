extends Node

## 26-student roster, front/back formation, and battle-relevant status
## transitions. DOWNED = battle KO, revivable at the Nurse's Office.
## DEAD = permanent, only ever caused by hunger-zero damage over time.

signal party_changed()

const MAX_FRONT := 3
const MAX_BACK := 3

var roster: Array[StudentData] = []
var front_row_ids: Array[StringName] = []
var back_row_ids: Array[StringName] = []
## student_id -> {status_id: rounds_remaining}. StudentData.status_effects
## holds which statuses are active (what the UI reads); this holds their
## clocks. A remaining of 0 means "until cured" and never decays.
var status_durations: Dictionary = {}

func _ready() -> void:
	roster = ContentDatabase.get_all_students()
	_default_formation()

func _default_formation() -> void:
	front_row_ids.clear()
	back_row_ids.clear()
	for s in roster:
		if not s.is_starter:
			continue

		var pref: int = s.student_class.preferred_row
		if pref == StudentClassData.RowPreference.BACK and back_row_ids.size() < MAX_BACK:
			back_row_ids.append(s.student_id)
		elif front_row_ids.size() < MAX_FRONT:
			front_row_ids.append(s.student_id)
		elif back_row_ids.size() < MAX_BACK:
			back_row_ids.append(s.student_id)

func get_student(id: StringName) -> StudentData:
	for s in roster:
		if s.student_id == id:
			return s

	return null

func get_party() -> Array[StudentData]:
	var party = []
	for s in front_row_ids:
		party.append(get_student(s))
	for s in back_row_ids:
		party.append(get_student(s))

	return party

func is_in_party(id: StringName) -> bool:
	if is_in_front_row(id) or is_in_back_row(id):
		return true

	return false

func is_in_front_row(id: StringName) -> bool:
	return front_row_ids.has(id)

func is_in_back_row(id: StringName) -> bool:
	return back_row_ids.has(id)

func get_living_roster() -> Array[StudentData]:
	var out: Array[StudentData] = []
	for s in roster:
		if s.is_alive():
			out.append(s)

	return out

func get_usable_roster() -> Array[StudentData]:
	var out: Array[StudentData] = []
	for s in roster:
		if s.is_usable():
			out.append(s)

	return out

func get_active_party_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.append_array(front_row_ids)
	out.append_array(back_row_ids)
	return out

func get_active_party() -> Array[StudentData]:
	var out: Array[StudentData] = []
	for id in get_active_party_ids():
		var s := get_student(id)
		if s != null:
			out.append(s)

	return out

func assign_to_party(id: StringName, row: String, slot: int = -1) -> bool:
	var student := get_student(id)
	if student == null or not student.is_usable():
		return false

	remove_from_party(id)
	var target := front_row_ids if row == "front" else back_row_ids
	var cap := MAX_FRONT if row == "front" else MAX_BACK
	if target.size() >= cap:
		return false

	if slot >= 0 and slot <= target.size():
		target.insert(slot, id)
	else:
		target.append(id)

	party_changed.emit()
	return true

func remove_from_party(id: StringName) -> void:
	front_row_ids.erase(id)
	back_row_ids.erase(id)

func swap_party_slots(a: StringName, b: StringName) -> void:
	var a_front := front_row_ids.has(a)
	var a_idx: int = (front_row_ids if a_front else back_row_ids).find(a)
	var b_front := front_row_ids.has(b)
	var b_idx: int = (front_row_ids if b_front else back_row_ids).find(b)

	if a_idx == -1 or b_idx == -1:
		return

	(front_row_ids if a_front else back_row_ids)[a_idx] = b
	(front_row_ids if b_front else back_row_ids)[b_idx] = a
	party_changed.emit()

func apply_damage(id: StringName, amount: int, is_hunger_dot: bool = false) -> void:
	var s := get_student(id)
	if s == null or not s.is_alive():
		return

	s.current_hp = max(0, s.current_hp - amount)
	if s.current_hp == 0:
		if is_hunger_dot:
			kill_student(id)
		elif not s.is_downed():
			s.status = StudentData.Status.DOWNED
			EventBus.student_downed.emit(id)

func get_effective_max_hp(id: StringName) -> int:
	## Base growth (StudentData.max_hp) plus any equipped max-HP bonuses.
	## Equipment never mutates the base field, so this is the ceiling every
	## heal/clamp/HP readout should use.
	var s := get_student(id)
	if s == null:
		return 0

	return max(1, s.max_hp + int(EquipmentManager.get_stat_bonus(id, "max_hp")))

func get_effective_max_mp(id: StringName) -> int:
	var s := get_student(id)
	if s == null:
		return 0

	return max(0, s.max_mp + int(EquipmentManager.get_stat_bonus(id, "max_mp")))

func heal_student(id: StringName, amount: int) -> void:
	var s := get_student(id)
	if s == null or not s.is_alive():
		return

	s.current_hp = min(get_effective_max_hp(id), s.current_hp + amount)

# ------------------------------------------------------------ status effects
func add_status(id: StringName, status_id: StringName, duration: int = 0) -> bool:
	## duration of 0 falls back to the status's own default_duration.
	## Re-applying an active status refreshes its clock rather than stacking.
	var s := get_student(id)
	if s == null or not s.is_alive():
		return false

	var data := ContentDatabase.get_status_effect(status_id)
	if data == null:
		push_warning("[PartyManager] unknown status effect '%s'" % status_id)
		return false

	var turns: int = duration if duration > 0 else data.default_duration
	if not status_durations.has(id):
		status_durations[id] = {}

	var clocks: Dictionary = status_durations[id]
	clocks[status_id] = max(turns, int(clocks.get(status_id, 0)))
	if s.status_effects.has(status_id):
		return true

	s.status_effects.append(status_id)
	EventBus.status_applied.emit(id, status_id)
	return true

func remove_status(id: StringName, status_id: StringName) -> void:
	var s := get_student(id)
	if s == null or not s.status_effects.has(status_id):
		return

	s.status_effects.erase(status_id)
	if status_durations.has(id):
		status_durations[id].erase(status_id)
		if status_durations[id].is_empty():
			status_durations.erase(id)

	EventBus.status_removed.emit(id, status_id)

func has_status(id: StringName, status_id: StringName) -> bool:
	var s := get_student(id)
	return s != null and s.status_effects.has(status_id)

func get_statuses(id: StringName) -> Array[StringName]:
	var s := get_student(id)
	if s == null:
		return []

	return s.status_effects

func get_status_remaining(id: StringName, status_id: StringName) -> int:
	return int(status_durations.get(id, {}).get(status_id, 0))

func clear_statuses(id: StringName, temporary_only: bool = false) -> void:
	## temporary_only leaves anything flagged persists_after_battle in place —
	## that's the battle-end cleanup. Omit it to cure everything (resting).
	var s := get_student(id)
	if s == null:
		return

	for status_id in s.status_effects.duplicate():
		if temporary_only:
			var data := ContentDatabase.get_status_effect(status_id)
			if data != null and data.persists_after_battle:
				continue

		remove_status(id, status_id)

func tick_statuses(id: StringName) -> Array[StringName]:
	## Takes one tick off every timed status; returns the ids that just expired
	## (already removed). Callers own the logging.
	var expired: Array[StringName] = []
	var clocks: Dictionary = status_durations.get(id, {})
	for status_id in clocks.keys():
		var remaining: int = int(clocks[status_id])
		if remaining <= 0:
			continue

		remaining -= 1
		if remaining <= 0:
			expired.append(status_id)
		else:
			clocks[status_id] = remaining

	for status_id in expired:
		remove_status(id, status_id)

	return expired

func tick_persistent_statuses() -> void:
	## Dungeon tile-step tick: damage-over-time and decay for statuses flagged
	## persists_after_battle. Battle runs its own per-round tick instead.
	for id in get_active_party_ids():
		var s := get_student(id)
		if s == null or not s.is_alive() or s.is_downed():
			continue

		var dot: int = 0
		for status_id in s.status_effects:
			var data := ContentDatabase.get_status_effect(status_id)
			if data != null and data.persists_after_battle:
				dot += data.dot_damage

		if dot > 0:
			apply_damage(id, dot)

		tick_statuses(id)

func revive_student(id: StringName, hp_amount: int) -> bool:
	var s := get_student(id)
	if s == null or not s.is_downed():
		return false

	s.status = StudentData.Status.ALIVE
	s.current_hp = max(1, hp_amount)
	clear_statuses(id)
	EventBus.student_revived.emit(id)
	return true

func kill_student(id: StringName) -> void:
	var s := get_student(id)
	if s == null or not s.is_alive():
		return

	s.status = StudentData.Status.DEAD
	s.current_hp = 0
	clear_statuses(id)
	remove_from_party(id)
	EventBus.student_died.emit(id)

	if get_living_roster().is_empty():
		EventBus.game_over.emit()
	elif is_party_wiped():
		EventBus.party_wiped.emit()

func is_party_wiped() -> bool:
	## True when either every party slot is DOWNED (battle loss) or when the
	## party has been whittled down to nobody (hunger deaths) — either way
	## there's no one left able to act.
	for id in get_active_party_ids():
		var s := get_student(id)
		if s != null and s.status == StudentData.Status.ALIVE:
			return false

	return true

func is_anyone_down() -> bool:
	for id in get_active_party_ids():
		var s := get_student(id)
		if s != null and s.is_downed():
			return true

	return false

func force_return_to_university() -> void:
	EventBus.party_wiped.emit()
