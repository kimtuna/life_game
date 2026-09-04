extends Node
## [BUILD] INBOX #98 확인용 — 인벤토리가 꽉 찬 상태에서 (a) 바닥 아이템을 주워도
## 사라지지 않고, (b) 제작을 시도해도 재료가 사라지지 않는지 검증한다.
## starter_chest_check.gd(#97)와 같은 방법: project.godot [autoload]에 이 스크립트를
## 임시로 추가하고 `godot --path .`로 실행한 뒤 되돌린다.
##
## (INBOX #102 QA 전체 스윕 재검증에서 확장) 원래 #98 검증은 (a) 바닥 드롭 줍기와
## (b) 제작 "시작" 거부만 봤다 — 저장 상자 이전(#96 try_transfer_to_player)과 제작
## "수령"(#99 collect_output(), 이미 완성돼 작업대 출력 버퍼에 쌓인 결과물을 나중에
## 꺼내는 별도 코드 경로)은 아직 인벤토리가 꽉 찬 상태로 검증된 적이 없었다 — 아래
## 5)/6)에서 그 두 경로를 추가로 검증한다.

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
## prefix를 받아 여러 번(체크마다) 서로 다른 필러 아이템 이름으로 다시 채울 수 있게 한다
## (INBOX #102 확장 — 이전 필러가 남아있는 채로 새 체크를 시작하면 "몇 칸이 비었는지"가
## 이전 체크의 결과에 우연히 의존하게 된다).
func _fill_inventory_completely(prefix: String = "qa98_filler") -> void:
	for i in range(InventoryData.GENERAL_SLOT_COUNT):
		InventoryData.add_item("%s_%d" % [prefix, i], InventoryData.STACK_MAX)


## 지금 실제로 마지막 슬롯(뒤에서부터 스캔)에 들어있는 아이템을 통째로 비운다("공간을
## 만들어준다"는 의도를 구현하는 범용 방법). `_fill_inventory_completely(prefix)`가 매번
## 새 prefix로 채우려 시도해도, 그 시점에 인벤토리가 "이미" 꽉 차 있으면(직전 체크가 새로
## 준 아이템이 남아있는 등) `add_item()`이 새 prefix 아이템을 실제로는 하나도 못 넣고
## 조용히 실패한다 — 그 상태에서 "qa102_x_0 슬롯을 비운다"처럼 특정 이름을 지목해 지우려
## 하면 애초에 없는 아이템이라 `remove_item()`이 아무 일도 안 하고 false만 반환해, "공간을
## 만들었다"고 착각한 채 뒤 체크가 계속 실패하는 문제를 실제로 겪었다(이 파일 최초 작성
## 시 이 문제로 검증 자체가 잘못됐었다). 이름에 의존하지 않고 슬롯이 실제로 무엇을
## 담고 있든 그 내용물 그대로 지우면 이름 불일치 문제가 구조적으로 생기지 않는다. 뒤에서부터
## 스캔하는 이유는 앞쪽 슬롯(0~3)이 시작 도구(총/도끼/곡괭이낫/낚싯대)라서 잘못 비우면
## 다른 체크(손에 든 도구 등)에 영향을 줄 수 있기 때문이다.
func _free_last_occupied_slot() -> void:
	var slots: Array = InventoryData.get_general_slots()
	for i in range(slots.size() - 1, -1, -1):
		if slots[i] != null:
			InventoryData.remove_item(slots[i]["item"], int(slots[i]["count"]))
			return


func _find_first_child_of_type(root: Node, script_path: String) -> Node:
	for child in root.get_children():
		var s = child.get_script()
		if s != null and s.resource_path == script_path:
			return child
	return null


