@tool
class_name InventoryItemData
extends Resource

## Common shape for anything that can occupy an InventoryManager.items stack:
## consumables/ingredients (ItemData) and gear (EquipmentData). Shop, sell, and
## inventory-listing code works on this type so it never has to know which kind
## an id refers to — resolve one with ContentDatabase.get_inventory_item(id).

@export var id: StringName
@export var display_name: String
@export_multiline var description: String = ""
@export_multiline var effect_summary: String = ""
@export var in_shop: bool = false
@export var buy_price: int = 0
@export var sell_price: int = 0
@export var icon_color: Color = Color.WHITE
