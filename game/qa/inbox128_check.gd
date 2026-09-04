extends Node
## INBOX #128 확인용 — 건설 해제 모드(X 토글 + 빨간 하이라이트 + 좌클릭 철거)가 실제로
## 동작하는지 검증한다. inbox121_check.gd와 같은 마우스 고정 오프셋 트릭을 재사용해서
## 원하는 격자 칸을 정확히 가리키게 만든 뒤, X 키/좌클릭 이벤트를 실제 엔진 입력 경로
## (Input.parse_input_event)로 흘려보내 검증한다.

const OUT_DIR := "/tmp/qa128"


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
	print("QA_INBOX128_CHECK_FAIL: ", msg)
	get_tree().quit()


## 마우스 고정 오프셋 트릭(#119~#121과 동일) — 카메라를 목표 칸 중심 - 오프셋으로 옮기면
## 마우스가 그 칸을 가리키게 된다.
func _point_mouse_at(world, offset: Vector2, target_cell: Vector2i) -> bool:
	var target_world: Vector2 = world._grid_to_world_center(target_cell)
	world.camera.global_position = target_world - offset
	## 카메라 위치 변경이 뷰포트 변환에 실제로 반영되기까지 한 프레임으로는 간헐적으로
	## 부족할 때가 있었다(같은 코드가 실행마다 다른 결과를 낸 것을 실측함) — 최대 5프레임까지
	## 기다리며 재확인해서 타이밍에 흔들리지 않게 한다.
	for i in range(5):
		await get_tree().process_frame
		var resolved_cell: Vector2i = world._world_to_grid(world.get_global_mouse_position())
		if resolved_cell == target_cell:
			return true
	return false


func _press_key(keycode: int) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventKey.new()
	up.keycode = keycode
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _click_left() -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	await get_tree().process_frame


