extends Node
## [QA] 전체 스윕 캡처 스크립트 (INBOX #56, #67에서 디자인 관점 검증을 위해 확장).
##
## 메인 메뉴 -> 캐릭터 슬롯 -> 캐릭터 커스터마이징 -> 멀티플레이 로비 -> 월드 스폰까지
## 실제 화면 전환(change_scene_to_file)을 그대로 타고 가면서, 월드에 들어간 뒤에는
## 이동/조준/도구 4종(idle/사용/이동)/인벤토리/농사/채집/채광/사냥/목장/낮밤/날씨 상태를
## 강제로 만들어 스크린샷을 찍는다. STATUS.md(바퀴 78/80/82/83)가 정립한 방법을 그대로
## 재사용한다:
##   - `--headless`가 아닌 실제 렌더러(`godot --path .`)로 실행한다(캡처를 위해 필수).
##   - project.godot의 [autoload]에 이 스크립트를 마지막 줄로 임시 추가해서 실행한다.
##   - 크롭 중심은 `get_visible_rect()`가 아니라 `img.get_size()`(캡처 이미지 자신의
##     실제 픽셀 크기) 기준으로 계산한다.
##   - 순차 캡처의 "시작 대기"와 "스텝별 대기"에 같은 변수를 재사용하지 않는다(바퀴 83이
##     겪은 함정) — 여기서는 매 스텝마다 새 지역 변수로 process_frame을 기다린다.
##
## 실행 후 project.godot의 [autoload] 임시 추가분은 반드시 되돌리고, 이 스크립트 자체는
## `game/qa/`에 남겨서 다음 전체 스윕(5개마다 자동 등록)이 재사용할 수 있게 한다.
##
## (바퀴 134, INBOX #82) logging_point_idle/logging_point_harvest 두 스텝을 추가해
## #80이 새로 만든 벌목(나무) 흐름을 스윕에 포함시켰다 — gathering/mining과 같은
## resource_point.gd를 쓰지만 use_kind로는 mining과 구분되지 않으므로(둘 다 "mining"),
## required_tool == "axe"로 필터링한다.
##
## (INBOX #113) mining_point_sand_idle/mining_point_sand_harvest,
## mining_point_copper_idle/mining_point_copper_harvest 네 스텝을 추가했다. 기존
## "mining_point" 스텝은 필드에 무작위로 스폰된 포인트 중 처음 찾은(가중치가 낮은
## 모래/구리광석은 뽑히지 않을 수 있음) mining 포인트 하나만 봤을 뿐, INBOX #103이 새로
## 추가한 모래/구리광석 채광 포인트를 실제로 캐보는 경로가 스윕에 없었다 —
## mining_variety5_check.gd(#103)와 같은 방식으로 mining_point_sand.tscn/
## mining_point_copper.tscn을 직접 인스턴스화해서 확실히 검증한다.

