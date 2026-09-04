extends Node
## INBOX #123 확인용 — 방-상자 자동 연동(#122가 만든 방 감지 위에 얹힘)이 실제로
## 동작하는지 확인한다. inbox119~122_check.gd와 같은 방법: project.godot [autoload]에
## 이 스크립트를 임시로 추가하고 `godot --path .`로 실행한 뒤 되돌린다.

const OUT_DIR := "/tmp/qa123"
const ProcessingTableScene := preload("res://scenes/processing_table/processing_table.tscn")
const StorageChestScene := preload("res://scenes/storage_chest/storage_chest.tscn")

## 가공대 RECIPES 중 가장 단순한 것(재료 1종) — DESIGN.md "생산 라인" 규칙대로 재료
## 종류가 1개뿐이라 확인 코드도 단순해진다.
const RECIPE := {"inputs": {"wood": 2}, "output": "plank", "amount": 1}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await _boot_to_world()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await _run_checks()


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


func _fail(msg: String) -> void:
	print("QA_INBOX123_CHECK_FAIL: ", msg)
	get_tree().quit()


## 마우스 고정 오프셋 트릭(#119~#122와 동일).
func _point_mouse_at(world, offset: Vector2, target_cell: Vector2i) -> void:
	var target_world: Vector2 = world._grid_to_world_center(target_cell)
	world.camera.global_position = target_world - offset
	await get_tree().process_frame


func _place_wall(world, offset: Vector2, cell: Vector2i) -> void:
	InventoryData._general_slots.fill(null)
	InventoryData.add_item("wood_wall", 1)
	world._select_hotbar(0)
	await _point_mouse_at(world, offset, cell)
	world._try_place_structure()
	await get_tree().process_frame


func _run_checks() -> void:
	var world := get_tree().current_scene
	world.set_physics_process(false)

	InventoryData._general_slots.fill(null)
	InventoryData._save()
	world.player_sprite.global_position = Vector2(310000, 310000)  # 다른 QA/기본 스폰과 격리
	world.camera.global_position = world.player_sprite.global_position
	await get_tree().process_frame

	var mouse_before: Vector2 = world.get_global_mouse_position()
	var offset: Vector2 = mouse_before - world.camera.global_position

	var center_cell: Vector2i = world._world_to_grid(world.player_sprite.global_position) + Vector2i(3, 3)
	var center_world: Vector2 = world._grid_to_world_center(center_cell)

	# --- 방 하나를 벽 4개로 만들고 가공대를 넣어 "제작소"로 인식시킨다 ---
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		await _place_wall(world, offset, center_cell + dir)

	var table := ProcessingTableScene.instantiate()
	table.global_position = center_world
	table.player_ref = world.player_sprite
	table.world_ref = world
	world.add_child(table)
	world._recompute_rooms()
	await get_tree().process_frame

	var room_id: int = world.get_room_id_at(center_world)
	var category: String = world.get_room_category(room_id)
	if category != "제작소":
		_fail("가공대를 넣었는데 '제작소'가 아니라 '%s'로 판정됨 (사전 조건 실패)" % category)
		return
	print("[setup] 방 안에 가공대 배치 -> 제작소 확인 OK")

	# --- 같은 방 안에 상자를 놓고 재료(wood)만 채운다. 플레이어 인벤토리는 비워둔다 ---
	var chest := StorageChestScene.instantiate()
	chest.global_position = center_world  # 가공대와 같은 칸이어도 방 ID만 같으면 됨(거리 무관 — DESIGN.md)
	chest.player_ref = world.player_sprite
	chest.world_ref = world
	world.add_child(chest)
	chest.add_item("wood", 10)
	await get_tree().process_frame

	if InventoryData.get_count("wood") != 0:
		_fail("사전 조건 실패: 플레이어 인벤토리에 이미 wood가 있음")
		return

	# --- 1) 플레이어 인벤토리가 비어 있어도, 같은 방 상자의 재료로 제작이 시작되는지 ---
	var started: bool = table.start_batch(RECIPE, 1)
	if not started:
		_fail("방 안 상자에 재료가 있는데도 start_batch()가 실패함")
		return
	if chest.get_count("wood") != 8:
		_fail("상자에서 재료가 정확히 소모되지 않음 (기대 8, 실제 %d)" % chest.get_count("wood"))
		return
	if InventoryData.get_count("wood") != 0:
		_fail("플레이어 인벤토리가 비어 있었는데 wood가 생김(잘못된 소모 경로)")
		return
	print("[check1] 방 안 상자 재료로 제작 시작 OK (상자 wood 10 -> 8)")

	# 배치를 강제로 끝까지 진행시켜(실시간 대기 대신 델타를 직접 넘김) 출력 버퍼 확인.
	table._advance_batch(CraftingStation.CRAFT_SECONDS_PER_UNIT)
	if int(table.output_buffer.get("plank", 0)) != 1:
		_fail("배치 완료 후 출력 버퍼에 plank가 없음")
		return
	table.collect_output()
	if InventoryData.get_count("plank") != 1:
		_fail("수령 후 플레이어 인벤토리에 plank가 없음")
		return
	print("[check2] 배치 완료 -> 수령까지 정상 동작 OK")

	# --- 2) 인벤토리+상자 합산으로도 부족하면 여전히 실패하는지(상자가 있다고 무한정 되는 게 아님) ---
	var short_recipe := {"inputs": {"wood": 999}, "output": "plank", "amount": 1}
	if table.start_batch(short_recipe, 1):
		_fail("재료가 실제로 부족한데도(상자+인벤토리 합쳐 8개뿐) start_batch()가 성공함")
		return
	print("[check3] 상자+인벤토리 합산해도 부족하면 실패 확인 OK")

	# --- 3) 회귀: 방 밖(잡실 포함)의 가공대는 근처 상자가 있어도 자동으로 못 쓴다 ---
	var open_cell: Vector2i = center_cell + Vector2i(20, 0)  # 벽으로 안 둘러싼 트인 자리
	var open_world: Vector2 = world._grid_to_world_center(open_cell)

	var table2 := ProcessingTableScene.instantiate()
	table2.global_position = open_world
	table2.player_ref = world.player_sprite
	table2.world_ref = world
	world.add_child(table2)

	var chest2 := StorageChestScene.instantiate()
	chest2.global_position = open_world
	chest2.player_ref = world.player_sprite
	chest2.world_ref = world
	world.add_child(chest2)
	chest2.add_item("wood", 10)
	await get_tree().process_frame

	if world.get_room_id_at(open_world) != -1:
		_fail("회귀 검사 사전 조건 실패: 벽으로 안 둘러싼 자리가 방으로 인식됨")
		return
	if InventoryData.get_count("wood") != 0:
		_fail("회귀 검사 사전 조건 실패: 플레이어 인벤토리에 이미 wood가 있음")
		return

	var started2: bool = table2.start_batch(RECIPE, 1)
	if started2:
		_fail("방이 없는(트인) 자리인데도 근처 상자 재료로 제작이 시작됨(자동 연동이 거리 기반으로 새고 있음)")
		return
	if chest2.get_count("wood") != 10:
		_fail("실패했어야 할 제작인데 상자 wood가 줄어듦(잘못된 소모)")
		return
	print("[check4] 방 없는(트인) 자리 -> 근처 상자 자동 연동 안 됨 확인 OK (회귀 없음)")

	print("QA_INBOX123_CHECK_PASS")
	get_tree().quit()
