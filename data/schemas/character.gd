@tool
class_name CharacterData
extends Resource

@export var portrait: CompressedTexture2D = preload("res://data/assets/generic.png")
@export var standing_portrait: CompressedTexture2D = null
@export var status_effects: Array[String] = [StatusEffects.FINE]
@export var display_name: String
@export var is_student: bool = false

@export_group("Stats")
@export var max_hp: int = 20
@export var current_hp: int = max_hp
@export var max_mp: int = 0
@export var max_san: int = 100
@export var current_san: int = 100

func restore_health(amount: int):
	current_hp = min(current_hp + amount, max_hp)

func restore_sanity(amount: int):
	current_san = min(current_san + amount, max_san)

func reduce_health(amount: int):
	current_hp = max(current_hp - amount, 0)

func reduce_sanity(amount: int):
	current_san = max(current_san - amount, 0)
