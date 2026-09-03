extends Node
## [DESIGN] INBOX #86 확인용 — 돌/유황광석 채광 포인트 월드 그림과 돌/유황광석/고기
## 아이템 아이콘이 실제 게임 화면에 반영됐는지 스크린샷으로 확인한다.
## deer_meat_check.gd(#85)와 같은 방법: project.godot [autoload]에 이 스크립트를
## 임시로 추가하고 `godot --path .`로 실행한 뒤 되돌린다.

const OUT_DIR := "/tmp/qa86"


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
	var player_pos: Vector2 = world.player_sprite.global_position

	# 1) 돌/유황광석 채광 포인트를 플레이어 근처에 나란히 배치.
	var stone_scene := preload("res://scenes/resource_point/mining_point_stone.tscn")
	var sulfur_scene := preload("res://scenes/resource_point/mining_point_sulfur.tscn")
	var stone_pt = stone_scene.instantiate()
	world.add_child(stone_pt)
	stone_pt.global_position = player_pos + Vector2(-150, -40)
	stone_pt.player_ref = world.player_sprite
	stone_pt.world_ref = world

	var sulfur_pt = sulfur_scene.instantiate()
	world.add_child(sulfur_pt)
	sulfur_pt.global_position = player_pos + Vector2(150, -40)
	sulfur_pt.player_ref = world.player_sprite
	sulfur_pt.world_ref = world

	# 2) 돌/유황광석/고기 드롭 아이템을 플레이어 아래쪽에 배치 (아이콘 확인용,
	# PICKUP_RADIUS 40보다 멀리 둬서 스크린샷 전에 자동 습득되지 않게 한다).
	world.spawn_dropped_item("stone", 1, player_pos + Vector2(-60, 100))
	world.spawn_dropped_item("sulfur_ore", 1, player_pos + Vector2(0, 100))
	world.spawn_dropped_item("meat", 1, player_pos + Vector2(60, 100))

	await get_tree().process_frame
	await get_tree().process_frame

	# 3) 광각 스크린샷 (채광 포인트 2개 + 드롭 아이템 3개 + 플레이어 한 화면에).
	var img_wide := get_tree().root.get_texture().get_image()
	img_wide.save_png(OUT_DIR + "/wide.png")

	# 4) 카메라를 확대해서 디테일 확인.
	var cam: Camera2D = world.get_node_or_null("Camera2D")
	if cam == null:
		cam = world.player_sprite.get_node_or_null("Camera2D")
	if cam != null:
		cam.zoom = Vector2(3, 3)
		await get_tree().process_frame
		await get_tree().process_frame
		var img_close := get_tree().root.get_texture().get_image()
		img_close.save_png(OUT_DIR + "/close.png")
	else:
		print("NOTE: Camera2D not found, skipped close-up zoom shot")

	print("QA86_DONE")
	get_tree().quit()
