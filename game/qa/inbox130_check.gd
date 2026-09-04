extends Node
## INBOX #130 확인용 — 건설 해제 모드(#128)를 상태를 가진 다른 설치물(상자/제작대류/
## 밭/목장)까지 확장한 것을 검증한다. #122/#128/#129와 같은 방법: project.godot
## [autoload]에 이 스크립트를 임시로 추가하고 `godot --path .`로 실행한 뒤 되돌린다.

const OUT_DIR := "/tmp/qa130"
const ProcessingTableScene := preload("res://scenes/processing_table/processing_table.tscn")
const StorageChestScene := preload("res://scenes/storage_chest/storage_chest.tscn")
const RanchZoneScene := preload("res://scenes/ranch_zone/ranch_zone.tscn")
const FarmPlotScene := preload("res://scenes/farm_plot/farm_plot.tscn")
const DeerScene := preload("res://scenes/deer/deer.tscn")


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
	print("QA_INBOX130_CHECK_FAIL: ", msg)
	get_tree().quit()


## 마우스 고정 오프셋 트릭(#119~#121/#128/#129와 동일).
func _point_mouse_at(world, offset: Vector2, target_cell: Vector2i) -> bool:
	var target_world: Vector2 = world._grid_to_world_center(target_cell)
	world.camera.global_position = target_world - offset
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
	world.player_sprite.global_position = Vector2(700000, 700000)  # 다른 QA 자리와 격리
	world.camera.global_position = world.player_sprite.global_position
	await get_tree().process_frame

	Input.warp_mouse(get_viewport().get_visible_rect().size / 2.0)
	await get_tree().process_frame
	var mouse_before: Vector2 = world.get_global_mouse_position()
	var offset: Vector2 = mouse_before - world.camera.global_position
	var player_cell: Vector2i = world._world_to_grid(world.player_sprite.global_position)

	# --- 준비: 벽 4개로 작은 방을 만들고 그 안에 가공대를 놓는다(방 카테고리 재계산
	#     검증용, #122 패턴 재사용) ---
	var room_cell: Vector2i = player_cell + Vector2i(3, 3)
	var room_world: Vector2 = world._grid_to_world_center(room_cell)
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var wall_cell: Vector2i = room_cell + dir
		world._grid_occupancy[wall_cell] = world._spawn_structure("wood_wall", wall_cell)
	var table := ProcessingTableScene.instantiate()
	table.global_position = room_world
	table.player_ref = world.player_sprite
	table.world_ref = world
	world.add_child(table)
	world._recompute_rooms()
	await get_tree().process_frame

	var room_id: int = world.get_room_id_at(room_world)
	if room_id == -1 or world.get_room_category(room_id) != "제작소":
		_fail("사전 조건 실패: 가공대가 있는 방이 '제작소'로 판정되지 않음 (room_id=%d, category=%s)" % [room_id, world.get_room_category(room_id)])
		return
	print("[setup] 벽 4개 + 가공대 -> 제작소 확인 OK")

	# --- X로 건설 해제 모드 켜기 ---
	await _press_key(KEY_X)
	if not world.is_deconstruct_mode_active():
		_fail("X를 눌렀는데 건설 해제 모드가 켜지지 않음")
		return

	# --- 1) 제작대류: 배치 진행 중이면 철거가 막혀야 함 ---
	table._batch_remaining = 3
	if not table.is_batch_active():
		_fail("사전 조건 실패: table._batch_remaining을 세팅했는데 is_batch_active()가 false")
		return
	if not await _point_mouse_at(world, offset, room_cell):
		_fail("가공대 칸 마우스 오프셋 보정 실패")
		return
	await get_tree().process_frame
	if world._deconstruct_highlighted_node != table:
		_fail("배치 진행 중인 가공대 칸인데 하이라이트 노드가 그 가공대가 아님(하이라이트는 막힘 여부와 무관하게 항상 보여야 함)")
		return
	var table_sprite: Sprite2D = world._get_structure_sprite(table)
	if not (table_sprite.modulate.r > table_sprite.modulate.g + 0.2 and table_sprite.modulate.r > table_sprite.modulate.b + 0.2):
		_fail("배치 진행 중인 가공대 칸 하이라이트 색이 빨간색 쪽으로 치우치지 않음: %s" % str(table_sprite.modulate))
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_table := get_viewport().get_texture().get_image()
	img_table.save_png("%s/00_crafting_station_blocked_highlight.png" % OUT_DIR)
	await _click_left()
	if not is_instance_valid(table):
		_fail("배치 진행 중인데도 가공대가 철거됨(막혔어야 함)")
		return
	## _recompute_rooms()는 매번 방 ID를 새로 부여하므로(호출될 때마다 _rooms를 통째로
	## 다시 만듦), 철거가 성공적으로 막혀서 재계산이 아예 일어나지 않았다면 room_id는
	## 그대로 유효해야 한다 — 여기서는 재조회 없이 기존 room_id로 그대로 확인한다.
	if world.get_room_category(room_id) != "제작소":
		_fail("철거가 막혔는데도 방 카테고리가 바뀜: %s" % world.get_room_category(room_id))
		return
	print("QA_INBOX130_CRAFTING_STATION_BLOCKED_WHILE_BATCH_ACTIVE_OK")

	# --- 2) 배치가 끝나면(진행 중 아님) 철거가 되고, 방 카테고리도 '잡실'로 재계산돼야 함 ---
	table._batch_remaining = 0
	await get_tree().process_frame
	await _click_left()
	if is_instance_valid(table):
		_fail("배치가 없는데도 가공대가 철거되지 않음")
		return
	## 철거 성공 시 _recompute_rooms()가 다시 돌면서 room_id 자체가 새로 부여되므로,
	## 기존 room_id로는 더 이상 조회할 수 없다(반환값이 빈 문자열이 되는 게 정상) —
	## 방 위치(room_world)로 새 room_id를 다시 찾아서 카테고리를 확인해야 한다.
	var new_room_id: int = world.get_room_id_at(room_world)
	if new_room_id == -1 or world.get_room_category(new_room_id) != "잡실":
		_fail("가공대 철거 후 방 카테고리가 '잡실'로 재계산되지 않음: room_id=%d category=%s" % [new_room_id, world.get_room_category(new_room_id)])
		return
	print("QA_INBOX130_CRAFTING_STATION_DECONSTRUCT_RECOMPUTES_ROOM_OK")

	# --- 3) 저장 상자: 내용물이 있으면 철거가 막혀야 함 ---
	var chest_cell: Vector2i = player_cell + Vector2i(10, 0)
	var chest_world: Vector2 = world._grid_to_world_center(chest_cell)
	var chest := StorageChestScene.instantiate()
	chest.global_position = chest_world
	chest.player_ref = world.player_sprite
	chest.world_ref = world
	world.add_child(chest)
	chest.add_item("wood", 1)
	await get_tree().process_frame

	if not await _point_mouse_at(world, offset, chest_cell):
		_fail("상자 칸 마우스 오프셋 보정 실패")
		return
	await get_tree().process_frame
	if world._deconstruct_highlighted_node != chest:
		_fail("내용물 있는 상자 칸인데 하이라이트 노드가 그 상자가 아님")
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_chest := get_viewport().get_texture().get_image()
	img_chest.save_png("%s/01_chest_blocked_highlight.png" % OUT_DIR)
	var wood_before: int = InventoryData.get_count("wood")
	await _click_left()
	if not is_instance_valid(chest):
		_fail("내용물이 있는데도 상자가 철거됨(막혔어야 함)")
		return
	if InventoryData.get_count("wood") != wood_before:
		_fail("철거가 막혔어야 하는데 인벤토리 wood 개수가 바뀜")
		return
	print("QA_INBOX130_CHEST_BLOCKED_WHILE_NOT_EMPTY_OK")

	# --- 4) 상자를 비우면 철거되고, 대응하는 아이템이 인벤토리로 돌아오지 않아야 함
	#     (이 픽스처들은 원래 크래프팅 아이템이 아니라 DESIGN.md에 없는 새 아이템을
	#     지어내지 않기로 판단했음 — world.gd의 _deconstruct_fixture() 주석 참고) ---
	chest.remove_item("wood", 1)
	if not chest.is_empty():
		_fail("사전 조건 실패: 상자를 비웠는데 is_empty()가 false")
		return
	var slot_count_before: int = InventoryData._general_slots.filter(func(s): return s != null).size()
	await _click_left()
	if is_instance_valid(chest):
		_fail("빈 상자인데도 철거되지 않음")
		return
	var slot_count_after: int = InventoryData._general_slots.filter(func(s): return s != null).size()
	if slot_count_after != slot_count_before:
		_fail("상자 철거로 인벤토리에 아이템이 새로 생김(환급 없어야 함) before=%d after=%d" % [slot_count_before, slot_count_after])
		return
	print("QA_INBOX130_CHEST_DECONSTRUCT_NO_ITEM_REFUND_OK")

	# --- 5) 목장: 동물이 있으면 철거가 막혀야 함 ---
	var ranch_cell: Vector2i = player_cell + Vector2i(14, 0)
	var ranch_world: Vector2 = world._grid_to_world_center(ranch_cell)
	var ranch := RanchZoneScene.instantiate()
	ranch.global_position = ranch_world
	ranch.player_ref = world.player_sprite
	ranch.world_ref = world
	world.add_child(ranch)
	await get_tree().process_frame

	var deer := DeerScene.instantiate()
	ranch.add_child(deer)
	deer.is_ranched = true
	deer.zone_center = Vector2.ZERO
	deer.zone_radius = ranch.ZONE_RADIUS
	deer.position = Vector2.ZERO
	await get_tree().process_frame

	if not ranch.has_animal():
		_fail("사전 조건 실패: 사슴을 넣었는데 has_animal()이 false")
		return
	if not await _point_mouse_at(world, offset, ranch_cell):
		_fail("목장 칸 마우스 오프셋 보정 실패")
		return
	await get_tree().process_frame
	if world._deconstruct_highlighted_node != ranch:
		_fail("동물 있는 목장 칸인데 하이라이트 노드가 그 목장이 아님")
		return
	await _click_left()
	if not is_instance_valid(ranch):
		_fail("동물이 있는데도 목장이 철거됨(막혔어야 함)")
		return
	print("QA_INBOX130_RANCH_BLOCKED_WHILE_HAS_ANIMAL_OK")

	# --- 6) 동물을 빼면 철거되어야 함 ---
	deer.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	if ranch.has_animal():
		_fail("사전 조건 실패: 사슴을 뺐는데 has_animal()이 여전히 true")
		return
	await _click_left()
	if is_instance_valid(ranch):
		_fail("동물이 없는데도 목장이 철거되지 않음")
		return
	print("QA_INBOX130_RANCH_DECONSTRUCT_AFTER_ANIMAL_REMOVED_OK")

	# --- 7) 밭: 상태(자라는 중)와 무관하게 항상 철거 가능해야 함 ---
	var plot_cell: Vector2i = player_cell + Vector2i(18, 0)
	var plot_world: Vector2 = world._grid_to_world_center(plot_cell)
	var plot := FarmPlotScene.instantiate()
	plot.global_position = plot_world
	plot.player_ref = world.player_sprite
	plot.world_ref = world
	world.add_child(plot)
	plot._state = FarmPlot.State.GROWING
	plot._grow_timer = 30.0
	await get_tree().process_frame

	if not await _point_mouse_at(world, offset, plot_cell):
		_fail("밭 칸 마우스 오프셋 보정 실패")
		return
	await get_tree().process_frame
	if world._deconstruct_highlighted_node != plot:
		_fail("밭 칸인데 하이라이트 노드가 그 밭이 아님")
		return
	await _click_left()
	if is_instance_valid(plot):
		_fail("자라는 중인 밭인데도(항상 가능해야 하는데) 철거되지 않음")
		return
	print("QA_INBOX130_FARM_PLOT_ALWAYS_DECONSTRUCTIBLE_OK")

	# --- 8) 정리: X로 모드 끄기 ---
	await _press_key(KEY_X)
	if world.is_deconstruct_mode_active():
		_fail("X를 다시 눌렀는데 건설 해제 모드가 꺼지지 않음")
		return
	print("QA_INBOX130_TOGGLE_OFF_OK")

	print("QA_INBOX130_CHECK_PASS")
	get_tree().quit()
