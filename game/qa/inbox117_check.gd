extends Node
## [BUILD] INBOX #117 확인용 — 테스트용 저장 상자(world.gd의 _spawn_storage_chest())가
## DEBUG_STARTER_CHEST_ITEMS(41종, #97+#117로 확장됨) 전부를 999개씩 담고 있는지 확인한다.
## unlimited_chest_check.gd(#116)와 같은 방법: project.godot [autoload]에 이 스크립트를
## 임시로 추가하고 `godot --path .`로 실행한 뒤 되돌린다.

const OUT_DIR := "/tmp/qa117"


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


func _find_by_script(world: Node, script_path: String) -> Node:
	var target_script := load(script_path)
	for child in world.get_children():
		if child.get_script() == target_script:
			return child
	return null


func _run_checks() -> void:
	var world := get_tree().current_scene
	var ok := true

	var chest := _find_by_script(world, "res://scenes/storage_chest/storage_chest.gd")
	if chest == null:
		print("FAIL: StorageChest not spawned in world")
		print("QA_INBOX117_CHECK_FAIL")
		get_tree().quit()
		return

	var slots: Array = chest.get_slots()
	var by_item := {}
	for s in slots:
		if s != null:
			by_item[s["item"]] = int(s["count"])

	var expected: Array = world.DEBUG_STARTER_CHEST_ITEMS
	var expected_amount: int = world.DEBUG_STARTER_CHEST_AMOUNT
	print("expected item count: ", expected.size(), " (should be 41)")
	if expected.size() != 41:
		print("FAIL: DEBUG_STARTER_CHEST_ITEMS size changed unexpectedly, got ", expected.size())
		ok = false

	var missing := []
	var wrong_amount := []
	for item_name in expected:
		if not by_item.has(item_name):
			missing.append(item_name)
		elif by_item[item_name] != expected_amount:
			wrong_amount.append("%s=%d" % [item_name, by_item[item_name]])

	if missing.size() > 0:
		print("FAIL: chest missing items: ", missing)
		ok = false
	else:
		print("all ", expected.size(), " expected items present in chest OK")

	if wrong_amount.size() > 0:
		print("FAIL: chest items with wrong amount: ", wrong_amount)
		ok = false
	else:
		print("all items have amount ", expected_amount, " OK")

	# 새로 추가된 26개 항목(#117 원문 나열, sand/copper_ore는 #97 이후 다른 바퀴가 이미
	# 채워둔 상태였음) 개별 확인.
	var inbox117_named := ["wood_wall", "wood_door", "stone_wall", "sand", "copper_ore",
		"steel", "glass", "copper", "nail", "hinge", "gear", "copper_wire", "glass_bottle",
		"steel_pickaxe", "steel_axe", "steel_fishing_rod", "steel_wall", "steel_door",
		"steel_chest", "window", "steel_armor", "battery", "lamp", "generator", "feed",
		"water_pump"]
	print("inbox117 named item count: ", inbox117_named.size(), " (should be 26)")
	var inbox117_missing := []
	for item_name in inbox117_named:
		if not by_item.has(item_name) or by_item[item_name] != expected_amount:
			inbox117_missing.append(item_name)
	if inbox117_missing.size() > 0:
		print("FAIL: INBOX #117 named items missing/wrong: ", inbox117_missing)
		ok = false
	else:
		print("all 26 INBOX #117 named items present with correct amount OK")

	# 화면으로 실제 상자 UI를 열어 스크린샷 확인.
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
		print("FAIL: storage window did not open")
		ok = false
	else:
		var img := get_tree().root.get_texture().get_image()
		img.save_png(OUT_DIR + "/01_chest_open.png")
		var scroll: ScrollContainer = world.get_node_or_null("UI/StorageWindow/Panel/VBox/Scroll")
		if scroll != null:
			scroll.scroll_vertical = 100000
			await get_tree().process_frame
			await get_tree().process_frame
			var img2 := get_tree().root.get_texture().get_image()
			img2.save_png(OUT_DIR + "/02_chest_scrolled_bottom.png")

	if ok:
		print("QA_INBOX117_CHECK_PASS")
	else:
		print("QA_INBOX117_CHECK_FAIL")
	get_tree().quit()
