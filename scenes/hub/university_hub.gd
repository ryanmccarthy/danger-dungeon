extends Control

## University hub: static button shell (built via ui_manage.build_layout) +
## one reusable popup panel whose content this script builds dynamically
## per facility. Keeps the scene shallow while every facility stays
## functionally wired to its manager autoload.

const REVIVE_COST := 15
const REVIVE_HP_FRACTION := 0.5
const HEAL_COST := 8
const FEED_COST := 6

const HOME_AREA_ID := &"forest_approach"

@onready var _hud_label: Label = $MainMargin/MainVBox/HUDLabel
@onready var _status_label: Label = $MainMargin/MainVBox/StatusLabel
@onready var _popup_root: Control = $PopupLayer/PopupRoot
@onready var _popup_title: Label = $PopupLayer/PopupRoot/PopupPanel/PopupMargin/PopupVBox/PopupTitle
@onready var _popup_content: VBoxContainer = $PopupLayer/PopupRoot/PopupPanel/PopupMargin/PopupVBox/PopupScroll/PopupContent
@onready var _popup_close: Button = $PopupLayer/PopupRoot/PopupPanel/PopupMargin/PopupVBox/PopupCloseButton

func _ready() -> void:
	$MainMargin/MainVBox/FacilityGrid/BtnCafeteria.pressed.connect(func(): _open_popup("cafeteria"))
	$MainMargin/MainVBox/FacilityGrid/BtnNurse.pressed.connect(func(): _open_popup("nurse"))
	$MainMargin/MainVBox/FacilityGrid/BtnLibrary.pressed.connect(func(): _open_popup("library"))
	$MainMargin/MainVBox/FacilityGrid/BtnShop.pressed.connect(func(): _open_popup("shop"))
	$MainMargin/MainVBox/FacilityGrid/BtnDorm.pressed.connect(func(): _open_popup("dorm"))
	$MainMargin/MainVBox/FacilityGrid/BtnGarage.pressed.connect(func(): _open_popup("garage"))
	$MainMargin/MainVBox/FacilityGrid/BtnQuestBoard.pressed.connect(func(): _open_popup("quests"))
	$MainMargin/MainVBox/FacilityGrid/BtnDepart.pressed.connect(_on_depart_pressed)
	_popup_close.pressed.connect(func(): _popup_root.visible = false)

	EventBus.supplies_changed.connect(func(_v): _refresh_hud())
	EventBus.inventory_changed.connect(func(_id, _v): _refresh_hud())
	EventBus.student_died.connect(func(_id): _refresh_hud())
	EventBus.student_revived.connect(func(_id): _refresh_hud())
	EventBus.party_wiped.connect(_on_party_wiped)

	_refresh_hud()

func enter_state(context: Dictionary = {}) -> void:
	_refresh_hud()
	if context.get("forced", false):
		_status_label.text = "The whole team went down out there. Reassign who's exploring next."
		_open_popup("dorm")

func _on_party_wiped() -> void:
	_status_label.text = "Party wiped! Forced back to campus — pick a new team at the Dorm."

func _refresh_hud() -> void:
	var alive := PartyManager.get_living_roster().size()
	_hud_label.text = "Supplies: %d   |   Roster: %d / 26 alive" % [InventoryManager.supplies, alive]

func _on_depart_pressed() -> void:
	var area: AreaData = ContentDatabase.get_area(HOME_AREA_ID)
	if GameState.depart_university(area):
		_status_label.text = "Departed for %s." % area.display_name
	else:
		_status_label.text = "Not enough supplies to depart (need %d)." % InventoryManager.get_travel_cost(area)

func _open_popup(kind: String) -> void:
	for c in _popup_content.get_children():
		c.queue_free()
	match kind:
		"cafeteria": _popup_title.text = "Cafeteria"; _build_cafeteria()
		"nurse": _popup_title.text = "Nurse's Office"; _build_nurse()
		"library": _popup_title.text = "Library"; _build_library()
		"shop": _popup_title.text = "Shop"; _build_shop()
		"dorm": _popup_title.text = "Dorm — Party Formation"; _build_dorm()
		"garage": _popup_title.text = "Garage"; _build_garage()
		"quests": _popup_title.text = "Quest Board"; _build_quests()
	_popup_root.visible = true

