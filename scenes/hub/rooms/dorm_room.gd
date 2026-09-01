extends HubRoomBase

## Dorm: assign the party's front row, back row, and bench.

func _build() -> void:
	_add_header("Front row: %d/3   Back row: %d/3  " % [PartyManager.front_row_ids.size(), PartyManager.MAX_BACK])

	for s in PartyManager.get_usable_roster():
		var label := "%s (%s - %s) HP %d/%d" % [s.display_name, s.student_class.class_name_display, s.student_class.archetype_tag, s.current_hp, s.max_hp]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.size_flags_horizontal = Control.SIZE_FILL
		var lbl := Label.new()
		lbl.text = label
		lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		row.add_child(lbl)

		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)

		if PartyManager.is_in_party(s.student_id):
			var button_container := HBoxContainer.new()
			button_container.add_theme_constant_override("separation", 20)
			button_container.size_flags_horizontal = Control.SIZE_SHRINK_END

			var position_label = Label.new()
			position_label.text = "[%s]" % ["Front" if PartyManager.is_in_front_row(s.student_id) else "Back"]
			button_container.add_child(position_label)

			var btn := Button.new()
			btn.text = "Bench"
			btn.pressed.connect(func(): _do_bench(s.student_id))
			button_container.add_child(btn)

			row.add_child(button_container)
		else:
			var button_container := HBoxContainer.new()
			button_container.add_theme_constant_override("separation", 10)
			button_container.size_flags_horizontal = Control.SIZE_SHRINK_END

			var front_btn := Button.new()
			front_btn.text = "-> Front"
			front_btn.disabled = PartyManager.front_row_ids.size() >= PartyManager.MAX_FRONT
			front_btn.pressed.connect(func(): _do_assign(s.student_id, "front"))
			button_container.add_child(front_btn)

			var back_btn := Button.new()
			back_btn.text = "-> Back"
			back_btn.disabled = PartyManager.back_row_ids.size() >= PartyManager.MAX_BACK
			back_btn.pressed.connect(func(): _do_assign(s.student_id, "back"))
			button_container.add_child(back_btn)

			row.add_child(button_container)

		var end_adjuster = Control.new()
		end_adjuster.custom_minimum_size = Vector2(10,0)
		row.add_child(end_adjuster)
		_content.add_child(row)

func _do_assign(id: StringName, row: String) -> void:
	PartyManager.assign_to_party(id, row)
	_refresh()

func _do_bench(id: StringName) -> void:
	PartyManager.remove_from_party(id)
	_refresh()
