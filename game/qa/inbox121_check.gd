extends Node
## INBOX #121 확인용 — #119/#120 격자 배치 프레임워크에 아이템 키만 추가해서 연결한
## stone_wall/steel_wall/steel_door/window 4종(+ 기존 wood_wall/wood_door 재확인 포함 총
## 6종, INBOX 원문의 "5종(나무벽/나무문 포함 총 7종)"에서 wood_wall/wood_door는 #119/#120
## 에서 이미 전면 검증됐으므로 여기서는 회귀만 가볍게 재확인한다)이 실제로 설치되고,
## 벽류는 플레이어를 막고, 문류(steel_door)는 wood_door처럼 여닫을 수 있는지 확인한다.
## inbox119_check.gd/inbox120_check.gd와 같은 방법: project.godot [autoload]에 이
## 스크립트를 임시로 추가하고 `godot --path .`로 실행한 뒤 되돌린다.

const OUT_DIR := "/tmp/qa121"

## 각 아이템을 서로 다른 행(row)에 설치해서 격자 점유가 겹치지 않게 한다.
const WALL_ITEMS := ["wood_wall", "stone_wall", "steel_wall", "window"]
const DOOR_ITEMS := ["wood_door", "steel_door"]


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
	print("QA_INBOX121_CHECK_FAIL: ", msg)
	get_tree().quit()


## 마우스 고정 오프셋 트릭(#119/#120과 동일) — 카메라를 목표 칸 중심 - 오프셋으로 옮기면
## 마우스가 그 칸을 가리키게 된다.
func _point_mouse_at(world, offset: Vector2, target_cell: Vector2i) -> bool:
	var target_world: Vector2 = world._grid_to_world_center(target_cell)
	world.camera.global_position = target_world - offset
	await get_tree().process_frame
	var resolved_cell: Vector2i = world._world_to_grid(world.get_global_mouse_position())
	return resolved_cell == target_cell


