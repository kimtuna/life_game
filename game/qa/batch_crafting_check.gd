extends Node
## [BUILD] INBOX #99 확인용 — 제작 방식을 "즉시 완성"에서 "수량 지정 → 재료 선소모 →
## 타이머(1개당 5초) → 작업대 내부 출력 버퍼에 쌓임 → 수동 수령" 방식으로 개편한 뒤,
## 가공대(processing_table)로 실제로 검증한다. gunpowder_ammo_check.gd(#89)와 같은 방법:
## project.godot [autoload]에 이 스크립트를 임시로 추가하고 `godot --path .`로 실행한 뒤
## 되돌린다.

const OUT_DIR := "/tmp/qa99"


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

	var table_script := load("res://scenes/processing_table/processing_table.gd")
	var table = null
	for child in world.get_children():
		if child.get_script() == table_script:
			table = child
			break
	if table == null:
		print("FAIL: ProcessingTable not spawned in world")
		print("QA_BATCH_CRAFTING_CHECK_FAIL")
		get_tree().quit()
		return

	# 목재→판자 레시피(재료 2개 -> 결과물 1개)를 찾는다.
	var plank_recipe: Dictionary = {}
	for recipe in table.get_recipes():
		if recipe.get("output", "") == "plank":
			plank_recipe = recipe
			break
	if plank_recipe.is_empty():
		print("FAIL: plank recipe not found on processing table")
		print("QA_BATCH_CRAFTING_CHECK_FAIL")
		get_tree().quit()
		return

	# 1) 플레이어를 가공대 근처로 옮기고 좌클릭으로 제작 창을 연다 — UI가 실제로 열리고
	# SpinBox/제작 시작 버튼/진행 상황 섹션이 그려지는지 스크린샷으로 눈으로 확인한다.
	world.player_sprite.global_position = table.global_position
	InventoryData.add_item("wood", 6)
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

	# 2) 수량 3으로 배치를 시작한다 — 그 즉시 재료(목재 6개)가 전량 소모돼야 하고,
	# 작업대에는 배치가 진행 중 상태가 돼야 한다.
	var wood_before: int = InventoryData.get_count("wood")
	var started: bool = table.start_batch(plank_recipe, 3)
	await get_tree().process_frame
	var wood_after_start: int = InventoryData.get_count("wood")
	print("start_batch(qty=3) -> ", started, " (expect true)")
	print("wood: ", wood_before, " -> ", wood_after_start, " (expect -6)")
	if not started:
		print("FAIL: start_batch failed despite having enough materials")
		ok = false
	if wood_after_start != wood_before - 6:
		print("FAIL: materials not consumed at batch start")
		ok = false
	if not table.is_batch_active():
		print("FAIL: is_batch_active() false right after starting a batch")
		ok = false

	# 3) 배치가 진행 중일 때 같은 레시피를 다시 시작하려 하면(한 번에 한 배치만) 실패해야
	# 하고, 이미 소모된 재료 외에 추가로 아무것도 소모되면 안 된다.
	InventoryData.add_item("wood", 10)
	var second_start: bool = table.start_batch(plank_recipe, 1)
	await get_tree().process_frame
	if second_start:
		print("FAIL: start_batch succeeded while a batch was already active")
		ok = false
	else:
		print("second start_batch correctly refused while batch active OK")

	# 4) 플레이어가 창을 닫고 자리를 떠나도(=UI를 전혀 안 열어도) 타이머가 계속 진행되는지
	# 확인하기 위해, 여기서는 창을 닫고 station._process()를 직접 여러 번 진행시킨다
	# (CRAFT_SECONDS_PER_UNIT=5초 x 3개 = 15초 이상 지나면 3개 다 완성돼야 함).
	world.close_crafting_window()
	for i in range(4):
		table._process(4.0)
	if table.is_batch_active():
		print("FAIL: batch still active after enough time passed (", table.output_buffer, ")")
		ok = false
	if int(table.output_buffer.get("plank", 0)) != 3:
		print("FAIL: expected 3 plank in output buffer, got ", table.output_buffer)
		ok = false
	else:
		print("batch completed into output buffer while window closed OK: ", table.output_buffer)

	# 5) 인벤토리를 완전히 채운 상태에서 수령하면, 아이템이 사라지지 않고 버퍼에 그대로
	# 남아야 한다(INBOX #98 안전 패턴 재사용 확인).
	for i in range(InventoryData.GENERAL_SLOT_COUNT):
		InventoryData.add_item("qa99_filler_%d" % i, InventoryData.STACK_MAX)
	await get_tree().process_frame
	table.collect_output()
	await get_tree().process_frame
	if int(table.output_buffer.get("plank", 0)) != 3:
		print("FAIL: output buffer lost items while inventory was full, got ", table.output_buffer)
		ok = false
	if InventoryData.get_count("plank") != 0:
		print("FAIL: plank leaked into full inventory")
		ok = false
	else:
		print("collect correctly refused while inventory full, buffer preserved OK")

	# 6) 공간을 만든 뒤 수령하면 실제로 플레이어 인벤토리로 들어가고 버퍼가 비어야 한다.
	InventoryData.remove_item("qa99_filler_0", InventoryData.STACK_MAX)
	await get_tree().process_frame
	table.collect_output()
	await get_tree().process_frame
	var img_after_collect := get_tree().root.get_texture().get_image()
	img_after_collect.save_png(OUT_DIR + "/02_after_collect.png")
	print("plank after collect: ", InventoryData.get_count("plank"), " (expect 3)")
	print("output_buffer after collect: ", table.output_buffer, " (expect empty)")
	if InventoryData.get_count("plank") != 3:
		print("FAIL: plank not collected into inventory after room freed")
		ok = false
	if not table.output_buffer.is_empty():
		print("FAIL: output buffer not empty after successful collect")
		ok = false

	if ok:
		print("QA_BATCH_CRAFTING_CHECK_PASS")
	else:
		print("QA_BATCH_CRAFTING_CHECK_FAIL")
	get_tree().quit()
