class_name CombatMath
extends RefCounted

## Row-based damage/heal math for the vertical slice. Enemies use a single
## row here; only the party's front/back mechanic is implemented (documented
## future extension: give enemies rows too).

const BACK_ROW_PHYSICAL_DEFENSE_MULT := 0.6
const BACK_ROW_PHYSICAL_OFFENSE_MULT := 0.7

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
