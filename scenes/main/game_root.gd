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

func _on_mode_changed(old_mode, new_mode, context: Dictionary) -> void:
	var effect := _cover_effect_for(old_mode, new_mode)
	var duration := (
		ScreenTransition.DUR_BATTLE
		if old_mode == GameState.GameMode.BATTLE or new_mode == GameState.GameMode.BATTLE
		else ScreenTransition.DUR_TRAVEL
	)
	ScreenTransition.play(
		func(): _swap_to(new_mode, context),
		effect,
		duration,
		_uncover_effect_for(old_mode, new_mode),
	)

## Deliberately asymmetric around battle: you get swirled into a fight, and the
## dungeon resolves back out of pixel blocks (which also hides the full
## DungeonBuilder geometry rebuild on the way back).
func _cover_effect_for(old_mode, new_mode) -> int:
	if new_mode == GameState.GameMode.BATTLE:
		return ScreenTransition.Effect.SWIRL
	if old_mode == GameState.GameMode.BATTLE:
		return ScreenTransition.Effect.PIXELATE
	return ScreenTransition.Effect.DISSOLVE

func _uncover_effect_for(old_mode, new_mode) -> int:
	if new_mode == GameState.GameMode.BATTLE:
		return ScreenTransition.Effect.FADE
	return _cover_effect_for(old_mode, new_mode)

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
