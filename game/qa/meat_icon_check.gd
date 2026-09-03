extends Node
## [DESIGN] INBOX #94 확인용 — 다시 그린 meat.png 아이콘이 stone/sulfur_ore와 나란히
## 놓았을 때 화면상 32px 최소 기준을 충족하는지 확인한다. obj_icon_check.gd(#91)와
## 같은 방법: project.godot [autoload]에 이 스크립트를 임시로 추가하고
## `godot --path .`로 실행한 뒤 되돌린다.

const OUT_DIR := "/tmp/qa94"


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
	var drop_center: Vector2 = world.player_sprite.global_position + Vector2(400, -300)
	var items := ["stone", "sulfur_ore", "meat"]
	for j in range(items.size()):
		var pos: Vector2 = drop_center + Vector2(j * 60 - 60, 0)
		world.spawn_dropped_item(items[j], 1, pos)
	await get_tree().process_frame
	await get_tree().process_frame
	world.player_sprite.global_position = drop_center + Vector2(1000, 1000)
	world.camera.global_position = drop_center
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/00_dropped_items.png" % OUT_DIR)

	print("QA_MEAT_ICON_CHECK_PASS")
	get_tree().quit()
