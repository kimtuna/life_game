extends Node2D

@onready var player_sprite: Sprite2D = $Player


func _ready() -> void:
	var character := CharacterData.get_character(CharacterData.active_slot_index)
	var variant: String = character.get("variant", "green")
	player_sprite.texture = load("res://assets/sprites/character/%s_south.png" % variant)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
