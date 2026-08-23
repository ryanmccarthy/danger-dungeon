extends Control

## Turn-based battle: SPD-sorted turn queue, front-row-priority command
## flow, party front/back row damage modifiers via CombatMath. Enemies use
## a single row in this slice (documented future extension). A combatant
## "ref" is a StringName (party student_id) or an int (index into `enemies`).

@onready var _round_label: Label = $MainMargin/MainVBox/RoundLabel
@onready var _enemy_row: HBoxContainer = $MainMargin/MainVBox/EnemyRow
@onready var _party_row: HBoxContainer = $MainMargin/MainVBox/PartyRow
@onready var _log_label: Label = $MainMargin/MainVBox/LogLabel
@onready var _action_area: VBoxContainer = $MainMargin/MainVBox/ActionArea

var enemies: Array = []
var party_ids: Array = []
var _defending: Dictionary = {}
var _cards: Dictionary = {}
var _turn_order: Array = []
var _turn_cursor: int = 0
var _round_num: int = 1
var _resolved: bool = false

func enter_state(_context: Dictionary = {}) -> void:
	_resolved = false
	_round_num = 1
	enemies.clear()
	_defending.clear()
	_cards.clear()
	var enemy_ids: Array = GameState.pending_encounter.get("enemy_ids", [])
	for id in enemy_ids:
		var data: EnemyData = ContentDatabase.get_enemy(id)
		if data == null:
			continue
		enemies.append({"data": data, "hp": data.max_hp, "name": data.display_name})
	party_ids.clear()
	for id in PartyManager.get_active_party_ids():
		var s := PartyManager.get_student(id)
		if s != null and s.status == StudentData.Status.ACTIVE:
			party_ids.append(id)
	var names: Array = []
	for e in enemies:
		names.append(e["name"])
	_log("A wild encounter: %s!" % ", ".join(names))
	_build_cards()
	_start_round()

func _build_cards() -> void:
	for c in _enemy_row.get_children():
		c.queue_free()
	for c in _party_row.get_children():
		c.queue_free()
	for i in enemies.size():
		_enemy_row.add_child(_make_card(i, enemies[i]["name"], false, null))
	for id in party_ids:
		var s := PartyManager.get_student(id)
		_party_row.add_child(_make_card(id, s.display_name, true, s.student_portrait))
	_refresh_cards()

func _make_card(ref, display_name: String, is_party: bool, portrait: Texture2D) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(150, 70)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var portrait_rect: TextureRect = null
	if portrait != null:
		portrait_rect = TextureRect.new()
		portrait_rect.texture = portrait
		portrait_rect.custom_minimum_size = Vector2(72, 72)
		portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(portrait_rect)
	var name_lbl := Label.new()
	name_lbl.text = display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_lbl)
	var hp_lbl := Label.new()
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hp_lbl)
	var mp_lbl: Label = null
	if is_party:
		mp_lbl = Label.new()
		mp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(mp_lbl)
	_cards[ref] = {"hp": hp_lbl, "mp": mp_lbl, "name_label": name_lbl, "portrait": portrait_rect}
	return box

func _refresh_cards() -> void:
	for i in enemies.size():
		var e = enemies[i]
		var card = _cards.get(i)
		if card == null:
			continue
		card["hp"].text = "HP %d / %d" % [max(0, e["hp"]), e["data"].max_hp]
		var e_tint := Color(1, 1, 1, 1) if e["hp"] > 0 else Color(0.4, 0.4, 0.4, 1)
		card["name_label"].modulate = e_tint
		if card["portrait"]:
			card["portrait"].modulate = e_tint
	for id in party_ids:
		var s := PartyManager.get_student(id)
		var card = _cards.get(id)
		if card == null or s == null:
			continue
		card["hp"].text = "HP %d / %d" % [s.current_hp, s.max_hp]
		if card["mp"]:
			card["mp"].text = "MP %d / %d" % [s.current_mp, s.max_mp]
		var alive := s.status == StudentData.Status.ACTIVE
		var s_tint := Color(1, 1, 1, 1) if alive else Color(0.4, 0.4, 0.4, 1)
		card["name_label"].modulate = s_tint
		if card["portrait"]:
			card["portrait"].modulate = s_tint

func _log(msg: String) -> void:
	_log_label.text = msg