func _run_checks() -> void:
	var world := get_tree().current_scene
	var ok := true

	var table := _find_first_child_of_type(world, "res://scenes/processing_table/processing_table.gd")
	var chest := _find_first_child_of_type(world, "res://scenes/storage_chest/storage_chest.gd")
	if table == null or chest == null:
		print("FAIL: setup — processing table or storage chest not found in world")
		print("QA_INVENTORY_SAFETY_CHECK_FAIL")
		get_tree().quit()
		return

	# 2번(배치 시작) 체크에서 쓸 재료를 인벤토리가 꽉 차기 "전에" 먼저 넣어둔다 — 완전히
	# 꽉 찬 뒤에는 새 아이템 스택을 위한 빈 칸이 없어 `add_item("wood", 2)`가 그 자체로
	# 실패해버려서(간단히 재현해서 확인함) 정작 테스트하려던 "배치 시작"까지 가지도 못한다.
	InventoryData.add_item("wood", 2)
	for i in range(1, InventoryData.GENERAL_SLOT_COUNT):
		InventoryData.add_item("qa98_filler_%d" % i, InventoryData.STACK_MAX)
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

	# 2) (INBOX #102 갱신 — #99가 즉시 완성 방식의 `_on_craft_pressed()`를 완전히
	# 지우고 "수량 지정 -> 재료 선소모 -> 타이머 -> 작업대 내부 출력 버퍼" 방식으로
	# 바꿔서, 옛 방식으로 이 체크를 하던 코드(`world._on_craft_pressed(...)`)가 이제
	# 존재하지 않는 함수를 불러 크래시하는 상태였다 — 이번에 새 API로 다시 썼다.)
	# 배치 "시작"은 결과물이 플레이어 인벤토리가 아니라 작업대 내부 출력 버퍼에 먼저
	# 쌓이므로, 인벤토리가 꽉 차 있어도 재료만 충분하면 성공해야 한다(공간 확인이
	# 필요한 시점은 "수령" — 아래 5번에서 확인). 재료(wood 2개)는 위 설정 단계에서
	# 인벤토리가 꽉 차기 전에 이미 넣어뒀다.
	var plank_recipe := {"inputs": {"wood": 2}, "output": "plank", "amount": 1}
	if not table.start_batch(plank_recipe, 1):
		print("FAIL: batch failed to start with sufficient materials even though output goes to the station's own buffer, not the player inventory")
		ok = false
	else:
		table._process(CraftingStation.CRAFT_SECONDS_PER_UNIT + 1.0)
		if int(table.output_buffer.get("plank", 0)) != 1:
			print("FAIL: batch did not produce output into the station buffer, buffer=", table.output_buffer)
			ok = false
		else:
			print("batch started and produced into station buffer OK despite full player inventory (output_buffer=", table.output_buffer, ")")

	# 3) 인벤토리에 공간을 만들어준 뒤(필러 3개 제거 — 줍기용 1칸을 마련한다) 바닥
	# 드롭 아이템이 마저 주워지는지 확인.
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

	# 4) (INBOX #102) 저장 상자 이전 안전성 — 인벤토리를 다시 완전히 채운 뒤 상자에서
	# 플레이어 인벤토리로 이전을 시도하면 실패해야 하고(공간 없음), 상자 슬롯 수량도
	# 그대로 유지돼야 한다(#96 try_transfer_to_player가 InventoryData.has_room()으로
	# 옮기기 전에 미리 확인하는 안전 패턴).
	_fill_inventory_completely("qa102_chest")
	await get_tree().process_frame
	var chest_slots_before: Array = chest.get_slots()
	var chest_index := -1
	for i in range(chest_slots_before.size()):
		if chest_slots_before[i] != null:
			chest_index = i
			break
	if chest_index == -1:
		print("FAIL: setup — storage chest has no items to test transfer with")
		ok = false
	else:
		var chest_item: String = chest_slots_before[chest_index]["item"]
		var chest_count_before: int = chest_slots_before[chest_index]["count"]
		var transferred: bool = chest.try_transfer_to_player(chest_index)
		var chest_slot_after = chest.get_slots()[chest_index]
		if transferred:
			print("FAIL: chest transfer succeeded despite full player inventory")
			ok = false
		elif chest_slot_after == null or int(chest_slot_after["count"]) != chest_count_before:
			print("FAIL: chest slot changed even though transfer should have been refused, before=", chest_count_before, " after=", chest_slot_after)
			ok = false
		else:
			print("chest transfer correctly refused with no item loss OK (", chest_item, " x", chest_count_before, " untouched)")

		# 공간을 마련해주면 같은 이전이 실제로 성공하는지도 확인한다.
		_free_last_occupied_slot()
		await get_tree().process_frame
		var transferred2: bool = chest.try_transfer_to_player(chest_index)
		if not transferred2:
			print("FAIL: chest transfer failed even though room was freed up")
			ok = false
		elif InventoryData.get_count(chest_item) <= 0:
			print("FAIL: chest transfer reported success but player inventory did not receive ", chest_item)
			ok = false
		else:
			print("chest transfer succeeded once room was freed OK (", chest_item, " x", InventoryData.get_count(chest_item), " in inventory)")

	# 5) (INBOX #102) 제작 "수령" 안전성 — 2번에서 만들어 작업대 출력 버퍼에 그대로
	# 남아있는 plank 1개를, 인벤토리를 다시 완전히 채운 상태에서 수령을 시도하면
	# 사라지지 않고 버퍼에 그대로 남아야 한다(#99 collect_output()이 #98의 add_item()
	# 반환값 안전 패턴을 재사용하는 별도 코드 경로 — 2번의 "시작"과는 다른 지점이다).
	var plank_before: int = InventoryData.get_count("plank")
	_fill_inventory_completely("qa102_collect")
	await get_tree().process_frame
	var buffer_before: int = int(table.output_buffer.get("plank", 0))
	if buffer_before <= 0:
		print("FAIL: setup — station output buffer should still hold plank from check 2, buffer=", table.output_buffer)
		ok = false
	else:
		table.collect_output()
		await get_tree().process_frame
		if InventoryData.get_count("plank") != plank_before:
			print("FAIL: collect leaked output into inventory despite no room, plank ", plank_before, " -> ", InventoryData.get_count("plank"))
			ok = false
		elif int(table.output_buffer.get("plank", 0)) != buffer_before:
			print("FAIL: collect lost output from station buffer despite failing to move it, buffer=", table.output_buffer)
			ok = false
		else:
			print("collect correctly refused with no item loss OK (still buffered: ", table.output_buffer, ")")

		# 공간을 마련해주면 수령이 실제로 성공하는지도 확인한다.
		_free_last_occupied_slot()
		await get_tree().process_frame
		table.collect_output()
		await get_tree().process_frame
		if InventoryData.get_count("plank") != plank_before + buffer_before:
			print("FAIL: collect did not succeed after room was freed, plank=", InventoryData.get_count("plank"))
			ok = false
		elif int(table.output_buffer.get("plank", 0)) != 0:
			print("FAIL: station buffer still holds plank after successful collect, buffer=", table.output_buffer)
			ok = false
		else:
			print("collect succeeded after room freed OK (plank=", InventoryData.get_count("plank"), ")")

	var img := get_tree().root.get_texture().get_image()
	img.save_png(OUT_DIR + "/01_after_checks.png")

	if ok:
		print("QA_INVENTORY_SAFETY_CHECK_PASS")
	else:
		print("QA_INVENTORY_SAFETY_CHECK_FAIL")
	get_tree().quit()