func _run_checks() -> void:
	var world := get_tree().current_scene
	world.set_physics_process(false)

	InventoryData._general_slots.fill(null)
	InventoryData._save()
	world.player_sprite.global_position = Vector2(400000, 400000)  # 다른 QA 자리와 격리
	world.camera.global_position = world.player_sprite.global_position
	await get_tree().process_frame

	## 마우스를 뷰포트 정중앙으로 워프해서 offset을 0에 가깝게 만든다 — 이렇게 해야
	## `_point_mouse_at`이 카메라를 목표 칸에 그대로 놓아도(offset=0) 마우스가 그 칸을
	## 가리키는 동시에 그 칸이 화면 정중앙에 렌더링되어, 스크린샷으로 실제 하이라이트
	## 색을 눈으로 확인할 수 있다(원래 오프셋이 크면 목표 칸이 화면 밖으로 밀려나
	## 스크린샷에 아무것도 안 보이는 문제가 있었다).
	Input.warp_mouse(get_viewport().get_visible_rect().size / 2.0)
	await get_tree().process_frame
	var mouse_before: Vector2 = world.get_global_mouse_position()
	var offset: Vector2 = mouse_before - world.camera.global_position
	var player_cell: Vector2i = world._world_to_grid(world.player_sprite.global_position)

	# --- 준비: 벽 하나 + 문 하나를 각각 다른 자리에 직접 설치 ---
	var wall_cell: Vector2i = player_cell + Vector2i(2, 0)
	world._grid_occupancy[wall_cell] = world._spawn_structure("wood_wall", wall_cell)
	var door_cell: Vector2i = player_cell + Vector2i(2, 4)
	world._grid_occupancy[door_cell] = world._spawn_structure("wood_door", door_cell)
	world._recompute_rooms()
	await get_tree().process_frame

	# --- 1) X로 모드 켜기 ---
	if world.is_deconstruct_mode_active():
		_fail("시작부터 건설 해제 모드가 켜져 있음")
		return
	await _press_key(KEY_X)
	if not world.is_deconstruct_mode_active():
		_fail("X를 눌렀는데 건설 해제 모드가 켜지지 않음")
		return
	if not world.deconstruct_mode_panel.visible:
		_fail("건설 해제 모드 HUD 패널이 표시되지 않음")
		return
	print("QA_INBOX128_TOGGLE_ON_OK")

	# --- 2) 빈 칸 위에서는 하이라이트가 없어야 함 ---
	var empty_cell: Vector2i = player_cell + Vector2i(5, 5)
	if not await _point_mouse_at(world, offset, empty_cell):
		_fail("빈 칸 마우스 오프셋 보정 실패")
		return
	await get_tree().process_frame
	if world._deconstruct_highlighted_node != null:
		_fail("빈 칸인데 하이라이트 노드가 설정됨")
		return
	print("QA_INBOX128_EMPTY_NO_HIGHLIGHT_OK")

	# --- 3) 벽 칸 위에서는 반투명 빨간색으로 하이라이트되어야 함 ---
	if not await _point_mouse_at(world, offset, wall_cell):
		_fail("벽 칸 마우스 오프셋 보정 실패")
		return
	await get_tree().process_frame
	var wall_node: Node = world._grid_occupancy[wall_cell]
	if world._deconstruct_highlighted_node != wall_node:
		_fail("벽 칸 위인데 하이라이트 노드가 그 벽이 아님")
		return
	var wall_sprite: Sprite2D = world._get_structure_sprite(wall_node)
	if not (wall_sprite.modulate.r > wall_sprite.modulate.g + 0.2 and wall_sprite.modulate.r > wall_sprite.modulate.b + 0.2):
		_fail("벽 칸 하이라이트 색이 빨간색 쪽으로 치우치지 않음: %s" % str(wall_sprite.modulate))
		return
	## 마우스를 화면 정중앙으로 워프해뒀으므로(offset≈0) `_point_mouse_at`이 카메라를
	## 목표 칸에 그대로 두는 동시에 그 칸이 화면 정중앙에 렌더링된다 — 그래서 별도로
	## 카메라를 옮기지 않아도 스크린샷에 실제 하이라이트 색이 눈에 보인다.
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_highlight := get_viewport().get_texture().get_image()
	img_highlight.save_png("%s/00_wall_highlighted.png" % OUT_DIR)
	print("QA_INBOX128_WALL_HIGHLIGHT_OK")

	# --- 4) 벽 칸에서 좌클릭 → 철거 + 인벤토리 환급 확인 ---
	var count_before: int = InventoryData.get_count("wood_wall")
	await _click_left()
	if world._grid_occupancy.has(wall_cell):
		_fail("좌클릭 철거 후에도 _grid_occupancy에 벽이 남아있음")
		return
	if is_instance_valid(wall_node):
		_fail("철거된 벽 노드가 씬 트리에서 제거되지 않음(queue_free 미반영)")
		return
	var count_after: int = InventoryData.get_count("wood_wall")
	if count_after != count_before + 1:
		_fail("철거 후 wood_wall 인벤토리 개수가 정확히 1개 늘지 않음 (before=%d after=%d)" % [count_before, count_after])
		return
	world.camera.global_position = world._grid_to_world_center(wall_cell)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_removed := get_viewport().get_texture().get_image()
	img_removed.save_png("%s/01_wall_removed.png" % OUT_DIR)
	print("QA_INBOX128_WALL_REMOVE_REFUND_OK")

	# --- 5) 문: 건설 해제 모드에서는 좌클릭이 열림/닫힘 토글이 아니라 철거여야 함
	#     (플레이어를 상호작용 반경 안에 둬서 door.gd 자체 핸들러 조건도 만족시킨 채 확인) ---
	var door_node: Door = world._grid_occupancy[door_cell]
	if door_node.is_open:
		_fail("문이 시작부터 열려 있음(테스트 전제 오류)")
		return
	if not await _point_mouse_at(world, offset, door_cell):
		_fail("문 칸 마우스 오프셋 보정 실패")
		return
	world.player_sprite.global_position = world._grid_to_world_center(door_cell) + Vector2(20, 0)
	await get_tree().process_frame
	var door_count_before: int = InventoryData.get_count("wood_door")
	await _click_left()
	## 열림 토글로 반응했다면 door_node는 여전히 유효하고 is_open=true일 것이다 — 반대로
	## 제대로 철거됐다면 노드 자체가 free돼서 is_open을 더 이상 읽을 수 없다(그게 정상).
	if is_instance_valid(door_node):
		_fail("건설 해제 모드에서 좌클릭했는데 문이 철거되지 않고 남아있음(열림 토글로 반응했을 가능성)")
		return
	if world._grid_occupancy.has(door_cell):
		_fail("문 철거 후에도 _grid_occupancy에 남아있음")
		return
	var door_count_after: int = InventoryData.get_count("wood_door")
	if door_count_after != door_count_before + 1:
		_fail("문 철거 후 wood_door 인벤토리 개수가 정확히 1개 늘지 않음")
		return
	print("QA_INBOX128_DOOR_REMOVE_OK")

	# --- 6) X로 모드 끄기 → 하이라이트 해제 + HUD 패널 숨김 ---
	await _press_key(KEY_X)
	if world.is_deconstruct_mode_active():
		_fail("다시 X를 눌렀는데 건설 해제 모드가 꺼지지 않음")
		return
	if world.deconstruct_mode_panel.visible:
		_fail("모드를 껐는데 HUD 패널이 계속 보임")
		return
	await get_tree().process_frame
	if world._deconstruct_highlighted_node != null:
		_fail("모드를 껐는데 하이라이트가 남아있음")
		return
	print("QA_INBOX128_TOGGLE_OFF_OK")

	# --- 7) 모드가 꺼진 상태에서는 평소처럼 문 좌클릭이 열림 토글로 동작해야 함(회귀 없음) ---
	## 4)/5)의 철거 환급으로 일반 슬롯 0/1이 이미 wood_wall/wood_door로 채워져 있으므로,
	## 정말로 빈손 슬롯을 골랐는지 확인하려면 먼저 슬롯을 비워야 한다(#109 결정 로그와
	## 같은 함정 — 환급된 아이템이 남아있으면 "빈손"이라는 테스트 전제가 깨진다).
	InventoryData._general_slots.fill(null)
	InventoryData._save()
	var door_cell2: Vector2i = player_cell + Vector2i(2, 8)
	world._grid_occupancy[door_cell2] = world._spawn_structure("wood_door", door_cell2)
	world._recompute_rooms()
	var door2: Door = world._grid_occupancy[door_cell2]
	world._select_hotbar(1)  # 이제 진짜 비어있음 → 빈손, 배치 모드 아님
	world.player_sprite.global_position = world._grid_to_world_center(door_cell2) + Vector2(20, 0)
	await get_tree().process_frame
	if world.get_held_item() != "":
		_fail("빈손 전제가 깨짐: 핫바 슬롯1에 여전히 %s가 들어있음" % world.get_held_item())
		return
	await _click_left()
	if not door2.is_open:
		_fail("모드가 꺼진 상태에서 좌클릭했는데 문이 열리지 않음(정상 토글 회귀)")
		return
	print("QA_INBOX128_NORMAL_TOGGLE_STILL_WORKS_OK")

	# --- 8) 배치 모드와의 상호 배제: 건설 아이템을 든 채 X를 누르면 배치 모드가 꺼져야 함 ---
	InventoryData.add_item("stone_wall", 1)
	world._select_hotbar(0)
	await get_tree().process_frame
	if world.get_held_item() != "stone_wall":
		_fail("stone_wall이 핫바에 선택되지 않음")
		return
	if not world.is_build_placement_active():
		_fail("건설 아이템을 들었는데 배치 모드가 활성화되지 않음(사전 조건 실패)")
		return
	await _press_key(KEY_X)
	if not world.is_deconstruct_mode_active():
		_fail("건설 아이템을 든 채 X를 눌렀는데 건설 해제 모드가 켜지지 않음")
		return
	if world.is_build_placement_active():
		_fail("건설 해제 모드가 켜졌는데 배치 모드가 여전히 활성 상태로 남아있음(상호 배제 실패)")
		return
	await get_tree().process_frame
	if world._build_ghost.visible:
		_fail("건설 해제 모드가 켜졌는데 배치 고스트가 여전히 보임")
		return
	await _press_key(KEY_X)  # 정리: 모드 끄기
	print("QA_INBOX128_MUTUAL_EXCLUSION_OK")

	# --- 9) 방 감지 재계산: 방을 두른 벽 하나를 철거하면 방이 사라져야 함 ---
	var room_origin_cell: Vector2i = player_cell + Vector2i(20, 20)
	for dx in range(4):
		for dy in range(4):
			if dx > 0 and dx < 3 and dy > 0 and dy < 3:
				continue
			var cell: Vector2i = room_origin_cell + Vector2i(dx, dy)
			world._grid_occupancy[cell] = world._spawn_structure("wood_wall", cell)
	world._recompute_rooms()
	var inner_cell: Vector2i = room_origin_cell + Vector2i(1, 1)
	var room_id_before: int = world.get_room_id_at(world._grid_to_world_center(inner_cell))
	if room_id_before == -1:
		_fail("방 둘레를 다 지었는데 방으로 인식되지 않음(사전 조건 실패)")
		return

	await _press_key(KEY_X)
	## 모서리(코너) 칸을 철거하면 4방향 연결로는 안팎이 이어지지 않는다(코너의 두 이웃이
	## 여전히 벽이라 안쪽과도 바깥과도 대각선으로만 붙어 있음) — 실제로 안팎을 뚫으려면
	## 변의 중간 칸(내부 칸과 바깥 칸에 각각 한 면씩 직접 붙어 있는 칸)을 철거해야 한다.
	var breach_cell: Vector2i = room_origin_cell + Vector2i(1, 0)
	if not await _point_mouse_at(world, offset, breach_cell):
		_fail("방 벽 칸 마우스 오프셋 보정 실패")
		return
	await get_tree().process_frame
	await _click_left()
	if world._grid_occupancy.has(breach_cell):
		_fail("방 벽을 철거했는데 _grid_occupancy에 여전히 남아있음")
		return
	var room_id_after: int = world.get_room_id_at(world._grid_to_world_center(inner_cell))
	if room_id_after != -1:
		_fail("방을 두른 벽 하나를 철거했는데도 여전히 방으로 인식됨(방 재계산 안 됨)")
		return
	print("QA_INBOX128_ROOM_RECOMPUTE_OK")
	await _press_key(KEY_X)  # 정리

	print("QA_INBOX128_CHECK_PASS")
	get_tree().quit()
