extends Node
## [BUILD] INBOX #89 확인용 — 가공대 RECIPES에 추가한 화약/탄약 레시피가 실제로
## 재료를 소모하고 결과물을 지급하는지 실제 게임을 실행해서 검증한다.
## processing_table_check.gd(#87)와 같은 방법: project.godot [autoload]에 이 스크립트를
## 임시로 추가하고 `godot --path .`로 실행한 뒤 되돌린다.

const OUT_DIR := "/tmp/qa89"


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

	# 1) 새 아이템(화약/탄약)이 ITEM_LABELS/ITEM_CATEGORIES에 등록됐는지.
	if world.ITEM_LABELS.get("gunpowder", "") == "":
		print("FAIL: ITEM_LABELS missing gunpowder")
		ok = false
	if world.ITEM_CATEGORIES.get("gunpowder", "") != "가공물":
		print("FAIL: ITEM_CATEGORIES[gunpowder] != 가공물, got: ", world.ITEM_CATEGORIES.get("gunpowder", "<missing>"))
		ok = false
	if world.ITEM_LABELS.get("ammo", "") == "":
		print("FAIL: ITEM_LABELS missing ammo")
		ok = false
	if world.ITEM_CATEGORIES.get("ammo", "") != "완성품":
		print("FAIL: ITEM_CATEGORIES[ammo] != 완성품, got: ", world.ITEM_CATEGORIES.get("ammo", "<missing>"))
		ok = false

	# 2) 가공대가 실제로 필드에 스폰됐는지, RECIPES에 화약/탄약 레시피가 들어있는지.
	var table = null
	var table_script := load("res://scenes/processing_table/processing_table.gd")
	for child in world.get_children():
		if child.get_script() == table_script:
			table = child
			break
	if table == null:
		print("FAIL: ProcessingTable not spawned in world")
		print("QA_GUNPOWDER_AMMO_CHECK_FAIL")
		get_tree().quit()
		return
	if table.RECIPES.size() != 4:
		print("FAIL: expected 4 recipes on processing table, got ", table.RECIPES.size())
		ok = false
	var gunpowder_recipe: Dictionary = table.RECIPES[2]
	var ammo_recipe: Dictionary = table.RECIPES[3]
	print("gunpowder recipe: ", gunpowder_recipe)
	print("ammo recipe: ", ammo_recipe)

	# 3) 플레이어를 가공대 근처로 옮기고 좌클릭으로 제작 창을 연다.
	world.player_sprite.global_position = table.global_position
	await get_tree().process_frame
	await get_tree().process_frame
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	table._unhandled_input(click)
	await get_tree().process_frame
	await get_tree().process_frame
	if not world.is_crafting_open():
		print("FAIL: crafting window did not open after click")
		ok = false
	var img_open := get_tree().root.get_texture().get_image()
	img_open.save_png(OUT_DIR + "/01_window_open.png")

	# 4) 유황광석+숯 -> 화약 1개 검증.
	var sulfur_before: int = InventoryData.get_count("sulfur_ore")
	var charcoal_before: int = InventoryData.get_count("charcoal")
	var gunpowder_before: int = InventoryData.get_count("gunpowder")
	InventoryData.add_item("sulfur_ore", 3)
	InventoryData.add_item("charcoal", 3)
	await get_tree().process_frame
	await get_tree().process_frame
	var img_materials := get_tree().root.get_texture().get_image()
	img_materials.save_png(OUT_DIR + "/02_materials_ready.png")

	world._on_craft_pressed(gunpowder_recipe)
	await get_tree().process_frame
	await get_tree().process_frame

	var sulfur_after: int = InventoryData.get_count("sulfur_ore")
	var charcoal_after: int = InventoryData.get_count("charcoal")
	var gunpowder_after: int = InventoryData.get_count("gunpowder")
	print("sulfur_ore: ", sulfur_before + 3, " -> ", sulfur_after, " (expect -1)")
	print("charcoal: ", charcoal_before + 3, " -> ", charcoal_after, " (expect -1)")
	print("gunpowder: ", gunpowder_before, " -> ", gunpowder_after, " (expect +1)")
	if sulfur_after != sulfur_before + 3 - 1:
		print("FAIL: sulfur_ore not consumed correctly")
		ok = false
	if charcoal_after != charcoal_before + 3 - 1:
		print("FAIL: charcoal not consumed correctly")
		ok = false
	if gunpowder_after != gunpowder_before + 1:
		print("FAIL: gunpowder not granted correctly")
		ok = false

	# 5) 화약+철 -> 탄약 3개 검증.
	var iron_before: int = InventoryData.get_count("iron")
	var ammo_before: int = InventoryData.get_count("ammo")
	InventoryData.add_item("iron", 3)
	await get_tree().process_frame

	world._on_craft_pressed(ammo_recipe)
	await get_tree().process_frame
	await get_tree().process_frame
	var img_crafted := get_tree().root.get_texture().get_image()
	img_crafted.save_png(OUT_DIR + "/03_after_craft.png")

	var iron_after: int = InventoryData.get_count("iron")
	var gunpowder_after2: int = InventoryData.get_count("gunpowder")
	var ammo_after: int = InventoryData.get_count("ammo")
	print("iron: ", iron_before + 3, " -> ", iron_after, " (expect -1)")
	print("gunpowder: ", gunpowder_after, " -> ", gunpowder_after2, " (expect -1)")
	print("ammo: ", ammo_before, " -> ", ammo_after, " (expect +3)")
	if iron_after != iron_before + 3 - 1:
		print("FAIL: iron not consumed correctly")
		ok = false
	if gunpowder_after2 != gunpowder_after - 1:
		print("FAIL: gunpowder not consumed correctly")
		ok = false
	if ammo_after != ammo_before + 3:
		print("FAIL: ammo not granted correctly (expect +3)")
		ok = false

	# 6) 재료 부족 상태에서 제작을 시도해도(방어적 재확인) 아무 일도 없는지.
	InventoryData.remove_item("sulfur_ore", InventoryData.get_count("sulfur_ore"))
	world._on_craft_pressed(gunpowder_recipe)
	await get_tree().process_frame
	if InventoryData.get_count("gunpowder") != gunpowder_after2:
		print("FAIL: crafting succeeded despite insufficient materials")
		ok = false
	else:
		print("insufficient-materials guard OK")

	# 7) 총 재장전(R)이 여전히 탄약과 무관하게 무한 재장전인지(회귀 확인, 범위 밖 유지).
	if world.has_method("_reload_current_gun"):
		print("note: gun reload method present, not modified (out of scope per INBOX #89)")

	if ok:
		print("QA_GUNPOWDER_AMMO_CHECK_PASS")
	else:
		print("QA_GUNPOWDER_AMMO_CHECK_FAIL")
	get_tree().quit()
