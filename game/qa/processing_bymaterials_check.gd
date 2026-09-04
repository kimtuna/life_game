extends Node
## [BUILD] INBOX #106 확인용 — 가공대에 추가된 부재료 5종 레시피(철 1개 -> 못 4개,
## 철 2개 -> 경첩 1개, 강철 2개 -> 톱니바퀴 1개, 구리 1개 -> 구리선 2개,
## 유리 1개 -> 유리병 1개)가 실제로 동작하는지 검증한다.
## steel_glass_copper_check.gd(#105)와 같은 방법: project.godot [autoload]에 이 스크립트를
## 임시로 추가하고 `godot --path .`로 실행한 뒤 되돌린다.

const OUT_DIR := "/tmp/qa106"


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

	# 1) ITEM_LABELS/ITEM_CATEGORIES에 5종이 "가공물"로 등록됐는지.
	for key in ["nail", "hinge", "gear", "copper_wire", "glass_bottle"]:
		if world.ITEM_LABELS.get(key, "") == "":
			print("FAIL: ITEM_LABELS missing ", key)
			ok = false
		if world.ITEM_CATEGORIES.get(key, "") != "가공물":
			print("FAIL: ITEM_CATEGORIES[", key, "] != 가공물, got: ", world.ITEM_CATEGORIES.get(key, "<missing>"))
			ok = false

	var table_script := load("res://scenes/processing_table/processing_table.gd")
	var table = null
	for child in world.get_children():
		if child.get_script() == table_script:
			table = child
			break
	if table == null:
		print("FAIL: ProcessingTable not spawned in world")
		print("QA_PROCESSING_BYMATERIALS_CHECK_FAIL")
		get_tree().quit()
		return

	var recipes := {}
	for recipe in table.get_recipes():
		recipes[recipe.get("output", "")] = recipe
	for key in ["nail", "hinge", "gear", "copper_wire", "glass_bottle"]:
		if not recipes.has(key):
			print("FAIL: recipe for ", key, " not found on processing table")
			ok = false
	if not ok:
		print("QA_PROCESSING_BYMATERIALS_CHECK_FAIL")
		get_tree().quit()
		return

	world.player_sprite.global_position = table.global_position
	InventoryData.add_item("iron", 3)
	InventoryData.add_item("steel", 2)
	InventoryData.add_item("copper", 1)
	InventoryData.add_item("glass", 1)
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

	# 2) 다섯 레시피를 순서대로(한 번에 한 배치만 가능하므로 하나씩) 실제로 제작한다.
	var expectations := [
		{"recipe_key": "nail", "input": "iron", "input_qty": 1, "output": "nail", "output_qty": 4},
		{"recipe_key": "hinge", "input": "iron", "input_qty": 2, "output": "hinge", "output_qty": 1},
		{"recipe_key": "gear", "input": "steel", "input_qty": 2, "output": "gear", "output_qty": 1},
		{"recipe_key": "copper_wire", "input": "copper", "input_qty": 1, "output": "copper_wire", "output_qty": 2},
		{"recipe_key": "glass_bottle", "input": "glass", "input_qty": 1, "output": "glass_bottle", "output_qty": 1},
	]
	for exp in expectations:
		var recipe: Dictionary = recipes[exp["recipe_key"]]
		var input_key: String = exp["input"]
		var input_qty: int = exp["input_qty"]
		var output_key: String = exp["output"]
		var output_qty: int = exp["output_qty"]
		var input_before: int = InventoryData.get_count(input_key)
		var started: bool = table.start_batch(recipe, 1)
		await get_tree().process_frame
		print("start_batch(", output_key, ") -> ", started, " (expect true)")
		if not started:
			print("FAIL: start_batch failed for ", output_key)
			ok = false
			continue
		var input_after_start: int = InventoryData.get_count(input_key)
		if input_after_start != input_before - input_qty:
			print("FAIL: ", input_key, " not consumed correctly, ", input_before, " -> ", input_after_start)
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
		print("QA_PROCESSING_BYMATERIALS_CHECK_PASS")
	else:
		print("QA_PROCESSING_BYMATERIALS_CHECK_FAIL")
	get_tree().quit()
