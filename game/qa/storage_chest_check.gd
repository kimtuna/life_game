extends Node
## [BUILD] INBOX #96 확인용 — 저장 상자가 실제로 스폰되고, 상자 UI를 열고 닫을 수 있고,
## 상자 슬롯(코드로 미리 채워넣은 것)에서 플레이어 인벤토리로 아이템을 꺼낼 수 있고,
## 인벤토리에 공간이 없을 때는 실패 표시가 뜨는지 실제 게임을 실행해서 검증한다.
## processing_table_check.gd(#87)/gunpowder_ammo_check.gd(#89)와 같은 방법: project.godot
## [autoload]에 이 스크립트를 임시로 추가하고 `godot --path .`로 실행한 뒤 되돌린다.
## 상자에 999개씩 채워 넣는 정식 초기화(#97)는 이번 항목 범위가 아니라서, 여기서는 이
## 스크립트가 직접 chest.add_item()으로 테스트 아이템을 채운다.

const OUT_DIR := "/tmp/qa96"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await _boot_to_world()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_run_checks()


func _boot_to_world() -> void:
	get_tree().current_scene._on_play_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene._on_slot_pressed(0)
	await get_tree().process_frame
	await get_tree().process_frame
	if get_tree().current_scene.has_method("_on_confirm_pressed"):
		get_tree().current_scene._on_confirm_pressed()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
	get_tree().current_scene._on_single_player_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _run_checks() -> void:
	var world := get_tree().current_scene
	var ok := true

	# 1) 저장 상자가 실제로 필드에 스폰됐는지.
	var chest = null
	var chest_script := load("res://scenes/storage_chest/storage_chest.gd")
	for child in world.get_children():
		if child.get_script() == chest_script:
			chest = child
			break
	if chest == null:
		print("FAIL: StorageChest not spawned in world")
		print("QA_STORAGE_CHEST_CHECK_FAIL")
		get_tree().quit()
		return

	# 2) 플레이어를 상자 근처로 옮기고 좌클릭으로 상자 창을 연다(처음엔 비어 있어야 함).
	world.player_sprite.global_position = chest.global_position
	await get_tree().process_frame
	await get_tree().process_frame
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	chest._unhandled_input(click)
	await get_tree().process_frame
	await get_tree().process_frame
	if not world.is_storage_open():
		print("FAIL: storage window did not open after click")
		ok = false
	var img_empty := get_tree().root.get_texture().get_image()
	img_empty.save_png(OUT_DIR + "/01_window_open_empty.png")

	# 3) 코드로 상자에 테스트 아이템을 채운다(#97의 999개 채우기와는 별개 — 이 항목은
	# "꺼내는 것"만 검증하면 되므로 작은 수치로 채운다). 상자는 스택 제한이 없어야 하므로
	# 99를 넘는 값(120)으로 채워 STACK_MAX를 실제로 넘는지도 함께 확인한다.
	chest.add_item("wood", 120)
	chest.add_item("stone", 5)
	await get_tree().process_frame
	await get_tree().process_frame
	var slots_after_fill: Array = chest.get_slots()
	var wood_slot = null
	for s in slots_after_fill:
		if s != null and s.get("item") == "wood":
			wood_slot = s
			break
	if wood_slot == null or int(wood_slot["count"]) != 120:
		print("FAIL: chest slot did not store 120 wood (no 99 stack cap expected), got: ", wood_slot)
		ok = false
	else:
		print("chest wood slot holds 120 (no stack cap) OK")
	var img_filled := get_tree().root.get_texture().get_image()
	img_filled.save_png(OUT_DIR + "/02_window_open_filled.png")

	# 4) 상자 슬롯(목재 120)에서 플레이어 인벤토리로 꺼낸다 — 클릭 한 번에 최대
	# TRANSFER_AMOUNT(99)만 옮겨져야 하고, 상자에는 21개가 남아야 한다.
	var wood_index := slots_after_fill.find(wood_slot)
	var player_wood_before: int = InventoryData.get_count("wood")
	var transferred: bool = chest.try_transfer_to_player(wood_index)
	await get_tree().process_frame
	await get_tree().process_frame
	var player_wood_after: int = InventoryData.get_count("wood")
	var chest_wood_after := 0
	for s in chest.get_slots():
		if s != null and s.get("item") == "wood":
			chest_wood_after = int(s["count"])
	print("transfer wood: player ", player_wood_before, " -> ", player_wood_after,
			" (expect +99), chest wood -> ", chest_wood_after, " (expect 21), transferred=", transferred)
	if not transferred or player_wood_after != player_wood_before + 99 or chest_wood_after != 21:
		print("FAIL: try_transfer_to_player did not move 99 wood correctly")
		ok = false
	var img_after_transfer := get_tree().root.get_texture().get_image()
	img_after_transfer.save_png(OUT_DIR + "/03_after_transfer.png")

	# 5) 인벤토리 공간이 전혀 없는 상태에서 다시 꺼내려 하면 실패(false)해야 하고, 상자
	# 슬롯 내용은 그대로 유지돼야 한다(잃어버리면 안 됨).
	var general_slots: Array = InventoryData.get_general_slots()
	var filler_i := 0
	for i in range(general_slots.size()):
		if general_slots[i] == null:
			InventoryData.add_item("test_filler_%d" % filler_i, InventoryData.STACK_MAX)
			filler_i += 1
	await get_tree().process_frame
	general_slots = InventoryData.get_general_slots()
	var has_empty_or_room := false
	for s in general_slots:
		if s == null or (s.get("item") == "stone" and int(s["count"]) < InventoryData.STACK_MAX):
			has_empty_or_room = true
	if has_empty_or_room:
		print("FAIL: setup did not fill inventory to capacity, test invalid")
		ok = false
	else:
		var stone_index := -1
		var chest_slots: Array = chest.get_slots()
		for i in range(chest_slots.size()):
			if chest_slots[i] != null and chest_slots[i].get("item") == "stone":
				stone_index = i
				break
		var stone_before: int = InventoryData.get_count("stone")
		var result: bool = chest.try_transfer_to_player(stone_index)
		await get_tree().process_frame
		await get_tree().process_frame
		var stone_after: int = InventoryData.get_count("stone")
		var chest_stone_after := 0
		for s in chest.get_slots():
			if s != null and s.get("item") == "stone":
				chest_stone_after = int(s["count"])
		print("full-inventory transfer attempt: result=", result, " stone player ", stone_before,
				" -> ", stone_after, " (expect unchanged), chest stone -> ", chest_stone_after, " (expect 5)")
		if result or stone_after != stone_before or chest_stone_after != 5:
			print("FAIL: transfer should have failed and left chest/inventory untouched when inventory is full")
			ok = false
		# UI에도 실패 메시지가 표시되는지(버튼을 눌렀을 때와 같은 코드 경로).
		world._on_storage_slot_pressed(stone_index)
		await get_tree().process_frame
		if not world._storage_message_label.visible:
			print("FAIL: failure message label not shown after failed transfer")
			ok = false
		var img_fail := get_tree().root.get_texture().get_image()
		img_fail.save_png(OUT_DIR + "/04_transfer_fail_message.png")

	# 6) ESC로 상자 창이 닫히는지.
	var esc := InputEventKey.new()
	esc.pressed = true
	esc.keycode = KEY_ESCAPE
	world._unhandled_input(esc)
	await get_tree().process_frame
	if world.is_storage_open():
		print("FAIL: ESC did not close storage window")
		ok = false
	else:
		print("ESC close OK")

	if ok:
		print("QA_STORAGE_CHEST_CHECK_PASS")
	else:
		print("QA_STORAGE_CHEST_CHECK_FAIL")
	get_tree().quit()
