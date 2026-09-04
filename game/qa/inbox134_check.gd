extends Node
## INBOX #134 확인용 — 나무벽/석제벽/강철벽/나무문/강철문/창문을 절차적(Pillow)으로
## "서 있는 벽"처럼(상단 캡/베이스 그림자/베벨) 다시 그린 뒤, 실제 게임 화면에서
## (1) 여러 개 이어붙였을 때 이음매가 자연스러운지, (2) 캐릭터와 비교해 비율이
## 어색하지 않은지, (3) 문/창문이 벽과 구분되면서도 같은 스타일인지 스크린샷으로
## 확인한다. inbox133_check.gd와 같은 패턴(격리된 좌표에 직접 _spawn_structure() 호출,
## 임시 autoload로 실행).

const OUT_DIR := "/tmp/qa134"


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
	print("QA_INBOX134_CHECK_FAIL: ", msg)
	get_tree().quit()


func _run_checks() -> void:
	var world := get_tree().current_scene
	world.set_physics_process(false)
	world.set_process(false)

	# 1) 6종(나무벽/석제벽/강철벽/나무문/강철문/창문)을 한 줄로 나란히 배치해 이음매와
	# 재질별 구분을 눈으로 확인한다.
	var kinds := ["wood_wall", "stone_wall", "steel_wall", "wood_door", "steel_door", "window"]
	var row_origin_world: Vector2 = Vector2(250000, 250000)
	var row_origin_cell: Vector2i = world._world_to_grid(row_origin_world)
	for i in range(kinds.size()):
		var cell: Vector2i = row_origin_cell + Vector2i(i, 0)
		var node: Node2D = world._spawn_structure(kinds[i], cell)
		world._grid_occupancy[cell] = node

	world.player_sprite.global_position = world._grid_to_world_center(row_origin_cell + Vector2i(2, 1)) + Vector2(0, 40)
	world.camera.global_position = world.player_sprite.global_position
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_row := get_viewport().get_texture().get_image()
	img_row.save_png("%s/00_six_kinds_row.png" % OUT_DIR)

	# 2) 캐릭터를 벽 바로 옆에 세워서 비율(키 대비 벽 높이)을 확인한다.
	world.player_sprite.global_position = world._grid_to_world_center(row_origin_cell) + Vector2(0, world.BUILD_GRID_SIZE)
	world.camera.global_position = world.player_sprite.global_position
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_scale := get_viewport().get_texture().get_image()
	img_scale.save_png("%s/01_player_next_to_wall.png" % OUT_DIR)

	# 3) 나무벽만 길게 5개 이어붙여 이음매 자연스러움을 다시 확인(#133 검증과 같은 자리
	# 패턴을 재사용, 그림만 새 것으로 바뀐 상태).
	var wall_row_origin_world: Vector2 = Vector2(260000, 260000)
	var wall_row_origin_cell: Vector2i = world._world_to_grid(wall_row_origin_world)
	for dx in range(5):
		var cell2: Vector2i = wall_row_origin_cell + Vector2i(dx, 0)
		var node2: Node2D = world._spawn_structure("wood_wall", cell2)
		world._grid_occupancy[cell2] = node2
	world.player_sprite.global_position = world._grid_to_world_center(wall_row_origin_cell + Vector2i(2, 0)) + Vector2(0, -50)
	world.camera.global_position = world.player_sprite.global_position
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_seam := get_viewport().get_texture().get_image()
	img_seam.save_png("%s/02_wood_wall_seam.png" % OUT_DIR)

	# 4) 문 열림/닫힘 상태가 여전히 구분되는지 확인(그림을 새로 그렸어도 door.gd의
	# modulate.a/position.x 토글 로직은 그대로 유지돼야 함).
	var door_origin_world: Vector2 = Vector2(270000, 270000)
	var door_cell: Vector2i = world._world_to_grid(door_origin_world)
	var door_node: Node2D = world._spawn_structure("wood_door", door_cell)
	world._grid_occupancy[door_cell] = door_node
	world.player_sprite.global_position = world._grid_to_world_center(door_cell) + Vector2(0, 60)
	world.camera.global_position = world.player_sprite.global_position
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_door_closed := get_viewport().get_texture().get_image()
	img_door_closed.save_png("%s/03_door_closed.png" % OUT_DIR)

	door_node._toggle()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_door_open := get_viewport().get_texture().get_image()
	img_door_open.save_png("%s/04_door_open.png" % OUT_DIR)

	# 5) 회귀: 벽 4개로 둘러싼 공간이 여전히 방으로 인식되는지(그림 교체가 충돌 크기에
	# 영향 주지 않았는지).
	var room_origin_world: Vector2 = Vector2(280000, 280000)
	var room_origin_cell: Vector2i = world._world_to_grid(room_origin_world)
	for dx in range(3):
		for dy in range(3):
			if dx > 0 and dx < 2 and dy > 0 and dy < 2:
				continue
			var cell3: Vector2i = room_origin_cell + Vector2i(dx, dy)
			world._grid_occupancy[cell3] = world._spawn_structure("stone_wall", cell3)
	world._recompute_rooms()
	var center_cell: Vector2i = room_origin_cell + Vector2i(1, 1)
	var room_id: int = world.get_room_id_at(world._grid_to_world_center(center_cell))
	if room_id == -1:
		_fail("벽으로 완전히 둘러쌌는데 방으로 인식되지 않음(room_id=-1) — 그림 교체가 회귀를 일으킴")
		return
	print("PROBE room_id=", room_id)

	print("QA_INBOX134_CHECK_PASS")
	get_tree().quit()
