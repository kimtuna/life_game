extends Node
## [DESIGN] INBOX #111 확인용 — #108~#110 완성품 11종 + 사료 + 급수 장치(총 13개) 새
## 아이템 아이콘이 실제 게임 화면(바닥 드롭 + 인벤토리)에 올바르게 나오는지 스크린샷으로
## 확인한다. wall_door_icon_check.gd(#101)와 같은 방법.

const OUT_DIR := "/tmp/qa111"
const NEW_ITEMS := [
	"steel_pickaxe", "steel_axe", "steel_fishing_rod",
	"steel_wall", "steel_door", "steel_chest", "window", "steel_armor",
	"battery", "lamp", "generator", "feed", "water_pump",
]


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

	# 이전 바퀴들의 QA로 슬롯 0 인벤토리가 가득 찼을 수 있으므로 먼저 비운다.
	InventoryData._general_slots.fill(null)
	InventoryData._save()

	# 1) 13개 아이템을 5열 그리드로 바닥에 드롭해서 한 화면에 모아 찍는다.
	var drop_center: Vector2 = world.player_sprite.global_position + Vector2(-3000, -3000)
	world.player_sprite.global_position = drop_center + Vector2(2000, 2000)  # 습득 반경 밖
	world.camera.global_position = drop_center
	world.camera.zoom = Vector2(0.6, 0.6)
	var cols := 5
	for j in range(NEW_ITEMS.size()):
		var col := j % cols
		var row := j / cols
		var pos: Vector2 = drop_center + Vector2((col - 2) * 90, (row - 1) * 90)
		world.spawn_dropped_item(NEW_ITEMS[j], 1, pos)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/00_dropped_icons.png" % OUT_DIR)

	world.camera.zoom = Vector2(1.0, 1.0)

	# 2) 인벤토리에 새 아이템을 채워 넣고 인벤토리 창을 열어 라벨 표시가 정상인지 확인.
	for item in NEW_ITEMS:
		InventoryData.add_item(item, 3)
	world._set_inventory_open(true)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img2 := get_viewport().get_texture().get_image()
	img2.save_png("%s/01_inventory.png" % OUT_DIR)

	print("QA_INBOX111_CHECK_PASS")
	get_tree().quit()
