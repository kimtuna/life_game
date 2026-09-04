extends Node
## [BUILD] INBOX #116 확인용 — 테스트용 저장 상자(storage_chest.gd)가 unlimited=true일 때
## 슬롯 개수(SLOT_COUNT=20) 이상으로 아이템 종류를 넣어도 전부 담기는지, 그리고 unlimited가
## 꺼진 일반 상자는 여전히 고정 SLOT_COUNT로 동작하는지 확인한다.
## starter_chest_check.gd(#97)와 같은 방법: project.godot [autoload]에 이 스크립트를
## 임시로 추가하고 `godot --path .`로 실행한 뒤 되돌린다.

const OUT_DIR := "/tmp/qa116"
const StorageChestScene := preload("res://scenes/storage_chest/storage_chest.tscn")


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


func _find_by_script(world: Node, script_path: String) -> Node:
	var target_script := load(script_path)
	for child in world.get_children():
		if child.get_script() == target_script:
			return child
	return null


func _run_checks() -> void:
	var world := get_tree().current_scene
	var ok := true

	# 1) world.gd가 스폰한 테스트 상자가 unlimited=true인지 확인.
	var chest := _find_by_script(world, "res://scenes/storage_chest/storage_chest.gd")
	if chest == null:
		print("FAIL: StorageChest not spawned in world")
		print("QA_UNLIMITED_CHEST_CHECK_FAIL")
		get_tree().quit()
		return
	if not chest.unlimited:
		print("FAIL: test chest unlimited flag is false")
		ok = false
	else:
		print("test chest unlimited=true OK")

	# 2) SLOT_COUNT(20)보다 훨씬 많은 아이템 종류(가상 아이템 60종)를 채워서 전부
	# 슬롯에 담기는지 확인 — 아직 실제 아이템 종류가 20개를 안 넘는 상태에서도(#117 전)
	# 미래에 계속 늘어나는 상황을 시뮬레이션한다.
	var before_slot_count: int = chest.get_slots().size()
	var fake_items := []
	for i in range(60):
		fake_items.append("qa116_fake_item_%d" % i)
	for item_name in fake_items:
		chest.add_item(item_name, 999)
	var slots_after: Array = chest.get_slots()
	var by_item := {}
	for s in slots_after:
		if s != null:
			by_item[s["item"]] = int(s["count"])
	var missing := []
	for item_name in fake_items:
		if not by_item.has(item_name) or by_item[item_name] != 999:
			missing.append(item_name)
	if missing.size() > 0:
		print("FAIL: unlimited chest lost items when exceeding fixed slot count: ", missing)
		ok = false
	else:
		print("unlimited chest holds all ", fake_items.size(), " extra item types OK (slots ", before_slot_count, " -> ", slots_after.size(), ")")

	# 3) 상자 UI를 열어 슬롯이 많아진 상태에서도 스크롤 컨테이너로 정상적으로 보이는지
	# 스크린샷으로 확인.
	world.player_sprite.global_position = chest.global_position
	await get_tree().process_frame
	await get_tree().process_frame
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	chest._unhandled_input(click)
	await get_tree().process_frame
	await get_tree().process_frame
	if not world.is_storage_open():
		print("FAIL: storage window did not open with many slots")
		ok = false
	else:
		var img_open := get_tree().root.get_texture().get_image()
		img_open.save_png(OUT_DIR + "/01_chest_open_many_slots.png")
	var esc := InputEventKey.new()
	esc.pressed = true
	esc.keycode = KEY_ESCAPE
	world._unhandled_input(esc)
	await get_tree().process_frame

	# 4) unlimited=false(일반 게임용 상자, 옵션을 껐을 때)는 여전히 SLOT_COUNT(20)로
	# 고정돼 있어서 21번째 새 아이템 종류는 못 들어가는지 별도 인스턴스로 확인
	# (기존 동작을 깨지 않았는지 회귀 검증).
	var normal_chest := StorageChestScene.instantiate()
	# unlimited 기본값 false 그대로 둔다.
	world.add_child(normal_chest)
	await get_tree().process_frame
	for i in range(20):
		normal_chest.add_item("qa116_normal_%d" % i, 1)
	normal_chest.add_item("qa116_normal_overflow", 1)
	var normal_slots: Array = normal_chest.get_slots()
	var normal_has_overflow := false
	for s in normal_slots:
		if s != null and s["item"] == "qa116_normal_overflow":
			normal_has_overflow = true
	if normal_slots.size() != 20:
		print("FAIL: normal (unlimited=false) chest slot array size changed, expected 20 got ", normal_slots.size())
		ok = false
	elif normal_has_overflow:
		print("FAIL: normal (unlimited=false) chest unexpectedly accepted item beyond fixed SLOT_COUNT")
		ok = false
	else:
		print("normal (unlimited=false) chest still fixed at 20 slots OK (regression check)")
	normal_chest.queue_free()

	if ok:
		print("QA_UNLIMITED_CHEST_CHECK_PASS")
	else:
		print("QA_UNLIMITED_CHEST_CHECK_FAIL")
	get_tree().quit()
