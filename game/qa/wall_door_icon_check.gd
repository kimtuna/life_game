extends Node
## [DESIGN] INBOX #101 확인용 — 나무벽/나무문/석제벽(#100 레시피) 3종의 새 아이템
## 아이콘이 실제 게임 화면(바닥 드롭 + 인벤토리)에 올바르게 나오는지 스크린샷으로
## 확인한다. obj_icon_check.gd(#91)와 같은 방법: project.godot [autoload]에 이 스크립트를
## 임시로 추가하고 `godot --path .`로 실행한 뒤 되돌린다.

const OUT_DIR := "/tmp/qa101"
const NEW_ITEMS := ["wood_wall", "wood_door", "stone_wall"]


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

	# world.gd의 _physics_process가 매 프레임 camera.global_position을 player 위치로
	# 되돌려버리므로(마우스 추종 로직과 같은 종류의 문제, STATUS.md "다음에 할 것" 필독
	# 항목), 카메라를 수동으로 배치하기 전에 반드시 물리 처리를 꺼야 한다.
	world.set_physics_process(false)

	# 1) 새 아이템 3종을 바닥에 드롭해서 한 화면에 모아 찍는다 (서로 실루엣/색이
	# 구별되는지, 32px 이상으로 보이는지 직접 눈으로 확인하기 위함).
	var drop_center: Vector2 = world.player_sprite.global_position + Vector2(300, -200)
	world.player_sprite.global_position = drop_center + Vector2(1000, 1000)  # 습득 반경 밖
	world.camera.global_position = drop_center
	for j in range(NEW_ITEMS.size()):
		var pos: Vector2 = drop_center + Vector2(j * 60 - 60, 0)
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

	print("QA_WALL_DOOR_ICON_CHECK_PASS")
	get_tree().quit()
