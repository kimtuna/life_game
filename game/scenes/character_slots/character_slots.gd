extends Control

@onready var slot_buttons: Array[Button] = [
	$CenterContainer/VBoxContainer/SlotsRow/Slot1Button,
	$CenterContainer/VBoxContainer/SlotsRow/Slot2Button,
	$CenterContainer/VBoxContainer/SlotsRow/Slot3Button,
]


func _ready() -> void:
	for i in range(slot_buttons.size()):
		_refresh_slot_button(i)


func _refresh_slot_button(slot_index: int) -> void:
	var button := slot_buttons[slot_index]
	var character := CharacterData.get_character(slot_index)
	if character.is_empty():
		button.text = "슬롯 %d\n\n+\n\n빈 슬롯" % (slot_index + 1)
	else:
		var label: String = String(character.get("label", "모험가"))
		button.text = "슬롯 %d\n\n%s\n\n입장하기" % [slot_index + 1, label]


func _on_slot_pressed(slot_index: int) -> void:
	CharacterData.active_slot_index = slot_index
	if CharacterData.has_character(slot_index):
		get_tree().change_scene_to_file("res://scenes/world/world.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/character_customization/character_customization.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
