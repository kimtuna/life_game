extends Node
## INBOX #125 확인용 — BUILD_GRID_SIZE를 64→16으로 줄인 뒤, 벽/문이 실제 화면에서
## 캐릭터 대비 자연스러운 비율로 보이는지 스크린샷으로 확인한다. inbox119_check.gd와
## 같은 마우스 오프셋 우회 없이, _spawn_structure()를 직접 호출해 원하는 칸에 벽/문을
## 놓고 눈으로 보는 용도로만 쓴다(배치 입력 자체는 #119/#120이 이미 검증함).

const OUT_DIR := "/tmp/qa125"


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
	print("QA_INBOX125_CHECK_FAIL: ", msg)
	get_tree().quit()


func _run_checks() -> void:
	var world := get_tree().current_scene
	world.set_physics_process(false)
	world.set_process(false)

	# 격리된 자리에서 벽 4칸으로 둘러싼 작은 방 + 문 하나를 실제로 놓고, 플레이어를
	# 그 옆에 세워서 크기 비율을 스크린샷으로 확인한다.
	var origin_world: Vector2 = Vector2(200000, 200000)
	var origin_cell: Vector2i = world._world_to_grid(origin_world)

	# 3x3 방 둘레(가장자리)에 벽을 놓고 한쪽에 문을 낸다.
	for dx in range(4):
		for dy in range(4):
			if dx > 0 and dx < 3 and dy > 0 and dy < 3:
				continue  # 안쪽은 비워둠(방)
			var cell: Vector2i = origin_cell + Vector2i(dx, dy)
			if dx == 0 and dy == 1:
				world._grid_occupancy[cell] = world._spawn_structure("wood_door", cell)
			else:
				world._grid_occupancy[cell] = world._spawn_structure("wood_wall", cell)
	world._recompute_rooms()

	# 플레이어를 방 한가운데 세운다.
	var center_cell: Vector2i = origin_cell + Vector2i(1, 1)
	world.player_sprite.global_position = world._grid_to_world_center(center_cell)
	world.camera.global_position = world.player_sprite.global_position
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_center := get_viewport().get_texture().get_image()
	img_center.save_png("%s/00_player_inside_room.png" % OUT_DIR)

	# 플레이어를 문 바로 옆(벽 하나와 나란히)에 세워 벽 1개와 직접 크기 비교.
	var wall_cell: Vector2i = origin_cell + Vector2i(3, 1)
	world.player_sprite.global_position = world._grid_to_world_center(wall_cell) + Vector2(-40, 0)
	world.camera.global_position = world.player_sprite.global_position
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_side := get_viewport().get_texture().get_image()
	img_side.save_png("%s/01_player_beside_wall.png" % OUT_DIR)

	# 방 감지가 여전히 동작하는지(카테고리는 핵심 오브젝트가 없으니 "잡실"이어야 함).
	var room_id: int = world.get_room_id_at(world._grid_to_world_center(center_cell))
	if room_id == -1:
		_fail("벽 4면으로 둘러쌌는데 방으로 인식되지 않음(room_id=-1) — ROOM_FLOOD_CELL_CAP 재조정 확인 필요")
		return
	print("PROBE room_id=", room_id, " category=", world.get_room_category(room_id))

	print("QA_INBOX125_CHECK_PASS")
	get_tree().quit()
