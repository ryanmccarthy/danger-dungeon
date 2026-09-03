extends CanvasLayer

## Global Esc-menu overlay: party roster + six nav buttons that open
## Inventory / Equipment (stub) / Status / Requests / Save+Load /
## Options sub-screens. Lives directly under GameRoot (a sibling of
## CurrentSceneHolder) so it survives Hub<->Dungeon scene swaps instead of
## being freed on every mode change. Only opens in HUB and DUNGEON modes;
## pauses the tree while open so it behaves as a real pause menu (blocks
## dungeon movement input and Hub facility buttons underneath it).

const OPEN_MODES := [GameState.GameMode.HUB, GameState.GameMode.DUNGEON]

const GOLD := Color(0.8784314, 0.75686276, 0.2901961, 1)
const BODY_TEXT := Color(0.7882353, 0.76862746, 0.84705883, 1)
const DIM_TEXT := Color(0.7, 0.68, 0.72, 1)
const GOOD_TEXT := Color(0.56078434, 0.83137256, 0.56078434, 1)
const BAD_TEXT := Color(0.83137256, 0.42, 0.42, 1)
const CARD_BORDER := Color(0.55, 0.16, 0.16, 1)
const ROW_BORDER := Color(0.32, 0.29, 0.31, 1)

const SAVE_SLOT_COUNT := 3

const SLOT_LABELS := {
	"weapon": "Weapon", "armor": "Armor",
	"accessory_1": "Accessory 1", "accessory_2": "Accessory 2",
}

@onready var _root: Control = $Root
@onready var _main_panel: Panel = $Root/MainPanel
@onready var _party_grid: GridContainer = $Root/MainPanel/MainMargin/MainVBox/PartyGrid
@onready var _nav_grid: GridContainer = $Root/MainPanel/MainMargin/MainVBox/NavGrid
@onready var _sub_panel: Panel = $Root/SubPanel
@onready var _sub_title: Label = $Root/SubPanel/SubMargin/SubVBox/SubHeaderRow/SubTitleLabel
@onready var _sub_body: VBoxContainer = $Root/SubPanel/SubMargin/SubVBox/SubBody
@onready var _back_button: Button = $Root/SubPanel/SubMargin/SubVBox/SubHeaderRow/BackButton

var _is_open: bool = false
var _save_load_status_text: String = ""
var _save_load_status_ok: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_sub_panel.visible = false

	for btn: Button in _nav_grid.get_children():
		_style_nav_button(btn)

	_nav_grid.get_node("BtnInventory").pressed.connect(func(): _open_sub("inventory"))
	_nav_grid.get_node("BtnEquipment").pressed.connect(func(): _open_sub("equipment"))
	_nav_grid.get_node("BtnStatus").pressed.connect(func(): _open_sub("status"))
	_nav_grid.get_node("BtnRequests").pressed.connect(func(): _open_sub("requests"))
	_nav_grid.get_node("BtnSaveLoad").pressed.connect(func(): _open_sub("saveload"))
	_nav_grid.get_node("BtnOptions").pressed.connect(func(): _open_sub("options"))
	_back_button.pressed.connect(_show_main)

	GameState.mode_changed.connect(_on_mode_changed)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	if _is_open:
		_close()
		get_viewport().set_input_as_handled()
	elif GameState.current_mode in OPEN_MODES:
		_open()
		get_viewport().set_input_as_handled()

func _on_mode_changed(_old_mode, new_mode, _context: Dictionary) -> void:
	if _is_open and not (new_mode in OPEN_MODES):
		_close()

func _open() -> void:
	_is_open = true
	_root.visible = true
	_show_main()
	get_tree().paused = true

func _close() -> void:
	_is_open = false
	_root.visible = false
	get_tree().paused = false

func _show_main() -> void:
	_sub_panel.visible = false
	_main_panel.visible = true
	_refresh_party_grid()

# --------------------------------------------------------------- party grid
func _refresh_party_grid() -> void:
	for c in _party_grid.get_children():
		c.queue_free()

	for id in PartyManager.get_active_party_ids():
		var s := PartyManager.get_student(id)
		if s != null:
			_party_grid.add_child(_make_party_card(s))

