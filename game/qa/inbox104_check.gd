extends Node
## [DESIGN] INBOX #104 확인용 — 모래/구리광석 전용 아이템 아이콘(32x32)과 채광 포인트
## 월드 그림(64x64)이 실제 게임 화면(필드/바닥 드롭/인벤토리)에서 기존 돌/철광석/
## 유황광석과 실루엣·색으로 뚜렷이 구별되는지 스크린샷으로 확인한다.
## wall_door_icon_check.gd(#101)/mining_variety5_check.gd(#103)와 같은 방법: project.godot
## [autoload]에 이 스크립트를 임시로 추가하고 `godot --path .`로 실행한 뒤 되돌린다.

const OUT_DIR := "/tmp/qa104"
const NEW_ITEMS := ["sand", "copper_ore"]


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


func _run_checks() -> void:
	var world := get_tree().current_scene
	world.set_physics_process(false)

	# 1) 필드에 모래/구리광석 채광 포인트를 배치해 새 전용 그림(64x64)을 확인.
	var field_center: Vector2 = world.player_sprite.global_position + Vector2(300, -200)
	world.player_sprite.global_position = field_center + Vector2(1000, 1000)
	world.camera.global_position = field_center
	var sand_point = preload("res://scenes/resource_point/mining_point_sand.tscn").instantiate()
	sand_point.player_ref = world.player_sprite
	sand_point.world_ref = world
	world.add_child(sand_point)
	sand_point.global_position = field_center + Vector2(-80, 0)
	var copper_point = preload("res://scenes/resource_point/mining_point_copper.tscn").instantiate()
	copper_point.player_ref = world.player_sprite
	copper_point.world_ref = world
	world.add_child(copper_point)
	copper_point.global_position = field_center + Vector2(80, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img0 := get_viewport().get_texture().get_image()
	img0.save_png("%s/00_field_sand_copper.png" % OUT_DIR)
	sand_point.queue_free()
	copper_point.queue_free()

	# 2) 새 아이템 2종을 바닥에 드롭해서 아이콘(32x32)을 한 화면에 모아 찍는다.
	var drop_center: Vector2 = field_center + Vector2(0, 200)
	world.camera.global_position = drop_center
	for j in range(NEW_ITEMS.size()):
		var pos: Vector2 = drop_center + Vector2(j * 60 - 30, 0)
		world.spawn_dropped_item(NEW_ITEMS[j], 1, pos)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img1 := get_viewport().get_texture().get_image()
	img1.save_png("%s/01_dropped_icons.png" % OUT_DIR)

	# 3) 인벤토리에 새 아이템을 채워 넣고 인벤토리 창을 열어 라벨 표시를 확인.
	for item in NEW_ITEMS:
		InventoryData.add_item(item, 3)
	world._set_inventory_open(true)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img2 := get_viewport().get_texture().get_image()
	img2.save_png("%s/02_inventory.png" % OUT_DIR)

	print("QA_INBOX104_CHECK_PASS")
	get_tree().quit()
