extends Control

## Turn-based battle: SPD-sorted turn queue, front-row-priority command
## flow, party front/back row damage modifiers via CombatMath. Enemies use
## a single row in this slice (documented future extension). A combatant
## "ref" is a StringName (party student_id) or an int (index into `enemies`).

@onready var _music: AudioStreamPlayer = $MusicPlayer
@onready var _round_label: Label = $MainMargin/MainVBox/RoundLabel
@onready var _enemy_row: HBoxContainer = $MainMargin/MainVBox/EnemyRow
@onready var _log_label: Label = $MainMargin/MainVBox/LogLabel
@onready var _action_panel: PanelContainer = $MainMargin/MainVBox/BottomRow/ActionPanel
@onready var _action_area: VBoxContainer = $MainMargin/MainVBox/BottomRow/ActionPanel/ActionArea
@onready var _portrait_panel: PanelContainer = $MainMargin/MainVBox/BottomRow/PortraitPanel
@onready var _roster_panel: PanelContainer = $MainMargin/MainVBox/BottomRow/RosterPanel

const CARD_SIZE := Vector2(140, 96)
const NEUTRAL_BORDER := Color(0.32, 0.29, 0.31, 1)
const HIGHLIGHT_COLOR := Color(0.8784314, 0.75686276, 0.2901961, 1)

var enemies: Array = []
var party_ids: Array = []
var _defending: Dictionary = {}
var _cards: Dictionary = {}
var _buffs: Dictionary = {} # ref -> Array[{"stat": String, "amount": float, "remaining": int}]
var _turn_order: Array = []
var _turn_cursor: int = 0
var _round_num: int = 1
var _resolved: bool = false
var _current_actor_ref = null

func _ready() -> void:
	# The action menu and roster list keep a bordered panel (for now);
	# portraits (enemy cards + the current-actor panel) are transparent
	_action_panel.add_theme_stylebox_override("panel", _neutral_style())
	_portrait_panel.add_theme_stylebox_override("panel", _transparent_style())
	_roster_panel.add_theme_stylebox_override("panel", _neutral_style())

	_music.finished.connect(func(): _music.play())
	_music.play()

func _log(msg: String) -> void:
	_log_label.text = msg

func enter_state(_context: Dictionary = {}) -> void:
	_resolved = false
	_round_num = 1
	enemies.clear()
	_defending.clear()
	_cards.clear()
	_buffs.clear()

	var enemy_ids: Array = GameState.pending_encounter.get("enemy_ids", [])
	for id in enemy_ids:
		var data: EnemyData = ContentDatabase.get_enemy(id)
		if data == null:
			continue
		enemies.append({"data": data, "hp": data.max_hp, "name": data.display_name})

	party_ids.clear()
	for id in PartyManager.get_active_party_ids():
		var s := PartyManager.get_student(id)
		if s != null and s.status == StudentData.Status.ALIVE:
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
	_cards.clear()

	for i in enemies.size():
		_enemy_row.add_child(_make_enemy_card(i))
	_refresh_cards()

func _neutral_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.08, 1.0)
	sb.set_border_width_all(2)
	sb.border_color = NEUTRAL_BORDER
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(6)

	return sb

func _transparent_style() -> StyleBoxEmpty:
	var sb := StyleBoxEmpty.new()
	sb.set_content_margin_all(6)

	return sb

func _make_portrait(texture: Texture2D, portrait_size: float = 64.0) -> TextureRect:
	var portrait_rect := TextureRect.new()
	portrait_rect.texture = texture
	portrait_rect.custom_minimum_size = Vector2(portrait_size, portrait_size)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	return portrait_rect

func _make_fitted_portrait(texture: Texture2D) -> TextureRect:
	# Fills whatever container it's placed in,
	# unlike _make_portrait's fixed small size.
	var portrait_rect := TextureRect.new()
	portrait_rect.texture = texture
	portrait_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL

	return portrait_rect