const OUT_DIR := "/tmp/qa67"

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
		"tool_gun_idle",
		"tool_gun_fire",
		"tool_gun_walk",
		"tool_axe_idle",
		"tool_axe_use",
		"tool_axe_walk",
		"tool_pickaxe_idle",
		"tool_pickaxe_mining_use",
		"tool_pickaxe_gathering_use",
		"tool_pickaxe_walk",
		"tool_fishing_rod_idle",
		"tool_fishing_rod_use",
		"tool_fishing_rod_walk",
		"inventory_open",
		"storage_chest_open",
		"storage_chest_transfer",
		"processing_table_open",
		"processing_table_batch_collect",
		"smelting_furnace_open",
		"cooking_table_open",
		"cooking_stove_open",
		"farm_empty",
		"farm_growing",
		"farm_ready",
		"gathering_point",
		"mining_point",
		"mining_point_sand_idle",
		"mining_point_sand_harvest",
		"mining_point_copper_idle",
		"mining_point_copper_harvest",
		"logging_point_idle",
		"logging_point_harvest",
		"ranch_zone",
		"hunting_aim",
		"hunting_hit",
		"world_night",
		"world_rain",
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
		"tool_gun_idle": _step_tool_gun_idle()
		"tool_gun_fire": _step_tool_gun_fire()
		"tool_gun_walk": _step_tool_walk()
		"tool_axe_idle": _step_tool_axe_idle()
		"tool_axe_use": _step_tool_axe_use()
		"tool_axe_walk": _step_tool_walk()
		"tool_pickaxe_idle": _step_tool_pickaxe_idle()
		"tool_pickaxe_mining_use": _step_tool_pickaxe_mining_use()
		"tool_pickaxe_gathering_use": _step_tool_pickaxe_gathering_use()
		"tool_pickaxe_walk": _step_tool_walk()
		"tool_fishing_rod_idle": _step_tool_fishing_rod_idle()
		"tool_fishing_rod_use": _step_tool_fishing_rod_use()
		"tool_fishing_rod_walk": _step_tool_walk()
		"inventory_open": _step_inventory_open()
		"storage_chest_open": _step_storage_chest_open()
		"storage_chest_transfer": _step_storage_chest_transfer()
		"processing_table_open": _step_processing_table_open()
		"processing_table_batch_collect": _step_processing_table_batch_collect()
		"smelting_furnace_open": _step_smelting_furnace_open()
		"cooking_table_open": _step_cooking_table_open()
		"cooking_stove_open": _step_cooking_stove_open()
		"farm_empty": _step_farm_empty()
		"farm_growing": _step_farm_growing()
		"farm_ready": _step_farm_ready()
		"gathering_point": _step_gathering_point()
		"mining_point": _step_mining_point()
		"mining_point_sand_idle": _step_mining_point_sand_idle()
		"mining_point_sand_harvest": _step_mining_point_sand_harvest()
		"mining_point_copper_idle": _step_mining_point_copper_idle()
		"mining_point_copper_harvest": _step_mining_point_copper_harvest()
		"logging_point_idle": _step_logging_point_idle()
		"logging_point_harvest": _step_logging_point_harvest()
		"ranch_zone": await _step_ranch_zone()
		"hunting_aim": _step_hunting_aim()
		"hunting_hit": _step_hunting_hit()
		"world_night": _step_world_night()
		"world_rain": _step_world_rain()


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
	# character_customization의 확정 버튼을 눌러야 로비로 넘어간다(캐릭터 저장 +
	# change_scene_to_file). 이전 버전은 이 호출이 빠져 있어 로비 이후 스텝이 전부
	# character_customization 화면에 멈춘 채로 진행돼(current_scene이 안 바뀜)
	# world/도구/농사 등 모든 후속 캡처가 무의미했다(INBOX #74에서 발견해 고침).
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


## idle(들고 있기)/사용(발사·패기·채광·채집·낚시)/이동 세 상태를 각각 별도 스텝으로
## 찍는다 (INBOX #67 — DESIGN.md "완성의 기준"의 "상태 누락 없음"/"idle-사용 구별"을
## 실제 화면으로 확인하기 위함). 이동은 #65가 정한 대로 어떤 도구를 들었든 맨손
## walk_<방향>으로 대체되는 게 의도된 동작이라, 직전에 든 도구와 무관하게 같은
## 함수를 재사용한다.
func _step_tool_walk() -> void:
	# (바퀴 134, INBOX #82 발견) set_physics_process(false)로 멈춰둔 상태에서는
	# _tool_use_flash_timer가 자연 감쇠하지 않아, 직전 스텝(발사/패기 등)의 사용
	# 애니메이션이 그대로 남은 채 캡처되는 스크립트 버그가 있었다(실제 게임에서는
	# _process가 계속 돌아 타이머가 줄어들므로 재현되지 않는 문제). "사용하지 않고
	# 이동만" 상태를 제대로 캡처하려면 타이머를 직접 0으로 초기화해야 한다.
	_world._tool_use_flash_timer = 0.0
	_world._is_moving = true
	_world._update_player_animation()


func _step_tool_gun_idle() -> void:
	_force_tool("gun")


func _step_tool_gun_fire() -> void:
	_world._tool_use_flash_timer = _world.GUN_MUZZLE_FLASH_DURATION
	_world._update_player_animation()


func _step_tool_axe_idle() -> void:
	_force_tool("axe")


func _step_tool_axe_use() -> void:
	_world._tool_use_flash_timer = _world.AXE_CHOP_FLASH_DURATION
	_world._update_player_animation()


func _step_tool_pickaxe_idle() -> void:
	_force_tool("pickaxe")


func _step_tool_pickaxe_mining_use() -> void:
	_world.play_pickaxe_use("mining")
	_world._update_player_animation()


func _step_tool_pickaxe_gathering_use() -> void:
	_world.play_pickaxe_use("gathering")
	_world._update_player_animation()


func _step_tool_fishing_rod_idle() -> void:
	_force_tool("fishing_rod")


func _step_tool_fishing_rod_use() -> void:
	_world._tool_use_flash_timer = _world.AXE_CHOP_FLASH_DURATION
	_world._update_player_animation()


func _step_inventory_open() -> void:
	InventoryData.add_item("rice_seed", 3)
	InventoryData.add_item("iron_ore", 2)
	InventoryData.add_item("rice", 1)
	_world._set_inventory_open(true)


