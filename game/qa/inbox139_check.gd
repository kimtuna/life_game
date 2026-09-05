extends Node
## INBOX #139 확인용 — noise_hint_overlay.gd(#136)가 만드는 "숨은 동물 방향 힌트"가
## 화면 하단 핫바(UI/HUD/HotbarBar)와 겹치던 버그(#137 QA 전체 스윕에서 발견)를
## 고쳤는지 확인한다. inbox136_check.gd와 같은 패턴(플레이 → 슬롯 → 확정 → 싱글플레이로
## 부팅, world._aim_direction 강제 조작)을 재사용한다.

const OUT_DIR := "/tmp/qa139"


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
	print("QA_INBOX139_CHECK_FAIL: ", msg)
	get_tree().quit()


func _capture(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, name])


func _run_checks() -> void:
	var world := get_tree().current_scene
	world.set_physics_process(false)
	world.set_process(true)  # noise_hint_overlay가 계속 redraw 하도록 켜둠

	var overlay: Control = world.noise_hint_overlay
	var hotbar: Control = world.hotbar_bar
	if hotbar == null:
		_fail("world.hotbar_bar가 null — HotbarBar 노드를 찾지 못함")
		return

	# 재현 조건 그대로: 플레이어 남쪽(핫바가 있는 화면 하단 방향)에 숨은 동물이 있다고
	# 신호를 보낸다 (버그 리포트가 지목한, 핫바와 겹치는 확률이 가장 높은 방향).
	world.player_sprite.global_position = Vector2(-4000, -4000)
	overlay.notify(world.player_sprite.global_position + Vector2(0, 400), world.player_sprite.global_position)
	if overlay._timer <= 0.0:
		_fail("notify() 직후 타이머가 켜지지 않음 — 힌트 자체가 표시되지 않음")
		return

	var hotbar_rect: Rect2 = hotbar.get_global_rect()
	var point: Vector2 = overlay._compute_point()
	# 힌트 삼각형이 point에서 최대 ICON_LENGTH만큼 튀어나올 수 있으니, 핫바 사각형을
	# 그만큼 넓혀서 "실제로 겹치는가"를 판정한다(핫바 자체의 여유(clearance)는 이미
	# _compute_point() 안에서 반영되므로 여기서는 순수 기하학적 겹침만 본다).
	var hotbar_padded: Rect2 = hotbar_rect.grow(overlay.ICON_LENGTH)
	if hotbar_padded.has_point(point):
		_fail("남쪽 힌트 위치(%s)가 여전히 핫바 사각형(%s, +여유)과 겹침" % [point, hotbar_rect])
		return

	await _capture("00_south_hint_above_hotbar")

	# 비교: 좌/우/북쪽처럼 핫바와 무관한 방향은 이번 수정으로 원래 위치가 안 바뀌어야
	# 한다 — _avoid_hotbar()가 겹치지 않는 방향까지 건드리면 회귀다.
	overlay.notify(world.player_sprite.global_position + Vector2(-400, 0), world.player_sprite.global_position)
	var west_point: Vector2 = overlay._compute_point()
	var expected_west: Vector2 = overlay.size * 0.5 + Vector2(-1, 0) * (overlay.size.x * 0.5 - overlay.EDGE_MARGIN)
	if not west_point.is_equal_approx(expected_west):
		_fail("서쪽 힌트 위치(%s)가 핫바와 무관한데도 기대값(%s)과 달라짐 — 회피 로직이 과잉 적용됨" % [west_point, expected_west])
		return

	print("QA_INBOX139_CHECK_PASS south_point=", point, " hotbar_rect=", hotbar_rect)
	get_tree().quit()