func _run_checks() -> void:
	var world := get_tree().current_scene
	world.set_physics_process(false)

	InventoryData._general_slots.fill(null)
	InventoryData._save()
	world.player_sprite.global_position = Vector2(200000, 200000)  # 기본 스폰 필드/다른 QA와 격리
	world.camera.global_position = world.player_sprite.global_position
	await get_tree().process_frame

	var mouse_before: Vector2 = world.get_global_mouse_position()
	var offset: Vector2 = mouse_before - world.camera.global_position

	var player_cell: Vector2i = world._world_to_grid(world.player_sprite.global_position)

	# --- 벽류 4종: 설치 + 인벤토리 소모 + 플레이어 차단 확인 ---
	for row in range(WALL_ITEMS.size()):
		var item: String = WALL_ITEMS[row]
		InventoryData._general_slots.fill(null)  # 매 아이템마다 슬롯 0에 확실히 들어가게
		InventoryData.add_item(item, 3)
		world._select_hotbar(0)
		await get_tree().process_frame
		if world.get_held_item() != item:
			_fail("핫바에 %s가 선택되지 않음: %s" % [item, world.get_held_item()])
			return

		var target_cell: Vector2i = player_cell + Vector2i(1, row * 3)
		if not await _point_mouse_at(world, offset, target_cell):
			_fail("%s: 마우스 오프셋 보정 실패" % item)
			return

		var count_before := InventoryData.get_count(item)
		world._try_place_structure()
		await get_tree().process_frame
		var count_after := InventoryData.get_count(item)
		if count_after != count_before - 1:
			_fail("%s: 설치 후 인벤토리 소모가 정확히 1개가 아님 (before=%d after=%d)" % [item, count_before, count_after])
			return
		if not world._grid_occupancy.has(target_cell):
			_fail("%s: 설치 후 _grid_occupancy에 등록되지 않음" % item)
			return
		var node: Node = world._grid_occupancy[target_cell]
		if node is Door:
			_fail("%s: 벽류인데 Door 노드로 생성됨" % item)
			return
		if not (node is StaticBody2D):
			_fail("%s: StaticBody2D가 아님: %s" % [item, node])
			return

		# 플레이어를 벽 칸으로 밀어 실제로 막히는지 확인 (격자보다 훨씬 작은 이동을
		# 여러 번 반복 — 바퀴173 결정 로그: 한 번에 큰 이동을 주면 중간 칸을 건너뛰어
		# 거짓 통과가 날 수 있다).
		var player_row_cell: Vector2i = player_cell + Vector2i(0, row * 3)
		world.player_sprite.global_position = world._grid_to_world_center(player_row_cell)
		for i in range(80):
			world._move_player_with_grid_collision(Vector2(8.0, 0.0))
		var blocked_cell: Vector2i = world._world_to_grid(world.player_sprite.global_position)
		if blocked_cell.x >= target_cell.x:
			_fail("%s: 벽인데 플레이어가 통과해버림 (after_cell=%s target_cell=%s)" % [item, str(blocked_cell), str(target_cell)])
			return

		# 재설치 시도(같은 칸) — 이미 점유돼 있으므로 소모 없어야 함.
		InventoryData.add_item(item, 1)
		world._select_hotbar(0)
		await get_tree().process_frame
		var recount_before := InventoryData.get_count(item)
		world._try_place_structure()
		await get_tree().process_frame
		if InventoryData.get_count(item) != recount_before:
			_fail("%s: 이미 점유된 칸에 재설치 시도했는데 인벤토리가 소모됨" % item)
			return

		print("QA_INBOX121_WALL_OK: ", item)

	# --- 문류 2종(wood_door 회귀 재확인 + steel_door 신규 검증): 설치 + 닫힘 차단 +
	#     좌클릭 토글로 열림 통과 + 재토글로 닫힘 복귀 확인 ---
	for i in range(DOOR_ITEMS.size()):
		var item: String = DOOR_ITEMS[i]
		var row: int = WALL_ITEMS.size() + i
		InventoryData._general_slots.fill(null)  # 매 아이템마다 슬롯 0에 확실히 들어가게
		InventoryData.add_item(item, 3)
		world._select_hotbar(0)
		await get_tree().process_frame
		if world.get_held_item() != item:
			_fail("핫바에 %s가 선택되지 않음: %s" % [item, world.get_held_item()])
			return

		var target_cell: Vector2i = player_cell + Vector2i(1, row * 3)
		if not await _point_mouse_at(world, offset, target_cell):
			_fail("%s: 마우스 오프셋 보정 실패" % item)
			return

		var count_before := InventoryData.get_count(item)
		world._try_place_structure()
		await get_tree().process_frame
		if InventoryData.get_count(item) != count_before - 1:
			_fail("%s: 설치 후 인벤토리 소모가 정확히 1개가 아님" % item)
			return
		var node: Node = world._grid_occupancy.get(target_cell)
		if not (node is Door):
			_fail("%s: 설치된 노드가 Door가 아님: %s" % [item, node])
			return
		var door: Door = node

		if door.is_open:
			_fail("%s: 설치 직후 문이 열림 상태로 시작함" % item)
			return
		if door._col.disabled:
			_fail("%s: 닫힌 문인데 CollisionShape2D가 disabled 상태임" % item)
			return

		var player_row_cell: Vector2i = player_cell + Vector2i(0, row * 3)
		world.player_sprite.global_position = world._grid_to_world_center(player_row_cell)
		for j in range(80):
			world._move_player_with_grid_collision(Vector2(8.0, 0.0))
		var blocked_cell: Vector2i = world._world_to_grid(world.player_sprite.global_position)
		if blocked_cell.x >= target_cell.x:
			_fail("%s: 닫힌 문인데 플레이어가 통과해버림" % item)
			return

		# 빈손으로 근처에서 좌클릭 → 열림 토글(실제 엔진 입력 경로)
		world._select_hotbar(1)  # 슬롯 1은 비어있음 → 빈손, 배치 모드 아님
		if world.is_build_placement_active():
			_fail("%s: 빈손인데 배치 모드가 활성 상태로 남아있음" % item)
			return
		var target_world: Vector2 = world._grid_to_world_center(target_cell)
		world.player_sprite.global_position = target_world + Vector2(30, 0)
		await get_tree().process_frame
		var click_event := InputEventMouseButton.new()
		click_event.button_index = MOUSE_BUTTON_LEFT
		click_event.pressed = true
		Input.parse_input_event(click_event)
		await get_tree().process_frame
		await get_tree().process_frame

		if not door.is_open:
			_fail("%s: 빈손으로 근처에서 좌클릭했는데 문이 열리지 않음" % item)
			return
		if not door._col.disabled:
			_fail("%s: 문이 열렸는데 CollisionShape2D가 여전히 활성 상태임" % item)
			return

		# 열린 문 통과 확인
		world.player_sprite.global_position = world._grid_to_world_center(player_row_cell)
		for j in range(80):
			world._move_player_with_grid_collision(Vector2(8.0, 0.0))
		var passed_cell: Vector2i = world._world_to_grid(world.player_sprite.global_position)
		if passed_cell.x < target_cell.x:
			_fail("%s: 열린 문인데 플레이어가 여전히 통과 못 함" % item)
			return

		if item == "steel_door":
			world.camera.global_position = target_world
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img_open := get_viewport().get_texture().get_image()
			img_open.save_png("%s/01_steel_door_open.png" % OUT_DIR)

		# 다시 좌클릭 → 닫힘 토글
		world.player_sprite.global_position = target_world + Vector2(30, 0)
		await get_tree().process_frame
		var click_event2 := InputEventMouseButton.new()
		click_event2.button_index = MOUSE_BUTTON_LEFT
		click_event2.pressed = true
		Input.parse_input_event(click_event2)
		await get_tree().process_frame
		await get_tree().process_frame

		if door.is_open:
			_fail("%s: 두 번째 좌클릭 후에도 문이 닫히지 않음" % item)
			return

		if item == "steel_door":
			world.camera.global_position = target_world
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img_closed := get_viewport().get_texture().get_image()
			img_closed.save_png("%s/02_steel_door_closed.png" % OUT_DIR)

		print("QA_INBOX121_DOOR_OK: ", item)

	# --- 전체 배치 결과 한 장 스크린샷 (벽 4종 + 문 2종이 격자에 깔끔히 배치됐는지) ---
	world.camera.global_position = world._grid_to_world_center(player_cell + Vector2i(1, 6))
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_overview := get_viewport().get_texture().get_image()
	img_overview.save_png("%s/03_overview.png" % OUT_DIR)

	print("QA_INBOX121_CHECK_PASS")
	get_tree().quit()
