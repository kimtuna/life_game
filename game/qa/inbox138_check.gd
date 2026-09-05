extends Node
## INBOX #138 검증 — 1칸짜리 최소 방(벽 4개)에 가공대를 놓아도 벽 4칸이 항상
## 오브젝트보다 앞에 그려지는지 확인한다. `inbox122_check.gd`의 부팅/배치 패턴을 재사용.
##
## 판정 방법: "가공대 없이 벽만 있는" 기준 스크린샷과 "벽 안에 가공대를 놓은" 스크린샷을
## 같은 카메라/좌표로 찍어서, 벽 4칸 각각의 중심 픽셀 색이 두 스크린샷에서 동일한지
## 비교한다 — 색이 같다면 그 위치는 여전히 벽이 그려지고 있다는 뜻이고(가공대 스프라이트에
## 덮이지 않음), 하나라도 색이 달라지면 그 벽이 가공대에 가려졌다는 뜻이므로 실패로 본다.

const OUT_DIR := "/tmp/qa138"
const ProcessingTableScene := preload("res://scenes/processing_table/processing_table.tscn")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await _boot_to_world()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await _run()


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


var _mouse_offset := Vector2.ZERO


func _capture_mouse_offset(world) -> void:
	Input.warp_mouse(get_viewport().get_visible_rect().size / 2)
	await get_tree().process_frame
	var mouse_before: Vector2 = world.get_global_mouse_position()
	_mouse_offset = mouse_before - world.camera.global_position


func _point_mouse_at(world, target_cell: Vector2i) -> void:
	var target_world: Vector2 = world._grid_to_world_center(target_cell)
	world.camera.global_position = target_world - _mouse_offset
	await get_tree().process_frame


func _place_wall(world, cell: Vector2i) -> void:
	InventoryData._general_slots.fill(null)
	InventoryData.add_item("wood_wall", 1)
	world._select_hotbar(0)
	await _point_mouse_at(world, cell)
	world._try_place_structure()
	await get_tree().process_frame


func _run() -> void:
	var world := get_tree().current_scene
	world.set_physics_process(false)

	InventoryData._general_slots.fill(null)
	InventoryData._save()
	world.player_sprite.global_position = Vector2(2000, 2000)
	world.camera.global_position = world.player_sprite.global_position

	var center_cell: Vector2i = world._world_to_grid(world.player_sprite.global_position) + Vector2i(3, 3)
	var center_world: Vector2 = world._grid_to_world_center(center_cell)
	await _capture_mouse_offset(world)

	var wall_offsets := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for dir in wall_offsets:
		await _place_wall(world, center_cell + dir)

	world.player_sprite.global_position = center_world
	world.camera.global_position = center_world
	await get_tree().process_frame
	await get_tree().process_frame
	var img_walls_only := get_viewport().get_texture().get_image()
	img_walls_only.save_png(OUT_DIR + "/walls_only.png")

	var table: Node2D = ProcessingTableScene.instantiate()
	table.global_position = center_world
	table.player_ref = world.player_sprite
	table.world_ref = world
	world.ysort_layer.add_child(table)
	await get_tree().process_frame
	await get_tree().process_frame
	var img_with_table := get_viewport().get_texture().get_image()
	img_with_table.save_png(OUT_DIR + "/room_with_table.png")

	# 화면 좌표 == 월드 좌표(카메라 zoom 1)이므로, 벽 칸 중심의 월드 오프셋(±32px)을
	# 그대로 뷰포트 중심 기준 화면 오프셋으로 써서 벽 4칸 각각의 중심 픽셀을 비교한다.
	var viewport_center: Vector2 = get_viewport().get_visible_rect().size / 2
	var all_pass := true
	for dir in wall_offsets:
		var screen_pos: Vector2i = Vector2i(viewport_center + Vector2(dir) * world.BUILD_GRID_SIZE)
		var before: Color = img_walls_only.get_pixel(screen_pos.x, screen_pos.y)
		var after: Color = img_with_table.get_pixel(screen_pos.x, screen_pos.y)
		var ok: bool = before.is_equal_approx(after)
		all_pass = all_pass and ok
		print("wall dir=", dir, " screen=", screen_pos, " before=", before, " after=", after, " match=", ok)

	if all_pass:
		print("QA_INBOX138_CHECK_PASS")
	else:
		print("QA_INBOX138_CHECK_FAIL")
	get_tree().quit()
