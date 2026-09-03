extends Node
## [BUILD] INBOX #90 확인용 — 조리대/조리용 화로가 실제로 스폰되고, 근처에서 좌클릭하면
## 제작 창이 열리고(조리대는 아직 레시피가 없어 빈 목록이어도 정상), 조리용 화로의
## 벼→밥/고기→익힌고기 레시피가 재료를 소모하고 결과물을 지급하는지 실제 게임을 실행해서
## 검증한다. processing_table_check.gd(#87)와 같은 방법: project.godot [autoload]에 이
## 스크립트를 임시로 추가하고 `godot --path .`로 실행한 뒤 되돌린다.

const OUT_DIR := "/tmp/qa90"


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

	# 1) 새 아이템(밥/익힌고기)이 ITEM_LABELS/ITEM_CATEGORIES에 가공식품으로 등록됐는지.
	for key in ["cooked_rice", "cooked_meat"]:
		if world.ITEM_LABELS.get(key, "") == "":
			print("FAIL: ITEM_LABELS missing ", key)
			ok = false
		if world.ITEM_CATEGORIES.get(key, "") != "가공식품":
			print("FAIL: ITEM_CATEGORIES[", key, "] != 가공식품, got: ", world.ITEM_CATEGORIES.get(key, "<missing>"))
			ok = false

	# 2) 조리대/조리용 화로가 실제로 필드에 스폰됐는지.
	var table = null
	var stove = null
	var table_script := load("res://scenes/cooking_table/cooking_table.gd")
	var stove_script := load("res://scenes/cooking_stove/cooking_stove.gd")
	for child in world.get_children():
		if child.get_script() == table_script:
			table = child
		elif child.get_script() == stove_script:
			stove = child
	if table == null:
		print("FAIL: CookingTable not spawned in world")
		ok = false
	if stove == null:
		print("FAIL: CookingStove not spawned in world")
		ok = false
	if table == null or stove == null:
		print("QA_COOKING_CHECK_FAIL")
		get_tree().quit()
		return
	print("CookingTable found at ", table.global_position)
	print("CookingStove found at ", stove.global_position)

	# 3) 조리대 근처에서 좌클릭하면(레시피 없어도) 빈 제작 창이 정상적으로 열리는지.
	world.player_sprite.global_position = table.global_position
	await get_tree().process_frame
	await get_tree().process_frame
	if not table.prompt.visible:
		print("FAIL: cooking table prompt not visible when player is in range")
		ok = false
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	table._unhandled_input(click)
	await get_tree().process_frame
	await get_tree().process_frame
	if not world.is_crafting_open():
		print("FAIL: crafting window did not open after clicking cooking table")
		ok = false
	var img_table := get_tree().root.get_texture().get_image()
	img_table.save_png(OUT_DIR + "/01_cooking_table_empty.png")
	world._unhandled_input(_esc_event())
	await get_tree().process_frame

	# 4) 조리용 화로 근처로 이동해서 좌클릭 -> 제작 창이 벼->밥/고기->익힌고기 레시피로 열리는지.
	world.player_sprite.global_position = stove.global_position
	await get_tree().process_frame
	await get_tree().process_frame
	if not stove.prompt.visible:
		print("FAIL: cooking stove prompt not visible when player is in range")
		ok = false
	stove._unhandled_input(click)
	await get_tree().process_frame
	await get_tree().process_frame
	if not world.is_crafting_open():
		print("FAIL: crafting window did not open after clicking cooking stove")
		ok = false
	var img_stove_empty := get_tree().root.get_texture().get_image()
	img_stove_empty.save_png(OUT_DIR + "/02_cooking_stove_no_materials.png")

	# 5) 재료(벼/고기)를 지급하고 실제로 제작 버튼을 눌러서 소모/지급이 정확한지 확인.
	var rice_before: int = InventoryData.get_count("rice")
	var meat_before: int = InventoryData.get_count("meat")
	var cooked_rice_before: int = InventoryData.get_count("cooked_rice")
	var cooked_meat_before: int = InventoryData.get_count("cooked_meat")

	InventoryData.add_item("rice", 3)
	InventoryData.add_item("meat", 3)
	await get_tree().process_frame
	await get_tree().process_frame
	var img_ready := get_tree().root.get_texture().get_image()
	img_ready.save_png(OUT_DIR + "/03_cooking_stove_with_materials.png")

	world._on_craft_pressed(stove.RECIPES[0])  # 벼 1 -> 밥 1
	await get_tree().process_frame
	world._on_craft_pressed(stove.RECIPES[1])  # 고기 1 -> 익힌고기 1
	await get_tree().process_frame
	await get_tree().process_frame
	var img_crafted := get_tree().root.get_texture().get_image()
	img_crafted.save_png(OUT_DIR + "/04_after_craft.png")

	var rice_after: int = InventoryData.get_count("rice")
	var meat_after: int = InventoryData.get_count("meat")
	var cooked_rice_after: int = InventoryData.get_count("cooked_rice")
	var cooked_meat_after: int = InventoryData.get_count("cooked_meat")
	print("rice: ", rice_before + 3, " -> ", rice_after, " (expect -1)")
	print("meat: ", meat_before + 3, " -> ", meat_after, " (expect -1)")
	print("cooked_rice: ", cooked_rice_before, " -> ", cooked_rice_after, " (expect +1)")
	print("cooked_meat: ", cooked_meat_before, " -> ", cooked_meat_after, " (expect +1)")
	if rice_after != rice_before + 3 - 1:
		print("FAIL: rice not consumed correctly")
		ok = false
	if meat_after != meat_before + 3 - 1:
		print("FAIL: meat not consumed correctly")
		ok = false
	if cooked_rice_after != cooked_rice_before + 1:
		print("FAIL: cooked_rice not granted correctly")
		ok = false
	if cooked_meat_after != cooked_meat_before + 1:
		print("FAIL: cooked_meat not granted correctly")
		ok = false

	# 6) 재료가 부족한 상태에서 제작을 시도해도(방어적 재확인) 아무 일도 없는지.
	world.close_crafting_window()
	InventoryData.remove_item("rice", InventoryData.get_count("rice"))
	world.open_crafting_window(stove.TABLE_TITLE, stove.RECIPES)
	await get_tree().process_frame
	world._on_craft_pressed(stove.RECIPES[0])
	await get_tree().process_frame
	if InventoryData.get_count("cooked_rice") != cooked_rice_after:
		print("FAIL: crafting succeeded despite insufficient materials")
		ok = false
	else:
		print("insufficient-materials guard OK")

	if ok:
		print("QA_COOKING_CHECK_PASS")
	else:
		print("QA_COOKING_CHECK_FAIL")
	get_tree().quit()


func _esc_event() -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = true
	e.keycode = KEY_ESCAPE
	return e