func _make_party_card(s: StudentData) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(320, 140)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_style())
	if s.status == StudentData.Status.DOWNED:
		card.modulate = Color(1, 1, 1, 0.6)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	card.add_child(hbox)
	hbox.add_child(_make_card_portrait(s.portrait))
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = s.display_name
	name_lbl.add_theme_font_size_override("font_size", 30)
	info.add_child(name_lbl)

	var class_lbl := Label.new()
	class_lbl.text = "%s — Lv %d" % [s.student_class.class_name_display, s.level]
	class_lbl.add_theme_font_size_override("font_size", 20)
	class_lbl.add_theme_color_override("font_color", BODY_TEXT)
	info.add_child(class_lbl)

	var stat_lbl := Label.new()
	stat_lbl.text = "HP %d/%d   MP %d/%d" % [s.current_hp, PartyManager.get_effective_max_hp(s.student_id),
											s.current_mp, PartyManager.get_effective_max_mp(s.student_id)]
	stat_lbl.add_theme_font_size_override("font_size", 20)
	info.add_child(stat_lbl)

	var status_lbl := Label.new()
	status_lbl.text = "Status: %s" % _status_summary(s)
	status_lbl.add_theme_font_size_override("font_size", 20)
	info.add_child(status_lbl)

	return card

func _make_card_portrait(texture: Texture2D, proportional: bool = true) -> TextureRect:
	"""
	Borderless, no background box.
	When `proportional` is true: scales to fill the
	card's full height while keeping the texture's own aspect ratio,
	instead of being boxed into a fixed square.
	When false: FIT_HEIGHT_PROPORTIONAL would keep growing the requested
	minimum width to match, blowing the panel out past the screen edge.
	"""
	var portrait := TextureRect.new()
	portrait.texture = texture
	portrait.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL if proportional else TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL

	return portrait

# --------------------------------------------------------------- sub-screens
func _open_sub(kind: String) -> void:
	_main_panel.visible = false
	_sub_panel.visible = true
	for c in _sub_body.get_children():
		c.queue_free()

	match kind:
		"inventory":
			_sub_title.text = "Inventory"
			_build_inventory()
		"equipment":
			_sub_title.text = "Equipment"
			_build_equipment()
		"status":
			_sub_title.text = "Status"
			_build_status()
		"requests":
			_sub_title.text = "Requests"
			_build_requests()
		"saveload":
			_sub_title.text = "Save/Load"
			_build_save_load()
		"options":
			_sub_title.text = "Options"
			_build_options()

func _build_stub(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", BODY_TEXT)
	lbl.add_theme_font_size_override("font_size", 24)
	_sub_body.add_child(lbl)

# ----------------------------------------------------------------- Inventory
func _build_inventory() -> void:
	for c in _sub_body.get_children():
		c.queue_free()

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sub_body.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	var supplies_lbl := Label.new()
	supplies_lbl.text = "Supplies: %d" % InventoryManager.supplies
	supplies_lbl.add_theme_color_override("font_color", GOLD)
	supplies_lbl.add_theme_font_size_override("font_size", 24)
	list.add_child(supplies_lbl)
	list.add_child(HSeparator.new())

	var ids: Array = InventoryManager.items.keys()
	ids.sort()
	var any := false
	for id in ids:
		var count: int = InventoryManager.items.get(id, 0)
		if count <= 0:
			continue

		# An owned id is either a consumable/ingredient or a piece of gear —
		# both live in the same flat InventoryManager.items stacks, and each
		# gets its own action (Use vs Equip).
		var entry := ContentDatabase.get_inventory_item(id)
		if entry == null:
			continue

		any = true
		if entry is EquipmentData:
			list.add_child(_make_equipment_inventory_row(entry, count))
		else:
			list.add_child(_make_inventory_row(entry, count))

	if not any:
		var lbl := Label.new()
		lbl.text = "No items."
		lbl.add_theme_color_override("font_color", DIM_TEXT)
		list.add_child(lbl)

func _make_inventory_row(item: ItemData, count: int) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _row_style())

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(box)

	var head_lbl := Label.new()
	head_lbl.text = "%s x%d" % [item.display_name, count]
	head_lbl.add_theme_font_size_override("font_size", 20)
	box.add_child(head_lbl)

	if item.description != "":
		var desc_lbl := Label.new()
		desc_lbl.text = item.description
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 16)
		desc_lbl.add_theme_color_override("font_color", DIM_TEXT)
		box.add_child(desc_lbl)

	var use_btn := Button.new()
	use_btn.text = "Use"
	use_btn.custom_minimum_size = Vector2(100, 44)
	use_btn.add_theme_font_size_override("font_size", 18)
	use_btn.disabled = not item.is_usable()
	use_btn.pressed.connect(func(): _show_use_target_select(item))
	hbox.add_child(use_btn)

	return row

