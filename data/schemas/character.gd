@tool
class_name CharacterData
extends Resource

@export var portrait: CompressedTexture2D = preload("res://data/assets/enemies/generic.png")
@export var status_effects: Array[String] = [StatusEffects.FINE]
@export var display_name: String

@export_group("Stats")
@export var max_hp: int = 20
@export var max_mp: int = 0
