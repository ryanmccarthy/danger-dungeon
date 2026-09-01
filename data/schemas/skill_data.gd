@tool
class_name SkillData
extends Resource

enum TargetType { SINGLE_ENEMY, ALL_ENEMIES, SINGLE_ALLY, ALL_ALLIES, SELF }
## Serialized as raw ints in every skill .tres — only ever append here,
## never insert, or all 106 authored skills silently re-map.
enum EffectType { DAMAGE, HEAL, BUFF, DEBUFF, LEARN_SKILL, INFLICT_STATUS, CURE_STATUS }
enum DamageSchool { PHYSICAL, MAGICAL }

@export var skill_id: StringName
@export var display_name: String
@export_multiline var description: String = ""
@export var mp_cost: int = 0
@export var target_type: TargetType = TargetType.SINGLE_ENEMY
@export var power: float = 1.0
@export var effect_type: Array[EffectType] = [EffectType.DAMAGE]
@export var damage_school: DamageSchool = DamageSchool.PHYSICAL
@export var debuff_stat_affected: String = Stat.NONE
@export var debuff_amount: int = -0
@export var debuff_duration: int = 0
@export var buff_amount: int = 0
@export var buff_duration: int = 0
@export var buff_stat_affected: String = Stat.NONE
## 0.0-1.0 chance this skill connects at all. Multiplied by the caster's
## status effects (blind halves it), so a 1.0 here still never misses.
@export var accuracy: float = 1.0
## Meaningful with INFLICT_STATUS or CURE_STATUS in effect_type: which status
## (an id from data/status_effects/) to apply or clear.
@export var status_to_inflict: StringName = &""
## Chance the status lands before the target's `res` resists it. 0.0 with
## INFLICT_STATUS set is read as "always attempt".
@export var status_chance: float = 0.0
## 0 falls back to the status's own default_duration.
@export var status_duration: int = 0
## True for close-range attacks (basic Attack is always melee
## too, but that's hardcoded rather than a SkillData).
## False for everything else — heals, buffs, debuffs, magic, etc.
## Melee skills can't be used by a party member in the back row.
@export var is_melee: bool = false
## Meaningful only when LEARN_SKILL is in effect_type: 0.0-1.0 chance the
## caster learns a random skill from the target enemy's skill_pool.
@export var learn_chance: float = 0.0
@export var icon_color: Color = Color.WHITE