func _make_enemy_card(idx: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_SIZE
	panel.add_theme_stylebox_override("panel", _transparent_style())

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)

	var name_lbl := Label.new()
	name_lbl.text = enemies[idx]["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_lbl)
	# box.add_child(_make_portrait(enemies[idx]["data"].portrait))
	box.add_child(_make_fitted_portrait(enemies[idx]["data"].portrait))

	# var hp_lbl := Label.new()
	# hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# box.add_child(hp_lbl)

	_cards[idx] = {"root": panel, "name_lbl": name_lbl} #, "hp": hp_lbl}

	return panel

func _refresh_cards() -> void:
	for i in enemies.size():
		var e = enemies[i]
		var card = _cards.get(i)
		if card == null:
			continue

		card["root"].modulate = Color(1, 1, 1, 1) if e["hp"] > 0 else Color(0.4, 0.4, 0.4, 0.7)
		card["name_lbl"].text = e["name"] + _buff_tag_string(i)

	_show_roster_list()

func _set_current_actor_portrait(ref) -> void:
	# Only called for party turns; the panel goes fully transparent on enemy
	# turns instead (see _next_turn).
	_clear_current_actor_portrait()

	var student := PartyManager.get_student(ref)
	var texture: Texture2D = student.portrait if student else null
	_portrait_panel.add_child(_make_fitted_portrait(texture))

func _clear_current_actor_portrait() -> void:
	for c in _portrait_panel.get_children():
		c.queue_free()

func _show_roster_list() -> void:
	for c in _roster_panel.get_children():
		c.queue_free()

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	_roster_panel.add_child(list)

	var current_party_ref = _current_actor_ref if not _is_enemy_ref(_current_actor_ref) else null
	for id in party_ids:
		var student := PartyManager.get_student(id)
		if student == null:
			continue

		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)

		var name_lbl := Label.new()
		name_lbl.text = student.display_name
		if id == current_party_ref:
			name_lbl.add_theme_color_override("font_color", HIGHLIGHT_COLOR)
		row.add_child(name_lbl)

		var stat_lbl := Label.new()
		stat_lbl.text = "HP %d/%d  MP %d/%d%s" % [student.current_hp, PartyManager.get_effective_max_hp(id),
												student.current_mp, PartyManager.get_effective_max_mp(id), _buff_tag_string(id)]
		stat_lbl.add_theme_font_size_override("font_size", 13)
		row.add_child(stat_lbl)

		var alive := student.status == StudentData.Status.ALIVE
		row.modulate = Color(1, 1, 1, 1) if alive else Color(0.4, 0.4, 0.4, 0.7)
		list.add_child(row)

# ------------------------------------------------------------ turn queue
func _start_round() -> void:
	if _check_battle_end():
		return

	_tick_buffs()
	_round_label.text = "Round %d" % _round_num
	_turn_order.clear()
	for i in enemies.size():
		if enemies[i]["hp"] > 0:
			_turn_order.append(i)

	for id in party_ids:
		var s := PartyManager.get_student(id)
		if s != null and s.status == StudentData.Status.ALIVE:
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

	_current_actor_ref = ref
	if _is_enemy_ref(ref):
		# Action menu and portrait go fully transparent (not hidden/resized)
		# on the enemy's turn; the roster list stays up throughout.
		_action_panel.modulate.a = 0.0
		_portrait_panel.modulate.a = 0.0
		_clear_action_area()
		_clear_current_actor_portrait()
		_show_roster_list()
		_enemy_act(ref)
	else:
		_action_panel.modulate.a = 1.0
		_portrait_panel.modulate.a = 1.0
		_set_current_actor_portrait(ref)
		_show_roster_list()
		_player_command_menu(ref)

func _check_battle_end() -> bool:
	if _resolved:
		return true

	if _living_enemies().size() < 1:
		_resolve("WON", _living_party())
		return true

	if _living_party().size() < 1:
		_resolve("LOST", [])
		return true

	return false

func _resolve(result: String, live_party: Array) -> void:
	if _resolved:
		return

	_resolved = true
	_clear_action_area()

	if result == "WON":
		var rewards := _roll_rewards(live_party)
		_log("Victory! Found: " + rewards.get("log", "nothing"))
	elif result == "LOST":
		_log("The party has fallen back...")
	GameState.resolve_battle(result, {})

func _roll_rewards(live_party: Array) -> Dictionary:
	var log_parts: Array[String] = []

	var total_xp: int = 0
	for e in enemies:
		var e_data: EnemyData = e["data"]
		InventoryManager.add_supplies(e_data.supply_reward)
		for drop in e_data.drop_table:
			if randf() <= float(drop["chance"]):
				var qty := randi_range(int(drop["min_qty"]), int(drop["max_qty"]))
				InventoryManager.add_item(drop["item_id"], qty)
				# Drop tables are loose Dictionaries, so the id can name gear
				# as readily as a consumable.
				var item := ContentDatabase.get_inventory_item(drop["item_id"])
				if item != null:
					log_parts.append("%s x%d" % [item.display_name, qty])
		total_xp += e_data.xp_drop

	for id in live_party:
		var member = PartyManager.get_student(id)
		member.add_experience(total_xp)

	return {"log": ", ".join(log_parts)}

