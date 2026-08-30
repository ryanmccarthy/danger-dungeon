extends Control

## University hub: pure navigation. Shows the map of facility buttons and
## decides which room scene to enter — all facility-specific logic (shop
## buy/sell, cooking, healing, party assignment, upgrades, quest list) lives
## in that facility's own scene under scenes/hub/rooms/. Hub itself is never
## freed while browsing a room (GameState.current_mode stays HUB throughout),
## so music and the HUD keep running uninterrupted.

const HOME_AREA_ID := &"forest_approach"

const CAFETERIA_ROOM := preload("res://scenes/hub/rooms/cafeteria_room.tscn")
const NURSE_ROOM := preload("res://scenes/hub/rooms/nurse_room.tscn")
const LIBRARY_ROOM := preload("res://scenes/hub/rooms/library_room.tscn")
const SHOP_ROOM := preload("res://scenes/hub/rooms/shop_room.tscn")
const DORM_ROOM := preload("res://scenes/hub/rooms/dorm_room.tscn")
const GARAGE_ROOM := preload("res://scenes/hub/rooms/garage_room.tscn")
const QUEST_BOARD_ROOM := preload("res://scenes/hub/rooms/quest_board_room.tscn")

@onready var _music: AudioStreamPlayer = $MusicPlayer
@onready var _hud_label: Label = $MainMargin/MainVBox/HUDLabel
@onready var _status_label: Label = $MainMargin/MainVBox/StatusLabel
@onready var _background: TextureRect = $Background
@onready var _map_root: Control = $MainMargin
@onready var _room_holder: Control = $RoomLayer/RoomHolder

var _current_room: Control = null

func _ready() -> void:
	$MainMargin/MainVBox/FacilityGrid/BtnCafeteria.pressed.connect(func(): _enter_room(CAFETERIA_ROOM))
	$MainMargin/MainVBox/FacilityGrid/BtnNurse.pressed.connect(func(): _enter_room(NURSE_ROOM))
	$MainMargin/MainVBox/FacilityGrid/BtnLibrary.pressed.connect(func(): _enter_room(LIBRARY_ROOM))
	$MainMargin/MainVBox/FacilityGrid/BtnShop.pressed.connect(func(): _enter_room(SHOP_ROOM))
	$MainMargin/MainVBox/FacilityGrid/BtnDorm.pressed.connect(func(): _enter_room(DORM_ROOM))
	$MainMargin/MainVBox/FacilityGrid/BtnGarage.pressed.connect(func(): _enter_room(GARAGE_ROOM))
	$MainMargin/MainVBox/FacilityGrid/BtnQuestBoard.pressed.connect(func(): _enter_room(QUEST_BOARD_ROOM))
	$MainMargin/MainVBox/FacilityGrid/BtnDepart.pressed.connect(_on_depart_pressed)

	EventBus.supplies_changed.connect(func(_v): _refresh_hud())
	EventBus.inventory_changed.connect(func(_id, _v): _refresh_hud())
	EventBus.student_died.connect(func(_id): _refresh_hud())
	EventBus.student_revived.connect(func(_id): _refresh_hud())
	EventBus.party_wiped.connect(_on_party_wiped)

	_music.finished.connect(func(): _music.play())
	_music.play()

	_refresh_hud()

func enter_state(context: Dictionary = {}) -> void:
	_refresh_hud()
	if context.get("forced", false):
		_status_label.text = "The whole team went down out there. Reassign who's exploring next."
		_enter_room(DORM_ROOM)

func _on_party_wiped() -> void:
	_status_label.text = "Party wiped! Forced back to campus — pick a new team at the Dorm."

func _refresh_hud() -> void:
	var alive := PartyManager.get_living_roster().size()
	_hud_label.text = "Supplies: %d   |   Roster: %d / 26 alive" % [InventoryManager.supplies, alive]

func _on_depart_pressed() -> void:
	var area: AreaData = ContentDatabase.get_area(HOME_AREA_ID)

	if PartyManager.get_active_party().is_empty():
		_status_label.text = "You need at least one student in your party to depart."
	elif PartyManager.get_living_roster().is_empty():
		_status_label.text = "Game Over: All students have perished."
	elif GameState.depart_university(area):
		_status_label.text = "Departed for %s." % area.display_name
	else:
		_status_label.text = "Not enough supplies to depart (need %d)." % InventoryManager.get_travel_cost(area)

func _enter_room(scene: PackedScene) -> void:
	if _current_room != null:
		return

	_current_room = scene.instantiate()
	_current_room.back_requested.connect(_exit_room)
	_room_holder.add_child(_current_room)
	_room_holder.visible = true
	_background.visible = false
	_map_root.visible = false

func _exit_room() -> void:
	if _current_room != null:
		_current_room.queue_free()
		_current_room = null

	_room_holder.visible = false
	_background.visible = true
	_map_root.visible = true
	_refresh_hud()
