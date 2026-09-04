extends Node
## INBOX #122 확인용 — 격자 배치 시스템(#119~#121)이 추적하는 _grid_occupancy를
## 바탕으로 flood-fill 방 감지가 실제로 동작하는지 확인한다. inbox119~121_check.gd와
## 같은 방법: project.godot [autoload]에 이 스크립트를 임시로 추가하고
## `godot --path .`로 실행한 뒤 되돌린다.

const OUT_DIR := "/tmp/qa122"
const ProcessingTableScene := preload("res://scenes/processing_table/processing_table.tscn")
const CookingTableScene := preload("res://scenes/cooking_table/cooking_table.tscn")


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
	print("QA_INBOX122_CHECK_FAIL: ", msg)
	get_tree().quit()


## 마우스 고정 오프셋 트릭(#119~#121과 동일).
func _point_mouse_at(world, offset: Vector2, target_cell: Vector2i) -> void:
	var target_world: Vector2 = world._grid_to_world_center(target_cell)
	world.camera.global_position = target_world - offset
	await get_tree().process_frame


func _place_wall(world, offset: Vector2, cell: Vector2i) -> void:
	InventoryData._general_slots.fill(null)
	InventoryData.add_item("wood_wall", 1)
	world._select_hotbar(0)
	await _point_mouse_at(world, offset, cell)
	world._try_place_structure()
	await get_tree().process_frame


func _run_checks() -> void:
	var world := get_tree().current_scene
	world.set_physics_process(false)

	InventoryData._general_slots.fill(null)
	InventoryData._save()
	world.player_sprite.global_position = Vector2(300000, 300000)  # 다른 QA/기본 스폰과 격리
	world.camera.global_position = world.player_sprite.global_position
	await get_tree().process_frame

	var mouse_before: Vector2 = world.get_global_mouse_position()
	var offset: Vector2 = mouse_before - world.camera.global_position

	var center_cell: Vector2i = world._world_to_grid(world.player_sprite.global_position) + Vector2i(3, 3)
	var center_world: Vector2 = world._grid_to_world_center(center_cell)

	# --- 1) 벽 4개(동서남북)로 center_cell 하나만 완전히 둘러싼다 ---
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		await _place_wall(world, offset, center_cell + dir)

	var room_id: int = world.get_room_id_at(center_world)
	if room_id == -1:
		_fail("벽 4개로 둘러싼 칸이 방으로 인식되지 않음")
		return
	var category: String = world.get_room_category(room_id)
	if category != "잡실":
		_fail("핵심 오브젝트가 없는데 '잡실'이 아니라 '%s'로 판정됨" % category)
		return
	print("[check1] 빈 방 -> 잡실 확인 OK (room_id=%d)" % room_id)

	# --- 2) 가공대를 그 칸 안에 놓으면 '제작소'로 바뀌는지 ---
	var table := ProcessingTableScene.instantiate()
	table.global_position = center_world
	table.player_ref = world.player_sprite
	table.world_ref = world
	world.add_child(table)
	world._recompute_rooms()
	await get_tree().process_frame

	room_id = world.get_room_id_at(center_world)
	category = world.get_room_category(room_id)
	if category != "제작소":
		_fail("가공대를 넣었는데 '제작소'가 아니라 '%s'로 판정됨" % category)
		return
	print("[check2] 가공대 -> 제작소 확인 OK")

	# --- 3) 조리대를 추가로 넣으면 카테고리가 섞여 '잡실'로 바뀌는지 ---
	var cooking_table := CookingTableScene.instantiate()
	cooking_table.global_position = center_world
	cooking_table.player_ref = world.player_sprite
	cooking_table.world_ref = world
	world.add_child(cooking_table)
	world._recompute_rooms()
	await get_tree().process_frame

	room_id = world.get_room_id_at(center_world)
	category = world.get_room_category(room_id)
	if category != "잡실":
		_fail("가공대+조리대가 섞였는데 '잡실'이 아니라 '%s'로 판정됨" % category)
		return
	print("[check3] 가공대+조리대 혼합 -> 잡실 확인 OK")

	cooking_table.queue_free()
	table.queue_free()
	await get_tree().process_frame

	# --- 4) 벽 하나를 없애면(트인 공간이 되면) 방 자체가 인식 안 되는지 ---
	var removed_cell: Vector2i = center_cell + Vector2i(1, 0)
	var wall_node = world._grid_occupancy.get(removed_cell)
	if wall_node != null:
		wall_node.queue_free()
	world._grid_occupancy.erase(removed_cell)
	world._recompute_rooms()
	await get_tree().process_frame

	room_id = world.get_room_id_at(center_world)
	if room_id != -1:
		_fail("벽 하나를 없앴는데도 여전히 방으로 인식됨 (room_id=%d)" % room_id)
		return
	print("[check4] 벽 하나 제거 -> 방 인식 해제 확인 OK")

	print("QA_INBOX122_CHECK_PASS")
	get_tree().quit()
