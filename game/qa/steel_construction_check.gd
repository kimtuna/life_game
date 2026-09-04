extends Node
## [BUILD] INBOX #109 확인용 — 가공대에 추가된 강철 건축 완성품 5종 레시피(강철벽
## 강철3+못1->1, 강철문 강철2+경첩1->1, 강철 상자 강철4+못2->1, 창문 유리2+못1->1,
## 강철 갑옷 강철5->1)가 실제로 동작하는지 검증한다.
## steel_tools_check.gd(#108)/processing_bymaterials_check.gd(#106)와 같은 방법:
## project.godot [autoload]에 이 스크립트를 임시로 추가하고 `godot --path .`로 실행한
## 뒤 되돌린다.

const OUT_DIR := "/tmp/qa109"


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

	var keys := ["steel_wall", "steel_door", "steel_chest", "window", "steel_armor"]
	for key in keys:
		if world.ITEM_LABELS.get(key, "") == "":
			print("FAIL: ITEM_LABELS missing ", key)
			ok = false
		if world.ITEM_CATEGORIES.get(key, "") != "완성품":
			print("FAIL: ITEM_CATEGORIES[", key, "] != 완성품, got: ", world.ITEM_CATEGORIES.get(key, "<missing>"))
			ok = false

	var table_script := load("res://scenes/processing_table/processing_table.gd")
	var table = null
	for child in world.get_children():
		if child.get_script() == table_script:
			table = child
			break
	if table == null:
		print("FAIL: ProcessingTable not spawned in world")
		print("QA_STEEL_CONSTRUCTION_CHECK_FAIL")
		get_tree().quit()
		return

	var recipes := {}
	for recipe in table.get_recipes():
		recipes[recipe.get("output", "")] = recipe
	for key in keys:
		if not recipes.has(key):
			print("FAIL: recipe for ", key, " not found on processing table")
			ok = false
	if not ok:
		print("QA_STEEL_CONSTRUCTION_CHECK_FAIL")
		get_tree().quit()
		return

	world.player_sprite.global_position = table.global_position
	# 이 캐릭터 슬롯(0번)은 이전 바퀴들의 QA 실행으로 저장된 인벤토리가 남아있어(#105~#108)
	# 18칸이 이미 꽉 차 있다 - 이번 검증 전 일반 슬롯을 비워서 깨끗한 상태로 시작한다.
	InventoryData._general_slots.fill(null)
	InventoryData._save()
	InventoryData.add_item("steel", 20)
	InventoryData.add_item("nail", 10)
	InventoryData.add_item("hinge", 5)
	InventoryData.add_item("glass", 5)
	await get_tree().process_frame
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
	img_open.save_png(OUT_DIR + "/01_window_open.png")

	# 다섯 레시피를 순서대로(한 번에 한 배치만 가능하므로 하나씩) 실제로 제작한다.
	var expectations := [
		{"recipe_key": "steel_wall", "inputs": {"steel": 3, "nail": 1}, "output": "steel_wall", "output_qty": 1},
		{"recipe_key": "steel_door", "inputs": {"steel": 2, "hinge": 1}, "output": "steel_door", "output_qty": 1},
		{"recipe_key": "steel_chest", "inputs": {"steel": 4, "nail": 2}, "output": "steel_chest", "output_qty": 1},
		{"recipe_key": "window", "inputs": {"glass": 2, "nail": 1}, "output": "window", "output_qty": 1},
		{"recipe_key": "steel_armor", "inputs": {"steel": 5}, "output": "steel_armor", "output_qty": 1},
	]
	for exp in expectations:
		var recipe: Dictionary = recipes[exp["recipe_key"]]
		var inputs: Dictionary = exp["inputs"]
		var output_key: String = exp["output"]
		var output_qty: int = exp["output_qty"]
		var before := {}
		for input_key in inputs:
			before[input_key] = InventoryData.get_count(input_key)
		var started: bool = table.start_batch(recipe, 1)
		await get_tree().process_frame
		print("start_batch(", output_key, ") -> ", started, " (expect true)")
		if not started:
			print("FAIL: start_batch failed for ", output_key)
			ok = false
			continue
		for input_key in inputs:
			var expected_after: int = before[input_key] - inputs[input_key]
			var actual_after: int = InventoryData.get_count(input_key)
			if actual_after != expected_after:
				print("FAIL: ", input_key, " not consumed correctly, ", before[input_key], " -> ", actual_after, " (expected ", expected_after, ")")
				ok = false
		# CRAFT_SECONDS_PER_UNIT=5초, 여유 있게 진행시켜 배치를 끝낸다.
		for i in range(3):
			table._process(4.0)
		if table.is_batch_active():
			print("FAIL: batch for ", output_key, " still active after enough time passed")
			ok = false
		table.collect_output()
		await get_tree().process_frame
		var output_count: int = InventoryData.get_count(output_key)
		print(output_key, " collected: ", output_count, " (expect ", output_qty, ")")
		if output_count != output_qty:
			print("FAIL: ", output_key, " not collected correctly")
			ok = false

	var img_after := get_tree().root.get_texture().get_image()
	img_after.save_png(OUT_DIR + "/02_after_craft_all.png")

	if ok:
		print("QA_STEEL_CONSTRUCTION_CHECK_PASS")
	else:
		print("QA_STEEL_CONSTRUCTION_CHECK_FAIL")
	get_tree().quit()