# ---- 저장 상자 / 가공·조리 라인 (INBOX #102 — 이전 전체 스윕(#56/#84까지)에는 없던
# 스텝. #96~#101에서 저장 상자와 가공대/제련로/조리대/조리용 화로가 추가됐는데도 그동안
# full_sweep.gd가 이 오브젝트들을 한 번도 실제로 열어본 적이 없었다 — #102가 명시적으로
# "저장 상자·가공/조리 라인 전체가 여전히 정상 동작하는지" 확인하라고 요구해서 이번에
# 처음 스윕 경로에 추가한다.)

func _find_station(script_path: String) -> Node:
	return _find_first_child_of_type(_world, script_path)


func _step_storage_chest_open() -> void:
	_world._set_inventory_open(false)
	var chest := _find_station("res://scenes/storage_chest/storage_chest.gd")
	_player.position = chest.global_position + Vector2(0, 90)
	_world.camera.global_position = _player.position
	_world.open_storage_window(chest.CHEST_TITLE, chest)


## 상자에 채워진 첫 슬롯 하나를 실제로 플레이어 인벤토리로 이전해본다(INBOX #96/#98
## 안전 패턴이 정상 경로에서도 실제로 아이템을 옮기는지 — 실패만 검증하는
## inventory_safety_check.gd와 달리 이건 "정상적으로 성공하는 길"을 스크린샷으로 본다).
func _step_storage_chest_transfer() -> void:
	var chest := _find_station("res://scenes/storage_chest/storage_chest.gd")
	var slots: Array = chest.get_slots()
	for i in range(slots.size()):
		if slots[i] != null:
			chest.try_transfer_to_player(i)
			break


func _step_processing_table_open() -> void:
	_world.close_storage_window()
	var table := _find_station("res://scenes/processing_table/processing_table.gd")
	_player.position = table.global_position + Vector2(0, 90)
	_world.camera.global_position = _player.position
	_world.open_crafting_window(table.get_title(), table.get_recipes(), table)


## 배치 제작(수량 지정 -> 재료 선소모 -> 타이머 -> 출력 버퍼 -> 수동 수령, INBOX #99)이
## 실제로 끝까지 도는지 확인한다. 5초 타이머를 실제로 기다리지 않고 `_process()`를 한 번에
## 크게 진행시켜(batch_crafting_check.gd와 같은 방법) 즉시 완성시킨 뒤 수령 버튼 콜백을
## 직접 호출한다.
func _step_processing_table_batch_collect() -> void:
	var table := _find_station("res://scenes/processing_table/processing_table.gd")
	InventoryData.add_item("wood", 2)
	table.start_batch({"inputs": {"wood": 2}, "output": "plank", "amount": 1}, 1)
	table._process(CraftingStation.CRAFT_SECONDS_PER_UNIT + 1.0)
	_world._on_collect_pressed()


func _step_smelting_furnace_open() -> void:
	_world.close_crafting_window()
	var furnace := _find_station("res://scenes/smelting_furnace/smelting_furnace.gd")
	_player.position = furnace.global_position + Vector2(0, 90)
	_world.camera.global_position = _player.position
	_world.open_crafting_window(furnace.get_title(), furnace.get_recipes(), furnace)


func _step_cooking_table_open() -> void:
	_world.close_crafting_window()
	var table := _find_station("res://scenes/cooking_table/cooking_table.gd")
	_player.position = table.global_position + Vector2(0, 90)
	_world.camera.global_position = _player.position
	_world.open_crafting_window(table.get_title(), table.get_recipes(), table)


func _step_cooking_stove_open() -> void:
	_world.close_crafting_window()
	var stove := _find_station("res://scenes/cooking_stove/cooking_stove.gd")
	_player.position = stove.global_position + Vector2(0, 90)
	_world.camera.global_position = _player.position
	_world.open_crafting_window(stove.get_title(), stove.get_recipes(), stove)


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
	_world.close_crafting_window()
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


# ---- 모래/구리광석 채광 포인트 (INBOX #103이 추가, #113이 스윕에 실제 채광 경로로
# 포함) — 필드 무작위 스폰에 의존하지 않고 직접 인스턴스화해서 확실히 검증한다
# (mining_variety5_check.gd와 같은 패턴). ----

var _mining_sand: Node2D = null
var _mining_copper: Node2D = null


