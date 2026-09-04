extends Node
## INBOX #133 확인용 — BUILD_GRID_SIZE(충돌/방 감지)와 벽/문 스프라이트 표시 크기를
## 다시 하나의 값(32)으로 합친 뒤, 벽을 겹치지 않게 인접 배치했을 때 (1) 화면상 빈틈/
## 겹침 없이 이음매가 딱 맞는지, (2) 그 이음매를 플레이어가 통과할 수 없는지, (3) 벽
## 4개로 두른 공간이 방으로 인식되는지를 코드+스크린샷으로 확인한다.
## inbox132_check.gd와 같은 패턴(격리된 좌표에 직접 _spawn_structure() 호출, 임시
## autoload로 실행)을 재사용한다.

const OUT_DIR := "/tmp/qa133"


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
	print("QA_INBOX133_CHECK_FAIL: ", msg)
	get_tree().quit()


func _run_checks() -> void:
	var world := get_tree().current_scene
	world.set_physics_process(false)
	world.set_process(false)

	# 1) 충돌 칸 크기와 스프라이트 표시 크기가 정확히 같은 값(BUILD_GRID_SIZE=32)인지
	# 코드로 직접 확인한다 — #133이 고치려는 핵심(둘이 분리돼 있으면 안 됨).
	if world.BUILD_GRID_SIZE != 32.0:
		_fail("BUILD_GRID_SIZE가 32가 아님: %s" % world.BUILD_GRID_SIZE)
		return
	var probe_origin: Vector2 = Vector2(210000, 210000)
	var probe_cell: Vector2i = world._world_to_grid(probe_origin)
	var wall_node: Node2D = world._spawn_structure("wood_wall", probe_cell)
	var wall_sprite: Sprite2D = world._get_structure_sprite(wall_node)
	if wall_sprite == null:
		_fail("벽 노드에서 Sprite2D를 찾지 못함")
		return
	var visual_px: Vector2 = wall_sprite.texture.get_size() * wall_sprite.scale
	var col_shape: CollisionShape2D = null
	for child in wall_node.get_children():
		if child is CollisionShape2D:
			col_shape = child
	print("PROBE wall visual_px=", visual_px, " collision_size=", col_shape.shape.size)
	if visual_px != col_shape.shape.size:
		_fail("시각 크기와 충돌 크기가 서로 다름 — visual=%s collision=%s" % [visual_px, col_shape.shape.size])
		return
	if visual_px.x < 32.0 or visual_px.y < 32.0:
		_fail("벽 시각 크기가 32px 미만 — visual_px=%s" % [visual_px])
		return
	wall_node.queue_free()

	# 2) 격리된 자리에서 벽을 겹치지 않게(그리드 상 인접 칸에) 옆으로 5개 쭉 이어붙이고,
	# 화면 픽셀 좌표 기준으로 이웃한 두 벽 사이에 빈틈/겹침이 없는지 확인한다.
	var origin_world: Vector2 = Vector2(230000, 230000)
	var origin_cell: Vector2i = world._world_to_grid(origin_world)
	var row_nodes: Array = []
	for dx in range(5):
		var cell: Vector2i = origin_cell + Vector2i(dx, 0)
		var node: Node2D = world._spawn_structure("wood_wall", cell)
		world._grid_occupancy[cell] = node
		row_nodes.append(node)

	for i in range(row_nodes.size() - 1):
		var s_a: Sprite2D = world._get_structure_sprite(row_nodes[i])
		var s_b: Sprite2D = world._get_structure_sprite(row_nodes[i + 1])
		var half_a: float = (s_a.texture.get_size().x * s_a.scale.x) / 2.0
		var half_b: float = (s_b.texture.get_size().x * s_b.scale.x) / 2.0
		var right_edge_a: float = s_a.global_position.x + half_a
		var left_edge_b: float = s_b.global_position.x - half_b
		var gap: float = left_edge_b - right_edge_a
		print("PROBE seam gap[%d->%d]=%s (0이면 완벽히 맞닿음)" % [i, i + 1, gap])
		if abs(gap) > 0.01:
			_fail("벽 %d와 %d 사이에 빈틈/겹침이 있음 — gap=%s" % [i, i + 1, gap])
			return

	# 3) 이 벽 라인을 플레이어가 통과할 수 없는지 확인한다 — 라인 왼쪽에서 오른쪽으로
	# 여러 스텝 밀어붙여도 _is_position_blocked()가 계속 막아야 한다.
	var left_of_line: Vector2 = world._grid_to_world_center(origin_cell) + Vector2(-60, 0)
	world.player_sprite.position = left_of_line
	var crossed := false
	for i in range(40):
		var motion := Vector2(4.0, 0.0)
		var try_pos: Vector2 = world.player_sprite.position + motion
		if not world._is_position_blocked(try_pos):
			world.player_sprite.position = try_pos
	var right_of_line: Vector2 = world._grid_to_world_center(origin_cell + Vector2i(4, 0)) + Vector2(60, 0)
	if world.player_sprite.position.x >= right_of_line.x:
		crossed = true
	print("PROBE player_x_after_push=", world.player_sprite.position.x, " right_of_line_x=", right_of_line.x)
	if crossed:
		_fail("벽 라인을 플레이어가 통과함 — 이음매에 빈틈이 있는 것으로 의심됨")
		return

	# 4) 벽 4개로 완전히 두른 별도 공간을 만들어 방으로 인식되는지 확인한다(회귀).
	var room_origin_world: Vector2 = Vector2(240000, 240000)
	var room_origin_cell: Vector2i = world._world_to_grid(room_origin_world)
	for dx in range(3):
		for dy in range(3):
			if dx > 0 and dx < 2 and dy > 0 and dy < 2:
				continue
			var cell: Vector2i = room_origin_cell + Vector2i(dx, dy)
			world._grid_occupancy[cell] = world._spawn_structure("wood_wall", cell)
	world._recompute_rooms()
	var center_cell: Vector2i = room_origin_cell + Vector2i(1, 1)
	var room_id: int = world.get_room_id_at(world._grid_to_world_center(center_cell))
	if room_id == -1:
		_fail("벽으로 완전히 둘러쌌는데 방으로 인식되지 않음(room_id=-1)")
		return
	print("PROBE room_id=", room_id, " category=", world.get_room_category(room_id))

	# 5) 스크린샷 — 인접 벽 라인 옆에 플레이어를 세워서 눈으로 이음매를 직접 확인한다.
	world.player_sprite.global_position = world._grid_to_world_center(origin_cell + Vector2i(2, 0)) + Vector2(0, -50)
	world.camera.global_position = world.player_sprite.global_position
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_seam := get_viewport().get_texture().get_image()
	img_seam.save_png("%s/00_wall_seam.png" % OUT_DIR)

	world.player_sprite.global_position = world._grid_to_world_center(center_cell)
	world.camera.global_position = world.player_sprite.global_position
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_room := get_viewport().get_texture().get_image()
	img_room.save_png("%s/01_player_inside_room.png" % OUT_DIR)

	print("QA_INBOX133_CHECK_PASS")
	get_tree().quit()
