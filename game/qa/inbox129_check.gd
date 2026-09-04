extends Node
## INBOX #129 확인용 — 건축 배치 시 겹침 검사가 벽/문뿐 아니라 다른 점유 오브젝트
## (밭/채집채광포인트/목장/상자/제작대류)와 플레이어가 서 있는 칸까지 막는지 검증한다.
## inbox128_check.gd와 같은 마우스 고정 오프셋 트릭을 재사용해서 원하는 격자 칸을
## 정확히 가리키게 만든 뒤, 실제 좌클릭 이벤트(Input.parse_input_event)로 배치를 시도한다.

const OUT_DIR := "/tmp/qa129"


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
	print("QA_INBOX129_CHECK_FAIL: ", msg)
	get_tree().quit()


## 마우스 고정 오프셋 트릭(#119~#121, #128과 동일) — 카메라를 목표 칸 중심 - 오프셋으로
## 옮기면 마우스가 그 칸을 가리키게 된다.
func _point_mouse_at(world, offset: Vector2, target_cell: Vector2i) -> bool:
	var target_world: Vector2 = world._grid_to_world_center(target_cell)
	world.camera.global_position = target_world - offset
	for i in range(5):
		await get_tree().process_frame
		var resolved_cell: Vector2i = world._world_to_grid(world.get_global_mouse_position())
		if resolved_cell == target_cell:
			return true
	return false


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
	world.player_sprite.global_position = Vector2(500000, 500000)  # 다른 QA 자리와 격리
	world.camera.global_position = world.player_sprite.global_position
	await get_tree().process_frame

	Input.warp_mouse(get_viewport().get_visible_rect().size / 2.0)
	await get_tree().process_frame
	var mouse_before: Vector2 = world.get_global_mouse_position()
	var offset: Vector2 = mouse_before - world.camera.global_position
	var player_cell: Vector2i = world._world_to_grid(world.player_sprite.global_position)

	# --- 준비: 상자 하나, 밭 하나를 각각 다른 자리에 직접 배치(전용 스폰 함수를 거치지
	#     않고 world.gd가 쓰는 것과 같은 씬을 직접 instantiate해서 위치만 제어한다) ---
	var chest_cell: Vector2i = player_cell + Vector2i(10, 0)
	var chest: Node = world.StorageChestScene.instantiate()
	chest.global_position = world._grid_to_world_center(chest_cell)
	chest.player_ref = world.player_sprite
	chest.world_ref = world
	world.add_child(chest)

	var plot_cell: Vector2i = player_cell + Vector2i(10, 10)
	var plot: Node = world.FarmPlotScene.instantiate()
	plot.global_position = world._grid_to_world_center(plot_cell)
	plot.player_ref = world.player_sprite
	plot.world_ref = world
	world.add_child(plot)

	await get_tree().process_frame

	InventoryData.add_item("wood_wall", 10)
	world._select_hotbar(0)
	await get_tree().process_frame
	if world.get_held_item() != "wood_wall":
		_fail("wood_wall이 핫바에 선택되지 않음(사전 조건 실패)")
		return

	# --- 1) 플레이어가 서 있는 칸에는 설치가 막혀야 함 ---
	if not await _point_mouse_at(world, offset, player_cell):
		_fail("플레이어 칸 마우스 오프셋 보정 실패")
		return
	await get_tree().process_frame
	if not world._is_cell_build_blocked(player_cell):
		_fail("플레이어가 서 있는 칸인데 _is_cell_build_blocked()가 false를 반환함")
		return
	var count_before_player: int = InventoryData.get_count("wood_wall")
	await _click_left()
	if world._grid_occupancy.has(player_cell):
		_fail("플레이어가 서 있는 칸에 벽이 실제로 설치됨")
		return
	if InventoryData.get_count("wood_wall") != count_before_player:
		_fail("플레이어 칸 설치가 막혔어야 하는데 인벤토리에서 wood_wall이 소모됨")
		return
	print("QA_INBOX129_PLAYER_CELL_BLOCKED_OK")

	# --- 2) 상자가 있는 칸에는 설치가 막혀야 함 ---
	if not await _point_mouse_at(world, offset, chest_cell):
		_fail("상자 칸 마우스 오프셋 보정 실패")
		return
	await get_tree().process_frame
	if not world._is_cell_build_blocked(chest_cell):
		_fail("상자가 있는 칸인데 _is_cell_build_blocked()가 false를 반환함")
		return
	## 고스트가 빨간색으로 경고하는지도 눈으로 확인할 스크린샷을 남긴다.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_chest := get_viewport().get_texture().get_image()
	img_chest.save_png("%s/00_chest_blocked_ghost.png" % OUT_DIR)
	if not (world._build_ghost.modulate.r > world._build_ghost.modulate.g + 0.2 \
			and world._build_ghost.modulate.r > world._build_ghost.modulate.b + 0.2):
		_fail("상자 칸 위인데 고스트가 빨간색으로 경고하지 않음: %s" % str(world._build_ghost.modulate))
		return
	var count_before_chest: int = InventoryData.get_count("wood_wall")
	await _click_left()
	if world._grid_occupancy.has(chest_cell):
		_fail("상자가 있는 칸에 벽이 실제로 설치됨")
		return
	if InventoryData.get_count("wood_wall") != count_before_chest:
		_fail("상자 칸 설치가 막혔어야 하는데 인벤토리에서 wood_wall이 소모됨")
		return
	print("QA_INBOX129_CHEST_CELL_BLOCKED_OK")

	# --- 3) 밭이 있는 칸에는 설치가 막혀야 함 ---
	if not await _point_mouse_at(world, offset, plot_cell):
		_fail("밭 칸 마우스 오프셋 보정 실패")
		return
	await get_tree().process_frame
	if not world._is_cell_build_blocked(plot_cell):
		_fail("밭이 있는 칸인데 _is_cell_build_blocked()가 false를 반환함")
		return
	var count_before_plot: int = InventoryData.get_count("wood_wall")
	await _click_left()
	if world._grid_occupancy.has(plot_cell):
		_fail("밭이 있는 칸에 벽이 실제로 설치됨")
		return
	if InventoryData.get_count("wood_wall") != count_before_plot:
		_fail("밭 칸 설치가 막혔어야 하는데 인벤토리에서 wood_wall이 소모됨")
		return
	print("QA_INBOX129_FARM_PLOT_CELL_BLOCKED_OK")

	# --- 4) 대조군: 아무것도 없는 먼 칸에는 정상적으로 설치돼야 함(회귀 없음 확인) ---
	var empty_cell: Vector2i = player_cell + Vector2i(30, 30)
	if not await _point_mouse_at(world, offset, empty_cell):
		_fail("빈 칸 마우스 오프셋 보정 실패")
		return
	await get_tree().process_frame
	if world._is_cell_build_blocked(empty_cell):
		_fail("아무것도 없는 칸인데 _is_cell_build_blocked()가 true를 반환함(과도하게 막힘)")
		return
	var count_before_empty: int = InventoryData.get_count("wood_wall")
	await _click_left()
	if not world._grid_occupancy.has(empty_cell):
		_fail("빈 칸에 벽 설치가 정상적으로 되지 않음(회귀)")
		return
	if InventoryData.get_count("wood_wall") != count_before_empty - 1:
		_fail("빈 칸 설치 시 wood_wall이 정확히 1개 소모되지 않음")
		return
	world.camera.global_position = world._grid_to_world_center(empty_cell)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_ok := get_viewport().get_texture().get_image()
	img_ok.save_png("%s/01_empty_cell_placed.png" % OUT_DIR)
	print("QA_INBOX129_EMPTY_CELL_STILL_WORKS_OK")

	print("QA_INBOX129_CHECK_PASS")
	get_tree().quit()