# Shown when "Use" is pressed on an inventory item — picks which roster
# member (ALIVE or DOWNED, same pool as the Status tab's get_living_roster)
# receives the item's effect, then consumes it and returns to the refreshed
# inventory list.
func _show_use_target_select(item: ItemData) -> void:
	for c in _sub_body.get_children():
		c.queue_free()

	var back := Button.new()
	back.text = "< Back"
	back.pressed.connect(_build_inventory)
	_sub_body.add_child(back)

	var hdr := Label.new()
	hdr.text = "Use %s on:" % item.display_name
	hdr.add_theme_font_size_override("font_size", 22)
	hdr.add_theme_color_override("font_color", GOLD)
	_sub_body.add_child(hdr)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sub_body.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var roster := PartyManager.get_living_roster()
	if roster.is_empty():
		list.add_child(_make_dim_label("No one to use this on."))
		return

	for s in roster:
		var btn := Button.new()
		btn.text = "%s   HP %d/%d   MP %d/%d" % [s.display_name, s.current_hp, s.max_hp, s.current_mp, s.max_mp]
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(func(): _use_item_on(item, s))
		list.add_child(btn)

func _use_item_on(item: ItemData, target: StudentData) -> void:
	if item.use_item(target): # only need to update if it was used
		_build_inventory()

# Gear counterpart to _make_inventory_row: "Equip" instead of "Use", routing
# through a roster picker rather than a use-target picker.
func _make_equipment_inventory_row(eq: EquipmentData, count: int) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _row_style())

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(box)

	var head_lbl := Label.new()
	head_lbl.text = "%s x%d   %s" % [eq.display_name, count, _equipment_summary(eq)]
	head_lbl.add_theme_font_size_override("font_size", 20)
	box.add_child(head_lbl)

	if eq.description != "":
		box.add_child(_make_dim_label(eq.description))

	var equip_btn := Button.new()
	equip_btn.text = "Equip"
	equip_btn.custom_minimum_size = Vector2(100, 44)
	equip_btn.add_theme_font_size_override("font_size", 18)
	equip_btn.pressed.connect(func(): _show_equip_student_select(eq))
	hbox.add_child(equip_btn)

	return row

func _show_equip_student_select(eq: EquipmentData) -> void:
	for c in _sub_body.get_children():
		c.queue_free()

	var back := Button.new()
	back.text = "< Back"
	back.pressed.connect(_build_inventory)
	_sub_body.add_child(back)

	var hdr := Label.new()
	hdr.text = "Equip %s on:" % eq.display_name
	hdr.add_theme_font_size_override("font_size", 22)
	hdr.add_theme_color_override("font_color", GOLD)
	_sub_body.add_child(hdr)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sub_body.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var roster := PartyManager.get_living_roster()
	if roster.is_empty():
		list.add_child(_make_dim_label("No one to equip this on."))
		return

	for s in roster:
		var btn := Button.new()
		btn.text = s.display_name
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(func(): _pick_equip_slot(eq, s))
		list.add_child(btn)

# Weapons and armor have exactly one home; accessories need the player to
# say which of the two interchangeable slots to fill.
func _pick_equip_slot(eq: EquipmentData, s: StudentData) -> void:
	var slot_key := eq.default_slot_key()
	if slot_key != "":
		EquipmentManager.equip(s.student_id, eq.id, slot_key)
		_build_inventory()
		return

	for c in _sub_body.get_children():
		c.queue_free()

	var back := Button.new()
	back.text = "< Back"
	back.pressed.connect(func(): _show_equip_student_select(eq))
	_sub_body.add_child(back)

	var hdr := Label.new()
	hdr.text = "Equip %s on %s in:" % [eq.display_name, s.display_name]
	hdr.add_theme_font_size_override("font_size", 22)
	hdr.add_theme_color_override("font_color", GOLD)
	_sub_body.add_child(hdr)

	for slot in ["accessory_1", "accessory_2"]:
		var worn := EquipmentManager.get_equipped(s.student_id, slot)
		var btn := Button.new()
		btn.text = "%s — %s" % [SLOT_LABELS[slot], worn.display_name if worn else "(empty)"]
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(func():
			EquipmentManager.equip(s.student_id, eq.id, slot)
			_build_inventory())
		_sub_body.add_child(btn)

