extends PanelContainer
## 인벤토리 창의 슬롯 하나 (INBOX #31). world.gd의 _build_inventory_slots()가
## 코드로 PanelContainer를 만든 뒤 이 스크립트를 붙이고 slot_kind/slot_index를 채운다.
## 실제 데이터 이동은 InventoryData(오토로드)에 바로 위임한다 — 슬롯 셀은 "어느
## 슬롯인지"만 알면 되고 인벤토리 로직을 몰라도 된다.

var slot_kind: String = "general"  ## "general" 또는 "equipment"
var slot_index: int = 0


func _get_drag_data(_at_position: Vector2) -> Variant:
	var arr := InventoryData.get_general_slots() if slot_kind == "general" else InventoryData.get_equipment_slots()
	if slot_index >= arr.size() or arr[slot_index] == null:
		return null
	var slot: Dictionary = arr[slot_index]
	var preview := Label.new()
	preview.text = str(slot.get("item", ""))
	preview.add_theme_font_size_override("font_size", 13)
	preview.modulate = Color(1, 1, 1, 0.85)
	set_drag_preview(preview)
	return {"slot_kind": slot_kind, "slot_index": slot_index}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("slot_kind") and data.has("slot_index")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	InventoryData.move_slot(data["slot_kind"], data["slot_index"], slot_kind, slot_index)
