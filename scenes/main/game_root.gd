extends Node

## State-machine root: swaps Hub/Dungeon/Battle scenes based on
## GameState.mode_changed and forwards enter_state(context) to whichever
## scene becomes active. Nothing else in the project holds a cross
## reference between those three scenes.

const TITLE_SCENE := preload("res://scenes/title/title_screen.tscn")
const HUB_SCENE := preload("res://scenes/hub/university_hub.tscn")
const DUNGEON_SCENE := preload("res://scenes/dungeon/dungeon_crawl.tscn")
const BATTLE_SCENE := preload("res://scenes/battle/battle_scene.tscn")

@onready var _holder: Node = $CurrentSceneHolder

var _current: Node = null

func _ready() -> void:
	GameState.mode_changed.connect(_on_mode_changed)
	EventBus.game_over.connect(_on_game_over)
	_swap_to(GameState.current_mode, {})

func _on_mode_changed(_old_mode, new_mode, context: Dictionary) -> void:
	_swap_to(new_mode, context)

func _on_game_over() -> void:
	push_warning("[GameRoot] GAME OVER — all 26 students have died.")

func _swap_to(mode: int, context: Dictionary) -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	var scene: PackedScene
	match mode:
		GameState.GameMode.TITLE:
			scene = TITLE_SCENE
		GameState.GameMode.HUB:
			scene = HUB_SCENE
		GameState.GameMode.DUNGEON:
			scene = DUNGEON_SCENE
		GameState.GameMode.BATTLE:
			scene = BATTLE_SCENE
	if scene == null:
		return
	_current = scene.instantiate()
	_holder.add_child(_current)
	if _current.has_method("enter_state"):
		_current.enter_state(context)
