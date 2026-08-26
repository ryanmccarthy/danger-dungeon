@tool
class_name StudentClassData
extends Resource

## Base archetype definition for a student's class (e.g. Cheerleader, Jock).
## Despite each class being unique to a particular student,
## classes are broken into their own files for organizational purposes.
## Class specifies character growth; student defines starting/current stats.

enum RowPreference { FRONT, BACK, EITHER }

@export var class_id: StringName
@export var class_name_display: String
@export var archetype_tag: String

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
