@tool
class_name StudentData
extends Resource

## One of the 26-student roster. ACTIVE/DOWNED are battle states (DOWNED is
## revivable at the Nurse's Office); DEAD is permanent and only ever caused
## by TPK.

enum Status { ACTIVE, DOWNED, DEAD }

@export var student_id: StringName
@export var display_name: String
@export var student_class: StudentClassData
@export var level: int = 1
@export var student_portrait: CompressedTexture2D = preload("res://data/assets/portraits/generic.png")

@export_group("Vitals")
@export var current_hp: int = 1
@export var max_hp: int = 1
@export var current_mp: int = 0
@export var max_mp: int = 0
@export var current_hunger: float = 100.0
@export var max_hunger: float = 100.0

@export_group("Meta")
@export var status: Status = Status.ACTIVE
@export var portrait_color: Color = Color.WHITE
@export_multiline var bio_flavor: String = ""
@export var is_starter: bool = false

func is_usable() -> bool:
	return status == Status.ACTIVE or status == Status.DOWNED

func is_alive() -> bool:
	return status != Status.DEAD