# ------------------------------------------------------------ turn queue
func _start_round() -> void:
	if _check_battle_end():
		return
	_round_label.text = "Round %d" % _round_num
	_turn_order.clear()
	for i in enemies.size():
		if enemies[i]["hp"] > 0:
			_turn_order.append(i)
	for id in party_ids:
		var s := PartyManager.get_student(id)
		if s != null and s.status == StudentData.Status.ACTIVE:
			_turn_order.append(id)
	_turn_order.sort_custom(func(a, b): return _get_spd(a) > _get_spd(b))
	_turn_cursor = 0
	_next_turn()

func _next_turn() -> void:
	if _check_battle_end():
		return
	if _turn_cursor >= _turn_order.size():
		_round_num += 1
		_start_round()
		return
	var ref = _turn_order[_turn_cursor]
	_turn_cursor += 1
	if not _is_alive(ref):
		_next_turn()
		return
	if _is_enemy_ref(ref):
		_enemy_act(ref)
	else:
		_player_command_menu(ref)

func _check_battle_end() -> bool:
	if _resolved:
		return true
	var any_enemy_alive := false
	for e in enemies:
		if e["hp"] > 0:
			any_enemy_alive = true
			break
	if not any_enemy_alive:
		_resolve("WON")
		return true
	var any_party_alive := false
	for id in party_ids:
		var s := PartyManager.get_student(id)
		if s != null and s.status == StudentData.Status.ACTIVE:
			any_party_alive = true
			break
	if not any_party_alive:
		_resolve("LOST")
		return true
	return false

func _resolve(result: String) -> void:
	if _resolved:
		return
	_resolved = true
	_clear_action_area()
	if result == "WON":
		var rewards := _roll_rewards()
		_log("Victory! Found: " + rewards.get("log", "nothing"))
	elif result == "LOST":
		_log("The party has fallen back...")
	GameState.resolve_battle(result, {})

func _roll_rewards() -> Dictionary:
	var log_parts: Array[String] = []
	for e in enemies:
		var data: EnemyData = e["data"]
		InventoryManager.add_supplies(data.supply_reward)
		for drop in data.drop_table:
			if randf() <= float(drop["chance"]):
				var qty := randi_range(int(drop["min_qty"]), int(drop["max_qty"]))
				InventoryManager.add_item(drop["item_id"], qty)
				var item := ContentDatabase.get_item(drop["item_id"])
				log_parts.append("%s x%d" % [item.display_name, qty])
	return {"log": ", ".join(log_parts)}

# --------------------------------------------------------- combatant helpers
func _is_enemy_ref(ref) -> bool:
	return typeof(ref) == TYPE_INT

func _is_alive(ref) -> bool:
	if _is_enemy_ref(ref):
		return enemies[ref]["hp"] > 0
	var s := PartyManager.get_student(ref)
	return s != null and s.status == StudentData.Status.ACTIVE

func _get_spd(ref) -> int:
	if _is_enemy_ref(ref):
		return enemies[ref]["data"].spd
	var s := PartyManager.get_student(ref)
	return s.student_class.base_spd + int(s.student_class.spd_per_level * (s.level - 1))

func _get_stat(ref, stat: String) -> int:
	if _is_enemy_ref(ref):
		var d: EnemyData = enemies[ref]["data"]
		match stat:
			"atk": return d.atk
			"def": return d.def
			"mag": return d.mag
			"res": return d.res
		return 0
	var s := PartyManager.get_student(ref)
	var c := s.student_class
	var lvl := s.level - 1
	match stat:
		"atk": return c.base_atk + int(c.atk_per_level * lvl)
		"def": return c.base_def + int(c.def_per_level * lvl)
		"mag": return c.base_mag + int(c.mag_per_level * lvl)
		"res": return c.base_res + int(c.res_per_level * lvl)
	return 0

func _in_back_row(ref) -> bool:
	if _is_enemy_ref(ref):
		return false
	return PartyManager.is_in_back_row(ref)

func _display_name(ref) -> String:
	if _is_enemy_ref(ref):
		return enemies[ref]["name"]
	var s := PartyManager.get_student(ref)
	return s.display_name if s else "???"

func _deal_damage(attacker, defender, power: float, school: int) -> int:
	var atk_stat := _get_stat(attacker, "atk" if school == SkillData.DamageSchool.PHYSICAL else "mag")
	var def_stat := _get_stat(defender, "def" if school == SkillData.DamageSchool.PHYSICAL else "res")
	var dmg := CombatMath.compute_damage(atk_stat, def_stat, power, school, _in_back_row(attacker), _in_back_row(defender))
	if _defending.get(defender, false):
		dmg = int(dmg * 0.6)
	_apply_damage(defender, dmg)
	return dmg

