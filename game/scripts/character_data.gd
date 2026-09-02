extends Node
## 오토로드 싱글톤: 캐릭터 슬롯 저장/조회를 담당한다.
## `user://characters.save`에 JSON으로 저장해 앱을 껐다 켜도 슬롯이 유지된다.

const SAVE_PATH := "user://characters.save"
const SLOT_COUNT := 3

## 슬롯 화면 -> 커스터마이징/월드 씬으로 넘어갈 때 "지금 다루는 슬롯 번호"를 전달하는 용도.
## (Godot는 change_scene에 인자를 직접 못 넘기므로 오토로드 전역 상태로 대신한다.)
var active_slot_index: int = -1

var slots: Array = [null, null, null]


func _ready() -> void:
	_load()


func has_character(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < slots.size() and slots[slot_index] != null


func get_character(slot_index: int) -> Dictionary:
	if has_character(slot_index):
		return slots[slot_index]
	return {}


func save_character(slot_index: int, data: Dictionary) -> void:
	slots[slot_index] = data
	_save()


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(slots))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		for i in range(min(SLOT_COUNT, parsed.size())):
			slots[i] = parsed[i]