# --------------------------------------------------------- combatant helpers
func _is_enemy_ref(ref) -> bool:
	return typeof(ref) == TYPE_INT

func _is_alive(ref) -> bool:
	if _is_enemy_ref(ref):
		return enemies[ref]["hp"] > 0

	var s := PartyManager.get_student(ref)
	return s != null and s.status == StudentData.Status.ALIVE

func _get_spd(ref) -> int:
	var base: int
	if _is_enemy_ref(ref):
		base = enemies[ref]["data"].spd
	else:
		var s := PartyManager.get_student(ref)
		base = s.spd + int(s.student_class.spd_per_level * (s.level - 1))

	return max(0, int(round(base + _get_buff_total(ref, "spd") + _get_equip_total(ref, "spd"))))

func _get_stat(ref, stat: String) -> int:
	var base: int = 0
	if _is_enemy_ref(ref):
		var d: EnemyData = enemies[ref]["data"]
		match stat:
			"atk": base = d.atk
			"def": base = d.def
			"mag": base = d.mag
			"res": base = d.res
	else:
		var s := PartyManager.get_student(ref)
		match stat:
			"atk": base = s.atk
			"def": base = s.def
			"mag": base = s.mag
			"res": base = s.res

	return max(0, int(round(base + _get_buff_total(ref, stat) + _get_equip_total(ref, stat))))

func _get_equip_total(ref, stat: String) -> float:
	# Enemies never carry equipment.
	if _is_enemy_ref(ref):
		return 0.0

	return EquipmentManager.get_stat_bonus(ref, stat)

# ------------------------------------------------------------------ buffs
func _get_buff_total(ref, stat: String) -> float:
	var total := 0.0
	for b in _buffs.get(ref, []):
		if b["stat"] == stat:
			total += b["amount"]

	return total

func _apply_buff(ref, stat: String, amount: float, duration: int) -> void:
	if stat == "" or duration <= 0:
		return

	if not _buffs.has(ref):
		_buffs[ref] = []

	_buffs[ref].append({"stat": stat, "amount": amount, "remaining": duration})

func _tick_buffs() -> void:
	for ref in _buffs.keys():
		var list: Array = _buffs[ref]
		var i := list.size() - 1
		while i >= 0:
			list[i]["remaining"] -= 1
			if list[i]["remaining"] <= 0:
				list.remove_at(i)
			i -= 1

		if list.is_empty():
			_buffs.erase(ref)

func _buff_tag_string(ref) -> String:
	var list: Array = _buffs.get(ref, [])
	if list.is_empty():
		return ""

	var parts: Array[String] = []
	for b in list:
		parts.append("%s%s (%d)" % [String(b["stat"]).to_upper(), _signed_str(b["amount"]), int(b["remaining"])])

	return "  " + "; ".join(parts)

# -------------------------------------------------------------- learning
func _try_learn_skill(actor: StringName, target, skill: SkillData) -> void:
	if not _is_enemy_ref(target):
		return

	var enemy_data: EnemyData = enemies[target]["data"]
	if enemy_data.skill_pool.is_empty():
		_log("%s finds nothing to learn from %s." % [_display_name(actor), _display_name(target)])
		return

	if randf() >= skill.learn_chance:
		_log("%s studies %s, but doesn't pick up anything new." % [_display_name(actor), _display_name(target)])
		return

	var s := PartyManager.get_student(actor)
	var known_ids: Array = []
	for known in s.student_class.skill_ids:
		known_ids.append(known.skill_id)
	known_ids.append_array(s.learned_skill_ids)

	var eligible: Array[SkillData] = []
	for candidate in enemy_data.skill_pool:
		if not known_ids.has(candidate.skill_id):
			eligible.append(candidate)

	if eligible.is_empty():
		_log("%s already knows everything %s has to teach." % [_display_name(actor), _display_name(target)])
		return

	var learned: SkillData = eligible[randi() % eligible.size()]
	s.learned_skill_ids.append(learned.skill_id)
	_log("%s learns %s from %s!" % [_display_name(actor), learned.display_name, _display_name(target)])

