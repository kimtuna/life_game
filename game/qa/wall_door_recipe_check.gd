extends Node
## [BUILD] INBOX #100 확인용 — 가공대에 추가된 나무벽/나무문/석제벽 레시피 3개가 실제로
## 재료를 소모하고, 배치 방식(#99)대로 타이머를 거쳐 출력 버퍼에 쌓였다가 수령되는지
## 확인한다. batch_crafting_check.gd(#99)와 같은 방법: project.godot [autoload]에 이
## 스크립트를 임시로 추가하고 `godot --path .`로 실행한 뒤 되돌린다.

const OUT_DIR := "/tmp/qa100"


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


func _check_recipe(table, output_key: String, ok_ref: Array) -> void:
	var recipe: Dictionary = {}
	for r in table.get_recipes():
		if r.get("output", "") == output_key:
			recipe = r
			break
	if recipe.is_empty():
		print("FAIL: recipe for ", output_key, " not found on processing table")
		ok_ref[0] = false
		return

	# 필요한 재료를 넉넉히 채운다.
	var inputs: Dictionary = recipe.get("inputs", {})
	for item_key in inputs.keys():
		InventoryData.add_item(item_key, int(inputs[item_key]) * 5)
	await get_tree().process_frame

	var before: Dictionary = {}
	for item_key in inputs.keys():
		before[item_key] = InventoryData.get_count(item_key)

	var started: bool = table.start_batch(recipe, 1)
	await get_tree().process_frame
	if not started:
		print("FAIL: start_batch failed for ", output_key)
		ok_ref[0] = false
		return
	for item_key in inputs.keys():
		var expected: int = int(before[item_key]) - int(inputs[item_key])
		if InventoryData.get_count(item_key) != expected:
			print("FAIL: ", item_key, " not consumed correctly for ", output_key)
			ok_ref[0] = false

	# 타이머를 완주시킨다 (1개 * 5초 = 5초, 여유 있게 6초 진행).
	table._process(6.0)
	if table.is_batch_active():
		print("FAIL: batch still active after enough time passed for ", output_key)
		ok_ref[0] = false
	var amount: int = int(recipe.get("amount", 1))
	if int(table.output_buffer.get(output_key, 0)) != amount:
		print("FAIL: expected ", amount, " ", output_key, " in output buffer, got ", table.output_buffer)
		ok_ref[0] = false
		return

	table.collect_output()
	await get_tree().process_frame
	if InventoryData.get_count(output_key) < amount:
		print("FAIL: ", output_key, " not collected into inventory")
		ok_ref[0] = false
	else:
		print(output_key, " recipe OK: crafted+collected ", InventoryData.get_count(output_key))


func _run_checks() -> void:
	var world := get_tree().current_scene
	var ok := [true]

	var table_script := load("res://scenes/processing_table/processing_table.gd")
	var table = null
	for child in world.get_children():
		if child.get_script() == table_script:
			table = child
			break
	if table == null:
		print("FAIL: ProcessingTable not spawned in world")
		print("QA_WALL_DOOR_RECIPE_CHECK_FAIL")
		get_tree().quit()
		return

	world.player_sprite.global_position = table.global_position
	await get_tree().process_frame

	await _check_recipe(table, "wood_wall", ok)
	await _check_recipe(table, "wood_door", ok)
	await _check_recipe(table, "stone_wall", ok)

	# 인벤토리 창을 열어서 새 아이템 3종이 텍스트로 정상 표시되는지 스크린샷으로 확인.
	world._set_inventory_open(true)
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_tree().root.get_texture().get_image()
	img.save_png(OUT_DIR + "/01_inventory_with_new_items.png")

	if ok[0]:
		print("QA_WALL_DOOR_RECIPE_CHECK_PASS")
	else:
		print("QA_WALL_DOOR_RECIPE_CHECK_FAIL")
	get_tree().quit()
