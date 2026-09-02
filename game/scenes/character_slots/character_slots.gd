extends Control


func _on_slot_pressed(_slot_index: int) -> void:
	# TODO(INBOX #3): 슬롯에 저장된 캐릭터가 있으면 바로 월드로 입장시켜야 한다.
	# 지금은 모든 슬롯이 항상 비어 있으므로 커스터마이징 화면(임시)으로 보낸다.
	get_tree().change_scene_to_file("res://scenes/placeholder/placeholder.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
