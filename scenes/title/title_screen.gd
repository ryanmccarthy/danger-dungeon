extends Control

## Title screen: plays theme music on loop, Start Game hands off to the
## Hub via GameState, Load Game opens a slot picker backed by SaveManager,
## Quit Game exits the app.

const GOLD := Color(0.8784314, 0.75686276, 0.2901961, 1)
const DIM_TEXT := Color(0.7, 0.68, 0.72, 1)
const BAD_TEXT := Color(0.83137256, 0.42, 0.42, 1)
const ROW_BORDER := Color(0.32, 0.29, 0.31, 1)

const SAVE_SLOT_COUNT := 3

@onready var _music: AudioStreamPlayer = $MusicPlayer
@onready var _start_button: Button = $ButtonBox/StartButton
@onready var _load_button: Button = $ButtonBox/LoadButton
@onready var _quit_button: Button = $ButtonBox/QuitButton

@onready var _load_panel_root: Control = $LoadPanelRoot
@onready var _load_body: VBoxContainer = $LoadPanelRoot/LoadPanel/LoadMargin/LoadVBox/LoadBody
@onready var _load_back_button: Button = $LoadPanelRoot/LoadPanel/LoadMargin/LoadVBox/LoadHeaderRow/LoadBackButton

var _load_status_text: String = ""

func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_load_button.pressed.connect(_on_load_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_load_back_button.pressed.connect(_close_load_panel)
	_music.finished.connect(_on_music_finished)
	_music.play()

func _on_music_finished() -> void:
	_music.play()

func _on_start_pressed() -> void:
	GameState.change_mode(GameState.GameMode.HUB)

func _on_quit_pressed() -> void:
	get_tree().quit()

# ------------------------------------------------------------------ Load Game
func _on_load_pressed() -> void:
	_load_status_text = ""
	_load_panel_root.visible = true
	_refresh_load_body()

func _close_load_panel() -> void:
	_load_panel_root.visible = false

func _refresh_load_body() -> void:
	for c in _load_body.get_children():
		c.queue_free()

	for slot in range(SAVE_SLOT_COUNT):
		_load_body.add_child(_make_load_slot_row(slot))

	if _load_status_text != "":
		var status_lbl := Label.new()
		status_lbl.text = _load_status_text
		status_lbl.add_theme_color_override("font_color", BAD_TEXT)
		status_lbl.add_theme_font_size_override("font_size", 16)
		_load_body.add_child(status_lbl)

func _make_load_slot_row(slot: int) -> Control:
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
	name_lbl.add_theme_font_size_override("font_size", 20)
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
	detail_lbl.add_theme_font_size_override("font_size", 14)
	detail_lbl.add_theme_color_override("font_color", DIM_TEXT)
	info.add_child(detail_lbl)

	var load_btn := Button.new()
	load_btn.text = "Load"
	load_btn.custom_minimum_size = Vector2(100, 40)
	load_btn.add_theme_font_size_override("font_size", 16)
	load_btn.disabled = not has_save
	load_btn.pressed.connect(func(): _on_load_slot_pressed(slot))
	hbox.add_child(load_btn)

	return row

func _on_load_slot_pressed(slot: int) -> void:
	if SaveManager.load_game(slot):
		_close_load_panel()
		GameState.change_mode(GameState.GameMode.HUB)
		return
	_load_status_text = "Failed to load Slot %d." % (slot + 1)
	_refresh_load_body()

func _row_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.08, 1.0)
	sb.set_border_width_all(1)
	sb.border_color = ROW_BORDER
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	return sb
