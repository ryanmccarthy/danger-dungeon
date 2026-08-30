extends HubRoomBase

## Dorm: assign the party's front row, back row, and bench.

func _build() -> void:
	_add_header("Front row: %d/3   Back row: %d/3  " % [PartyManager.front_row_ids.size(), PartyManager.MAX_BACK])

	for s in PartyManager.get_usable_roster():
		var in_front := PartyManager.front_row_ids.has(s.student_id)
		var in_back := PartyManager.back_row_ids.has(s.student_id)
		var loc := "Front" if in_front else ("Back" if in_back else "Bench")
		var label := "%s (%s - %s) [%s] HP %d/%d" % [s.display_name, s.student_class.class_name_display, s.student_class.archetype_tag, loc, s.current_hp, s.max_hp]

		if in_front or in_back:
			_add_row(label, "Bench", func(): _do_bench(s.student_id))
		else:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			row.size_flags_horizontal = Control.SIZE_SHRINK_END
			var lbl := Label.new()
			lbl.text = label
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
			_content.add_child(row)

func _do_assign(id: StringName, row: String) -> void:
	PartyManager.assign_to_party(id, row)
	_refresh()

func _do_bench(id: StringName) -> void:
	PartyManager.remove_from_party(id)
	_refresh()