# ----------------------------------------------------------------- Equipment
# Two columns: roster list (left) | the picked student's four slots plus their
# combined bonuses (right). Same skeleton as the Status tab below, minus the
# portrait column. `focus_id` re-opens on a specific student after an
# equip/unequip so the screen doesn't snap back to the first roster member.
func _build_equipment(focus_id: StringName = &"") -> void:
	for c in _sub_body.get_children():
		c.queue_free()

	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 20)
	_sub_body.add_child(hbox)

	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(220, 0)
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(left_scroll)

	var left_list := VBoxContainer.new()
	left_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_list.add_theme_constant_override("separation", 6)
	left_scroll.add_child(left_list)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(detail_scroll)

	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 6)
	detail_scroll.add_child(detail)

	var roster := PartyManager.get_living_roster()
	if roster.is_empty():
		detail.add_child(_make_dim_label("No party members available."))
		return

	var focus: StudentData = roster[0]
	for s in roster:
		if s.student_id == focus_id:
			focus = s
		var btn := Button.new()
		btn.text = s.display_name
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(func(): _fill_equipment_detail(detail, s))
		left_list.add_child(btn)

	_fill_equipment_detail(detail, focus)

func _fill_equipment_detail(detail: VBoxContainer, s: StudentData) -> void:
	for c in detail.get_children():
		c.queue_free()

	var name_lbl := Label.new()
	name_lbl.text = s.display_name
	name_lbl.add_theme_font_size_override("font_size", 30)
	name_lbl.add_theme_color_override("font_color", GOLD)
	detail.add_child(name_lbl)

	_add_section_header(detail, "Loadout")
	for slot_key in EquipmentManager.SLOT_KEYS:
		detail.add_child(_make_equipment_slot_row(s, slot_key))

	_add_section_header(detail, "Equipment Bonuses")
	var pairs: Array = []
	for stat: String in ["atk", "def", "mag", "res", "spd", "luck", "max_hp", "max_mp"]:
		var amount := EquipmentManager.get_stat_bonus(s.student_id, stat)
		pairs.append([stat.replace("_", " ").to_upper(), _signed_str(amount)])
	detail.add_child(_make_stat_grid(pairs, 4))

	var passives := _passive_summary(s.student_id)
	if passives != "":
		detail.add_child(_make_dim_label(passives))

# One row per fixed loadout slot: what's worn (or "(empty)") plus the single
# action that applies — Unequip when occupied, Equip when not.
func _make_equipment_slot_row(s: StudentData, slot_key: String) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _row_style())

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(box)

	var eq := EquipmentManager.get_equipped(s.student_id, slot_key)

	var head_lbl := Label.new()
	head_lbl.text = "%s: %s" % [SLOT_LABELS[slot_key], eq.display_name if eq else "(empty)"]
	head_lbl.add_theme_font_size_override("font_size", 20)
	if eq == null:
		head_lbl.add_theme_color_override("font_color", DIM_TEXT)
	box.add_child(head_lbl)

	if eq != null and eq.description != "":
		box.add_child(_make_dim_label(eq.description))

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120, 44)
	btn.add_theme_font_size_override("font_size", 18)
	if eq != null:
		btn.text = "Unequip"
		btn.pressed.connect(func():
			EquipmentManager.unequip(s.student_id, slot_key)
			_build_equipment(s.student_id))
	else:
		btn.text = "Equip"
		btn.pressed.connect(func(): _show_equip_item_select(s, slot_key))
	hbox.add_child(btn)

	return row

# Shown when "Equip" is pressed on an empty slot — lists owned equipment
# whose own Slot enum fits this loadout key, then equips and returns to the
# refreshed loadout view.
func _show_equip_item_select(s: StudentData, slot_key: String) -> void:
	for c in _sub_body.get_children():
		c.queue_free()

	var back := Button.new()
	back.text = "< Back"
	back.pressed.connect(func(): _build_equipment(s.student_id))
	_sub_body.add_child(back)

	var hdr := Label.new()
	hdr.text = "%s — %s:" % [s.display_name, SLOT_LABELS[slot_key]]
	hdr.add_theme_font_size_override("font_size", 22)
	hdr.add_theme_color_override("font_color", GOLD)
	_sub_body.add_child(hdr)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sub_body.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var ids: Array = InventoryManager.items.keys()
	ids.sort()
	var any := false
	for id in ids:
		if InventoryManager.items.get(id, 0) <= 0:
			continue

		var eq: EquipmentData = ContentDatabase.get_equipment(id)
		if eq == null or not eq.fits_slot_key(slot_key):
			continue

		any = true
		var btn := Button.new()
		btn.text = "%s   %s" % [eq.display_name, _equipment_summary(eq)]
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(func():
			EquipmentManager.equip(s.student_id, eq.id, slot_key)
			_build_equipment(s.student_id))
		list.add_child(btn)

	if not any:
		list.add_child(_make_dim_label("Nothing in the bag fits this slot."))