func _apply_damage(ref, amount: int) -> void:
	if _is_enemy_ref(ref):
		enemies[ref]["hp"] = max(0, enemies[ref]["hp"] - amount)
	else:
		PartyManager.apply_damage(ref, amount, false)
	_refresh_cards()

func _apply_heal(ref, amount: int) -> void:
	if _is_enemy_ref(ref):
		var e = enemies[ref]
		e["hp"] = min(e["data"].max_hp, e["hp"] + amount)
	else:
		PartyManager.heal_student(ref, amount)
	_refresh_cards()

func _living_enemies() -> Array:
	var out := []
	for i in enemies.size():
		if enemies[i]["hp"] > 0:
			out.append(i)
	return out

func _living_party() -> Array:
	var out := []
	for id in party_ids:
		if _is_alive(id):
			out.append(id)
	return out

# -------------------------------------------------------------- enemy AI
func _enemy_act(ref: int) -> void:
	var data: EnemyData = enemies[ref]["data"]
	var targets := _living_party()
	if targets.is_empty():
		_next_turn()
		return
	var target = targets[randi() % targets.size()]
	if data.skill_pool.is_empty():
		var dmg := _deal_damage(ref, target, 1.0, SkillData.DamageSchool.PHYSICAL)
		_log("%s hits %s for %d." % [_display_name(ref), _display_name(target), dmg])
	else:
		var skill: SkillData = data.skill_pool[randi() % data.skill_pool.size()]
		if skill.target_type == SkillData.TargetType.ALL_ENEMIES:
			for t in _living_party():
				var dmg := _deal_damage(ref, t, skill.power, skill.damage_school)
				_log("%s uses %s on %s for %d." % [_display_name(ref), skill.display_name, _display_name(t), dmg])
		else:
			var dmg := _deal_damage(ref, target, skill.power, skill.damage_school)
			_log("%s uses %s on %s for %d." % [_display_name(ref), skill.display_name, _display_name(target), dmg])
	await get_tree().create_timer(0.5).timeout
	_next_turn()

# ------------------------------------------------------- player command UI
func _clear_action_area() -> void:
	for c in _action_area.get_children():
		c.queue_free()

func _player_command_menu(actor: StringName) -> void:
	_clear_action_area()
	_defending.erase(actor)
	var label := Label.new()
	label.text = "%s's turn:" % _display_name(actor)
	_action_area.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_action_area.add_child(row)
	_add_action_button(row, "Attack", func(): _begin_target_select(actor, func(t): _do_attack(actor, t)))
	_add_action_button(row, "Skill", func(): _show_skill_menu(actor))
	_add_action_button(row, "Item", func(): _show_item_menu(actor))
	_add_action_button(row, "Defend", func(): _do_defend(actor))
	_add_action_button(row, "Flee", func(): _do_flee(actor))

