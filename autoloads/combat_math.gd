class_name CombatMath
extends RefCounted

## Row-based damage/heal math for the vertical slice. Enemies use a single
## row here; only the party's front/back mechanic is implemented (documented
## future extension: give enemies rows too).

const BACK_ROW_PHYSICAL_DEFENSE_MULT := 0.6
const BACK_ROW_PHYSICAL_OFFENSE_MULT := 0.7
const MIN_HIT_CHANCE := 0.05
const MAX_HIT_CHANCE := 1.0

static func compute_damage(attacker_stat: int, defender_stat: int, power: float,
		school: int, attacker_in_back: bool, defender_in_back: bool) -> int:
	var raw: float = float(attacker_stat) * power - float(defender_stat) * 0.5
	if school == SkillData.DamageSchool.PHYSICAL:
		if attacker_in_back:
			raw *= BACK_ROW_PHYSICAL_OFFENSE_MULT
		if defender_in_back:
			raw *= BACK_ROW_PHYSICAL_DEFENSE_MULT
	return int(round(max(1.0, raw)))

static func compute_heal(caster_stat: int, power: float) -> int:
	return int(round(max(1.0, float(caster_stat) * power)))

static func compute_hit_chance(base_accuracy: float, attacker_accuracy_mult: float) -> float:
	"""
	0.0-1.0 chance an attack connects. `base_accuracy` is SkillData.accuracy;
	`attacker_accuracy_mult` is the product of the attacker's status effects,
	so an unafflicted attacker using a 1.0-accuracy skill always hits.
	"""
	return clamp(base_accuracy * attacker_accuracy_mult, MIN_HIT_CHANCE, MAX_HIT_CHANCE)

static func compute_status_land_chance(base_chance: float, target_res: int, attacker_luck: int) -> float:
	"""
	0.0-1.0 chance an inflicted status lands. `res` does double duty: it is
	already the magical-defense stat in compute_damage, and it is also the
	status-resist stat (see student_data.gd). One stat, both jobs. Luck nudges
	the roll in the attacker's favor.
	"""
	return clamp(base_chance - float(target_res) * 0.01 + float(attacker_luck) * 0.005, 0.05, 0.95)