# "ATK +4  DEF +2" — only the stats a piece actually modifies, so slot rows
# and pick lists stay readable.
func _equipment_summary(eq: EquipmentData) -> String:
	var parts: Array[String] = []
	for stat in ["atk", "def", "mag", "res", "spd", "luck", "max_hp", "max_mp"]:
		var amount := eq.get_stat_bonus(stat)
		if amount != 0.0:
			parts.append("%s %s" % [stat.to_upper(), _signed_str(amount)])

	if eq.passive_effect != EquipmentData.PassiveEffect.NONE:
		parts.append(_passive_label(eq))

	return "  ".join(parts)

func _passive_summary(student_id: StringName) -> String:
	var parts: Array[String] = []
	for slot_key in EquipmentManager.SLOT_KEYS:
		var eq := EquipmentManager.get_equipped(student_id, slot_key)
		if eq != null and eq.passive_effect != EquipmentData.PassiveEffect.NONE:
			parts.append(_passive_label(eq))

	return "  •  ".join(parts)

func _passive_label(eq: EquipmentData) -> String:
	match eq.passive_effect:
		EquipmentData.PassiveEffect.LIFESTEAL:
			return "Lifesteal %d%%" % int(round(eq.passive_value * 100.0))
		EquipmentData.PassiveEffect.REDUCED_HUNGER_DECAY:
			return "Hunger decay -%d%%" % int(round(eq.passive_value * 100.0))
	return ""

func _signed_str(amount: float) -> String:
	return "+%d" % int(amount) if amount >= 0.0 else str(int(amount))

# -------------------------------------------------------------------- Status
# Three columns: roster list (left) | stats broken into sections (center) |
# portrait scaled to fill the available height (right).
func _build_status() -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 20)
	_sub_body.add_child(hbox)

	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(220, 0)
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(left_scroll)

	var left_list := VBoxContainer.new()
	left_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_list.add_theme_constant_override("separation", 6)
	left_scroll.add_child(left_list)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(detail_scroll)

	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 6)
	detail_scroll.add_child(detail)

	var portrait_panel := PanelContainer.new()
	portrait_panel.custom_minimum_size = Vector2(260, 0)
	portrait_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait_panel.clip_contents = true

	portrait_panel.add_theme_stylebox_override("panel", _portrait_style())
	hbox.add_child(portrait_panel)

	var roster := PartyManager.get_living_roster()
	if roster.is_empty():
		var lbl := Label.new()
		lbl.text = "No party members available."
		detail.add_child(lbl)
		return

	for s in roster:
		var btn := Button.new()
		btn.text = s.display_name
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(func(): _fill_status_detail(detail, portrait_panel, s))
		left_list.add_child(btn)

	_fill_status_detail(detail, portrait_panel, roster[0])

