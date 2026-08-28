class_name HubRoomBase
extends Control

## Shared base for every hub facility room (Cafeteria, Nurse, Library, Shop,
## Dorm, Garage, Quest Board). Provides the row/header procedural-UI helpers
## that used to live on university_hub.gd's popup builder, plus the
## back-button wiring every room needs to return to the hub map.

signal back_requested

@warning_ignore_start("unused_private_class_variable")
@onready var _content: VBoxContainer = $MainMargin/MainVBox/PopupScroll/PopupContent
@onready var _status_label: Label = $MainMargin/MainVBox/StatusLabel
@onready var _hud_label: Label = $MainMargin/MainVBox/HUDLabel
@onready var _back_button: Button = $MainMargin/MainVBox/BackButton

func _ready() -> void:
	_back_button.pressed.connect(func(): back_requested.emit())
	_refresh_hud()
	_refresh()

## Subclasses override this to populate _content with their facility's rows.
func _build() -> void:
	pass

func _refresh() -> void:
	for c in _content.get_children():
		c.queue_free()
	_build()

func _refresh_hud() -> void:
	var alive := PartyManager.get_living_roster().size()
	_hud_label.text = "Supplies: %d   |   Roster: %d / 26 alive" % [InventoryManager.supplies, alive]

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

	_content.add_child(row)

func _add_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("#e0c14a"))
	_content.add_child(label)
