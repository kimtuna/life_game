extends Node
## [BUILD] INBOX #103 확인용 — 채광 포인트 종류가 돌/철광석/유황광석 3종에서
## 모래/구리광석을 더한 5종으로 늘어난 뒤, 실제로 섞여 스폰되고 각각 캐면 올바른
## 아이템이 드롭되는지 실제 게임을 실행해서 검증한다 (mining_variety_check.gd의 #103
## 확장판 — 3종 버전은 그대로 남겨두고 새 파일로 분리).

const OUT_DIR := "/tmp/qa103"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await _boot_to_world()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_run_checks()


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

	# 1) 새 아이템 2종이 ITEM_LABELS/ITEM_CATEGORIES에 원재료로 등록됐는지.
	for key in ["sand", "copper_ore"]:
		if world.ITEM_LABELS.get(key, "") == "":
			print("FAIL: ITEM_LABELS missing ", key)
			ok = false
		if world.ITEM_CATEGORIES.get(key, "") != "원재료":
			print("FAIL: ITEM_CATEGORIES[", key, "] != 원재료, got: ", world.ITEM_CATEGORIES.get(key, "<missing>"))
			ok = false

	# 2) _pick_mining_point_scene()을 2000번 굴려서 5종이 전부 나오는지.
	var counts := {"stone": 0, "iron_ore": 0, "sulfur_ore": 0, "sand": 0, "copper_ore": 0}
	for i in range(2000):
		var scene: PackedScene = world._pick_mining_point_scene()
		var inst = scene.instantiate()
		counts[inst.item_name] += 1
		inst.free()
	print("scene pick distribution over 2000 rolls: ", counts)
	for key in counts.keys():
		if counts[key] == 0:
			print("FAIL: ", key, " never appeared in 2000 rolls")
			ok = false

	# 3) 5종을 각각 직접 배치해서 캐봤을 때 올바른 아이템이 정확히 드롭/습득되는지.
	for entry in [
		{"scene": preload("res://scenes/resource_point/mining_point_stone.tscn"), "item": "stone"},
		{"scene": preload("res://scenes/resource_point/mining_point.tscn"), "item": "iron_ore"},
		{"scene": preload("res://scenes/resource_point/mining_point_sulfur.tscn"), "item": "sulfur_ore"},
		{"scene": preload("res://scenes/resource_point/mining_point_sand.tscn"), "item": "sand"},
		{"scene": preload("res://scenes/resource_point/mining_point_copper.tscn"), "item": "copper_ore"},
	]:
		var point = entry["scene"].instantiate()
		point.player_ref = world.player_sprite
		point.world_ref = world
		world.add_child(point)
		point.global_position = world.player_sprite.global_position
		var before: int = InventoryData.get_count(entry["item"])
		point._harvest()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var after: int = InventoryData.get_count(entry["item"])
		if after != before + point.item_amount:
			print("FAIL: harvesting ", entry["item"], " did not add correct amount, before=", before, " after=", after)
			ok = false
		else:
			print("harvest OK: ", entry["item"], " ", before, " -> ", after)
		point.queue_free()

	# 4) 모래/구리광석이 화면에서 돌/철광석과 색으로 구별되는지 스크린샷으로 확인.
	for entry in [
		{"scene": preload("res://scenes/resource_point/mining_point_sand.tscn"), "name": "sand"},
		{"scene": preload("res://scenes/resource_point/mining_point_copper.tscn"), "name": "copper_ore"},
	]:
		var point = entry["scene"].instantiate()
		point.player_ref = world.player_sprite
		point.world_ref = world
		world.add_child(point)
		point.global_position = world.player_sprite.global_position + Vector2(0, -120)
		await get_tree().process_frame
		await get_tree().process_frame
		var img := get_tree().root.get_texture().get_image()
		img.save_png(OUT_DIR + "/field_" + entry["name"] + ".png")
		point.queue_free()

	if ok:
		print("QA_MINING_VARIETY5_CHECK_PASS")
	else:
		print("QA_MINING_VARIETY5_CHECK_FAIL")
	get_tree().quit()