func _fill_status_detail(detail: VBoxContainer, portrait_panel: PanelContainer, s: StudentData) -> void:
	for c in detail.get_children():
		c.queue_free()

	for c in portrait_panel.get_children():
		c.queue_free()

	var portrait = s.standing_portrait if s.standing_portrait else s.portrait
	portrait_panel.add_child(_make_card_portrait(portrait, false))

	# --- Top: identity — name, class, level, condition/status ---
	var name_lbl := Label.new()
	name_lbl.text = s.display_name
	name_lbl.add_theme_font_size_override("font_size", 30)
	name_lbl.add_theme_color_override("font_color", GOLD)
	detail.add_child(name_lbl)

	detail.add_child(_make_ident_grid(s))

	if s.bio_flavor != "":
		_add_section_header(detail, "About")
		var bio_lbl := Label.new()
		bio_lbl.text = s.bio_flavor
		bio_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bio_lbl.add_theme_font_size_override("font_size", 18)
		detail.add_child(bio_lbl)

	# --- Middle: stats — resource pools, then core attributes ---
	_add_section_header(detail, "Vitals")
	detail.add_child(_make_stat_grid([
		["HP", "%d / %d" % [s.current_hp, PartyManager.get_effective_max_hp(s.student_id)]],
		["MP", "%d / %d" % [s.current_mp, PartyManager.get_effective_max_mp(s.student_id)]],
		["SAN", "%d / %d" % [s.current_san, s.max_san]],
		["Hunger", "%d / %d" % [int(s.current_hunger), int(s.max_hunger)]],
	], 2))

	_add_section_header(detail, "Attributes")
	detail.add_child(_make_stat_grid([
		["ATK", _attr_str(s, "atk", s.atk)], ["DEF", _attr_str(s, "def", s.def)],
		["MAG", _attr_str(s, "mag", s.mag)], ["RES", _attr_str(s, "res", s.res)],
		["SPD", _attr_str(s, "spd", s.spd)], ["LUCK", _attr_str(s, "luck", s.luck)],
	], 3))

	# --- Bottom: equipment — read-only mirror of the Equipment tab's loadout ---
	_add_section_header(detail, "Equipment")
	for slot_key in EquipmentManager.SLOT_KEYS:
		var eq := EquipmentManager.get_equipped(s.student_id, slot_key)
		detail.add_child(_make_dim_label("%s: %s" % [SLOT_LABELS[slot_key], eq.display_name if eq else "(empty)"]))

# Attributes are shown as the effective total (what combat actually uses),
# with the equipment share broken out so gear's contribution stays visible.
func _attr_str(s: StudentData, stat: String, base: int) -> String:
	var bonus := EquipmentManager.get_stat_bonus(s.student_id, stat)
	if bonus == 0.0:
		return str(base)

	return "%d (%s)" % [base + int(bonus), _signed_str(bonus)]

func _add_section_header(detail: VBoxContainer, text: String) -> void:
	detail.add_child(HSeparator.new())
	var hdr := Label.new()
	hdr.text = text
	hdr.add_theme_font_size_override("font_size", 18)
	hdr.add_theme_color_override("font_color", GOLD)
	detail.add_child(hdr)

func _get_grid(columns: int) -> GridContainer:
	var grid = GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 4)

	return grid

func _make_ident_grid(student: StudentData) -> GridContainer:
	var grid = _get_grid(2)

	var class_lbl := Label.new()
	class_lbl.text = "%s — Level %d" % [student.student_class.class_name_display, student.level]
	class_lbl.add_theme_font_size_override("font_size", 20)
	class_lbl.add_theme_color_override("font_color", BODY_TEXT)
	grid.add_child(class_lbl)

	var xp_lbl := Label.new()
	xp_lbl.text = "XP %d / %d" % [student.experience, student.xp_to_next_level]
	xp_lbl.add_theme_font_size_override("font_size", 16)
	xp_lbl.add_theme_color_override("font_color", DIM_TEXT)
	grid.add_child(xp_lbl)

	var condition_lbl := Label.new()
	var row_str := "Benched" if !PartyManager.is_in_party(student.student_id) else \
		("Back Row" if PartyManager.is_in_back_row(student.student_id) else "Front Row")
	condition_lbl.text = "%s   •   %s" % [StudentData.Status.keys()[student.status], row_str]
	condition_lbl.add_theme_font_size_override("font_size", 18)
	condition_lbl.add_theme_color_override("font_color", GOOD_TEXT if student.status == StudentData.Status.ALIVE else BAD_TEXT)
	grid.add_child(condition_lbl)

	var effects_lbl := Label.new()
	effects_lbl.text = "Status: %s" % _status_summary(student)
	effects_lbl.add_theme_font_size_override("font_size", 18)
	effects_lbl.add_theme_color_override("font_color", DIM_TEXT)
	grid.add_child(effects_lbl)

	return grid

func _make_stat_grid(pairs: Array, columns: int) -> GridContainer:
	var grid := _get_grid(columns)

	for pair in pairs:
		var lbl := Label.new()
		lbl.text = "%s  %s" % [pair[0], pair[1]]
		lbl.add_theme_font_size_override("font_size", 18)
		grid.add_child(lbl)

	return grid

