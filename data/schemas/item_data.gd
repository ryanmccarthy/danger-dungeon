@tool
class_name ItemData
extends Resource

enum Category { INGREDIENT, CONSUMABLE, KEY_ITEM }
enum UseEffect { NONE, HEAL_HP, HEAL_MP, CURE_HUNGER, BUFF_FOOD }

@export var item_id: StringName
@export var display_name: String
@export_multiline var description: String = ""
@export var item_category: Category = Category.CONSUMABLE
@export var buy_price: int = 0
@export var sell_price: int = 0
@export var stack_size: int = 99
@export var use_effect: UseEffect = UseEffect.NONE
@export var use_value: float = 0.0
@export var icon_color: Color = Color.WHITE
