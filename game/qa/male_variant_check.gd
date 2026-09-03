extends Node
## [DESIGN] INBOX #81 확인용 — 파이썬 절차적 생성으로 만든 male_{south,north,east,west}.png를
## 실제 캐릭터에 장착한 상태로 4방향 idle을 캡처한다(실험 항목, 완화된 합격 기준).
##
## game/qa/full_sweep.gd/tool_motion_sweep.gd와 같은 방법: 실제 렌더러(`godot --path .`)로
## 실행하고, project.godot [autoload]에 이 스크립트를 임시로 추가한 뒤 실행 후 되돌린다.

const OUT_DIR := "/tmp/qa81"
const FACINGS := ["south", "east", "north", "west"]

var _world: Node2D = null
var _player: AnimatedSprite2D = null
var _step := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
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
	_world._variant = "male"
	_player.sprite_frames = _world._build_player_sprite_frames("male")
	_world._held_tool = ""
	_world._is_moving = false
	_world._tool_use_flash_timer = 0.0


func _next_step() -> void:
	if _step >= FACINGS.size():
		print("QA_MALE_VARIANT_CHECK_DONE")
		get_tree().quit()
		return
	var facing: String = FACINGS[_step]
	_world._facing = facing
	_world._update_player_animation()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_capture(facing)
	_step += 1
	_next_step()


func _capture(facing: String) -> void:
	var img := get_tree().root.get_texture().get_image()
	img.save_png("%s/%02d_idle_%s.png" % [OUT_DIR, _step, facing])
	print("captured idle_", facing, " animation=", _player.animation)
