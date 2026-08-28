@tool
class_name EquipmentData
extends InventoryItemData

## Permanent gear: static per-definition stat bonuses + an optional passive
## effect. Ownership/stacking is tracked the same way ItemData ids are — as
## flat StringName keys in InventoryManager.items. No random rolls, so a
## single Resource per id is sufficient (mirrors ItemData /
## SkillData / RecipeData / UpgradeData's separate-schema-plus-own-
## ContentDatabase-index convention). See autoloads/equipment_manager.gd
## for equip/unequip flow.

enum Slot { WEAPON, ARMOR, ACCESSORY }
enum PassiveEffect { NONE, LIFESTEAL, REDUCED_HUNGER_DECAY }

@export var slot: Slot = Slot.WEAPON

@export_group("Stat Bonuses")
@export var bonus_atk: int = 0
@export var bonus_def: int = 0
@export var bonus_mag: int = 0
@export var bonus_res: int = 0
@export var bonus_spd: int = 0
@export var bonus_luck: int = 0
@export var bonus_max_hp: int = 0
@export var bonus_max_mp: int = 0

@export_group("Passive Effect")
@export var passive_effect: PassiveEffect = PassiveEffect.NONE
## Meaning depends on passive_effect: both LIFESTEAL and
## REDUCED_HUNGER_DECAY read it as a 0.0-1.0 fraction.
@export var passive_value: float = 0.0

## String-keyed lookup mirroring battle_scene.gd's _get_buff_total /
## _apply_buff convention ("atk"/"def"/"mag"/"res"/"spd"/"luck"), plus
## "max_hp"/"max_mp" for PartyManager's effective-max helpers.
func get_stat_bonus(stat: String) -> float:
	match stat:
		"atk": return float(bonus_atk)
		"def": return float(bonus_def)
		"mag": return float(bonus_mag)
		"res": return float(bonus_res)
		"spd": return float(bonus_spd)
		"luck": return float(bonus_luck)
		"max_hp": return float(bonus_max_hp)
		"max_mp": return float(bonus_max_mp)
	return 0.0

## True if this item's own Slot enum is compatible with a given fixed
## loadout key ("weapon"/"armor"/"accessory_1"/"accessory_2").
func fits_slot_key(slot_key: String) -> bool:
	match slot:
		Slot.WEAPON: return slot_key == "weapon"
		Slot.ARMOR: return slot_key == "armor"
		Slot.ACCESSORY: return slot_key == "accessory_1" or slot_key == "accessory_2"
	return false

## Unambiguous loadout key for WEAPON/ARMOR; "" for ACCESSORY, which the
## caller must disambiguate (two interchangeable slots).
func default_slot_key() -> String:
	match slot:
		Slot.WEAPON: return "weapon"
		Slot.ARMOR: return "armor"
	return ""