func _add_row(text: String, button_text: String = "", callback: Callable = Callable(), enabled: bool = true) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	if button_text != "":
		var btn := Button.new()
		btn.text = button_text
		btn.disabled = not enabled
		if callback.is_valid():
			btn.pressed.connect(callback)
		row.add_child(btn)
	_popup_content.add_child(row)

func _add_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("#e0c14a"))
	_popup_content.add_child(label)

# ---------------------------------------------------------------- Cafeteria
func _build_cafeteria() -> void:
	_add_header("Cook dropped ingredients into buff food.")
	for recipe: RecipeData in [ContentDatabase.get_recipe(&"recipe_spirit_cupcake")]:
		if recipe == null:
			continue
		var have_all := true
		var parts: Array[String] = []
		for entry in recipe.ingredients:
			var item: ItemData = ContentDatabase.get_item(entry["item_id"])
			var have: int = InventoryManager.items.get(entry["item_id"], 0)
			if have < int(entry["count"]):
				have_all = false
			parts.append("%s x%d (have %d)" % [item.display_name, entry["count"], have])
		_add_row("%s — needs %s" % [recipe.display_name, ", ".join(parts)], "Cook", func(): _cook_recipe(recipe), have_all)

func _cook_recipe(recipe: RecipeData) -> void:
	for entry in recipe.ingredients:
		InventoryManager.remove_item(entry["item_id"], int(entry["count"]))
	InventoryManager.add_item(recipe.result_item.item_id)
	_status_label.text = "Cooked %s." % recipe.result_item.display_name
	_build_cafeteria_refresh()

func _build_cafeteria_refresh() -> void:
	for c in _popup_content.get_children():
		c.queue_free()
	_build_cafeteria()

# ------------------------------------------------------------- Nurse's Office
func _build_nurse() -> void:
	_add_header("Heal, revive, and feed your students.")
	for id in PartyManager.get_active_party_ids():
		var s: StudentData = PartyManager.get_student(id)
		if s == null:
			continue
		if s.status == StudentData.Status.DOWNED:
			_add_row("%s is down." % s.display_name, "Revive (%d)" % REVIVE_COST, func(): _do_revive(id), InventoryManager.supplies >= REVIVE_COST)
		else:
			if s.current_hp < s.max_hp:
				_add_row("%s: %d / %d HP" % [s.display_name, s.current_hp, s.max_hp], "Heal (%d)" % HEAL_COST, func(): _do_heal(id), InventoryManager.supplies >= HEAL_COST)
			if s.current_hunger < s.max_hunger:
				_add_row("%s: %d / %d hunger" % [s.display_name, int(s.current_hunger), int(s.max_hunger)], "Feed (%d)" % FEED_COST, func(): _do_feed(id), InventoryManager.supplies >= FEED_COST)

func _do_revive(id: StringName) -> void:
	var s := PartyManager.get_student(id)
	if s == null or not InventoryManager.spend_supplies(REVIVE_COST):
		return
	PartyManager.revive_student(id, int(s.max_hp * REVIVE_HP_FRACTION))
	_refresh_popup("nurse")

func _do_heal(id: StringName) -> void:
	if not InventoryManager.spend_supplies(HEAL_COST):
		return
	var s := PartyManager.get_student(id)
	PartyManager.heal_student(id, s.max_hp)
	_refresh_popup("nurse")

func _do_feed(id: StringName) -> void:
	if not InventoryManager.spend_supplies(FEED_COST):
		return
	var s := PartyManager.get_student(id)
	HungerSystem.restore_hunger(id, s.max_hunger)
	_refresh_popup("nurse")

# ----------------------------------------------------------------- Library
func _build_library() -> void:
	_add_header("Research unlocks new ways to survive the fog.")
	for upgrade: UpgradeData in [ContentDatabase.get_upgrade(&"bus_repair_tier1")]:
		if upgrade == null:
			continue
		var status := ""
		if upgrade.upgrade_id in UpgradeManager.unlocked_upgrade_ids:
			status = "Unlocked"
		elif upgrade.requires_quest_id != StringName() and not QuestManager.is_quest_complete(upgrade.requires_quest_id):
			status = "Locked — complete \"%s\" first" % ContentDatabase.get_quest(upgrade.requires_quest_id).display_name
		else:
			status = "%d supplies" % upgrade.unlock_cost_supplies
		var can := UpgradeManager.can_unlock(upgrade.upgrade_id)
		_add_row("%s (%s) — %s" % [upgrade.display_name, status, upgrade.description], "Unlock" if can else "", func(): _do_unlock(upgrade.upgrade_id), can)