# ------------------------------------------------------------------ Requests
func _build_requests() -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 20)
	_sub_body.add_child(hbox)

	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(240, 0)
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(left_scroll)

	var left_list := VBoxContainer.new()
	left_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_list.add_theme_constant_override("separation", 6)
	left_scroll.add_child(left_list)

	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 8)
	hbox.add_child(detail)

	var first_quest: QuestData = null
	var first_complete := false

	var accepted_hdr := Label.new()
	accepted_hdr.text = "Accepted"
	accepted_hdr.add_theme_color_override("font_color", GOLD)
	accepted_hdr.add_theme_font_size_override("font_size", 20)
	left_list.add_child(accepted_hdr)

	if QuestManager.active_quest_ids.is_empty():
		left_list.add_child(_make_dim_label("(none)"))

	for id in QuestManager.active_quest_ids:
		var q: QuestData = ContentDatabase.get_quest(id)
		if q == null:
			continue
		if first_quest == null:
			first_quest = q
			first_complete = false
		var btn := Button.new()
		btn.text = q.display_name
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(func(): _fill_quest_detail(detail, q, false))
		left_list.add_child(btn)

	left_list.add_child(HSeparator.new())

	var completed_hdr := Label.new()
	completed_hdr.text = "Completed"
	completed_hdr.add_theme_color_override("font_color", GOLD)
	completed_hdr.add_theme_font_size_override("font_size", 20)
	left_list.add_child(completed_hdr)

	if QuestManager.completed_quest_ids.is_empty():
		left_list.add_child(_make_dim_label("(none)"))

	for id in QuestManager.completed_quest_ids:
		var q: QuestData = ContentDatabase.get_quest(id)
		if q == null:
			continue
		if first_quest == null:
			first_quest = q
			first_complete = true
		var btn := Button.new()
		btn.text = q.display_name
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(func(): _fill_quest_detail(detail, q, true))
		left_list.add_child(btn)

	if first_quest != null:
		_fill_quest_detail(detail, first_quest, first_complete)
	else:
		detail.add_child(_make_dim_label("No quests yet."))

func _make_dim_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", DIM_TEXT)
	lbl.add_theme_font_size_override("font_size", 16)
	return lbl

func _fill_quest_detail(detail: VBoxContainer, q: QuestData, is_complete: bool) -> void:
	for c in detail.get_children():
		c.queue_free()

	var name_lbl := Label.new()
	name_lbl.text = q.display_name
	name_lbl.add_theme_font_size_override("font_size", 30)
	name_lbl.add_theme_color_override("font_color", GOLD)
	detail.add_child(name_lbl)

	var type_lbl := Label.new()
	var type_str := "Main" if q.quest_type == QuestData.QuestType.MAIN else "Side"
	var state_str := "Completed" if is_complete else "In Progress"
	type_lbl.text = "%s Quest — %s" % [type_str, state_str]
	type_lbl.add_theme_font_size_override("font_size", 18)
	type_lbl.add_theme_color_override("font_color", GOOD_TEXT if is_complete else BODY_TEXT)
	detail.add_child(type_lbl)

	detail.add_child(HSeparator.new())

	if q.description != "":
		var desc_lbl := Label.new()
		desc_lbl.text = q.description
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 20)
		detail.add_child(desc_lbl)

	var progress_lbl := Label.new()
	var progress: int = q.objective_count if is_complete else QuestManager.get_quest_progress(q.quest_id)
	progress_lbl.text = "Progress: %d / %d" % [progress, q.objective_count]
	progress_lbl.add_theme_font_size_override("font_size", 20)
	detail.add_child(progress_lbl)

	if q.reward_supplies > 0 or not q.reward_items.is_empty():
		detail.add_child(HSeparator.new())
		var reward_parts: Array[String] = []
		if q.reward_supplies > 0:
			reward_parts.append("%d supplies" % q.reward_supplies)
		for item: ItemData in q.reward_items:
			reward_parts.append(item.display_name)
		var reward_lbl := Label.new()
		reward_lbl.text = "Reward: %s" % ", ".join(reward_parts)
		reward_lbl.add_theme_font_size_override("font_size", 20)
		detail.add_child(reward_lbl)

# -------------------------------------------------------------------Save/Load
func _build_save_load() -> void:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	_sub_body.add_child(vbox)

	for slot in range(SAVE_SLOT_COUNT):
		vbox.add_child(_make_save_slot_row(slot))

	if _save_load_status_text != "":
		vbox.add_child(HSeparator.new())
		var status_lbl := Label.new()
		status_lbl.text = _save_load_status_text
		status_lbl.add_theme_color_override("font_color", GOOD_TEXT if _save_load_status_ok else BAD_TEXT)
		status_lbl.add_theme_font_size_override("font_size", 18)
		vbox.add_child(status_lbl)

