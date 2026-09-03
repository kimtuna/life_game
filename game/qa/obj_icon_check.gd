extends Node
## [DESIGN] INBOX #91 확인용 — 가공대/제련로/조리대/조리용 화로 4개의 새 월드 그림과
## 새 아이템 아이콘 8종(판자/석재/철/숯/화약/탄약/밥/익힌고기)이 실제 게임 화면에
## 올바르게 나오는지 스크린샷으로 확인한다. processing_table_check.gd(#87)와 같은 방법:
## project.godot [autoload]에 이 스크립트를 임시로 추가하고 `godot --path .`로 실행한 뒤
## 되돌린다.

const OUT_DIR := "/tmp/qa91"


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
	var ok := true

	var scripts := {
		"processing_table": load("res://scenes/processing_table/processing_table.gd"),
		"smelting_furnace": load("res://scenes/smelting_furnace/smelting_furnace.gd"),
		"cooking_table": load("res://scenes/cooking_table/cooking_table.gd"),
		"cooking_stove": load("res://scenes/cooking_stove/cooking_stove.gd"),
	}
	var found := {}
	for child in world.get_children():
		for key in scripts.keys():
			if child.get_script() == scripts[key]:
				found[key] = child

	for key in scripts.keys():
		if not found.has(key):
			print("FAIL: ", key, " not spawned in world")
			ok = false
	if not ok:
		print("QA_OBJ_ICON_CHECK_FAIL")
		get_tree().quit()
		return

	# 1) 오브젝트 4개를 각각 카메라 중앙에 놓고 스크린샷 (실제 스프라이트가 화면에
	# 정상적으로 그려지는지, 서로 실루엣이 구별되는지 직접 눈으로 확인하기 위함).
	var i := 0
	for key in ["processing_table", "smelting_furnace", "cooking_table", "cooking_stove"]:
		var node: Node2D = found[key]
		world.player_sprite.global_position = node.global_position + Vector2(0, 140)
		world.camera.global_position = node.global_position
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%02d_%s.png" % [OUT_DIR, i, key])
		i += 1

	# 2) 새 아이템 아이콘 8종을 바닥에 드롭해서 한 화면에 모아 찍는다.
	var drop_center: Vector2 = found["processing_table"].global_position + Vector2(400, -300)
	var new_items := ["plank", "stone_block", "iron", "charcoal", "gunpowder", "ammo", "cooked_rice", "cooked_meat"]
	for j in range(new_items.size()):
		var pos: Vector2 = drop_center + Vector2((j % 4) * 60 - 90, (j / 4) * 60 - 30)
		world.spawn_dropped_item(new_items[j], 1, pos)
	await get_tree().process_frame
	await get_tree().process_frame
	world.player_sprite.global_position = drop_center + Vector2(1000, 1000)  # 습득 반경 밖으로 치워 안 주워지게
	world.camera.global_position = drop_center
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img2 := get_viewport().get_texture().get_image()
	img2.save_png("%s/04_dropped_icons.png" % OUT_DIR)

	# 3) 인벤토리에 새 아이템을 직접 채워 넣고 인벤토리 창을 열어 텍스트 표시(아이콘은
	# 인벤토리 UI에 없다는 기존 구조 그대로, 라벨만 확인)도 회귀 없는지 스크린샷.
	for item in new_items:
		InventoryData.add_item(item, 3)
	world._set_inventory_open(true)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img3 := get_viewport().get_texture().get_image()
	img3.save_png("%s/05_inventory.png" % OUT_DIR)

	print("QA_OBJ_ICON_CHECK_PASS")
	get_tree().quit()
