extends Node
## [BUILD] INBOX #98 확인용 — 인벤토리가 꽉 찬 상태에서 (a) 바닥 아이템을 주워도
## 사라지지 않고, (b) 제작을 시도해도 재료가 사라지지 않는지 검증한다.
## starter_chest_check.gd(#97)와 같은 방법: project.godot [autoload]에 이 스크립트를
## 임시로 추가하고 `godot --path .`로 실행한 뒤 되돌린다.

const OUT_DIR := "/tmp/qa98"


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


## 인벤토리 18칸 전부를 서로 다른 필러 아이템으로 99개씩 채워 완전히 꽉 채운다(빈 슬롯도
## 없고, 기존 재료와 스택을 합칠 수 있는 슬롯도 없게 만들어 "공간 없음"을 확실히 만든다).
func _fill_inventory_completely() -> void:
	for i in range(InventoryData.GENERAL_SLOT_COUNT):
		InventoryData.add_item("qa98_filler_%d" % i, InventoryData.STACK_MAX)


func _run_checks() -> void:
	var world := get_tree().current_scene
	var ok := true

	_fill_inventory_completely()
	await get_tree().process_frame
	var slots_before: Array = InventoryData.get_general_slots()
	for s in slots_before:
		if s == null:
			print("FAIL: setup — inventory should have zero empty slots")
			ok = false

	# 1) 인벤토리가 꽉 찬 상태에서 바닥 드롭 아이템을 플레이어 근처에 스폰 — 사라지면 안 된다.
	world.spawn_dropped_item("stone", 5, world.player_sprite.global_position)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var drop: Node = null
	for child in world.get_children():
		if child.get_script() == load("res://scenes/dropped_item/dropped_item.gd"):
			drop = child
			break
	if drop == null:
		print("FAIL: dropped item vanished while inventory was full (should stay on ground)")
		ok = false
	elif drop.item_amount != 5:
		print("FAIL: dropped item amount changed with no room, expected 5 got ", drop.item_amount)
		ok = false
	else:
		print("dropped item survived full inventory OK (amount=", drop.item_amount, ")")
	if InventoryData.get_count("stone") != 0:
		print("FAIL: stone leaked into inventory despite no room")
		ok = false

	# 2) 인벤토리가 꽉 찬 상태에서 제작 시도(재료로 이미 갖고 있는 필러 아이템을 씀) —
	# 재료가 사라지면 안 되고 결과물도 안 생겨야 한다.
	var plank_before: int = InventoryData.get_count("plank")
	world._on_craft_pressed({"inputs": {"qa98_filler_0": 1}, "output": "plank", "amount": 1})
	await get_tree().process_frame
	var plank_after: int = InventoryData.get_count("plank")
	var filler0_after: int = InventoryData.get_count("qa98_filler_0")
	if plank_after != plank_before:
		print("FAIL: craft produced output despite full inventory, plank ", plank_before, " -> ", plank_after)
		ok = false
	if filler0_after != InventoryData.STACK_MAX:
		print("FAIL: craft consumed input material despite failing (space check should happen before consuming), qa98_filler_0=", filler0_after)
		ok = false
	else:
		print("craft correctly refused (no materials consumed, no output produced) OK")

	# 3) 인벤토리에 공간을 만들어준 뒤(필러 3개 제거 — 줍기용 1칸 + 제작 재료용 1칸 +
	# 제작 결과물용 1칸을 각각 분리해서 마련한다, 안 그러면 "재료가 비워진 칸에 결과물이
	# 들어갈 수 있는가" 같은 우연에 기대게 된다) 같은 드롭 아이템이 마저 주워지는지 확인.
	InventoryData.remove_item("qa98_filler_0", InventoryData.STACK_MAX)
	InventoryData.remove_item("qa98_filler_1", InventoryData.STACK_MAX)
	InventoryData.remove_item("qa98_filler_2", InventoryData.STACK_MAX)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(drop):
		print("FAIL: dropped item should be picked up now that there is room, still on ground with amount=", drop.item_amount)
		ok = false
	elif InventoryData.get_count("stone") != 5:
		print("FAIL: stone count after room freed up, expected 5 got ", InventoryData.get_count("stone"))
		ok = false
	else:
		print("dropped item picked up once room was freed OK")

	# 4) 남은 빈 칸(제작 재료용 1칸 + 제작 결과물용 1칸)으로 제작도 정상적으로 성공하는지 확인.
	InventoryData.add_item("wood", 2)
	world._on_craft_pressed({"inputs": {"wood": 2}, "output": "plank", "amount": 1})
	await get_tree().process_frame
	if InventoryData.get_count("plank") != plank_before + 1:
		print("FAIL: craft did not succeed after room was freed, plank=", InventoryData.get_count("plank"))
		ok = false
	else:
		print("craft succeeded after room freed OK")

	var img := get_tree().root.get_texture().get_image()
	img.save_png(OUT_DIR + "/01_after_checks.png")

	if ok:
		print("QA_INVENTORY_SAFETY_CHECK_PASS")
	else:
		print("QA_INVENTORY_SAFETY_CHECK_FAIL")
	get_tree().quit()