func _signed_str(amount: float) -> String:
	return "+%d" % int(amount) if amount >= 0.0 else str(int(amount))

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
	_apply_lifesteal(attacker, dmg)
	return dmg

func _apply_lifesteal(attacker, damage_dealt: int) -> void:
	if _is_enemy_ref(attacker) or damage_dealt <= 0:
		return

	var frac := EquipmentManager.get_passive_value(attacker, EquipmentData.PassiveEffect.LIFESTEAL)
	if frac > 0.0:
		_apply_heal(attacker, int(round(damage_dealt * frac)))

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
	_add_action_button(row, "Flee", func(): _do_flee())

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

func _do_flee() -> void:
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

	var student := PartyManager.get_student(actor)
	var back := Button.new()
	back.text = "< Back"
	back.pressed.connect(func(): _player_command_menu(actor))
	_action_area.add_child(back)
	var desc_lbl := _make_description_label()
	var known_skills: Array[SkillData] = student.student_class.skill_ids.duplicate()
	for id in student.learned_skill_ids:
		var learned := ContentDatabase.get_skill(id)
		if learned != null:
			known_skills.append(learned)
	for skill: SkillData in known_skills:
		var can_afford: bool = student.current_mp >= skill.mp_cost
		var btn := Button.new()
		btn.text = "%s (MP %d)" % [skill.display_name, skill.mp_cost]
		btn.disabled = not can_afford
		btn.pressed.connect(func(): _use_skill(actor, skill))
		btn.mouse_entered.connect(func(): desc_lbl.text = skill.description)
		_action_area.add_child(btn)
	_action_area.add_child(desc_lbl)

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
		for effect: SkillData.EffectType in skill.effect_type:
			match effect:
				SkillData.EffectType.DAMAGE:
					var dmg := _deal_damage(actor, t, skill.power, skill.damage_school)
					_log("%s uses %s on %s for %d." % [_display_name(actor), skill.display_name, _display_name(t), dmg])
				SkillData.EffectType.HEAL:
					var amount := CombatMath.compute_heal(_get_stat(actor, "mag"), skill.power)
					_apply_heal(t, amount)
					_log("%s uses %s, healing %s for %d." % [_display_name(actor), skill.display_name, _display_name(t), amount])
				SkillData.EffectType.BUFF:
					_apply_buff(t, skill.buff_stat_affected, skill.buff_amount, skill.buff_duration)
					_log("%s uses %s on %s (%s %s for %d rounds)." % [_display_name(actor), skill.display_name,
							_display_name(t), String(skill.buff_stat_affected).to_upper(),
							_signed_str(skill.buff_amount), skill.buff_duration])
				SkillData.EffectType.DEBUFF:
					_apply_buff(t, skill.debuff_stat_affected, -skill.debuff_amount, skill.debuff_duration)
					_log("%s uses %s on %s (%s %s for %d rounds)." % [_display_name(actor), skill.display_name,
							_display_name(t), String(skill.debuff_stat_affected).to_upper(),
							_signed_str(-skill.debuff_amount), skill.debuff_duration])
				SkillData.EffectType.LEARN_SKILL:
					_try_learn_skill(actor, t, skill)

	_end_player_turn()

func _show_item_menu(actor: StringName) -> void:
	_clear_action_area()

	var back := Button.new()
	back.text = "< Back"
	back.pressed.connect(func(): _player_command_menu(actor))
	_action_area.add_child(back)

	var desc_lbl := _make_description_label()
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
		btn.mouse_entered.connect(func(): desc_lbl.text = item.description)

		_action_area.add_child(btn)

	if not any:
		var lbl := Label.new()
		lbl.text = "No usable items."
		_action_area.add_child(lbl)

	_action_area.add_child(desc_lbl)

func _make_description_label() -> Label:
	var desc_lbl := Label.new()
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(0, 36)
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.68, 0.72, 1))

	return desc_lbl

func _use_item(actor: StringName, item_id: StringName) -> void:
	var item := ContentDatabase.get_item(item_id)
	_begin_target_select(actor, func(t): _apply_item(actor, item, t), _living_party())

func _apply_item(actor: StringName, item: ItemData, target) -> void:
	var student := PartyManager.get_student(target)
	if student == null or not item.use_item(student):
		return

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
