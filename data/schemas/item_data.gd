@tool
class_name ItemData
extends Resource

enum Category { INGREDIENT, CONSUMABLE, KEY_ITEM }
enum UseEffect { NONE, HEAL_HP, HEAL_MP, CURE_HUNGER, BUFF_FOOD, HEAL_SAN, REDUCE_HP, REDUCE_MP, INCREASE_HUNGER, DEBUFF_FOOD, REDUCE_SAN, }

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

@export var bonus_effect: UseEffect = UseEffect.NONE
@export var bonus_value: float = 0.0

## Applies this item's use_effect (and bonus_effect) to target, consuming
## one copy from InventoryManager. Returns false (and leaves the item
## unconsumed) if there wasn't one to use.
func use_item(target: CharacterData) -> bool:
	if not InventoryManager.remove_item(item_id):
		return false

	match use_effect:
		ItemData.UseEffect.HEAL_HP:
			target.restore_health(int(use_value))
		ItemData.UseEffect.HEAL_MP:
			if target.is_student:
				target.restore_mp(int(use_value))
		ItemData.UseEffect.CURE_HUNGER:
			if target.is_student:
				HungerSystem.restore_hunger(target.student_id, int(use_value))

	_apply_bonus_effect(target)
	return true

func _apply_bonus_effect(target: CharacterData):
	match bonus_effect:
		ItemData.UseEffect.REDUCE_HP:
			target.reduce_health(int(bonus_value))
		ItemData.UseEffect.REDUCE_MP:
			if target.is_student:
				target.reduce_mp(int(bonus_value))
		ItemData.UseEffect.INCREASE_HUNGER:
			if target.is_student:
				HungerSystem.reduce_hunger(target.student_id, int(bonus_value))
		ItemData.UseEffect.REDUCE_SAN:
			target.reduce_sanity(int(bonus_value))
