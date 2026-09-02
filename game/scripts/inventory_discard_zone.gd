extends Control
## 인벤토리 창(UI/InventoryWindow)에 붙는 "바깥으로 드래그하면 버리기" 처리 (INBOX #31).
## 슬롯 셀(inventory_slot_cell.gd)이 자기 위치에서 먼저 드롭을 받으므로, 이 스크립트의
## _drop_data까지 올라오는 경우는 실제로 슬롯이 아닌 곳(빈 배경, 창 바깥 여백)에
## 놓았을 때뿐이다 — Godot은 드롭 대상을 찾을 때 마우스 아래 Control에서 시작해
## _can_drop_data가 true를 반환할 때까지 부모 Control로 거슬러 올라간다.

## world.gd가 _ready()에서 채워준다 (discard_inventory_slot() 호출용).
var world_ref: Node = null


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("slot_kind") and data.has("slot_index")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if world_ref != null:
		world_ref.discard_inventory_slot(data["slot_kind"], data["slot_index"])
