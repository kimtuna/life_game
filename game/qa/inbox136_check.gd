extends Node
## INBOX #136 확인용 — #135가 만든 시야 안개를 덕코프 스타일로 순화한 세 가지 변경이
## 실제로 동작하는지 확인한다: (1) FOG_COLOR 알파가 0.15~0.3 사이로 낮아졌는지,
## (2) 벽/문/창문 칸은 시야 콘/가림과 무관하게 항상 안개 없이 보이는지(has_structure_at
## 접근자 + 스크린샷), (3) 사슴이 시야 밖/가림 상태면 완전히 숨고(스프라이트
## visible=false), 숨은 채로 움직이면(state != idle) 화면 힌트가 뜨는지.
## inbox135_check.gd와 같은 패턴(격리된 좌표에 직접 _spawn_structure() 호출, 임시
## autoload로 실행, world._aim_direction을 직접 강제 조작)을 재사용한다.

const OUT_DIR := "/tmp/qa136"


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
	print("QA_INBOX136_CHECK_FAIL: ", msg)
	get_tree().quit()


func _capture(_world: Node, name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, name])


func _run_checks() -> void:
	var world := get_tree().current_scene
	world.set_physics_process(false)
	world.set_process(true)  # fog_of_war/room_overlay/noise_hint_overlay가 계속 redraw 하도록 켜둠

	# 1) FOG_COLOR 알파가 DESIGN.md 지침(0.15~0.3) 안에 있는지 직접 확인.
	var fog_alpha: float = FogOfWar.FOG_COLOR.a
	if fog_alpha < 0.15 or fog_alpha > 0.3:
		_fail("FOG_COLOR.a=%s 가 DESIGN.md 지침(0.15~0.3) 밖에 있음" % fog_alpha)
		return
	if is_equal_approx(fog_alpha, 1.0):
		_fail("FOG_COLOR.a가 여전히 1.0(완전 불투명) — #136 이전 값 그대로임")
		return

	# 5x5 돌벽 방 하나를 짓는다 (#135와 같은 격리 좌표, 문 없이 완전히 막음).
	var room_origin_world: Vector2 = Vector2(-3200, -3200)
	var room_origin_cell: Vector2i = world._world_to_grid(room_origin_world)
	var wall_cell: Vector2i = room_origin_cell + Vector2i(2, 0)  # 방 북쪽 벽 중앙
	for dx in range(5):
		for dy in range(5):
			if dx > 0 and dx < 4 and dy > 0 and dy < 4:
				continue
			var cell: Vector2i = room_origin_cell + Vector2i(dx, dy)
			var node: Node2D = world._spawn_structure("stone_wall", cell)
			world._grid_occupancy[cell] = node
	world._recompute_rooms()

	# 2) has_structure_at() 접근자 자체가 올바른지 확인.
	if not world.has_structure_at(wall_cell):
		_fail("has_structure_at(wall_cell)가 false — 벽을 놓은 칸인데 구조물 없음으로 판정됨")
		return
	var empty_cell: Vector2i = room_origin_cell + Vector2i(2, 2)
	if world.has_structure_at(empty_cell):
		_fail("has_structure_at(empty_cell)가 true — 방 내부 빈 칸인데 구조물 있음으로 잘못 판정됨")
		return

	var room_center: Vector2 = world._grid_to_world_center(room_origin_cell + Vector2i(2, 2))

	# 3) 방 한가운데서 남쪽(벽에서 등 돌린 방향)을 조준 — 북쪽 벽(wall_cell)은 콘/가림
	#    판정상 안 보여야 정상이지만, 벽은 안개 예외이므로 화면에 그대로 밝게 보여야 한다.
	#    같은 자리에서 grass(빈 칸) 방향은 옅게라도 어두워야(완전 검정은 아님) 대비된다.
	world.player_sprite.global_position = room_center
	world.camera.global_position = room_center
	world._aim_direction = Vector2.DOWN
	await _capture(world, "00_room_center_facing_away_from_wall")

	# 4) 문이 없는 벽이므로 항상 시야가 막혀야 정상인 지점(방 밖 북쪽)에서, 벽 자체는
	#    여전히 정상적으로 보이는지 비교용으로 한 장 더 찍는다(조준 방향을 바꿔도 벽은
	#    안 어두워짐을 눈으로 대조).
	world._aim_direction = Vector2.UP
	await _capture(world, "01_room_center_facing_wall")

	# 5) 사슴 숨김 — 기존 필드 사슴 하나를 집어서 방 안(플레이어 등 뒤, 시야 밖)으로
	#    옮기고 배회 상태로 만든다. is_position_visible()이 false를 반환해야 하고,
	#    _update_fog_visibility()가 스프라이트를 숨겨야 한다.
	var deer: Node = null
	for child in world.get_children():
		if child.has_method("take_hit") and child.get("world_ref") != null:
			deer = child
			break
	if deer == null:
		_fail("월드에서 사슴(take_hit 메서드를 가진 노드)을 찾지 못함 — _spawn_deer() 회귀 확인 필요")
		return

	world._aim_direction = Vector2.DOWN  # 4)에서 UP으로 바꿔둔 것을 남쪽으로 되돌림
	var hidden_spot: Vector2 = room_center + Vector2(0, -120)  # 남쪽을 보는 플레이어 등 뒤(콘 밖)
	deer.global_position = hidden_spot
	deer._state = "idle"
	deer._update_fog_visibility()
	if world.fog_of_war.is_position_visible(hidden_spot):
		_fail("is_position_visible(hidden_spot)이 true — 플레이어가 반대 방향을 보는데 등 뒤가 보인다고 판정됨")
		return
	if deer.sprite.visible:
		_fail("사슴이 시야 밖(콘 밖)인데 sprite.visible이 true로 남아있음 — 완전 숨김 실패")
		return
	if deer._fog_visible:
		_fail("사슴이 시야 밖인데 _fog_visible 플래그가 true로 남아있음")
		return

	# 6) idle(정지) 상태에서는 힌트가 뜨지 않아야 한다(DESIGN.md: 움직이는 경우에만 힌트).
	world.noise_hint_overlay._timer = 0.0
	deer._update_fog_visibility()
	if world.noise_hint_overlay._timer > 0.0:
		_fail("사슴이 idle(정지)인데도 noise_hint_overlay 타이머가 켜짐 — 정지 상태에서도 힌트가 뜨면 안 됨")
		return

	# 7) wander(이동 중) 상태로 바꾸면 숨겨진 채로도 방향 힌트가 떠야 한다.
	deer._state = "wander"
	deer._update_fog_visibility()
	if world.noise_hint_overlay._timer <= 0.0:
		_fail("사슴이 wander(이동 중)이고 시야 밖인데 noise_hint_overlay 타이머가 켜지지 않음")
		return
	await _capture(world, "02_hidden_moving_deer_noise_hint")

	# 8) 사슴을 다시 플레이어 시야 콘 안(등 뒤 대신 앞, 즉 남쪽)으로 옮기면 다시 보여야 한다.
	var visible_spot: Vector2 = room_center + Vector2(0, 40)  # 방 안(남쪽 벽 못 미침), 플레이어가 보는 방향(DOWN) 쪽
	deer.global_position = visible_spot
	deer._update_fog_visibility()
	if not deer.sprite.visible:
		_fail("사슴을 다시 시야 콘 안으로 옮겼는데 sprite.visible이 여전히 false")
		return
	if not deer._fog_visible:
		_fail("사슴을 다시 시야 콘 안으로 옮겼는데 _fog_visible이 여전히 false")
		return
	await _capture(world, "03_deer_visible_again")

	print("QA_INBOX136_CHECK_PASS fog_alpha=", fog_alpha)
	get_tree().quit()
