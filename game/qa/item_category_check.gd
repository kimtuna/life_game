extends Node
## [BUILD] INBOX #83 확인용 — iron -> iron_ore 개명과 ITEM_CATEGORIES 도입을 실제로
## 게임을 실행해서 검증한다. male_variant_check.gd/tool_motion_sweep.gd와 같은 방법:
## 실제 렌더러(`godot --path .`)로 실행하고, project.godot [autoload]에 이 스크립트를
## 임시로 추가한 뒤 실행 후 되돌린다.

const OUT_DIR := "/tmp/qa83"


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

	# 1) ITEM_LABELS/ITEM_CATEGORIES에 iron이 남아있지 않고 iron_ore로 정정됐는지.
	if world.ITEM_LABELS.has("iron"):
		print("FAIL: ITEM_LABELS still has 'iron'")
		ok = false
	if world.ITEM_LABELS.get("iron_ore", "") != "철광석":
		print("FAIL: ITEM_LABELS['iron_ore'] != '철광석', got: ", world.ITEM_LABELS.get("iron_ore", "<missing>"))
		ok = false
	if not world.ITEM_CATEGORIES.has("iron_ore"):
		print("FAIL: ITEM_CATEGORIES missing 'iron_ore'")
		ok = false

	# 2) 모든 기존 아이템이 ITEM_CATEGORIES에 분류돼 있는지.
	for key in world.ITEM_LABELS.keys():
		if not world.ITEM_CATEGORIES.has(key):
			print("FAIL: ITEM_CATEGORIES missing category for ", key)
			ok = false

	# 3) 광산에서 캐면 iron_ore가 인벤토리에 들어가고, 화면 인벤토리 라벨에 "철광석"으로
	#    표시되는지 (world.gd의 spawn_dropped_item -> InventoryData.add_item 경로 재현).
	InventoryData.add_item("iron_ore", 2)
	await get_tree().process_frame
	if InventoryData.get_count("iron_ore") != 2:
		print("FAIL: InventoryData.get_count('iron_ore') != 2, got: ", InventoryData.get_count("iron_ore"))
		ok = false
	if not ("철광석" in world.inventory_label.text):
		print("FAIL: inventory_label.text does not contain '철광석': ", world.inventory_label.text)
		ok = false
	else:
		print("inventory_label.text = ", world.inventory_label.text)

	var img := get_tree().root.get_texture().get_image()
	img.save_png(OUT_DIR + "/inventory_label.png")

	# 4) 실제 광산(mining_point) 채광 -> 바닥 드롭 -> 자동 습득까지 전체 경로가
	#    item_name="iron_ore"로도 그대로 동작하는지 (씬 필드/아이콘 로드 포함).
	var before := InventoryData.get_count("iron_ore")
	var mining_point: Node = null
	for child in world.get_children():
		if child.has_method("_harvest") and child.get("item_name") == "iron_ore":
			mining_point = child
			break
	if mining_point == null:
		print("FAIL: no mining_point (required_tool=pickaxe) found in world")
		print("world children: ", world.get_children())
		ok = false
	else:
		world.player_sprite.global_position = mining_point.global_position
		mining_point._harvest()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var after := InventoryData.get_count("iron_ore")
		if after != before + mining_point.item_amount:
			print("FAIL: mining harvest did not add iron_ore, before=", before, " after=", after)
			ok = false
		else:
			print("mining harvest OK, iron_ore count ", before, " -> ", after)

	if ok:
		print("QA_ITEM_CATEGORY_CHECK_PASS")
	else:
		print("QA_ITEM_CATEGORY_CHECK_FAIL")
	get_tree().quit()
