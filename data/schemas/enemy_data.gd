@tool
class_name EnemyData
extends Resource

## drop_table entries: {"item": ItemData, "chance": float, "min_qty": int, "max_qty": int}
## primitive_shape is consumed only by the dungeon/battle visual resolver, never by combat logic.

enum PrimitiveShape { BOX, SPHERE, CAPSULE }

@export var enemy_id: StringName
@export var display_name: String
@export var enemy_portrait: CompressedTexture2D = preload("res://data/assets/enemies/generic.png")

@export_group("Stats")
@export var max_hp: int = 20
@export var atk: int = 5
@export var def: int = 5
@export var mag: int = 5
@export var res: int = 5
@export var spd: int = 5

@export_group("Behavior")
@export var skill_pool: Array[SkillData] = []
@export var drop_table: Array[Dictionary] = []
@export var supply_reward: int = 0

@export_group("Presentation")
@export var primitive_shape: PrimitiveShape = PrimitiveShape.BOX
@export var icon_color: Color = Color.WHITE
