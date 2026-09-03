extends Node
## [BUILD] INBOX #85 확인용 — 사슴을 기본탄으로 사살하면 고기가 드롭되는지, 마취탄
## 생포 흐름은 회귀 없이 그대로 동작하는지 실제 게임을 실행해서 검증한다.
## mining_variety_check.gd(#84)와 같은 방법: project.godot [autoload]에 이 스크립트를
## 임시로 추가하고 `godot --path .`로 실행한 뒤 되돌린다.

const OUT_DIR := "/tmp/qa85"


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


func _spawn_deer(world) -> Node:
	var deer_scene := preload("res://scenes/deer/deer.tscn")
	var deer = deer_scene.instantiate()
	world.add_child(deer)
	deer.player_ref = world.player_sprite
	deer.world_ref = world
	# PICKUP_RADIUS(40)보다 가깝게 스폰해야 사망/포획 시 드롭된 아이템이 자동 습득된다.
	deer.global_position = world.player_sprite.global_position + Vector2(0, 20)
	return deer


func _run_checks() -> void:
	var world := get_tree().current_scene
	var ok := true

	# 1) ITEM_LABELS/ITEM_CATEGORIES에 meat이 육류로 등록됐는지.
	if world.ITEM_LABELS.get("meat", "") != "고기":
		print("FAIL: ITEM_LABELS[meat] != 고기, got: ", world.ITEM_LABELS.get("meat", "<missing>"))
		ok = false
	if world.ITEM_CATEGORIES.get("meat", "") != "육류":
		print("FAIL: ITEM_CATEGORIES[meat] != 육류, got: ", world.ITEM_CATEGORIES.get("meat", "<missing>"))
		ok = false

	# 2) 기본탄으로 사살 -> 고기 드롭 -> 접촉 시 자동 습득.
	var meat_before: int = InventoryData.get_count("meat")
	var deer1 := _spawn_deer(world)
	deer1.take_hit(100, "normal")  # 정확히 체력을 0으로 만들어 _die() 경로를 탄다.
	# take_hit()/_die()/spawn_dropped_item()의 add_child()는 모두 동기 호출이라, 프레임을
	# 기다리기 전(드롭 오브젝트가 스스로를 주워 queue_free()하기 전)에 바로 확인해야 한다.
	var dropped_found := false
	for child in world.get_children():
		if child.has_method("_process") and child.get("item_name") == "meat":
			dropped_found = true
	if not dropped_found:
		print("FAIL: no dropped_item(meat) found near player after lethal shot")
		ok = false
	await get_tree().process_frame
	if is_instance_valid(deer1):
		print("FAIL: deer did not die/free after lethal normal-ammo hit")
		ok = false
	for i in range(5):
		await get_tree().process_frame
	var meat_after: int = InventoryData.get_count("meat")
	if meat_after != meat_before + 1:
		print("FAIL: meat count did not increase by 1, before=", meat_before, " after=", meat_after)
		ok = false
	else:
		print("meat drop OK: ", meat_before, " -> ", meat_after)

	# 3) 스크린샷으로 직접 확인 (사살 직후 화면).
	var deer2 := _spawn_deer(world)
	deer2.take_hit(100, "normal")
	await get_tree().process_frame
	var img := get_tree().root.get_texture().get_image()
	img.save_png(OUT_DIR + "/meat_drop.png")

	# 4) 회귀 확인: 마취탄으로 체력 10% 미만 -> 생포(captured_deer)는 여전히 정상 동작.
	var captured_before: int = InventoryData.get_count("captured_deer")
	var deer3 := _spawn_deer(world)
	deer3.take_hit(95, "normal")  # 체력을 5(=5%)까지 깎아 포획 조건(<=10)을 만든다.
	deer3.take_hit(0, "tranq")  # 데미지 0이라도 resulting(5) <= 10이라 포획 분기를 탄다.
	await get_tree().process_frame
	if is_instance_valid(deer3):
		print("FAIL: deer did not get captured/freed after tranq hit at low health")
		ok = false
	for i in range(5):
		await get_tree().process_frame
	var captured_after: int = InventoryData.get_count("captured_deer")
	if captured_after != captured_before + 1:
		print("FAIL: captured_deer count did not increase, before=", captured_before, " after=", captured_after)
		ok = false
	else:
		print("capture regression OK: ", captured_before, " -> ", captured_after)

	if ok:
		print("QA_DEER_MEAT_CHECK_PASS")
	else:
		print("QA_DEER_MEAT_CHECK_FAIL")
	get_tree().quit()
