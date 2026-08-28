extends HubRoomBase

## Cafeteria: cook dropped ingredients into buff food.

func _build() -> void:
	_add_header("Cook dropped ingredients into buff food.")
	for recipe: RecipeData in [ContentDatabase.get_recipe(&"recipe_spirit_cupcake")]:
		if recipe == null:
			continue

		var have_all := true
		var parts: Array[String] = []
		for entry in recipe.ingredients:
			var item := ContentDatabase.get_inventory_item(entry["item_id"])
			if item == null:
				continue

			var have: int = InventoryManager.get_count(entry["item_id"])
			if have < int(entry["count"]):
				have_all = false
			parts.append("%s x%d (have %d)" % [item.display_name, entry["count"], have])

		_add_row("%s — needs %s" % [recipe.display_name, ", ".join(parts)], "Cook", func(): _cook_recipe(recipe), have_all)

func _cook_recipe(recipe: RecipeData) -> void:
	for entry in recipe.ingredients:
		InventoryManager.remove_item(entry["item_id"], int(entry["count"]))

	InventoryManager.add_item(recipe.result_item.id)
	_status_label.text = "Cooked %s." % recipe.result_item.display_name
	_refresh()