func _do_unlock(id: StringName) -> void:
	if UpgradeManager.unlock(id):
		_status_label.text = "Unlocked upgrade."
		_refresh_popup("library")

# ------------------------------------------------------------------- Shop
func _build_shop() -> void:
	_add_header("Buy supplies-for-goods, sell what you find.")
	for id in [&"item_bandage", &"item_energy_drink", &"item_trail_mix"]:
		var item: ItemData = ContentDatabase.get_item(id)
		if item == null:
			continue
		_add_row("Buy %s — %d supplies" % [item.display_name, item.buy_price], "Buy", func(): _do_buy(id), InventoryManager.supplies >= item.buy_price)
	_add_header("Sell")
	for id in [&"ingredient_wisp_essence", &"ingredient_stale_snack"]:
		var item: ItemData = ContentDatabase.get_item(id)
		var have: int = InventoryManager.items.get(id, 0)
		if item == null or have <= 0:
			continue
		_add_row("Sell %s (have %d) — +%d supplies" % [item.display_name, have, item.sell_price], "Sell", func(): _do_sell(id), true)

func _do_buy(id: StringName) -> void:
	var item := ContentDatabase.get_item(id)
	if not InventoryManager.spend_supplies(item.buy_price):
		return
	InventoryManager.add_item(id)
	_refresh_popup("shop")

func _do_sell(id: StringName) -> void:
	var item := ContentDatabase.get_item(id)
	if not InventoryManager.remove_item(id):
		return
	InventoryManager.add_supplies(item.sell_price)
	_refresh_popup("shop")

# -------------------------------------------------------------------- Dorm
func _build_dorm() -> void:
	_add_header("Front row: %d/3   Back row: %d/3" % [PartyManager.front_row_ids.size(), PartyManager.MAX_BACK])
	for s in PartyManager.get_usable_roster():
		var in_front := PartyManager.front_row_ids.has(s.student_id)
		var in_back := PartyManager.back_row_ids.has(s.student_id)
		var loc := "Front" if in_front else ("Back" if in_back else "Bench")
		var label := "%s (%s) [%s] HP %d/%d" % [s.display_name, s.student_class.class_name_display, loc, s.current_hp, s.max_hp]
		if in_front or in_back:
			_add_row(label, "Bench", func(): _do_bench(s.student_id))
		else:
			var row := HBoxContainer.new()
			var lbl := Label.new()
			lbl.text = label
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(lbl)
			var front_btn := Button.new()
			front_btn.text = "-> Front"
			front_btn.disabled = PartyManager.front_row_ids.size() >= PartyManager.MAX_FRONT
			front_btn.pressed.connect(func(): _do_assign(s.student_id, "front"))
			row.add_child(front_btn)
			var back_btn := Button.new()
			back_btn.text = "-> Back"
			back_btn.disabled = PartyManager.back_row_ids.size() >= PartyManager.MAX_BACK
			back_btn.pressed.connect(func(): _do_assign(s.student_id, "back"))
			row.add_child(back_btn)
			_popup_content.add_child(row)

func _do_assign(id: StringName, row: String) -> void:
	PartyManager.assign_to_party(id, row)
	_refresh_popup("dorm")

func _do_bench(id: StringName) -> void:
	PartyManager.remove_from_party(id)
	_refresh_popup("dorm")

# ------------------------------------------------------------------ Garage
func _build_garage() -> void:
	var discount := UpgradeManager.get_bus_travel_discount()
	_add_header("The bus, such as it is.")
	_add_row("Travel supply discount: %d%%" % int(round(discount * 100.0)))
	_add_row("Repair upgrades are researched at the Library.")

# ------------------------------------------------------------- Quest Board
func _build_quests() -> void:
	_add_header("Active")
	for id in QuestManager.active_quest_ids:
		var q: QuestData = ContentDatabase.get_quest(id)
		_add_row("%s — %d / %d — %s" % [q.display_name, QuestManager.get_quest_progress(id), q.objective_count, q.description])
	if QuestManager.active_quest_ids.is_empty():
		_add_row("(none active)")
	_add_header("Completed")
	for id in QuestManager.completed_quest_ids:
		var q: QuestData = ContentDatabase.get_quest(id)
		_add_row("%s — done" % q.display_name)
	if QuestManager.completed_quest_ids.is_empty():
		_add_row("(none yet)")

func _refresh_popup(kind: String) -> void:
	_open_popup(kind)
