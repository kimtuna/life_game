extends Node
## 오토로드 싱글톤: 인벤토리(슬롯 기반) 상태를 담당한다. (INBOX #21)
## 일반 슬롯 18칸(그중 앞 9칸이 핫바를 겸함) + 장비 슬롯 9칸(고정 부위)으로 구성된다.
## `user://inventory.save`에 JSON으로 저장해 앱을 껐다 켜도 아이템이 유지된다.

const SAVE_PATH := "user://inventory.save"

const GENERAL_SLOT_COUNT := 18
const HOTBAR_SIZE := 9
const STACK_MAX := 99

## 장비 슬롯 부위(고정 순서). DESIGN.md "인벤토리 / 장비" 절 그대로: 모자1/상의1/하의1/
## 신발1/목걸이2/반지2/가방1.
const EQUIPMENT_SLOT_TYPES := [
	"hat", "top", "bottom", "shoes",
	"necklace", "necklace", "ring", "ring", "bag",
]

## 인벤토리 변화(HUD/인벤토리 창 갱신용) 신호.
signal changed

## 일반 슬롯: 각 원소는 null(빈 슬롯) 또는 {"item": String, "count": int}.
var _general_slots: Array = []
## 장비 슬롯: 각 원소는 null(빈 슬롯) 또는 {"item": String}. 부위는 EQUIPMENT_SLOT_TYPES 참고.
var _equipment_slots: Array = []


func _ready() -> void:
	_general_slots.resize(GENERAL_SLOT_COUNT)
	_equipment_slots.resize(EQUIPMENT_SLOT_TYPES.size())
	_load()


## ---- 슬롯 조회 (인벤토리 창 UI용) ----

func get_general_slots() -> Array:
	return _general_slots.duplicate(true)


func get_equipment_slots() -> Array:
	return _equipment_slots.duplicate(true)


## ---- 기존 카운트 기반 API (사냥/채집/채광/농사/목장 호출부 호환용) ----

func get_count(item_name: String) -> int:
	var total := 0
	for slot in _general_slots:
		if slot != null and slot.get("item") == item_name:
			total += slot.get("count", 0)
	return total


## 같은 아이템이 이미 있는 슬롯부터 채우고, 남으면 빈 슬롯에 새 스택을 만든다.
## 빈 슬롯이 모자라 다 못 넣으면 넣은 만큼만 넣는다(18칸이 넉넉해 실사용에서는 거의
## 발생하지 않는다).
func add_item(item_name: String, amount: int) -> void:
	var remaining := amount
	for i in range(_general_slots.size()):
		if remaining <= 0:
			break
		var slot = _general_slots[i]
		if slot != null and slot.get("item") == item_name and slot.get("count", 0) < STACK_MAX:
			var space: int = STACK_MAX - int(slot["count"])
			var add: int = min(space, remaining)
			slot["count"] = int(slot["count"]) + add
			remaining -= add
	for i in range(_general_slots.size()):
		if remaining <= 0:
			break
		if _general_slots[i] == null:
			var add: int = min(STACK_MAX, remaining)
			_general_slots[i] = {"item": item_name, "count": add}
			remaining -= add
	_save()
	changed.emit()


func has_item(item_name: String, amount: int = 1) -> bool:
	return get_count(item_name) >= amount


## 성공하면 true를 반환하고 개수를 뺀다(다 빠진 슬롯은 다시 빈 슬롯이 된다). 보유량이
## 부족하면 아무것도 바꾸지 않고 false.
func remove_item(item_name: String, amount: int) -> bool:
	if not has_item(item_name, amount):
		return false
	var remaining := amount
	for i in range(_general_slots.size()):
		if remaining <= 0:
			break
		var slot = _general_slots[i]
		if slot != null and slot.get("item") == item_name:
			var take: int = min(int(slot["count"]), remaining)
			slot["count"] = int(slot["count"]) - take
			remaining -= take
			if int(slot["count"]) <= 0:
				_general_slots[i] = null
	_save()
	changed.emit()
	return true


## ---- 슬롯 이동/버리기 (드래그 앤 드롭, INBOX #31) ----

func _array_for(kind: String) -> Variant:
	if kind == "general":
		return _general_slots
	if kind == "equipment":
		return _equipment_slots
	return null


## 슬롯 사이에서 아이템을 옮긴다(일반↔일반, 일반↔장비, 핫바 포함 — 핫바는 일반 슬롯의
## 앞 9칸일 뿐이라 별도 kind가 없다). general↔general이고 같은 아이템이면 스택을
## 합치고(공간이 남는 만큼만), 그 외에는 두 슬롯 내용을 통째로 교환한다(swap) — 대상이
## 비어 있으면 그냥 이동한 것과 같다.
func move_slot(from_kind: String, from_index: int, to_kind: String, to_index: int) -> void:
	if from_kind == to_kind and from_index == to_index:
		return
	var from_array = _array_for(from_kind)
	var to_array = _array_for(to_kind)
	if from_array == null or to_array == null:
		return
	if from_index < 0 or from_index >= from_array.size():
		return
	if to_index < 0 or to_index >= to_array.size():
		return
	var from_val = from_array[from_index]
	if from_val == null:
		return
	var to_val = to_array[to_index]
	if from_kind == "general" and to_kind == "general" and to_val != null \
			and to_val.get("item") == from_val.get("item"):
		var space: int = STACK_MAX - int(to_val["count"])
		var move_amount: int = min(space, int(from_val["count"]))
		if move_amount > 0:
			to_val["count"] = int(to_val["count"]) + move_amount
			from_val["count"] = int(from_val["count"]) - move_amount
			from_array[from_index] = from_val if int(from_val["count"]) > 0 else null
			_save()
			changed.emit()
		return
	to_array[to_index] = from_val
	from_array[from_index] = to_val
	_save()
	changed.emit()


## 슬롯 내용을 반환하고 그 자리를 비운다(버리기용). 빈 슬롯이면 빈 딕셔너리를 반환한다.
func take_slot(kind: String, index: int) -> Dictionary:
	var arr = _array_for(kind)
	if arr == null or index < 0 or index >= arr.size():
		return {}
	var val = arr[index]
	if val == null:
		return {}
	arr[index] = null
	_save()
	changed.emit()
	return val


func all_counts() -> Dictionary:
	var counts := {}
	for slot in _general_slots:
		if slot != null:
			var item: String = slot["item"]
			counts[item] = counts.get(item, 0) + int(slot["count"])
	return counts


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"general": _general_slots,
		"equipment": _equipment_slots,
	}))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.has("general"):
		_load_slots(_general_slots, parsed.get("general", []))
		_load_slots(_equipment_slots, parsed.get("equipment", []))
	elif parsed is Dictionary:
		# 옛 저장 형식(아이템명 -> 개수 딕셔너리, INBOX #21 이전)에서 마이그레이션한다.
		for item_name in parsed.keys():
			var count := int(parsed[item_name])
			if count > 0:
				add_item(item_name, count)


func _load_slots(target: Array, saved: Array) -> void:
	for i in range(target.size()):
		if i < saved.size() and saved[i] != null:
			target[i] = saved[i]
