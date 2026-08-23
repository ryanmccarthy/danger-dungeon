extends Control

## Title screen: plays theme music on loop, Start Game hands off to the
## Hub via GameState, Quit Game exits the app.

@onready var _music: AudioStreamPlayer = $MusicPlayer
@onready var _start_button: Button = $ButtonBox/StartButton
@onready var _quit_button: Button = $ButtonBox/QuitButton

func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_music.finished.connect(_on_music_finished)
	_music.play()

func _on_music_finished() -> void:
	_music.play()

func _on_start_pressed() -> void:
	GameState.change_mode(GameState.GameMode.HUB)

func _on_quit_pressed() -> void:
	get_tree().quit()
