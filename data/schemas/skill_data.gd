@tool
class_name SkillData
extends Resource

enum TargetType { SINGLE_ENEMY, ALL_ENEMIES, SINGLE_ALLY, ALL_ALLIES, SELF }
enum EffectType { DAMAGE, HEAL, BUFF, DEBUFF, LEARN_SKILL }
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
@export var accuracy: float = 1.0
## True for physical, contact-range attacks (basic Attack is always melee
## too, but that's hardcoded rather than a SkillData). False for anything
## with no meaningful range concept — heals, buffs, debuffs, magic, etc.
## Melee skills can't be used by a party member in the back row.
@export var is_melee: bool = false
## Meaningful only when LEARN_SKILL is in effect_type: 0.0-1.0 chance the
## caster learns a random skill from the target enemy's skill_pool.
@export var learn_chance: float = 0.0
@export var icon_color: Color = Color.WHITE
