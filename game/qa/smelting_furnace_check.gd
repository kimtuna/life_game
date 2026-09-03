extends Node
## [BUILD] INBOX #88 확인용 — 제련로가 실제로 스폰되고, 근처에서 좌클릭하면 제작 창이
## 열리고, 철광석→철/목재→숯 레시피가 재료를 소모하고 결과물을 지급하는지, 그리고 가공대
## (#87)와 두 오브젝트가 동시에 존재해도 서로 간섭하지 않는지 실제 게임을 실행해서
## 검증한다. processing_table_check.gd(#87)와 같은 방법: project.godot [autoload]에 이
## 스크립트를 임시로 추가하고 `godot --path .`로 실행한 뒤 되돌린다.

const OUT_DIR := "/tmp/qa88"


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

	# 1) 새 아이템(철/숯)이 ITEM_LABELS/ITEM_CATEGORIES에 가공물로 등록됐는지.
	for key in ["iron", "charcoal"]:
		if world.ITEM_LABELS.get(key, "") == "":
			print("FAIL: ITEM_LABELS missing ", key)
			ok = false
		if world.ITEM_CATEGORIES.get(key, "") != "가공물":
			print("FAIL: ITEM_CATEGORIES[", key, "] != 가공물, got: ", world.ITEM_CATEGORIES.get(key, "<missing>"))
			ok = false

	# 2) 제련로가 실제로 필드에 스폰됐는지, 그리고 가공대(#87)도 여전히 같이 있는지
	# (별개 오브젝트 요구사항, DESIGN.md "화로를 가공대와 겸용으로 쓰지 않는다").
	var furnace = null
	var furnace_script := load("res://scenes/smelting_furnace/smelting_furnace.gd")
	var table = null
	var table_script := load("res://scenes/processing_table/processing_table.gd")
	for child in world.get_children():
		if child.get_script() == furnace_script:
			furnace = child
		elif child.get_script() == table_script:
			table = child
	if furnace == null:
		print("FAIL: SmeltingFurnace not spawned in world")
		ok = false
		print("QA_SMELTING_FURNACE_CHECK_FAIL")
		get_tree().quit()
		return
	if table == null:
		print("FAIL: ProcessingTable missing after furnace was added (should coexist)")
		ok = false
	else:
		print("ProcessingTable and SmeltingFurnace both present, distance=",
				table.global_position.distance_to(furnace.global_position))
	print("SmeltingFurnace found at ", furnace.global_position)

	# 3) 플레이어를 제련로 근처로 옮기면 프롬프트가 보이는지.
	world.player_sprite.global_position = furnace.global_position
	await get_tree().process_frame
	await get_tree().process_frame
	if not furnace.prompt.visible:
		print("FAIL: prompt not visible when player is in range")
		ok = false
	var img_prompt := get_tree().root.get_texture().get_image()
	img_prompt.save_png(OUT_DIR + "/01_prompt.png")

	# 3b) 가공대 근처에서는 제련로 프롬프트가 안 보여야(멀리 있으므로) — 두 오브젝트가
	# 서로 다른 위치의 별개 오브젝트임을 재확인.
	if table != null:
		var dist_to_table: float = table.global_position.distance_to(furnace.global_position)
		if dist_to_table < furnace.INTERACT_RADIUS + table.INTERACT_RADIUS:
			print("FAIL: table and furnace too close, prompts could overlap ambiguously")
			ok = false

	# 4) 좌클릭 이벤트를 흉내내면 제작 창이 열리는지.
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	furnace._unhandled_input(click)
	await get_tree().process_frame
	await get_tree().process_frame
	if not world.is_crafting_open():
		print("FAIL: crafting window did not open after click")
		ok = false
	var img_open := get_tree().root.get_texture().get_image()
	img_open.save_png(OUT_DIR + "/02_window_open_no_materials.png")

	# 5) 재료(철광석/목재) 지급 전 상태 기록.
	var iron_ore_before: int = InventoryData.get_count("iron_ore")
	var wood_before: int = InventoryData.get_count("wood")
	var iron_before: int = InventoryData.get_count("iron")
	var charcoal_before: int = InventoryData.get_count("charcoal")

	# 6) 재료를 지급하고 실제로 제작 버튼을 눌러서 소모/지급이 정확한지 확인.
	InventoryData.add_item("iron_ore", 4)
	InventoryData.add_item("wood", 4)
	await get_tree().process_frame
	await get_tree().process_frame
	var img_ready := get_tree().root.get_texture().get_image()
	img_ready.save_png(OUT_DIR + "/03_window_open_with_materials.png")

	world._on_craft_pressed(furnace.RECIPES[0])  # 철광석 2 -> 철 1
	await get_tree().process_frame
	world._on_craft_pressed(furnace.RECIPES[1])  # 목재 2 -> 숯 1
	await get_tree().process_frame
	await get_tree().process_frame
	var img_crafted := get_tree().root.get_texture().get_image()
	img_crafted.save_png(OUT_DIR + "/04_after_craft.png")

	var iron_ore_after: int = InventoryData.get_count("iron_ore")
	var wood_after: int = InventoryData.get_count("wood")
	var iron_after: int = InventoryData.get_count("iron")
	var charcoal_after: int = InventoryData.get_count("charcoal")
	print("iron_ore: ", iron_ore_before + 4, " -> ", iron_ore_after, " (expect -2)")
	print("wood: ", wood_before + 4, " -> ", wood_after, " (expect -2)")
	print("iron: ", iron_before, " -> ", iron_after, " (expect +1)")
	print("charcoal: ", charcoal_before, " -> ", charcoal_after, " (expect +1)")
	if iron_ore_after != iron_ore_before + 4 - 2:
		print("FAIL: iron_ore not consumed correctly")
		ok = false
	if wood_after != wood_before + 4 - 2:
		print("FAIL: wood not consumed correctly")
		ok = false
	if iron_after != iron_before + 1:
		print("FAIL: iron not granted correctly")
		ok = false
	if charcoal_after != charcoal_before + 1:
		print("FAIL: charcoal not granted correctly")
		ok = false

	# 7) 재료가 부족한 상태에서 제작을 시도해도(방어적 재확인) 아무 일도 없는지.
	world.close_crafting_window()
	InventoryData.remove_item("iron_ore", InventoryData.get_count("iron_ore"))
	world.open_crafting_window(furnace.TABLE_TITLE, furnace.RECIPES)
	await get_tree().process_frame
	world._on_craft_pressed(furnace.RECIPES[0])
	await get_tree().process_frame
	if InventoryData.get_count("iron") != iron_after:
		print("FAIL: crafting succeeded despite insufficient materials")
		ok = false
	else:
		print("insufficient-materials guard OK")

	# 8) ESC로 닫히는지.
	world._unhandled_input(_esc_event())
	await get_tree().process_frame
	if world.is_crafting_open():
		print("FAIL: ESC did not close crafting window")
		ok = false
	else:
		print("ESC close OK")

	if ok:
		print("QA_SMELTING_FURNACE_CHECK_PASS")
	else:
		print("QA_SMELTING_FURNACE_CHECK_FAIL")
	get_tree().quit()


func _esc_event() -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = true
	e.keycode = KEY_ESCAPE
	return e