## RESOURCE_SPAWN_RADIUS(1400)보다 훨씬 먼 좌표를 써서, 필드에 무작위로 스폰된 다른
## 채집/채광/벌목 포인트와 절대 겹치지 않는 자리에 스폰한다. (INBOX #113 QA 도중 발견:
## 처음엔 이전 스텝이 플레이어를 옮겨둔 위치 바로 옆에 스폰했더니, 근처에 무작위로 이미
## 스폰돼 있던 다른 포인트와 겹쳐 두 프롬프트 텍스트가 한 화면에 포개져 렌더링되는 바람에
## 스크린샷을 읽을 수 없었다 — 게임 결함(포인트 간 최소 거리 미보장, 별도 티켓으로 등록)과
## 이 스크립트의 좌표 선택 문제가 뒤섞여 보이지 않도록 스크립트 쪽을 격리된 좌표로 고쳤다.)
## world.tscn의 Ground Sprite2D는 region_rect 8000x8000(centered)라 대략
## (-4000,-4000)~(4000,4000) 범위만 잔디 타일로 덮여 있다 — 그보다 먼 좌표는 배경이
## 회색 빈 화면으로 찍힌다(첫 시도에서 (6000,6000)을 썼다가 발견, 게임 결함 아님, 이
## 스크립트가 잔디 범위 밖을 골랐던 것뿐). RESOURCE_SPAWN_RADIUS(1400)+INTERACT_RADIUS(70)
## 보다는 확실히 멀되 잔디 범위 안에 들어오는 좌표로 조정했다.
const ISOLATED_SPAWN_POS := Vector2(2500, 2500)


func _spawn_mining_point_isolated(scene_path: String) -> Node2D:
	var point: Node2D = load(scene_path).instantiate()
	point.player_ref = _player
	point.world_ref = _world
	_world.add_child(point)
	point.global_position = ISOLATED_SPAWN_POS
	return point


func _step_mining_point_sand_idle() -> void:
	_mining_sand = _spawn_mining_point_isolated("res://scenes/resource_point/mining_point_sand.tscn")
	_player.position = _mining_sand.global_position + Vector2(0, 60)
	_world.camera.global_position = _player.position
	_force_tool("pickaxe")


func _step_mining_point_sand_harvest() -> void:
	_mining_sand._harvest()


func _step_mining_point_copper_idle() -> void:
	_mining_copper = _spawn_mining_point_isolated("res://scenes/resource_point/mining_point_copper.tscn")
	_player.position = _mining_copper.global_position + Vector2(0, 60)
	_world.camera.global_position = _player.position
	_force_tool("pickaxe")


func _step_mining_point_copper_harvest() -> void:
	_mining_copper._harvest()


# ---- 벌목 (INBOX #80이 새로 만든 흐름, 바퀴 134가 스윕에 추가) ----

func _find_logging_point() -> Node2D:
	for child in _world.get_children():
		var s = child.get_script()
		if s != null and s.resource_path == "res://scenes/resource_point/resource_point.gd" \
				and child.required_tool == "axe":
			return child
	return null


func _step_logging_point_idle() -> void:
	var point := _find_logging_point()
	_player.position = point.global_position + Vector2(0, 60)
	_world.camera.global_position = _player.position
	_force_tool("axe")


func _step_logging_point_harvest() -> void:
	var point := _find_logging_point()
	_world._tool_use_flash_timer = _world.AXE_CHOP_FLASH_DURATION
	_world._update_player_animation()
	point._harvest()


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


## ---- 낮/밤 · 날씨 ----
## TimeData의 낮/밤 10분 주기를 실제로 기다릴 수 없으므로, 값을 직접 강제해서
## world.gd의 _process()가 다음 프레임에 CanvasModulate/RainOverlay를 갱신하게 만든다
## (world.gd._process는 set_physics_process(false)의 영향을 받지 않는 일반 _process라
## 계속 돈다). 손에 든 도구와 무관한 관찰이므로 빈손(핫바 5번, 도구 없음)으로 든다.

func _step_world_night() -> void:
	_player.position = Vector2.ZERO
	_world.camera.global_position = Vector2.ZERO
	_world._select_hotbar(4)
	TimeData.is_day = false
	TimeData._phase_elapsed = 0.0  # 밤 시작 시점 = NIGHT_COLOR 그대로, 가장 어두움
	TimeData.is_raining = false
	_world.rain_overlay.visible = false


func _step_world_rain() -> void:
	TimeData.is_day = true
	TimeData._phase_elapsed = 0.0  # 낮 시작 시점 = DAY_COLOR 그대로, 비 여부만 관찰
	TimeData.is_raining = true
	_world.rain_overlay.visible = true


static func now() -> String:
	return Time.get_datetime_string_from_system()
