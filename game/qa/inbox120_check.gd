extends Node
## INBOX #120 확인용 — 나무문(wood_door)이 #119 프레임워크로 설치되고, 여닫을 수
## 있는지 확인한다. inbox119_check.gd와 같은 방법: project.godot [autoload]에 이
## 스크립트를 임시로 추가하고 `godot --path .`로 실행한 뒤 되돌린다.
##
## 마우스 고정 오프셋 트릭(#119)은 설치 단계에서만 필요하다 — 설치 이후 열림/닫힘
## 토글은 door.gd의 _unhandled_input()이 "플레이어와의 거리 + 배치 모드 여부"만
## 보므로, 실제 엔진 입력 경로(Input.parse_input_event)로 좌클릭을 흘려서 검증한다
## (resource_point_overlap_check.gd(#115)와 같은 패턴).

const OUT_DIR := "/tmp/qa120"


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
	print("QA_INBOX120_CHECK_FAIL: ", msg)
	get_tree().quit()


func _run_checks() -> void:
	var world := get_tree().current_scene
	world.set_physics_process(false)

	# 일반 슬롯을 비우고 시작(바퀴163 결정 로그 — 다른 QA 스크립트 잔여 아이템으로 인한
	# 오검출 방지).
	InventoryData._general_slots.fill(null)
	InventoryData._save()
	InventoryData.add_item("wood_door", 5)
	world.player_sprite.global_position = Vector2(100000, 100000)  # 기본 스폰 필드와 격리
	world.camera.global_position = world.player_sprite.global_position
	world._select_hotbar(0)  # 방금 채운 wood_door가 일반 슬롯 0번(핫바 1번)
	await get_tree().process_frame

	if world.get_held_item() != "wood_door":
		_fail("핫바에 wood_door가 선택되지 않음: %s" % world.get_held_item())
		return

	# --- 마우스 고정 오프셋 측정 (#119와 동일한 트릭) ---
	var mouse_before: Vector2 = world.get_global_mouse_position()
	var offset: Vector2 = mouse_before - world.camera.global_position

	var player_cell: Vector2i = world._world_to_grid(world.player_sprite.global_position)
	var target_cell: Vector2i = player_cell + Vector2i(1, 0)
	var target_world: Vector2 = world._grid_to_world_center(target_cell)
	world.camera.global_position = target_world - offset
	await get_tree().process_frame

	var resolved_cell: Vector2i = world._world_to_grid(world.get_global_mouse_position())
	if resolved_cell != target_cell:
		_fail("마우스 오프셋 보정 실패: resolved=%s target=%s" % [str(resolved_cell), str(target_cell)])
		return

	# --- 1) 좌클릭으로 문 설치 + 인벤토리 소모 확인 ---
	var count_before := InventoryData.get_count("wood_door")
	world._try_place_structure()
	await get_tree().process_frame
	var count_after := InventoryData.get_count("wood_door")
	if count_after != count_before - 1:
		_fail("설치 후 인벤토리 소모가 정확히 1개가 아님: before=%d after=%d" % [count_before, count_after])
		return
	if not world._grid_occupancy.has(target_cell):
		_fail("설치 후 _grid_occupancy에 등록되지 않음")
		return
	var door_node: Node = world._grid_occupancy[target_cell]
	if not (door_node is Door):
		_fail("설치된 노드가 Door가 아님: %s" % door_node)
		return
	var door: Door = door_node

	# --- 2) 기본 상태(설치 직후)는 닫힘 = 충돌 활성 ---
	if door.is_open:
		_fail("설치 직후 문이 열림 상태로 시작함(기본값은 닫힘이어야 함)")
		return
	if door._col.disabled:
		_fail("닫힌 문인데 CollisionShape2D가 disabled 상태임")
		return

	# --- 3) 닫힌 문은 플레이어를 막는다 ---
	# _move_player_with_grid_collision()은 한 번의 큰 이동(예: 500유닛)을 통째로 목적지
	# 기준으로만 막힘 여부를 검사한다(중간 경로는 안 봄) — 실제 물리 루프에서는 매 프레임
	# 격자 크기(64)보다 훨씬 작은 이동만 들어오므로 문제가 없지만, QA에서 한 번에 큰
	# 이동을 흉내내면 문을 그냥 건너뛰어 버리는 오검출이 난다(실제로 이 실수로 겪음).
	# 실제 게임처럼 격자보다 훨씬 작은 이동을 여러 번 반복해서 검증한다.
	world.player_sprite.global_position = world._grid_to_world_center(player_cell)
	for i in range(80):
		world._move_player_with_grid_collision(Vector2(8.0, 0.0))
	var blocked_cell: Vector2i = world._world_to_grid(world.player_sprite.global_position)
	if blocked_cell.x >= target_cell.x:
		_fail("닫힌 문인데 플레이어가 통과해버림: after_cell=%s target_cell=%s" % [str(blocked_cell), str(target_cell)])
		return

	# --- 4) 빈손으로 문 근처에서 좌클릭 → 열림 토글 (실제 엔진 입력 경로) ---
	world._select_hotbar(1)  # 슬롯 1은 비어있음 → 빈손, 배치 모드 아님
	if world.is_build_placement_active():
		_fail("빈손인데 배치 모드가 활성 상태로 남아있음")
		return
	world.player_sprite.global_position = target_world + Vector2(30, 0)  # INTERACT_RADIUS(70) 안
	await get_tree().process_frame

	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	Input.parse_input_event(click_event)
	await get_tree().process_frame
	await get_tree().process_frame

	if not door.is_open:
		_fail("빈손으로 근처에서 좌클릭했는데 문이 열리지 않음")
		return
	if not door._col.disabled:
		_fail("문이 열렸는데 CollisionShape2D가 여전히 활성 상태임")
		return

	# --- 5) 열린 문은 여전히 _grid_occupancy에 남아있어야 한다(#122가 참조할 자료구조) ---
	if not world._grid_occupancy.has(target_cell) or world._grid_occupancy[target_cell] != door:
		_fail("문이 열린 뒤 _grid_occupancy에서 사라짐 — 방 감지가 참조할 수 없게 됨")
		return

	# --- 6) 열린 문은 플레이어가 통과할 수 있어야 한다 (위 3)과 같은 이유로 잘게 나눠 이동) ---
	world.player_sprite.global_position = world._grid_to_world_center(player_cell)
	for i in range(80):
		world._move_player_with_grid_collision(Vector2(8.0, 0.0))
	var passed_cell: Vector2i = world._world_to_grid(world.player_sprite.global_position)
	if passed_cell.x < target_cell.x:
		_fail("열린 문인데 플레이어가 여전히 통과 못 함: after_cell=%s target_cell=%s" % [str(passed_cell), str(target_cell)])
		return

	world.camera.global_position = target_world
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_open := get_viewport().get_texture().get_image()
	img_open.save_png("%s/01_door_open.png" % OUT_DIR)

	# --- 7) 다시 좌클릭 → 닫힘 토글 ---
	world.player_sprite.global_position = target_world + Vector2(30, 0)
	await get_tree().process_frame
	var click_event2 := InputEventMouseButton.new()
	click_event2.button_index = MOUSE_BUTTON_LEFT
	click_event2.pressed = true
	Input.parse_input_event(click_event2)
	await get_tree().process_frame
	await get_tree().process_frame

	if door.is_open:
		_fail("두 번째 좌클릭 후에도 문이 닫히지 않음")
		return
	if door._col.disabled:
		_fail("문이 닫혔는데 CollisionShape2D가 여전히 비활성 상태임")
		return

	world.camera.global_position = target_world
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_closed := get_viewport().get_texture().get_image()
	img_closed.save_png("%s/02_door_closed.png" % OUT_DIR)

	# --- 8) 배치 모드 중에는 근처에서 좌클릭해도 토글되면 안 된다 ---
	# (world._try_place_structure()의 다른 부작용과 분리하기 위해, 여기서는 Door의
	# _unhandled_input()만 직접 호출해서 "배치 모드 여부" 가드 하나만 targeted로 확인한다
	# — 실제 엔진 입력 경로를 통한 전체 통합 검증은 위 4)/7)에서 이미 마쳤다.)
	world._select_hotbar(0)  # 아직 남은 wood_door 4개 → 배치 모드 재진입
	if not world.is_build_placement_active():
		_fail("wood_door를 다시 든 상태인데 배치 모드가 활성화되지 않음")
		return
	var state_before_guard := door.is_open
	world.player_sprite.global_position = target_world + Vector2(30, 0)
	await get_tree().process_frame
	var click_event3 := InputEventMouseButton.new()
	click_event3.button_index = MOUSE_BUTTON_LEFT
	click_event3.pressed = true
	door._unhandled_input(click_event3)
	if door.is_open != state_before_guard:
		_fail("배치 모드 중인데도 근처 좌클릭이 문을 토글시킴(막혔어야 함)")
		return

	print("QA_INBOX120_CHECK_PASS")
	get_tree().quit()
