extends HubRoomBase

## Shop: buy goods for supplies, sell what you find.

func _build() -> void:
	_add_header("Buy goods for supplies, sell what you find.")
	for item in ShopManager.get_shop_inventory():
		_add_row("Buy %s — %d supplies" % [item.display_name, item.buy_price], "Buy",
				func(): _do_buy(item.id), InventoryManager.supplies >= item.buy_price)

	_add_header("Sell")
	for item in InventoryManager.get_sellable():
		var have: int = InventoryManager.get_count(item.id)
		_add_row("Sell %s (have %d) — +%d supplies" % [item.display_name, have, item.sell_price],
				"Sell", func(): _do_sell(item.id), true)

func _do_buy(id: StringName) -> void:
	# The shop stocks consumables and gear alike, so resolve through the union.
	var item := ContentDatabase.get_inventory_item(id)
	if item == null or not InventoryManager.spend_supplies(item.buy_price):
		return

	InventoryManager.add_item(id)
	_refresh()

func _do_sell(id: StringName) -> void:
	var item := ContentDatabase.get_inventory_item(id)
	if item == null or not InventoryManager.remove_item(id):
		return

	InventoryManager.add_supplies(item.sell_price)
	_refresh()

func _refresh() -> void:
	super._refresh()
	_refresh_hud() # updates supplies display
