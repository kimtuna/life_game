extends Node
## INBOX #132 확인용 — 벽/문 스프라이트의 시각적 크기를 BUILD_GRID_SIZE(16, 충돌/방
## 감지 해상도)에서 분리해 BUILD_STRUCTURE_VISUAL_SIZE(32)로 고정한 뒤, 실제로
## 캐릭터 대비 자연스러운 비율(최소 32px 기준 충족)로 보이는지, 그리고 방 감지가
## 여전히 정상 동작하는지(회귀) 스크린샷+코드 양쪽으로 확인한다. inbox125_check.gd와
## 같은 패턴(격리된 좌표에 직접 _spawn_structure() 호출)을 재사용한다.

const OUT_DIR := "/tmp/qa132"


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
	print("QA_INBOX132_CHECK_FAIL: ", msg)
	get_tree().quit()


func _run_checks() -> void:
	var world := get_tree().current_scene
	world.set_physics_process(false)
	world.set_process(false)

	# 1) 스프라이트 scale 값 자체를 직접 확인한다 — BUILD_GRID_SIZE(16)가 아니라
	# BUILD_STRUCTURE_VISUAL_SIZE(32)로 계산돼야 한다(원본 아이콘 32x32이므로 scale=1.0 기대).
	var probe_origin: Vector2 = Vector2(210000, 210000)
	var probe_cell: Vector2i = world._world_to_grid(probe_origin)
	var wall_node: Node2D = world._spawn_structure("wood_wall", probe_cell)
	var wall_sprite: Sprite2D = world._get_structure_sprite(wall_node)
	if wall_sprite == null:
		_fail("벽 노드에서 Sprite2D를 찾지 못함")
		return
	var visual_px: Vector2 = wall_sprite.texture.get_size() * wall_sprite.scale
	print("PROBE wall visual size(px)=", visual_px, " scale=", wall_sprite.scale)
	if visual_px.x < 32.0 or visual_px.y < 32.0:
		_fail("벽 시각 크기가 32px 미만 — visual_px=%s" % [visual_px])
		return
	wall_node.queue_free()

	# 2) 격리된 자리에서 벽 4x4 둘레 + 문 하나를 실제로 놓고, 플레이어를 옆에 세워
	# 크기 비율을 스크린샷으로 확인한다(inbox125_check.gd와 같은 패턴).
	var origin_world: Vector2 = Vector2(220000, 220000)
	var origin_cell: Vector2i = world._world_to_grid(origin_world)
	for dx in range(4):
		for dy in range(4):
			if dx > 0 and dx < 3 and dy > 0 and dy < 3:
				continue
			var cell: Vector2i = origin_cell + Vector2i(dx, dy)
			if dx == 0 and dy == 1:
				world._grid_occupancy[cell] = world._spawn_structure("wood_door", cell)
			else:
				world._grid_occupancy[cell] = world._spawn_structure("wood_wall", cell)
	world._recompute_rooms()

	var center_cell: Vector2i = origin_cell + Vector2i(1, 1)
	world.player_sprite.global_position = world._grid_to_world_center(center_cell)
	world.camera.global_position = world.player_sprite.global_position
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_center := get_viewport().get_texture().get_image()
	img_center.save_png("%s/00_player_inside_room.png" % OUT_DIR)

	var wall_cell: Vector2i = origin_cell + Vector2i(3, 1)
	world.player_sprite.global_position = world._grid_to_world_center(wall_cell) + Vector2(-40, 0)
	world.camera.global_position = world.player_sprite.global_position
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_side := get_viewport().get_texture().get_image()
	img_side.save_png("%s/01_player_beside_wall.png" % OUT_DIR)

	# 3) 배치 모드 고스트 미리보기도 같은 시각 크기로 맞춰졌는지 확인(#132 원문 요구).
	# 핫바 슬롯 규칙과 무관하게 슬롯 0을 직접 wood_wall로 덮어써서 확실히 손에 들게 한다
	# (시작 무료 지급 도구가 이미 앞 슬롯을 채우고 있을 수 있어 add_item만으론 슬롯 위치가
	# 불확실함 — QA 전용 스크립트이므로 InventoryData 내부 배열을 직접 조작해도 무방하다).
	InventoryData._general_slots[0] = {"item": "wood_wall", "count": 1}
	world._select_hotbar(0)
	if world.get_held_item() != "wood_wall":
		_fail("wood_wall을 슬롯 0에 직접 넣고 선택했는데 get_held_item()이 다른 값을 반환함: %s" % world.get_held_item())
		return
	world.player_sprite.global_position = world._grid_to_world_center(wall_cell)
	world.camera.global_position = world.player_sprite.global_position
	world._update_build_ghost()
	if world._build_ghost.visible:
		var ghost_px: Vector2 = world._build_ghost.texture.get_size() * world._build_ghost.scale
		print("PROBE ghost visual size(px)=", ghost_px)
		if ghost_px.x < 32.0 or ghost_px.y < 32.0:
			_fail("고스트 미리보기 시각 크기가 32px 미만 — ghost_px=%s" % [ghost_px])
			return
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img_ghost := get_viewport().get_texture().get_image()
		img_ghost.save_png("%s/02_build_ghost.png" % OUT_DIR)
	else:
		print("PROBE ghost not visible (held item mismatch) — skipped ghost screenshot")

	# 4) 방 감지 회귀 확인(카테고리는 핵심 오브젝트가 없으니 "잡실"이어야 함).
	var room_id: int = world.get_room_id_at(world._grid_to_world_center(center_cell))
	if room_id == -1:
		_fail("벽 4면으로 둘러쌌는데 방으로 인식되지 않음(room_id=-1) — 시각 크기 변경이 격자/충돌에 영향을 준 것으로 의심됨")
		return
	print("PROBE room_id=", room_id, " category=", world.get_room_category(room_id))

	print("QA_INBOX132_CHECK_PASS")
	get_tree().quit()
