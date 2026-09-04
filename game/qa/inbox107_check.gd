extends Node
## [DESIGN] INBOX #107 확인용 — 강철/유리/구리/못/경첩/톱니바퀴/구리선/유리병 8종의
## 새 아이템 아이콘이 실제 게임 화면(바닥 드롭 + 인벤토리)에 올바르게 나오는지 스크린샷으로
## 확인한다. wall_door_icon_check.gd(#101)와 같은 방법: project.godot [autoload]에 이
## 스크립트를 임시로 추가하고 `godot --path .`로 실행한 뒤 되돌린다.

const OUT_DIR := "/tmp/qa107"
const NEW_ITEMS := ["steel", "glass", "copper", "nail", "hinge", "gear", "copper_wire", "glass_bottle"]


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

	# 1) 새 아이템 8종을 바닥에 두 줄로 드롭해서 한 화면에 모아 찍는다 (서로 실루엣/색이
	# 구별되는지, 32px 이상으로 보이는지 직접 눈으로 확인하기 위함).
	var drop_center: Vector2 = world.player_sprite.global_position + Vector2(300, -200)
	world.player_sprite.global_position = drop_center + Vector2(1000, 1000)  # 습득 반경 밖
	world.camera.global_position = drop_center
	for j in range(NEW_ITEMS.size()):
		var col: int = j % 4
		var row: int = j / 4
		var pos: Vector2 = drop_center + Vector2(col * 70 - 105, row * 70 - 35)
		world.spawn_dropped_item(NEW_ITEMS[j], 1, pos)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/00_dropped_icons.png" % OUT_DIR)

	# 2) 인벤토리에 새 아이템을 채워 넣고 인벤토리 창을 열어 라벨 표시가 정상인지 확인.
	for item in NEW_ITEMS:
		InventoryData.add_item(item, 3)
	world._set_inventory_open(true)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img2 := get_viewport().get_texture().get_image()
	img2.save_png("%s/01_inventory.png" % OUT_DIR)

	print("QA_INBOX107_CHECK_PASS")
	get_tree().quit()