func _make_save_slot_row(slot: int) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _row_style())

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	row.add_child(hbox)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = "Slot %d" % (slot + 1)
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", GOLD)
	info.add_child(name_lbl)

	var path := SaveManager.SAVE_DIR + "slot_%d.json" % slot
	var has_save := FileAccess.file_exists(path)

	var detail_lbl := Label.new()
	if has_save:
		var ts := Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time(path), true)
		detail_lbl.text = "Saved: %s" % ts.replace("T", "  ")
	else:
		detail_lbl.text = "Empty"
	detail_lbl.add_theme_font_size_override("font_size", 16)
	detail_lbl.add_theme_color_override("font_color", DIM_TEXT)
	info.add_child(detail_lbl)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.custom_minimum_size = Vector2(110, 44)
	save_btn.add_theme_font_size_override("font_size", 18)
	save_btn.pressed.connect(func(): _on_save_pressed(slot))
	hbox.add_child(save_btn)

	var load_btn := Button.new()
	load_btn.text = "Load"
	load_btn.custom_minimum_size = Vector2(110, 44)
	load_btn.add_theme_font_size_override("font_size", 18)
	load_btn.disabled = not has_save
	load_btn.pressed.connect(func(): _on_load_pressed(slot))
	hbox.add_child(load_btn)

	return row

func _on_save_pressed(slot: int) -> void:
	_save_load_status_ok = SaveManager.save_game(slot)
	_save_load_status_text = (
		"Saved to Slot %d." % (slot + 1) if _save_load_status_ok
		else "Failed to save to Slot %d." % (slot + 1)
	)
	_open_sub("saveload")

func _on_load_pressed(slot: int) -> void:
	_save_load_status_ok = SaveManager.load_game(slot)
	if _save_load_status_ok:
		_save_load_status_text = "Loaded Slot %d." % (slot + 1)
		# Dungeon position/mode aren't part of the save payload, so drop back
		# to the Hub (fresh scene instance) to reflect the loaded state
		# cleanly rather than leaving stale Dungeon geometry on screen.
		_close()
		GameState.change_mode(GameState.GameMode.HUB)
		return
	_save_load_status_text = "Failed to load Slot %d." % (slot + 1)
	_open_sub("saveload")

# -------------------------------------------------------------------Options
func _build_options() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sub_body.add_child(vbox)

	var note := Label.new()
	note.text = "Audio and gameplay settings are coming soon."
	note.add_theme_color_override("font_color", DIM_TEXT)
	note.add_theme_font_size_override("font_size", 18)
	vbox.add_child(note)

	var title_btn := Button.new()
	title_btn.text = "Quit to Title Screen"
	title_btn.custom_minimum_size = Vector2(320, 56)
	title_btn.add_theme_font_size_override("font_size", 20)
	title_btn.pressed.connect(_on_quit_to_title)
	vbox.add_child(title_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Quit to Desktop"
	quit_btn.custom_minimum_size = Vector2(320, 56)
	quit_btn.add_theme_font_size_override("font_size", 20)
	quit_btn.pressed.connect(func(): get_tree().quit())
	vbox.add_child(quit_btn)

func _on_quit_to_title() -> void:
	_close()
	GameState.change_mode(GameState.GameMode.TITLE)

# --------------------------------------------------------------------styles
func _card_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.08, 1.0)
	sb.set_border_width_all(2)
	sb.border_color = CARD_BORDER
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	return sb

func _portrait_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 1)
	sb.set_border_width_all(2)
	sb.border_color = Color.WHITE
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(2)
	return sb

func _row_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.08, 1.0)
	sb.set_border_width_all(1)
	sb.border_color = ROW_BORDER
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	return sb

func _style_nav_button(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", 26)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.07, 0.07, 0.08, 1.0)
	normal.set_border_width_all(2)
	normal.border_color = GOLD
	normal.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.16, 0.14, 0.08, 1.0)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed_sb: StyleBoxFlat = normal.duplicate()
	pressed_sb.bg_color = Color(0.22, 0.19, 0.1, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed_sb)

func _status_summary(character: CharacterData) -> String:
	## status_effects holds ids; resolve them to display names. Empty is
	## healthy -- there is no "Fine" sentinel stored on the character.
	if character == null or character.status_effects.is_empty():
		return "Fine"

	var parts: Array[String] = []
	for status_id in character.status_effects:
		var data := ContentDatabase.get_status_effect(status_id)
		parts.append(data.display_name if data != null else String(status_id))

	return ", ".join(parts)
