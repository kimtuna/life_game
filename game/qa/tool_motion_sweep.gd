extends Node
## [QA] "도구 관련 모션" 좁은 범위 검사 (INBOX #75).
##
## 총/도끼/곡괭이낫/낚싯대 4개 도구 x 4방향(south/east/north/west) x 3상태
## (idle / 사용 중(이동하면서 좌클릭) / 사용 안 하고 이동만)을 전부 캡처한다.
## world.gd의 _current_animation_name()이 실제로 어떤 애니메이션을 골랐는지
## (player_sprite.animation)도 텍스트로 같이 남겨서, 스크린샷과 대조해 판정한다.
##
## game/qa/full_sweep.gd가 정립한 방법을 그대로 재사용한다:
##   - `--headless`가 아닌 실제 렌더러(`godot --path .`)로 실행해야 캡처가 된다.
##   - project.godot의 [autoload]에 이 스크립트를 마지막 줄로 임시 추가해서 실행한다.
##   - 크롭 없이 `get_tree().root.get_texture().get_image()`를 그대로 저장한다.
##
## 실행 후 [autoload] 임시 추가분은 반드시 되돌릴 것. 이 스크립트 자체는
## game/qa/에 남겨서 다음 좁은 범위 도구 QA가 재사용할 수 있게 한다.

const OUT_DIR := "/tmp/qa75"
const TOOLS := ["gun", "axe", "pickaxe", "fishing_rod"]
const FACINGS := ["south", "east", "north", "west"]

var _world: Node2D = null
var _player: AnimatedSprite2D = null
var _plan: Array = []
var _step := 0
var _log: Array = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for tool in TOOLS:
		for facing in FACINGS:
			_plan.append({"tool": tool, "facing": facing, "state": "idle"})
			_plan.append({"tool": tool, "facing": facing, "state": "use_while_moving"})
			_plan.append({"tool": tool, "facing": facing, "state": "walk_no_use"})
			## 곡괭이낫은 채광(mining)과 채집(gathering) 모션이 서로 다르므로 채집도 따로 찍는다.
			if tool == "pickaxe":
				_plan.append({"tool": tool, "facing": facing, "state": "use_while_moving_gathering"})
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await _boot_to_world()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_next_step()


func _boot_to_world() -> void:
	get_tree().current_scene._on_play_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene._on_slot_pressed(0)
	await get_tree().process_frame
	await get_tree().process_frame
	## 이미 저장된 캐릭터가 있으면 슬롯 선택이 바로 multiplayer_lobby로 넘어가고,
	## 빈 슬롯이면 character_customization을 거쳐야 한다 — 둘 다 대응한다.
	if get_tree().current_scene.has_method("_on_confirm_pressed"):
		get_tree().current_scene._on_confirm_pressed()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
	get_tree().current_scene._on_single_player_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_world = get_tree().current_scene
	_player = _world.get_node("Player")
	_player.position = Vector2.ZERO
	_world.camera.global_position = Vector2.ZERO
	_world.set_physics_process(false)


func _next_step() -> void:
	if _step >= _plan.size():
		var f := FileAccess.open(OUT_DIR + "/log.txt", FileAccess.WRITE)
		for line in _log:
			f.store_line(line)
		f.close()
		print("QA_TOOL_MOTION_SWEEP_DONE")
		get_tree().quit()
		return
	var item: Dictionary = _plan[_step]
	_step += 1
	_run_step(item)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_capture(item)
	_next_step()


func _select_tool(tool_key: String) -> void:
	var index: int = TOOL_KEYS_INDEX(tool_key)
	_world._select_hotbar(index)


func TOOL_KEYS_INDEX(tool_key: String) -> int:
	return ["gun", "axe", "pickaxe", "fishing_rod"].find(tool_key)


func _trigger_use(tool_key: String, kind: String = "mining") -> void:
	match tool_key:
		"gun":
			_world._tool_use_flash_timer = _world.GUN_MUZZLE_FLASH_DURATION
		"axe":
			_world._tool_use_flash_timer = _world.AXE_CHOP_FLASH_DURATION
		"pickaxe":
			_world.play_pickaxe_use(kind)
		"fishing_rod":
			_world._tool_use_flash_timer = _world.AXE_CHOP_FLASH_DURATION


func _run_step(item: Dictionary) -> void:
	var tool: String = item["tool"]
	var facing: String = item["facing"]
	var state: String = item["state"]
	_select_tool(tool)
	_world._facing = facing
	_world._tool_use_flash_timer = 0.0
	match state:
		"idle":
			_world._is_moving = false
		"use_while_moving":
			_world._is_moving = true
			_trigger_use(tool)
		"use_while_moving_gathering":
			_world._is_moving = true
			_trigger_use(tool, "gathering")
		"walk_no_use":
			_world._is_moving = true
	_world._update_player_animation()


func _capture(item: Dictionary) -> void:
	var tool: String = item["tool"]
	var facing: String = item["facing"]
	var state: String = item["state"]
	var name := "%s_%s_%s" % [tool, facing, state]
	var img := get_tree().root.get_texture().get_image()
	img.save_png("%s/%02d_%s.png" % [OUT_DIR, _step, name])
	var anim_name: String = _player.animation
	_log.append("%02d %s -> animation=%s" % [_step, name, anim_name])
	print("captured ", name, " animation=", anim_name)
