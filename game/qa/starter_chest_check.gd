extends Node
## [BUILD] INBOX #97 확인용 — 스폰 지점 근처 저장 상자(INBOX #96)가 게임 시작 시점에
## 이미 재료 15종을 999개씩 채운 채로 스폰되는지, 그리고 그 재료를 인벤토리로 옮겨
## 가공대/제련로/조리대/조리용 화로 레시피를 실제로 테스트할 수 있는지 확인한다.
## processing_table_check.gd/storage_chest_check.gd(#87/#96)와 같은 방법: project.godot
## [autoload]에 이 스크립트를 임시로 추가하고 `godot --path .`로 실행한 뒤 되돌린다.
## 이 스크립트는 chest.add_item()을 직접 호출하지 않는다 — world.gd의
## _spawn_storage_chest()가 자동으로 채운 상태를 그대로 검증하는 것이 이번 항목의 핵심이다.

const OUT_DIR := "/tmp/qa97"

const EXPECTED_ITEMS := [
	"rice_seed", "iron_ore", "stone", "sulfur_ore", "wood",
	"rice", "meat",
	"plank", "stone_block", "iron", "charcoal", "gunpowder",
	"ammo",
	"cooked_rice", "cooked_meat",
]
const EXPECTED_AMOUNT := 999


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

	# 1) 저장 상자가 스폰 시점에 이미 15종 x 999개로 채워져 있는지 (수동 add_item 없음).
	var chest := _find_by_script(world, "res://scenes/storage_chest/storage_chest.gd")
	if chest == null:
		print("FAIL: StorageChest not spawned in world")
		print("QA_STARTER_CHEST_CHECK_FAIL")
		get_tree().quit()
		return

	var slots: Array = chest.get_slots()
	var by_item := {}
	for s in slots:
		if s != null:
			by_item[s["item"]] = int(s["count"])
	for item_name in EXPECTED_ITEMS:
		if not by_item.has(item_name) or by_item[item_name] != EXPECTED_AMOUNT:
			print("FAIL: chest missing/wrong count for ", item_name, " got ", by_item.get(item_name, "MISSING"))
			ok = false
	if by_item.size() != EXPECTED_ITEMS.size():
		print("FAIL: chest has unexpected extra/missing item count, slots filled=", by_item.size(), " expected=", EXPECTED_ITEMS.size())
		ok = false
	print("chest starter contents check: ", by_item)

	# 2) 상자 UI를 열어 스크린샷으로 직접 확인.
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
	var img_open := get_tree().root.get_texture().get_image()
	img_open.save_png(OUT_DIR + "/01_chest_open_prefilled.png")
	var esc := InputEventKey.new()
	esc.pressed = true
	esc.keycode = KEY_ESCAPE
	world._unhandled_input(esc)
	await get_tree().process_frame

	# 3) 가공대/제련로/조리용 화로 레시피를 각각 하나씩 실제로 테스트한다 — 상자에서
	# 재료를 인벤토리로 옮긴 뒤(try_transfer_to_player) 그 재료로 실제 제작이 되는지 확인.
	var wood_index := -1
	var iron_ore_index := -1
	var rice_index := -1
	var meat_index := -1
	for i in range(slots.size()):
		var s = slots[i]
		if s == null:
			continue
		match s["item"]:
			"wood": wood_index = i
			"iron_ore": iron_ore_index = i
			"rice": rice_index = i
			"meat": meat_index = i

	for idx in [wood_index, iron_ore_index, rice_index, meat_index]:
		if idx < 0:
			print("FAIL: could not find expected chest slot index for a test material")
			ok = false

	if ok:
		chest.try_transfer_to_player(wood_index)
		chest.try_transfer_to_player(iron_ore_index)
		chest.try_transfer_to_player(rice_index)
		chest.try_transfer_to_player(meat_index)
		await get_tree().process_frame
		await get_tree().process_frame

		# 가공대: 목재 2 -> 판자 1
		var plank_before: int = InventoryData.get_count("plank")
		world._on_craft_pressed({"inputs": {"wood": 2}, "output": "plank", "amount": 1})
		await get_tree().process_frame
		var plank_after: int = InventoryData.get_count("plank")
		if plank_after != plank_before + 1:
			print("FAIL: processing_table wood->plank craft did not work, ", plank_before, " -> ", plank_after)
			ok = false
		else:
			print("processing_table wood->plank OK")

		# 제련로: 철광석 2 -> 철 1
		var iron_before: int = InventoryData.get_count("iron")
		world._on_craft_pressed({"inputs": {"iron_ore": 2}, "output": "iron", "amount": 1})
		await get_tree().process_frame
		var iron_after: int = InventoryData.get_count("iron")
		if iron_after != iron_before + 1:
			print("FAIL: smelting_furnace iron_ore->iron craft did not work, ", iron_before, " -> ", iron_after)
			ok = false
		else:
			print("smelting_furnace iron_ore->iron OK")

		# 조리용 화로: 벼 1 -> 밥 1, 고기 1 -> 익힌고기 1
		var cooked_rice_before: int = InventoryData.get_count("cooked_rice")
		world._on_craft_pressed({"inputs": {"rice": 1}, "output": "cooked_rice", "amount": 1})
		await get_tree().process_frame
		var cooked_rice_after: int = InventoryData.get_count("cooked_rice")
		if cooked_rice_after != cooked_rice_before + 1:
			print("FAIL: cooking_stove rice->cooked_rice craft did not work, ", cooked_rice_before, " -> ", cooked_rice_after)
			ok = false
		else:
			print("cooking_stove rice->cooked_rice OK")

		var cooked_meat_before: int = InventoryData.get_count("cooked_meat")
		world._on_craft_pressed({"inputs": {"meat": 1}, "output": "cooked_meat", "amount": 1})
		await get_tree().process_frame
		var cooked_meat_after: int = InventoryData.get_count("cooked_meat")
		if cooked_meat_after != cooked_meat_before + 1:
			print("FAIL: cooking_stove meat->cooked_meat craft did not work, ", cooked_meat_before, " -> ", cooked_meat_after)
			ok = false
		else:
			print("cooking_stove meat->cooked_meat OK")

	if ok:
		print("QA_STARTER_CHEST_CHECK_PASS")
	else:
		print("QA_STARTER_CHEST_CHECK_FAIL")
	get_tree().quit()
