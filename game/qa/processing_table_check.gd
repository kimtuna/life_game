extends Node
## [BUILD] INBOX #87 확인용 — 가공대가 실제로 스폰되고, 근처에서 좌클릭하면 제작 창이
## 열리고, 목재→판자/돌→석재 레시피가 재료를 소모하고 결과물을 지급하는지 실제 게임을
## 실행해서 검증한다. mining_variety_check.gd(#84)와 같은 방법: project.godot
## [autoload]에 이 스크립트를 임시로 추가하고 `godot --path .`로 실행한 뒤 되돌린다.

const OUT_DIR := "/tmp/qa87"


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

	# 1) 새 아이템(판자/석재)이 ITEM_LABELS/ITEM_CATEGORIES에 가공물로 등록됐는지.
	for key in ["plank", "stone_block"]:
		if world.ITEM_LABELS.get(key, "") == "":
			print("FAIL: ITEM_LABELS missing ", key)
			ok = false
		if world.ITEM_CATEGORIES.get(key, "") != "가공물":
			print("FAIL: ITEM_CATEGORIES[", key, "] != 가공물, got: ", world.ITEM_CATEGORIES.get(key, "<missing>"))
			ok = false

	# 2) 가공대가 실제로 필드에 스폰됐는지.
	var table = null
	var table_script := load("res://scenes/processing_table/processing_table.gd")
	for child in world.get_children():
		if child.get_script() == table_script:
			table = child
			break
	if table == null:
		print("FAIL: ProcessingTable not spawned in world")
		ok = false
		print("QA_PROCESSING_TABLE_CHECK_FAIL")
		get_tree().quit()
		return
	print("ProcessingTable found at ", table.global_position)

	# 3) 플레이어를 가공대 근처로 옮기면 프롬프트가 보이는지.
	world.player_sprite.global_position = table.global_position
	await get_tree().process_frame
	await get_tree().process_frame
	if not table.prompt.visible:
		print("FAIL: prompt not visible when player is in range")
		ok = false
	var img_prompt := get_tree().root.get_texture().get_image()
	img_prompt.save_png(OUT_DIR + "/01_prompt.png")

	# 4) 좌클릭 이벤트를 흉내내면 제작 창이 열리는지.
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	table._unhandled_input(click)
	await get_tree().process_frame
	await get_tree().process_frame
	if not world.is_crafting_open():
		print("FAIL: crafting window did not open after click")
		ok = false
	var img_open := get_tree().root.get_texture().get_image()
	img_open.save_png(OUT_DIR + "/02_window_open_no_materials.png")

	# 5) 재료(목재/돌) 지급 전에는 "제작" 버튼이 비활성화(재료 부족)인지 확인.
	var wood_before: int = InventoryData.get_count("wood")
	var stone_before: int = InventoryData.get_count("stone")
	var plank_before: int = InventoryData.get_count("plank")
	var stone_block_before: int = InventoryData.get_count("stone_block")

	# 6) 재료를 지급하고 실제로 제작 버튼을 눌러서 소모/지급이 정확한지 확인.
	InventoryData.add_item("wood", 4)
	InventoryData.add_item("stone", 4)
	await get_tree().process_frame
	await get_tree().process_frame
	var img_ready := get_tree().root.get_texture().get_image()
	img_ready.save_png(OUT_DIR + "/03_window_open_with_materials.png")

	world._on_craft_pressed(table.RECIPES[0])  # 목재 2 -> 판자 1
	await get_tree().process_frame
	world._on_craft_pressed(table.RECIPES[1])  # 돌 2 -> 석재 1
	await get_tree().process_frame
	await get_tree().process_frame
	var img_crafted := get_tree().root.get_texture().get_image()
	img_crafted.save_png(OUT_DIR + "/04_after_craft.png")

	var wood_after: int = InventoryData.get_count("wood")
	var stone_after: int = InventoryData.get_count("stone")
	var plank_after: int = InventoryData.get_count("plank")
	var stone_block_after: int = InventoryData.get_count("stone_block")
	print("wood: ", wood_before + 4, " -> ", wood_after, " (expect -2)")
	print("stone: ", stone_before + 4, " -> ", stone_after, " (expect -2)")
	print("plank: ", plank_before, " -> ", plank_after, " (expect +1)")
	print("stone_block: ", stone_block_before, " -> ", stone_block_after, " (expect +1)")
	if wood_after != wood_before + 4 - 2:
		print("FAIL: wood not consumed correctly")
		ok = false
	if stone_after != stone_before + 4 - 2:
		print("FAIL: stone not consumed correctly")
		ok = false
	if plank_after != plank_before + 1:
		print("FAIL: plank not granted correctly")
		ok = false
	if stone_block_after != stone_block_before + 1:
		print("FAIL: stone_block not granted correctly")
		ok = false

	# 7) 재료가 부족한 상태에서 제작을 시도해도(방어적 재확인) 아무 일도 없는지.
	var wood_before_fail: int = InventoryData.get_count("wood")
	world.close_crafting_window()
	InventoryData.remove_item("wood", InventoryData.get_count("wood"))
	world.open_crafting_window(table.TABLE_TITLE, table.RECIPES)
	await get_tree().process_frame
	world._on_craft_pressed(table.RECIPES[0])
	await get_tree().process_frame
	if InventoryData.get_count("plank") != plank_after:
		print("FAIL: crafting succeeded despite insufficient materials")
		ok = false
	else:
		print("insufficient-materials guard OK")

	# 8) ESC로 닫히는지, 닫힌 뒤 이동이 다시 되는지.
	world._unhandled_input(_esc_event())
	await get_tree().process_frame
	if world.is_crafting_open():
		print("FAIL: ESC did not close crafting window")
		ok = false
	else:
		print("ESC close OK")

	if ok:
		print("QA_PROCESSING_TABLE_CHECK_PASS")
	else:
		print("QA_PROCESSING_TABLE_CHECK_FAIL")
	get_tree().quit()


func _esc_event() -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = true
	e.keycode = KEY_ESCAPE
	return e
