extends Node
## [BUILD] INBOX #84 확인용 — 채광 포인트 종류(돌/철광석/유황광석)가 실제로 섞여
## 스폰되고, 각각 캐면 올바른 아이템이 드롭되는지 실제 게임을 실행해서 검증한다.
## item_category_check.gd(#83)와 같은 방법: project.godot [autoload]에 이 스크립트를
## 임시로 추가하고 `godot --path .`로 실행한 뒤 되돌린다.

const OUT_DIR := "/tmp/qa84"


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

	# 1) 새 아이템이 ITEM_LABELS/ITEM_CATEGORIES에 원재료로 등록됐는지.
	for key in ["stone", "sulfur_ore"]:
		if world.ITEM_LABELS.get(key, "") == "":
			print("FAIL: ITEM_LABELS missing ", key)
			ok = false
		if world.ITEM_CATEGORIES.get(key, "") != "원재료":
			print("FAIL: ITEM_CATEGORIES[", key, "] != 원재료, got: ", world.ITEM_CATEGORIES.get(key, "<missing>"))
			ok = false

	# 2) _pick_mining_point_scene()을 1000번 굴려서 세 종류가 모두 나오고, 대략
	#    돌(60%) > 철광석(30%) > 유황광석(10%) 순서가 유지되는지 (허용 오차 넉넉히).
	var counts := {"stone": 0, "iron_ore": 0, "sulfur_ore": 0}
	for i in range(1000):
		var scene: PackedScene = world._pick_mining_point_scene()
		var inst = scene.instantiate()
		counts[inst.item_name] += 1
		inst.free()
	print("scene pick distribution over 1000 rolls: ", counts)
	if counts["stone"] == 0 or counts["iron_ore"] == 0 or counts["sulfur_ore"] == 0:
		print("FAIL: not all three mining point types appeared in 1000 rolls")
		ok = false
	if not (counts["stone"] > counts["iron_ore"] and counts["iron_ore"] > counts["sulfur_ore"]):
		print("FAIL: distribution order not stone > iron_ore > sulfur_ore: ", counts)
		ok = false

	# 3) 실제 스폰된 필드에도 여러 종류가 섞여 있는지 (RESOURCE_POINT_COUNT=5개 중).
	var spawned_kinds := {}
	var one_of_each := {}
	for child in world.get_children():
		if child.has_method("_harvest") and child.get("use_kind") == "mining" and child.item_name != "wood":
			spawned_kinds[child.item_name] = spawned_kinds.get(child.item_name, 0) + 1
			one_of_each[child.item_name] = child
	print("spawned mining point kinds in field: ", spawned_kinds)

	# 3b) 색 구분이 실제로 눈에 보이는지 확인하기 위해 스폰된 돌/유황광석 포인트 근처로
	#     플레이어를 옮겨 스크린샷을 찍는다 (있으면).
	for kind in ["stone", "sulfur_ore"]:
		if one_of_each.has(kind):
			world.player_sprite.global_position = one_of_each[kind].global_position + Vector2(0, 90)
			await get_tree().process_frame
			await get_tree().process_frame
			var img2 := get_tree().root.get_texture().get_image()
			img2.save_png(OUT_DIR + "/field_" + kind + ".png")

	# 4) 세 종류를 각각 직접 배치해서 캐봤을 때 올바른 아이템이 정확히 드롭/습득되는지.
	for entry in [
		{"scene": preload("res://scenes/resource_point/mining_point_stone.tscn"), "item": "stone"},
		{"scene": preload("res://scenes/resource_point/mining_point.tscn"), "item": "iron_ore"},
		{"scene": preload("res://scenes/resource_point/mining_point_sulfur.tscn"), "item": "sulfur_ore"},
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

	var img := get_tree().root.get_texture().get_image()
	img.save_png(OUT_DIR + "/mining_variety.png")

	if ok:
		print("QA_MINING_VARIETY_CHECK_PASS")
	else:
		print("QA_MINING_VARIETY_CHECK_FAIL")
	get_tree().quit()
