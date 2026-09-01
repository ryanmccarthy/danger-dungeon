@tool
class_name StatusEffectData
extends Resource

## An inflictable condition (blind, poison, ...)
##
## Landing a status is resisted by the target's `res`

@export var status_id: StringName
@export var display_name: String
@export_multiline var description: String = ""
@export var icon_color: Color = Color.WHITE
## Rounds in battle, or dungeon tile-steps out of it. 0 means "until cured".
@export var default_duration: int = 3
## False: cleared when the battle resolves. True: follows the party into the
## dungeon, ticks on every tile step, and is saved.
@export var persists_after_battle: bool = false

@export_group("Behavior")
## Multiplies the bearer's chance to land an attack. < 1.0 blinds.
@export var accuracy_mult: float = 1.0
## Damage taken per tick (per round in battle, per tile step in the dungeon).
@export var dot_damage: int = 0
## 0.0-1.0 chance the bearer loses their turn entirely.
@export var skip_turn_chance: float = 0.0
## 0.0-1.0 chance the bearer attacks their own side instead of acting.
@export var confuse_chance: float = 0.0
