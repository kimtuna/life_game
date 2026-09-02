extends Node
## 오토로드 싱글톤: 인벤토리(아이템 종류·개수) 상태를 담당한다. (INBOX #10)
## `user://inventory.save`에 JSON으로 저장해 앱을 껐다 켜도 아이템이 유지된다.

const SAVE_PATH := "user://inventory.save"

## 인벤토리 변화(HUD 갱신용) 신호.
signal changed

var _counts: Dictionary = {}


func _ready() -> void:
	_load()


func get_count(item_name: String) -> int:
	return _counts.get(item_name, 0)


func add_item(item_name: String, amount: int) -> void:
	_counts[item_name] = get_count(item_name) + amount
	_save()
	changed.emit()


func all_counts() -> Dictionary:
	return _counts.duplicate()


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_counts))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_counts = parsed
