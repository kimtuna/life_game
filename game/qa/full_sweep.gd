extends Node
## [QA] 전체 스윕 캡처 스크립트 (INBOX #56).
##
## 메인 메뉴 -> 캐릭터 슬롯 -> 캐릭터 커스터마이징 -> 멀티플레이 로비 -> 월드 스폰까지
## 실제 화면 전환(change_scene_to_file)을 그대로 타고 가면서, 월드에 들어간 뒤에는
## 이동/조준/도구 4종/인벤토리/농사/채집/채광/사냥/목장 상태를 강제로 만들어 스크린샷을
## 찍는다. STATUS.md(바퀴 78/80/82/83)가 정립한 방법을 그대로 재사용한다:
##   - `--headless`가 아닌 실제 렌더러(`godot --path .`)로 실행한다(캡처를 위해 필수).
##   - project.godot의 [autoload]에 이 스크립트를 마지막 줄로 임시 추가해서 실행한다.
##   - 크롭 중심은 `get_visible_rect()`가 아니라 `img.get_size()`(캡처 이미지 자신의
##     실제 픽셀 크기) 기준으로 계산한다.
##   - 순차 캡처의 "시작 대기"와 "스텝별 대기"에 같은 변수를 재사용하지 않는다(바퀴 83이
##     겪은 함정) — 여기서는 매 스텝마다 새 지역 변수로 process_frame을 기다린다.
##
## 실행 후 project.godot의 [autoload] 임시 추가분은 반드시 되돌리고, 이 스크립트 자체는
## `game/qa/`에 남겨서 다음 전체 스윕(5개마다 자동 등록)이 재사용할 수 있게 한다.

const OUT_DIR := "/tmp/qa56"

var _step := 0
var _plan: Array = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_plan = [
		"main_menu",
		"character_slots",
		"character_customization",
		"multiplayer_lobby",
		"world_enter",
		"world_setup",
		"tool_gun",
		"tool_axe",
		"tool_pickaxe",
		"tool_fishing_rod",
		"inventory_open",
		"farm_empty",
		"farm_growing",
		"farm_ready",
		"gathering_point",
		"mining_point",
		"ranch_zone",
		"hunting_aim",
		"hunting_hit",
	]
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_next_step()


func _next_step() -> void:
	if _step >= _plan.size():
		print("QA_SWEEP_DONE")
		get_tree().quit()
		return
	var name: String = _plan[_step]
	_step += 1
	await _run_step(name)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture(name)
	_next_step()


func _run_step(name: String) -> void:
	match name:
		"main_menu": _step_main_menu()
		"character_slots": _step_character_slots()
		"character_customization": _step_character_customization()
		"multiplayer_lobby": _step_multiplayer_lobby()
		"world_enter": _step_world_enter()
		"world_setup": _step_world_setup()
		"tool_gun": _step_tool_gun()
		"tool_axe": _step_tool_axe()
		"tool_pickaxe": _step_tool_pickaxe()
		"tool_fishing_rod": _step_tool_fishing_rod()
		"inventory_open": _step_inventory_open()
		"farm_empty": _step_farm_empty()
		"farm_growing": _step_farm_growing()
		"farm_ready": _step_farm_ready()
		"gathering_point": _step_gathering_point()
		"mining_point": _step_mining_point()
		"ranch_zone": await _step_ranch_zone()
		"hunting_aim": _step_hunting_aim()
		"hunting_hit": _step_hunting_hit()


func _capture(name: String) -> void:
	var img := get_tree().root.get_texture().get_image()
	img.save_png("%s/%02d_%s.png" % [OUT_DIR, _step, name])
	print("captured ", name, " size=", img.get_size())


func _current() -> Node:
	return get_tree().current_scene


# ---- 화면 흐름 ----

func _step_main_menu() -> void:
	pass  # run/main_scene이 이미 main_menu다.


func _step_character_slots() -> void:
	_current()._on_play_pressed()


func _step_character_customization() -> void:
	_current()._on_slot_pressed(0)


func _step_multiplayer_lobby() -> void:
	_current()._on_confirm_pressed()


func _step_world_enter() -> void:
	_current()._on_single_player_pressed()


# ---- 월드 준비 (플레이어를 화면 중앙 고정, 카메라도 그 자리로) ----

var _world: Node2D = null
var _player: AnimatedSprite2D = null


func _step_world_setup() -> void:
	_world = _current()
	_player = _world.get_node("Player")
	_player.position = Vector2.ZERO
	_world.camera.global_position = Vector2.ZERO
	_world.set_physics_process(false)


