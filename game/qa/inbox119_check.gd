extends Node
## INBOX #119 확인용 — 건축 격자 배치 시스템(나무벽)이 실제로 동작하는지 확인한다.
## wall_door_icon_check.gd(#101)와 같은 방법: project.godot [autoload]에 이 스크립트를
## 임시로 추가하고 `godot --path .`로 실행한 뒤 되돌린다.
##
## 헤드리스/오프스크린 환경에서는 get_viewport().warp_mouse()로 마우스를 옮겨도
## get_global_mouse_position() 계산에 반영되지 않는다는 게 이미 STATUS.md에 기록돼
## 있다(마우스가 화면상 고정된 지점에 머무는 것으로 보임). 이 스크립트는 먼저 그
## 고정 오프셋(카메라 위치와 get_global_mouse_position()의 차이)을 측정한 뒤,
## 그 오프셋을 거꾸로 이용해서 카메라(물리 처리를 꺼서 마우스 추종을 막음)를
## 원하는 격자 칸 위로 옮기는 방식으로 실제 좌클릭 배치 플로우를 검증한다.

const OUT_DIR := "/tmp/qa119"


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
	print("QA_INBOX119_CHECK_FAIL: ", msg)
	get_tree().quit()


func _run_checks() -> void:
	var world := get_tree().current_scene
	world.set_physics_process(false)

	# 인벤토리를 깨끗이 비우고 시작(다른 QA 스크립트 잔여 아이템으로 인한 오검출 방지 —
	# STATUS.md 바퀴163 결정 로그의 "일반 슬롯 비우고 시작" 패턴).
	InventoryData._general_slots.fill(null)
	InventoryData._save()
	InventoryData.add_item("wood_wall", 5)
	world.player_sprite.global_position = Vector2(100000, 100000)  # 기본 스폰 필드와 확실히 격리
	world.camera.global_position = world.player_sprite.global_position
	world._select_hotbar(0)  # 방금 채운 wood_wall이 일반 슬롯 0번(핫바 1번)에 들어감
	await get_tree().process_frame

	if world.get_held_item() != "wood_wall":
		_fail("핫바에 wood_wall이 선택되지 않음: %s" % world.get_held_item())
		return

	# --- 마우스 고정 오프셋 측정 ---
	var mouse_before: Vector2 = world.get_global_mouse_position()
	var offset: Vector2 = mouse_before - world.camera.global_position
	print("PROBE offset=", offset, " mouse=", mouse_before)

	# 오프셋을 거꾸로 이용해서 "마우스가 가리키는 지점"을 플레이어 바로 오른쪽 칸
	# 중심으로 옮긴다: camera_pos = 목표지점 - offset.
	var player_cell: Vector2i = world._world_to_grid(world.player_sprite.global_position)
	var target_cell: Vector2i = player_cell + Vector2i(1, 0)
	var target_world: Vector2 = world._grid_to_world_center(target_cell)
	world.camera.global_position = target_world - offset
	await get_tree().process_frame

	var mouse_now: Vector2 = world.get_global_mouse_position()
	var resolved_cell: Vector2i = world._world_to_grid(mouse_now)
	if resolved_cell != target_cell:
		_fail("마우스 오프셋 보정 실패: resolved=%s target=%s" % [str(resolved_cell), str(target_cell)])
		return

	# --- 1) 고스트 미리보기가 목표 칸에 뜨는지 확인 ---
	await get_tree().process_frame
	if not world._build_ghost.visible:
		_fail("배치 모드인데 고스트가 안 보임")
		return
	if world._build_ghost.global_position.distance_to(target_world) > 1.0:
		_fail("고스트 위치가 격자 중심에 스냅되지 않음: %s vs %s" % [world._build_ghost.global_position, target_world])
		return

	# 위 마우스 오프셋 트릭은 카메라를 target_world - offset에 둬야만 유효해서, 카메라를
	# 화면 중앙 구도로 옮기면(스크린샷용) 고스트가 그 프레임에는 다른 칸으로 튀어버린다
	# (오프셋이 뷰포트 절반보다 커서 고스트가 항상 화면 밖에 위치함 — 실측 offset=(-782,476),
	# 뷰포트 절반은 640×360). 고스트 위치/스냅이 target_world와 일치한다는 것은 이미 위에서
	# 코드로 검증했으니, 화면 구도는 카메라를 target_world로 옮기고 고스트를 그 자리에 맞춰
	# 직접 배치해 눈으로 보는 용도로만 쓴다(고스트 텍스처/스케일/투명도 자체는 동일).
	## _process()가 매 프레임 고스트를 마우스 위치로 되돌리므로, 수동 배치가 다음 프레임에
	## 덮어써지지 않도록 잠깐 꺼둔다(물리 처리는 이미 꺼져 있음).
	world.set_process(false)
	world.camera.global_position = target_world
	world._build_ghost.global_position = target_world
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_ghost := get_viewport().get_texture().get_image()
	img_ghost.save_png("%s/00_ghost_preview.png" % OUT_DIR)
	world.set_process(true)
	world.camera.global_position = target_world - offset  # 마우스 오프셋 트릭 복귀(배치 입력 검증용)
	## Camera2D의 뷰포트 변환은 카메라가 다음 프레임을 처리해야 반영된다 — 이 프레임을
	## 기다리지 않고 바로 get_global_mouse_position()을 읽으면 옮기기 전(스크린샷용) 카메라
	## 위치가 계속 잡혀서 엉뚱한 칸을 클릭하게 된다(실제로 이 대기를 빠뜨려서 겪음).
	await get_tree().process_frame

	# --- 2) 좌클릭으로 실제 설치 + 인벤토리 소모 확인 ---
	var count_before := InventoryData.get_count("wood_wall")
	world._try_place_structure()
	await get_tree().process_frame
	var count_after := InventoryData.get_count("wood_wall")
	if count_after != count_before - 1:
		_fail("설치 후 인벤토리 소모가 정확히 1개가 아님: before=%d after=%d" % [count_before, count_after])
		return
	if not world._grid_occupancy.has(target_cell):
		_fail("설치 후 _grid_occupancy에 등록되지 않음")
		return
	var structure_node: Node = world._grid_occupancy[target_cell]
	if not (structure_node is StaticBody2D):
		_fail("설치된 노드가 StaticBody2D가 아님: %s" % structure_node)
		return
	if structure_node.get_child_count() < 2:
		_fail("설치된 노드에 CollisionShape2D/Sprite2D 자식이 부족함")
		return

	world.camera.global_position = target_world  # 실제 설치된 벽은 마우스와 무관하게 고정돼 있으니 화면 중앙에서 그대로 보임
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_placed := get_viewport().get_texture().get_image()
	img_placed.save_png("%s/01_placed.png" % OUT_DIR)

	# --- 3) 이미 벽이 있는 칸에는 재설치 안 됨 ---
	world.camera.global_position = target_world - offset  # 마우스가 다시 target_cell을 가리키게 복귀
	await get_tree().process_frame
	var count_before2 := InventoryData.get_count("wood_wall")
	world._try_place_structure()
	await get_tree().process_frame
	var count_after2 := InventoryData.get_count("wood_wall")
	if count_after2 != count_before2:
		_fail("이미 벽이 있는 칸인데 또 소모됨: before=%d after=%d" % [count_before2, count_after2])
		return

	# --- 4) 플레이어가 벽을 통과 못 하는지 확인 (grid collision) ---
	# 목표 칸 바로 왼쪽(플레이어 칸)에서 오른쪽으로 이동을 시도 — 벽 칸을 넘어가면 안 됨.
	# (INBOX #125 수정) 예전엔 한 번에 500유닛을 통째로 넘겼는데, 그러면
	# _move_player_with_grid_collision()이 목적지 지점만 확인해서 벽을 통째로
	# 건너뛰어도 통과 실패로 안 잡힐 수 있다(STATUS.md 바퀴173 결정 로그에 이미 기록된
	# 함정 — #120 검증 때 실제로 이 방식 때문에 원인 불명 실패를 겪었다). 실제 물리
	# 루프처럼 격자 크기보다 훨씬 작은 이동을 여러 번 반복해서 검증한다(#120과 동일 패턴).
	world.player_sprite.global_position = world._grid_to_world_center(player_cell)
	var before_pos: Vector2 = world.player_sprite.global_position
	for i in range(80):
		world._move_player_with_grid_collision(Vector2(8.0, 0.0))
	var after_pos: Vector2 = world.player_sprite.global_position
	var after_cell: Vector2i = world._world_to_grid(after_pos)
	if after_cell.x >= target_cell.x:
		_fail("플레이어가 벽 칸을 통과해버림: after_cell=%s target_cell=%s" % [str(after_cell), str(target_cell)])
		return
	print("PROBE player blocked before_pos=", before_pos, " after_pos=", after_pos, " after_cell=", after_cell)

	# --- 5) 우클릭으로 배치 모드 취소 확인 ---
	InventoryData.add_item("wood_wall", 1)
	world._select_hotbar(0)
	world._build_placement_cancelled = true
	await get_tree().process_frame
	if world._build_ghost.visible:
		_fail("우클릭 취소 후에도 고스트가 계속 보임")
		return
	# 도구를 바꾸면(핫바 재선택) 취소 상태가 풀려야 한다.
	world._select_hotbar(0)
	if world._build_placement_cancelled:
		_fail("핫바를 다시 고른 뒤에도 배치 취소 상태가 안 풀림")
		return

	# --- 6) 실제 스폰 지점(잔디 배경) 근처에서 벽 여러 개를 이어붙인 모습도 눈으로 확인 ---
	world.set_process(false)
	var spawn_cell: Vector2i = world._world_to_grid(Vector2(2000, 2000))  # 다른 스폰 오브젝트와 겹치지 않는 자리
	for i in range(3):
		var cell: Vector2i = spawn_cell + Vector2i(i, 0)
		_grid_placeholder_wall(world, cell)
	world.player_sprite.global_position = world._grid_to_world_center(spawn_cell + Vector2i(1, 1))
	world.camera.global_position = world.player_sprite.global_position
	world.set_process(true)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_row := get_viewport().get_texture().get_image()
	img_row.save_png("%s/02_wall_row_with_grass.png" % OUT_DIR)

	print("QA_INBOX119_CHECK_PASS")
	get_tree().quit()


## _try_place_structure()는 마우스 위치에 의존하므로, 눈으로 보는 용도의 마지막 스크린샷은
## _spawn_structure()를 직접 호출해 원하는 칸에 확실히 놓는다(인벤토리 소모 없이).
func _grid_placeholder_wall(world: Node, cell: Vector2i) -> void:
	world._grid_occupancy[cell] = world._spawn_structure("wood_wall", cell)
