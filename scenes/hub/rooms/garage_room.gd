extends HubRoomBase

## Garage: the bus, such as it is. Read-only info for now.

func _build() -> void:
	var discount := UpgradeManager.get_bus_travel_discount()
	_add_header("The bus, such as it is.")
	_add_row("Travel supply discount: %d%%" % int(round(discount * 100.0)))
	_add_row("Repair upgrades are researched at the Library.")
