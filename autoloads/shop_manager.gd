extends Node

## Shop contents are data-driven: any ItemData/EquipmentData resource with
## in_shop = true is offered for sale.

func get_shop_items() -> Array[ItemData]:
	var shop_items: Array[ItemData] = []
	for item in ContentDatabase.get_all_items():
		if item.in_shop:
			shop_items.append(item)

	return shop_items

func get_shop_equipment() -> Array[EquipmentData]:
	var shop_equipment: Array[EquipmentData] = []
	for equipment in ContentDatabase.get_all_equipment():
		if equipment.in_shop:
			shop_equipment.append(equipment)

	return shop_equipment

func get_shop_inventory() -> Array[InventoryItemData]:
	var inventory: Array[InventoryItemData] = []
	inventory.append_array(get_shop_items())
	inventory.append_array(get_shop_equipment())
	return inventory