func _add_action_button(parent: Control, text: String, cb: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(cb)
	parent.add_child(btn)

func _do_attack(actor, target) -> void:
	var dmg := _deal_damage(actor, target, 1.0, SkillData.DamageSchool.PHYSICAL)
	_log("%s attacks %s for %d." % [_display_name(actor), _display_name(target), dmg])
	_end_player_turn()

func _do_defend(actor) -> void:
	_defending[actor] = true
	_log("%s braces for impact." % _display_name(actor))
	_end_player_turn()

func _do_flee(actor) -> void:
	var party_spd := 0
	for id in _living_party():
		party_spd += _get_spd(id)
	var enemy_spd := 0
	for i in _living_enemies():
		enemy_spd += _get_spd(i)
	var chance: float = clamp(0.5 + float(party_spd - enemy_spd) * 0.01, 0.1, 0.9)
	if randf() < chance:
		_log("The party flees!")
		_resolved = true
		_clear_action_area()
		GameState.resolve_battle("FLED", {})
	else:
		_log("Couldn't get away!")
		_end_player_turn()

func _show_skill_menu(actor: StringName) -> void:
	_clear_action_area()
	var s := PartyManager.get_student(actor)
	var back := Button.new()
	back.text = "< Back"
	back.pressed.connect(func(): _player_command_menu(actor))
	_action_area.add_child(back)
	for skill: SkillData in s.student_class.skill_ids:
		var can_afford: bool = s.current_mp >= skill.mp_cost
		var btn := Button.new()
		btn.text = "%s (MP %d)" % [skill.display_name, skill.mp_cost]
		btn.disabled = not can_afford
		btn.pressed.connect(func(): _use_skill(actor, skill))
		_action_area.add_child(btn)

func _use_skill(actor: StringName, skill: SkillData) -> void:
	var s := PartyManager.get_student(actor)
	if s.current_mp < skill.mp_cost:
		return
	match skill.target_type:
		SkillData.TargetType.SINGLE_ENEMY:
			_begin_target_select(actor, func(t): _cast_skill(actor, skill, [t]), _living_enemies())
		SkillData.TargetType.ALL_ENEMIES:
			_cast_skill(actor, skill, _living_enemies())
		SkillData.TargetType.SINGLE_ALLY:
			_begin_target_select(actor, func(t): _cast_skill(actor, skill, [t]), _living_party())
		SkillData.TargetType.ALL_ALLIES:
			_cast_skill(actor, skill, _living_party())
		SkillData.TargetType.SELF:
			_cast_skill(actor, skill, [actor])

func _cast_skill(actor: StringName, skill: SkillData, targets: Array) -> void:
	var s := PartyManager.get_student(actor)
	if s.current_mp < skill.mp_cost:
		return
	s.current_mp -= skill.mp_cost
	for t in targets:
		match skill.effect_type:
			SkillData.EffectType.DAMAGE:
				var dmg := _deal_damage(actor, t, skill.power, skill.damage_school)
				_log("%s uses %s on %s for %d." % [_display_name(actor), skill.display_name, _display_name(t), dmg])
			SkillData.EffectType.HEAL:
				var amount := CombatMath.compute_heal(_get_stat(actor, "mag"), skill.power)
				_apply_heal(t, amount)
				_log("%s uses %s, healing %s for %d." % [_display_name(actor), skill.display_name, _display_name(t), amount])
			SkillData.EffectType.BUFF, SkillData.EffectType.DEBUFF:
				_log("%s uses %s on %s." % [_display_name(actor), skill.display_name, _display_name(t)])
	_end_player_turn()

func _show_item_menu(actor: StringName) -> void:
	_clear_action_area()
	var back := Button.new()
	back.text = "< Back"
	back.pressed.connect(func(): _player_command_menu(actor))
	_action_area.add_child(back)
	var usable_ids: Array = [&"item_bandage", &"item_energy_drink", &"item_trail_mix"]
	var any := false
	for id in usable_ids:
		var have: int = InventoryManager.items.get(id, 0)
		if have <= 0:
			continue
		any = true
		var item := ContentDatabase.get_item(id)
		var btn := Button.new()
		btn.text = "%s x%d" % [item.display_name, have]
		btn.pressed.connect(func(): _use_item(actor, id))
		_action_area.add_child(btn)
	if not any:
		var lbl := Label.new()
		lbl.text = "No usable items."
		_action_area.add_child(lbl)

func _use_item(actor: StringName, item_id: StringName) -> void:
	var item := ContentDatabase.get_item(item_id)
	_begin_target_select(actor, func(t): _apply_item(actor, item_id, item, t), _living_party())

func _apply_item(actor: StringName, item_id: StringName, item: ItemData, target) -> void:
	if not InventoryManager.remove_item(item_id):
		return
	match item.use_effect:
		ItemData.UseEffect.HEAL_HP:
			_apply_heal(target, int(item.use_value))
		ItemData.UseEffect.HEAL_MP:
			var s := PartyManager.get_student(target)
			if s:
				s.current_mp = min(s.max_mp, s.current_mp + int(item.use_value))
		ItemData.UseEffect.CURE_HUNGER:
			HungerSystem.restore_hunger(target, item.use_value)
	_log("%s uses %s on %s." % [_display_name(actor), item.display_name, _display_name(target)])
	_end_player_turn()

func _begin_target_select(actor, on_pick: Callable, pool: Array = []) -> void:
	if pool.is_empty():
		pool = _living_enemies()
	_clear_action_area()
	var back := Button.new()
	back.text = "< Back"
	back.pressed.connect(func(): _player_command_menu(actor))
	_action_area.add_child(back)
	for ref in pool:
		var btn := Button.new()
		btn.text = "Target: %s" % _display_name(ref)
		btn.pressed.connect(func(): on_pick.call(ref))
		_action_area.add_child(btn)

func _end_player_turn() -> void:
	_clear_action_area()
	_refresh_cards()
	if _check_battle_end():
		return
	await get_tree().create_timer(0.3).timeout
	_next_turn()
