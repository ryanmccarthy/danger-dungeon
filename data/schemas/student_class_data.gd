@tool
class_name StudentClassData
extends Resource

## Base archetype definition for a student's RPG class (e.g. Cheerleader, Jock).

enum RowPreference { FRONT, BACK, EITHER }

@export var class_id: StringName
@export var class_name_display: String
@export var archetype_tag: String

@export_group("Base Stats")
@export var base_hp: int = 50
@export var base_mp: int = 20
@export var base_atk: int = 8
@export var base_def: int = 8
@export var base_mag: int = 8
@export var base_res: int = 8
@export var base_spd: int = 8
@export var base_luck: int = 8

@export_group("Growth Per Level")
@export var hp_per_level: float = 4.0
@export var mp_per_level: float = 1.5
@export var atk_per_level: float = 0.6
@export var def_per_level: float = 0.6
@export var mag_per_level: float = 0.6
@export var res_per_level: float = 0.6
@export var spd_per_level: float = 0.5
@export var luck_per_level: float = 0.3

@export_group("Presentation")
@export var preferred_row: RowPreference = RowPreference.EITHER
@export var skill_ids: Array[SkillData] = []
@export var icon_color: Color = Color.WHITE
@export_multiline var flavor_text: String = ""
