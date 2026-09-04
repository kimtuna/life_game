extends Node2D
## 저장 상자 (INBOX #96, 사용자 지시 2026-09-04). processing_table.gd와 같은 "근처에서
## 좌클릭" 패턴으로 상호작용해 상자 UI(world.gd의 범용 저장 상자 창)를 연다.
## 플레이어 인벤토리(InventoryData)와 완전히 별개인 자체 슬롯 배열을 갖고,
## InventoryData.STACK_MAX(99) 제한을 받지 않는다 — 슬롯 하나에 999개 같은 큰 수량을
## 그대로 저장할 수 있다. 플레이어 인벤토리로 옮길 때만(InventoryData.add_item()을 거쳐서)
## 99 스택 제한이 자연스럽게 적용된다.
## 이 오브젝트는 테스트용 한정이 아니라 나중에 실제 게임에도 쓰일 저장 기능의 기반이다
## (INBOX #96 원문) — 다만 재료를 미리 999개씩 채워 넣는 건 INBOX #97의 몫이라 이 상자는
## 처음엔 비어 있다.
## 이 오브젝트의 월드 그림은 이번 항목 범위가 아니다(임시 ColorRect) — 실제 그림은 나중
## [DESIGN] 항목에서 만든다.

const INTERACT_RADIUS := 90.0
const CHEST_TITLE := "저장 상자"
const SLOT_COUNT := 20

## true면 슬롯 배열이 고정 SLOT_COUNT가 아니라 아이템 종류 수만큼 자동으로 늘어난다
## (INBOX #116). world.gd의 테스트용 상자(_spawn_storage_chest())만 이 옵션을 켠다 —
## 나중에 플레이어가 실제로 짓는 저장 상자는 이 옵션을 끈 채(기본값 false) 그대로
## 고정 슬롯 수로 재사용할 수 있다.
var unlimited: bool = false

## 한 번 클릭으로 상자 슬롯에서 플레이어 인벤토리로 옮기는 최대 수량. 상자는 스택 제한이
## 없어 한 슬롯에 999개가 있을 수 있는데, 한 번에 다 옮기려 하면 플레이어 인벤토리 공간이
## 거의 항상 모자라 실패할 것이므로, 플레이어 쪽 스택 크기(InventoryData.STACK_MAX)만큼씩
## 옮긴다(INBOX #96 원문 "클릭 한 번에 최대 99개씩 옮기거나" 선택지를 그대로 채택).
const TRANSFER_AMOUNT := 99

## 슬롯 배열: 각 원소는 null(빈 슬롯) 또는 {"item": String, "count": int}.
## InventoryData의 슬롯과 달리 count에 상한이 없다.
var _slots: Array = []

## world.gd의 상자 창이 슬롯 변화(채우기/꺼내기)에 맞춰 다시 그릴 수 있도록 알린다.
signal changed

@onready var prompt: Label = $Prompt

## world.gd가 스폰 직후 채워준다 (다른 상호작용 오브젝트와 같은 패턴).
var player_ref: Node2D = null
var world_ref: Node2D = null


func _ready() -> void:
	if not unlimited:
		_slots.resize(SLOT_COUNT)
	prompt.visible = false


func _process(_delta: float) -> void:
	var in_range := player_ref != null \
			and global_position.distance_to(player_ref.global_position) <= INTERACT_RADIUS
	prompt.visible = in_range and world_ref != null \
			and not world_ref.is_crafting_open() and not world_ref.is_storage_open()


func _unhandled_input(event: InputEvent) -> void:
	if not prompt.visible or world_ref == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		world_ref.open_storage_window(CHEST_TITLE, self)


## ---- 슬롯 조회/조작 (world.gd의 저장 상자 UI, INBOX #97의 초기 채우기 로직이 쓴다) ----

func get_slots() -> Array:
	return _slots.duplicate(true)


## 상자 자체에 아이템을 채운다(초기 채우기용, INBOX #97). 스택 제한이 없어 같은 아이템이
## 이미 있는 슬롯에 개수만 더한다 — 없으면 빈 슬롯에 새로 채운다.
func add_item(item_name: String, amount: int) -> void:
	for slot in _slots:
		if slot != null and slot.get("item") == item_name:
			slot["count"] = int(slot["count"]) + amount
			changed.emit()
			return
	for i in range(_slots.size()):
		if _slots[i] == null:
			_slots[i] = {"item": item_name, "count": amount}
			changed.emit()
			return
	# 빈 슬롯이 없을 때: unlimited면 슬롯을 새로 늘려서 담고(INBOX #116), 아니면(일반
	# 게임용 고정 슬롯 상자) 예전과 같이 조용히 못 넣는다(용량 초과 처리는 범위 밖).
	if unlimited:
		_slots.append({"item": item_name, "count": amount})
		changed.emit()


## 상자 슬롯 하나에서 플레이어 인벤토리로 최대 TRANSFER_AMOUNT개를 옮기려 시도한다.
## 플레이어 인벤토리에 공간이 부족하면 아무것도 옮기지 않고 false를 반환한다(호출부가
## "인벤토리에 공간이 없으면 실패 표시"를 하도록, INBOX #96 원문 요구사항).
func try_transfer_to_player(index: int) -> bool:
	if index < 0 or index >= _slots.size():
		return false
	var slot = _slots[index]
	if slot == null:
		return false
	var item: String = slot["item"]
	var move_amount: int = min(int(slot["count"]), TRANSFER_AMOUNT)
	if not InventoryData.has_room(item, move_amount):
		return false
	InventoryData.add_item(item, move_amount)
	slot["count"] = int(slot["count"]) - move_amount
	if int(slot["count"]) <= 0:
		_slots[index] = null
	changed.emit()
	return true
