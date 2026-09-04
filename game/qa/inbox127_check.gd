extends Node
## INBOX #127 확인용 — AmmoPanel이 총을 들었을 때만 보이고 다른 도구/빈손이면
## 숨겨지는지, InventoryPanel이 완전히 제거됐는지, 남은 HUD 레이아웃이 깨지지
## 않았는지 스크린샷으로 확인한다. inbox126_check.gd와 같은 부팅 패턴 재사용.

const OUT_DIR := "/tmp/qa127"


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


func _fail(msg: String) -> void:
	print("QA_INBOX127_CHECK_FAIL: ", msg)
	get_tree().quit()


func _run_checks() -> void:
	var world := get_tree().current_scene
	world.set_physics_process(false)
	world.set_process(false)

	# 1) InventoryPanel 노드 자체가 완전히 없어졌는지 확인.
	if world.has_node("UI/HUD/InventoryPanel"):
		_fail("UI/HUD/InventoryPanel 노드가 아직 남아 있음")
		return

	# 2) 월드 진입 직후(슬롯0=총이 기본 지급되어 자동 선택됨)에는 AmmoPanel이 보여야 한다.
	if not world.ammo_panel.visible:
		_fail("총을 든 시작 상태인데 ammo_panel이 안 보임")
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_gun := get_viewport().get_texture().get_image()
	img_gun.save_png("%s/00_gun_held_ammo_visible.png" % OUT_DIR)

	# 3) 도끼(핫바 2번, index 1)로 바꾸면 AmmoPanel이 숨겨져야 한다.
	world._select_hotbar(1)
	await get_tree().process_frame
	if world.ammo_panel.visible:
		_fail("도끼를 들었는데 ammo_panel이 계속 보임")
		return
	await RenderingServer.frame_post_draw
	var img_axe := get_viewport().get_texture().get_image()
	img_axe.save_png("%s/01_axe_held_ammo_hidden.png" % OUT_DIR)

	# 4) 빈 슬롯(index 8, 아무 도구도 없는 핫바 끝칸)을 선택하면 빈손 상태 — 역시 숨겨져야 한다.
	world._select_hotbar(8)
	await get_tree().process_frame
	if world.ammo_panel.visible:
		_fail("빈손 상태인데 ammo_panel이 계속 보임")
		return
	if world._held_tool != "":
		_fail("index 8 슬롯이 비어있지 않음 — 테스트 가정이 깨짐(held_tool=%s)" % world._held_tool)
		return
	await RenderingServer.frame_post_draw
	var img_empty := get_viewport().get_texture().get_image()
	img_empty.save_png("%s/02_empty_hand_ammo_hidden.png" % OUT_DIR)

	# 5) 다시 총으로 돌아오면 재표시돼야 한다.
	world._select_hotbar(0)
	await get_tree().process_frame
	if not world.ammo_panel.visible:
		_fail("다시 총을 들었는데 ammo_panel이 안 보임")
		return
	await RenderingServer.frame_post_draw
	var img_back := get_viewport().get_texture().get_image()
	img_back.save_png("%s/03_gun_again_ammo_visible.png" % OUT_DIR)

	print("QA_INBOX127_CHECK_PASS")
	get_tree().quit()
