extends Node

## Signal-only hub. No state. Decouples the dungeon/battle/hub scenes so
## none of them needs a direct reference to another.
@warning_ignore_start("unused_signal")

signal encounter_triggered(enemy_ids: Array, is_fixed: bool)
signal battle_won(rewards: Dictionary)
signal battle_lost()
signal battle_fled()

signal player_departed_university(area_id: StringName)
signal player_returned_to_university()

signal hunger_changed(student_id: StringName, new_value: float)
signal hunger_hit_zero(student_id: StringName)

signal student_downed(student_id: StringName)
signal student_revived(student_id: StringName)
signal student_died(student_id: StringName)
signal party_wiped()
signal game_over()

signal quest_started(quest_id: StringName)
signal quest_progress_updated(quest_id: StringName)
signal quest_completed(quest_id: StringName)

signal supplies_changed(new_amount: int)
signal inventory_changed(item_id: StringName, new_count: int)

signal upgrade_unlocked(upgrade_id: StringName)

signal dungeon_tile_moved(coord: Vector2i, facing: Vector2i)
