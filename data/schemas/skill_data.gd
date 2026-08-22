@tool
class_name SkillData
extends Resource

enum TargetType { SINGLE_ENEMY, ALL_ENEMIES, SINGLE_ALLY, ALL_ALLIES, SELF }
enum EffectType { DAMAGE, HEAL, BUFF, DEBUFF }
enum DamageSchool { PHYSICAL, MAGICAL }

@export var skill_id: StringName
@export var display_name: String
@export_multiline var description: String = ""
@export var mp_cost: int = 0
@export var target_type: TargetType = TargetType.SINGLE_ENEMY
@export var power: float = 1.0
@export var effect_type: EffectType = EffectType.DAMAGE
@export var damage_school: DamageSchool = DamageSchool.PHYSICAL
@export var stat_affected: String = ""
@export var buff_amount: float = 0.0
@export var buff_duration: int = 0
@export var accuracy: float = 1.0
@export var icon_color: Color = Color.WHITE
