extends Control

@onready var resolution_option: OptionButton = $CenterContainer/VBoxContainer/ResolutionOption


func _ready() -> void:
	resolution_option.clear()
	for i in range(SettingsData.RESOLUTIONS.size()):
		resolution_option.add_item(SettingsData.resolution_label(i))
	resolution_option.select(SettingsData.resolution_index)


func _on_resolution_option_item_selected(index: int) -> void:
	SettingsData.set_resolution(index)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
