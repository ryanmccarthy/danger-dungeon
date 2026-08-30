@tool
class_name StudentData
extends CharacterData

## One of the 26-student roster. Defines starting/current stats.

## ALIVE/DOWNED are battle states (DOWNED is revivable at the Nurse's Office);
## DEAD is permanent and only ever caused by TPK.
enum Status { ALIVE, DOWNED, DEAD }

@export var student_id: StringName
@export var student_class: StudentClassData
## Skills learned on top of student_class.skill_ids (e.g. via the
## Valedictorian's Analyze). Stored as ids, not resources, so this is
## per-student state, never shared with other students of the same class.
@export var learned_skill_ids: Array[StringName] = []
@export var level: int = 1
@export var experience: int = 0
@export var xp_to_next_level: int = 100

@export_group("Stats")
@export var current_mp: int = max_mp
@export var current_hunger: float = 100.0
@export var max_hunger: float = 100.0

@export var atk: int = 8
@export var def: int = 8
@export var mag: int = 8

# Affects skill, status, and SAN-drain resistance
@export var res: int= 8
# Affects turn order and metabolism (and some classes' skills)
@export var spd: int = 8
# Affects many things (from crit chance to level up amount)
@export var luck: int = 8

@export_group("Meta")
@export var status: Status = Status.ALIVE
@export var portrait_color: Color = Color.WHITE
@export_multiline var bio_flavor: String = ""
@export var is_starter: bool = false # only used on new game init

func _init():
	is_student = true

func is_usable() -> bool:
	## Need to just refactor this out as it's always evaluated to the same thing
	## as is_alive(), but that sounds like a headache so TODO
	return is_alive()

func is_downed() -> bool:
	return status == Status.DOWNED

func is_alive() -> bool:
	return status != Status.DEAD

func add_experience(xp: int):
	experience += xp

	while experience >= xp_to_next_level and level < len(experience_table):
		level_up()

func level_up():
	level += 1
	if level+1 in experience_table:
		xp_to_next_level = experience_table[level+1]

	# Apply stat growth from student class
	if student_class:
		var roll: float = randf() * (luck/100.0)

		max_hp += int(max_hp * student_class.hp_per_level * roll)
		current_hp = max_hp # heal on level up
		max_mp += int(max_mp * student_class.mp_per_level * roll)
		current_mp = max_mp # heal on level up

		# Stat not guaranteed to increase;
		# eventually intended to reliably increase through crafting instead
		if randf()*100 < luck:
			atk += int(student_class.atk_per_level * roll * atk)
		if randf()*100 < luck:
			def += int(student_class.def_per_level * roll * def)
		if randf()*100 < luck:
			mag += int(student_class.mag_per_level * roll * mag)
		if randf()*100 < luck:
			res += int(student_class.res_per_level * roll * res)
		if randf()*100 < luck:
			spd += int(student_class.spd_per_level * roll * spd)
		if randf()*100 < luck:
			luck += int(student_class.luck_per_level * roll * luck)

const experience_table = {
	1: 100,
	2: 200,
	3: 350,
	4: 550,
	5: 800,
	6: 1100,
	7: 1450,
	8: 1850,
	9: 2300,
	10: 2800,
}

func restore_mp(amount: int):
	current_mp = min(current_mp + amount, max_mp)

func reduce_mp(amount: int):
	current_mp = max(current_mp - amount, 0)