func _force_tool(tool_key: String) -> void:
	# TOOL_KEYS = ["gun", "axe", "pickaxe", "fishing_rod"] 순서로 핫바 1~4번에 지급됨
	# (world.gd._ensure_starting_tools 참고).
	var index: int = ["gun", "axe", "pickaxe", "fishing_rod"].find(tool_key)
	_world._select_hotbar(index)
	_world._facing = "south"
	_world._is_moving = false
	_world._tool_use_flash_timer = 0.0
	_world._update_player_animation()


func _step_tool_gun() -> void:
	_force_tool("gun")


func _step_tool_axe() -> void:
	_force_tool("axe")


func _step_tool_pickaxe() -> void:
	_force_tool("pickaxe")


func _step_tool_fishing_rod() -> void:
	_force_tool("fishing_rod")


func _step_inventory_open() -> void:
	InventoryData.add_item("rice_seed", 3)
	InventoryData.add_item("iron", 2)
	InventoryData.add_item("rice", 1)
	_world._set_inventory_open(true)


# ---- 농사 ----

var _farm_plot: Node2D = null


func _find_first_child_of_type(root: Node, script_path: String) -> Node:
	for child in root.get_children():
		var s = child.get_script()
		if s != null and s.resource_path == script_path:
			return child
	return null


func _step_farm_empty() -> void:
	_world._set_inventory_open(false)
	_farm_plot = _find_first_child_of_type(_world, "res://scenes/farm_plot/farm_plot.gd")
	_player.position = _farm_plot.global_position + Vector2(0, 90)
	_world.camera.global_position = _player.position
	InventoryData.add_item("rice_seed", 1)
	# 씨앗을 핫바 슬롯에 두고 손에 든 상태로 만든다.
	var slots := InventoryData.get_general_slots()
	for i in range(slots.size()):
		if slots[i] != null and slots[i]["item"] == "rice_seed":
			_world._select_hotbar(i if i < InventoryData.HOTBAR_SIZE else 0)
			break
	_farm_plot._interact()  # EMPTY 상태에서 심기


func _step_farm_growing() -> void:
	pass  # 방금 심어서 GROWING 상태 그대로.


func _step_farm_ready() -> void:
	_farm_plot._grow_timer = 0.0
	_farm_plot._process(0.016)  # READY로 전이


# ---- 채집/채광 ----

func _step_gathering_point() -> void:
	var point: Node2D = null
	# world.gd가 채집(gathering)/채광(mining) 포인트를 섞어서 자식으로 두므로, use_kind로 구분.
	for child in _world.get_children():
		var s = child.get_script()
		if s != null and s.resource_path == "res://scenes/resource_point/resource_point.gd" \
				and child.use_kind == "gathering":
			point = child
			break
	_player.position = point.global_position + Vector2(0, 60)
	_world.camera.global_position = _player.position
	_force_tool("pickaxe")


func _step_mining_point() -> void:
	var point: Node2D = null
	for child in _world.get_children():
		var s = child.get_script()
		if s != null and s.resource_path == "res://scenes/resource_point/resource_point.gd" \
				and child.use_kind == "mining":
			point = child
			break
	_player.position = point.global_position + Vector2(0, 60)
	_world.camera.global_position = _player.position
	_force_tool("pickaxe")


# ---- 목장 ----

func _step_ranch_zone() -> void:
	var zone := _find_first_child_of_type(_world, "res://scenes/ranch_zone/ranch_zone.gd")
	InventoryData.add_item("captured_deer", 1)
	var slots := InventoryData.get_general_slots()
	for i in range(slots.size()):
		if slots[i] != null and slots[i]["item"] == "captured_deer":
			_world._select_hotbar(i if i < InventoryData.HOTBAR_SIZE else 0)
			break
	_player.position = zone.global_position + Vector2(0, 130)
	_world.camera.global_position = _player.position
	zone._release_one()
	await get_tree().process_frame


# ---- 사냥 ----

var _deer: Node2D = null


func _step_hunting_aim() -> void:
	_deer = _world.get_children().filter(func(c):
		var s = c.get_script()
		return s != null and s.resource_path == "res://scenes/deer/deer.gd"
	)[0]
	_deer.player_ref = null  # 도주 AI가 화면 밖으로 안 벗어나게 접근 감지를 잠시 끈다.
	_player.position = _deer.global_position + Vector2(0, 150)
	_world.camera.global_position = _player.position
	_force_tool("gun")


func _step_hunting_hit() -> void:
	_deer.take_hit(25, "normal")
	_deer.player_ref = _player


static func now() -> String:
	return Time.get_datetime_string_from_system()
