extends Node
## [DESIGN] INBOX #95 확인용 — 유황광석 채광 포인트 그림을 결정질 크리스탈로
## 다시 그린 뒤, 돌/철광석/유황광석 세 채광 포인트를 한 화면에 나란히 놓고
## 실루엣 구분과 "불꽃처럼 보이지 않는지"를 스크린샷으로 확인한다.
## project.godot [autoload]에 이 스크립트를 임시로 추가하고 `godot --path .`로
## 실행한 뒤 되돌린다 (inbox86_check.gd와 같은 방법).

const OUT_DIR := "/tmp/qa95"


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

	var stone_scene := preload("res://scenes/resource_point/mining_point_stone.tscn")
	var iron_scene := preload("res://scenes/resource_point/mining_point.tscn")
	var sulfur_scene := preload("res://scenes/resource_point/mining_point_sulfur.tscn")

	var stone_pt = stone_scene.instantiate()
	world.add_child(stone_pt)
	stone_pt.global_position = player_pos + Vector2(-180, -40)
	stone_pt.player_ref = world.player_sprite
	stone_pt.world_ref = world

	var iron_pt = iron_scene.instantiate()
	world.add_child(iron_pt)
	iron_pt.global_position = player_pos + Vector2(0, -40)
	iron_pt.player_ref = world.player_sprite
	iron_pt.world_ref = world

	var sulfur_pt = sulfur_scene.instantiate()
	world.add_child(sulfur_pt)
	sulfur_pt.global_position = player_pos + Vector2(180, -40)
	sulfur_pt.player_ref = world.player_sprite
	sulfur_pt.world_ref = world

	world.spawn_dropped_item("stone", 1, player_pos + Vector2(-60, 120))
	world.spawn_dropped_item("sulfur_ore", 1, player_pos + Vector2(0, 120))

	await get_tree().process_frame
	await get_tree().process_frame

	# 광각 스크린샷 (채광 포인트 3개를 한 화면에).
	var img_wide := get_tree().root.get_texture().get_image()
	img_wide.save_png(OUT_DIR + "/wide.png")

	# 카메라를 확대해서 디테일 확인.
	var cam: Camera2D = world.get_node_or_null("Camera2D")
	if cam == null:
		cam = world.player_sprite.get_node_or_null("Camera2D")
	if cam != null:
		cam.zoom = Vector2(3, 3)
		cam.global_position = sulfur_pt.global_position
		await get_tree().process_frame
		await get_tree().process_frame
		var img_close := get_tree().root.get_texture().get_image()
		img_close.save_png(OUT_DIR + "/close_sulfur.png")
	else:
		print("NOTE: Camera2D not found, skipped close-up zoom shot")

	print("QA95_DONE")
	get_tree().quit()
