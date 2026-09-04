extends Node
## [BUILD] INBOX #115 확인용 — 리소스 포인트 겹침 버그 수정 검증.
##
## 두 가지를 확인한다:
## 1) 실제 스폰(_spawn_resource_points())으로 생성된 15개 리소스 포인트가 전부
##    RESOURCE_MIN_DISTANCE_BETWEEN_POINTS(220) 이상 떨어져 있는지 — 새 게임을 여러 번
##    반복해서 우연에 기대지 않고 확인한다.
## 2) 일부러 40유닛 간격으로 두 포인트를 겹쳐 배치하고 좌클릭 이벤트 1회를
##    Input.parse_input_event()로 실제 엔진 입력 경로에 흘려서, 한쪽만 채집되고
##    (set_input_as_handled()가 실제로 다른 쪽 _unhandled_input 호출을 막는지) 나머지
##    한쪽은 그대로 남는지 확인한다.
##
## processing_bymaterials_check.gd(#106) 등과 같은 방법: project.godot [autoload]에 이
## 스크립트를 임시로 추가하고 `godot --path .`로 실행한 뒤 되돌린다.

const OUT_DIR := "/tmp/qa115"
const NEW_GAME_TRIALS := 8


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await _boot_to_world()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var ok := true
	ok = await _check_no_overlap_across_new_games() and ok
	ok = await _check_overlapping_click_harvests_only_one() and ok
	if ok:
		print("QA_INBOX115_CHECK_PASS")
	else:
		print("QA_INBOX115_CHECK_FAIL")
	get_tree().quit()


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


## world.gd가 스폰한 실제 resource_point 인스턴스들을 모아 반환한다.
func _collect_resource_points(world: Node2D) -> Array:
	var script := load("res://scenes/resource_point/resource_point.gd")
	var points := []
	for child in world.get_children():
		if child.get_script() == script:
			points.append(child)
	return points


## _spawn_resource_points()를 여러 번 반복 호출해서(우연이 아니라 항상) 어떤 두 포인트도
## RESOURCE_MIN_DISTANCE_BETWEEN_POINTS보다 가깝지 않은지 확인한다.
func _check_no_overlap_across_new_games() -> bool:
	var world := get_tree().current_scene
	var ok := true
	for trial in range(NEW_GAME_TRIALS):
		for child in _collect_resource_points(world):
			child.queue_free()
		await get_tree().process_frame
		world._spawn_resource_points()
		var points := _collect_resource_points(world)
		if points.size() != 15:
			print("FAIL: trial ", trial, " expected 15 resource points, got ", points.size())
			ok = false
		for i in range(points.size()):
			for j in range(i + 1, points.size()):
				var dist: float = points[i].global_position.distance_to(points[j].global_position)
				if dist < world.RESOURCE_MIN_DISTANCE_BETWEEN_POINTS:
					print("FAIL: trial ", trial, " points ", i, "/", j, " too close: ", dist)
					ok = false
	return ok


## 40유닛 간격으로 두 포인트를 강제로 겹쳐 배치하고 좌클릭 1회로 하나만 채집되는지 확인.
func _check_overlapping_click_harvests_only_one() -> bool:
	var world := get_tree().current_scene
	var player = world.get_node("Player")

	# 필드에서 멀리 떨어진 격리 좌표에 배치해 자연 스폰 포인트와 안 겹치게 한다.
	var isolated_pos := Vector2(-5000, -5000)
	player.global_position = isolated_pos
	world.camera.global_position = isolated_pos
	world._select_hotbar(2)  # 시작 인벤토리 핫바 인덱스 2 = 곡괭이낫 (steel_tools_check.gd 등과 동일 가정)
	await get_tree().process_frame

	var scene1 := load("res://scenes/resource_point/gathering_point.tscn")
	var scene2 := load("res://scenes/resource_point/mining_point_sand.tscn")
	var point1 = scene1.instantiate()
	var point2 = scene2.instantiate()
	world.add_child(point1)
	world.add_child(point2)
	point1.player_ref = player
	point1.world_ref = world
	point2.player_ref = player
	point2.world_ref = world
	point1.global_position = isolated_pos + Vector2(0, 0)
	point2.global_position = isolated_pos + Vector2(40, 0)
	await get_tree().process_frame
	await get_tree().process_frame

	if world.get_held_tool() != "pickaxe":
		print("FAIL: held tool is not pickaxe, got ", world.get_held_tool())
		point1.queue_free()
		point2.queue_free()
		return false

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame

	var harvested_count := 0
	if not point1.sprite.visible:
		harvested_count += 1
	if not point2.sprite.visible:
		harvested_count += 1

	point1.queue_free()
	point2.queue_free()

	if harvested_count != 1:
		print("FAIL: overlapping click harvested ", harvested_count, " points (expected exactly 1)")
		return false
	return true
