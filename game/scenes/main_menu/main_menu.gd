extends Control


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/character_slots/character_slots.tscn")


func _on_settings_pressed() -> void:
	SettingsData.return_scene_path = "res://scenes/main_menu/main_menu.tscn"
	get_tree().change_scene_to_file("res://scenes/settings/settings.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
