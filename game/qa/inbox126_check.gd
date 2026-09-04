extends Node
## INBOX #126 확인용 — 방(Room) 오버레이 토글이 실제로 켜지고, 방 종류별 색(제작소)과
## 잡실/야외 색(회색)이 화면에 서로 다르게 칠해지는지 스크린샷으로 확인한다.
## inbox125_check.gd와 같은 패턴(격리된 좌표에 직접 벽/오브젝트를 놓고 카메라를 옮겨
## 스크린샷)을 그대로 재사용한다.

const OUT_DIR := "/tmp/qa126"


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
	print("QA_INBOX126_CHECK_FAIL: ", msg)
	get_tree().quit()


func _run_checks() -> void:
	var world := get_tree().current_scene
	world.set_physics_process(false)
	world.set_process(false)

	if world.room_overlay == null:
		_fail("world.room_overlay 노드가 없음")
		return
	if world.room_overlay_toggle == null:
		_fail("world.room_overlay_toggle 버튼이 없음")
		return

	# 격리된 자리에 3x3 방 둘레에 벽을 놓고, 그 안에 가공대를 넣어 "제작소"로 판정되게 한다.
	var origin_world: Vector2 = Vector2(-200000, -200000)
	var origin_cell: Vector2i = world._world_to_grid(origin_world)
	for dx in range(4):
		for dy in range(4):
			if dx > 0 and dx < 3 and dy > 0 and dy < 3:
				continue
			var cell: Vector2i = origin_cell + Vector2i(dx, dy)
			world._grid_occupancy[cell] = world._spawn_structure("wood_wall", cell)
	var table := preload("res://scenes/processing_table/processing_table.tscn").instantiate()
	var inner_cell: Vector2i = origin_cell + Vector2i(1, 1)
	table.global_position = world._grid_to_world_center(inner_cell)
	table.player_ref = world.player_sprite
	table.world_ref = world
	world.add_child(table)
	world._recompute_rooms()

	var room_id: int = world.get_room_id_at(world._grid_to_world_center(inner_cell))
	if room_id == -1:
		_fail("방으로 인식되지 않음(room_id=-1)")
		return
	var category: String = world.get_room_category(room_id)
	if category != "제작소":
		_fail("가공대가 있는 방이 '제작소'로 판정되지 않음 — 실제: %s" % category)
		return

	# 오버레이를 켠다 (토글 버튼을 눌렀을 때와 동일한 경로).
	world.room_overlay_toggle.button_pressed = true
	await get_tree().process_frame

	if not world.room_overlay.active:
		_fail("토글을 켰는데 room_overlay.active가 false")
		return
	if not world.room_overlay.visible:
		_fail("토글을 켰는데 room_overlay.visible이 false")
		return

	# 카메라를 방 한가운데(제작소, 색이 있어야 함)에 둔 스크린샷.
	world.player_sprite.global_position = world._grid_to_world_center(inner_cell)
	world.camera.global_position = world.player_sprite.global_position
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_room := get_viewport().get_texture().get_image()
	img_room.save_png("%s/00_overlay_on_workshop_room.png" % OUT_DIR)

	# 카메라를 방 밖 트인 들판(잡실/방 없음 = 회색)으로 옮긴 스크린샷 — 같은 화면에
	# 방(색)과 바깥(회색) 경계가 같이 보이게 절반쯤 걸치는 위치로 잡는다.
	var outside_world: Vector2 = world._grid_to_world_center(origin_cell + Vector2i(2, 8))
	world.player_sprite.global_position = outside_world
	world.camera.global_position = outside_world
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_outside := get_viewport().get_texture().get_image()
	img_outside.save_png("%s/01_overlay_on_outside_gray.png" % OUT_DIR)

	# 토글을 끄면 오버레이가 다시 안 보여야 한다.
	world.room_overlay_toggle.button_pressed = false
	await get_tree().process_frame
	if world.room_overlay.active or world.room_overlay.visible:
		_fail("토글을 껐는데도 room_overlay가 여전히 active/visible")
		return
	await RenderingServer.frame_post_draw
	var img_off := get_viewport().get_texture().get_image()
	img_off.save_png("%s/02_overlay_off.png" % OUT_DIR)

	print("QA_INBOX126_CHECK_PASS")
	get_tree().quit()
