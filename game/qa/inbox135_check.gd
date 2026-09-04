extends Node
## INBOX #135 확인용 — 시야/전장의 안개(Fog of War)가 DESIGN.md대로 동작하는지 확인한다:
## (1) 조준 방향을 중심으로 한 콘 밖은 검게 덮이고 고개(조준)를 돌리면 보이는 범위가
## 바뀌는지, (2) 콘 안이라도 벽/닫힌 문 뒤는 안 보이는지, (3) 문을 열면 그 방향이
## 보이는지. inbox134_check.gd와 같은 패턴(격리된 좌표에 직접 _spawn_structure() 호출,
## 임시 autoload로 실행, world._aim_direction을 직접 강제 조작).

const OUT_DIR := "/tmp/qa135"


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
	print("QA_INBOX135_CHECK_FAIL: ", msg)
	get_tree().quit()


func _capture(world: Node, name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, name])


func _run_checks() -> void:
	var world := get_tree().current_scene
	world.set_physics_process(false)
	world.set_process(true)  # fog_of_war._process()/room_overlay._process()가 계속 redraw 하도록 켜둠

	# 5x5 돌벽 방 하나를 짓고, 남쪽 벽 중앙만 나무문으로 바꿔서 열림/닫힘 시야를 함께 본다.
	# (좌표: Ground 스프라이트가 실제로 그려지는 범위(-4000..4000) 안이면서, 기존 스폰물
	# (사슴/밭/목장/제작대 등, 대략 플레이어 시작점(640,360) 반경 1600~2000 안)과는 멀리
	# 떨어진 -3200,-3200 근방을 쓴다 — 배경이 원래 안 그려지는 빈 영역이 아니라 실제
	# 잔디 위에서 안개가 검게 덮이는지 눈으로 구별하기 위함.
	var room_origin_world: Vector2 = Vector2(-3200, -3200)
	var room_origin_cell: Vector2i = world._world_to_grid(room_origin_world)
	var door_cell: Vector2i = room_origin_cell + Vector2i(2, 4)
	var door_node: Node2D = null
	for dx in range(5):
		for dy in range(5):
			if dx > 0 and dx < 4 and dy > 0 and dy < 4:
				continue
			var cell: Vector2i = room_origin_cell + Vector2i(dx, dy)
			var kind := "wood_door" if cell == door_cell else "stone_wall"
			var node: Node2D = world._spawn_structure(kind, cell)
			world._grid_occupancy[cell] = node
			if cell == door_cell:
				door_node = node
	world._recompute_rooms()

	var room_center: Vector2 = world._grid_to_world_center(room_origin_cell + Vector2i(2, 2))
	var room_id: int = world.get_room_id_at(room_center)
	if room_id == -1:
		_fail("벽으로 둘러쌌는데 방으로 인식되지 않음(room_id=-1) — 회귀 확인 실패")
		return

	# 1) 방 한가운데서 동쪽을 조준 — 동쪽 벽 안쪽(방 내부)은 밝고, 서쪽(등 뒤, 콘 밖)과
	#    동쪽 벽 너머(가림)는 검게 덮여야 한다.
	world.player_sprite.global_position = room_center
	world.camera.global_position = room_center
	world._aim_direction = Vector2.RIGHT
	await _capture(world, "00_room_center_facing_east")

	# 2) 같은 자리에서 북쪽을 조준 — 보이는 범위가 실제로 바뀌는지(콘이 조준을 따라
	#    도는지) 확인.
	world._aim_direction = Vector2.UP
	await _capture(world, "01_room_center_facing_north")

	# 3) 방 밖(남쪽) 야외에서 방을 향해(북쪽) 조준 — 문이 닫혀 있으면 벽/문 너머 방
	#    내부가 검게 덮여야 한다(가림 판정).
	var outside_pos: Vector2 = world._grid_to_world_center(door_cell) + Vector2(0, 90)
	world.player_sprite.global_position = outside_pos
	world.camera.global_position = outside_pos
	world._aim_direction = Vector2.UP
	await _capture(world, "02_outside_door_closed_facing_room")

	# 4) 문을 열고 같은 자리/같은 조준 — 문이 열리면 그 방향으로는 방 내부가 보여야 한다
	#    (열린 문은 시야를 막지 않음).
	door_node._toggle()
	if not door_node.is_open:
		_fail("door_node._toggle() 이후에도 is_open이 false — 문 상태 전환 실패")
		return
	await _capture(world, "03_outside_door_open_facing_room")

	# 5) 반경(FOG_RADIUS) 확인 — 트인 들판 한복판에서 아무 방향이나 조준하면, 화면
	#    구석(카메라 시야 경계 부근)은 콘 안에 들어와도 일정 거리 밖은 여전히 검어야
	#    한다. 열린 벌판 좌표로 이동해서 확인.
	var open_field: Vector2 = Vector2(-3200, 3200)
	world.player_sprite.global_position = open_field
	world.camera.global_position = open_field
	world._aim_direction = Vector2.RIGHT
	await _capture(world, "04_open_field_radius_check")

	print("QA_INBOX135_CHECK_PASS room_id=", room_id)
	get_tree().quit()
