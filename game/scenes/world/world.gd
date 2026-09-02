extends Node2D

const MOVE_SPEED := 220.0

## 기본 소총 스탯 (DESIGN.md "총기 스탯" 절 그대로 적용)
const GUN_RANGE := 800.0
const GUN_DAMAGE := 25
const GUN_FIRE_INTERVAL := 0.5  # 초당 2발
const GUN_BULLET_SPEED := 2200.0
const GUN_SPREAD_IDLE_DEG := 1.0
const GUN_SPREAD_MOVE_DEG := 8.0
const GUN_RECOIL_PER_SHOT := 0.15
const GUN_RECOIL_MAX := 0.6
const GUN_RECOIL_DECAY_PER_SEC := 2.0

const BulletScene := preload("res://scenes/bullet/bullet.tscn")

@onready var player_sprite: Sprite2D = $Player
@onready var camera: Camera2D = $Camera2D
@onready var pause_menu: Control = $UI/PauseMenu
@onready var ammo_label: Label = $UI/HUD/AmmoPanel/AmmoLabel

var _variant: String = "green"
var _facing: String = "south"
var _paused: bool = false
var _ammo_type: String = "normal"
var _fire_cooldown: float = 0.0
var _recoil: float = 0.0
var _is_moving: bool = false


func _ready() -> void:
	var character := CharacterData.get_character(CharacterData.active_slot_index)
	_variant = character.get("variant", "green")
	_update_texture()
	_update_ammo_label()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_set_paused(not _paused)
	elif event is InputEventMouseButton and event.pressed and not _paused \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		_ammo_type = "tranq" if _ammo_type == "normal" else "normal"
		_update_ammo_label()


func _physics_process(delta: float) -> void:
	if _paused:
		return

	var input_dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_D):
		input_dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		input_dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		input_dir.y -= 1.0
	_is_moving = input_dir.length() > 0.0
	if _is_moving:
		input_dir = input_dir.normalized()
	player_sprite.position += input_dir * MOVE_SPEED * delta

	var to_mouse := get_global_mouse_position() - player_sprite.global_position
	if to_mouse.length() > 1.0:
		var new_facing := _facing_from_direction(to_mouse)
		if new_facing != _facing:
			_facing = new_facing
			_update_texture()

	camera.global_position = player_sprite.global_position

	_recoil = maxf(0.0, _recoil - GUN_RECOIL_DECAY_PER_SEC * delta)
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _fire_cooldown <= 0.0:
		_fire()


## 조준 방향에 반동(위로 튐)과 탄퍼짐(이동 중이면 커짐)을 섞어서 총알을 하나 쏜다.
func _fire() -> void:
	_fire_cooldown = GUN_FIRE_INTERVAL
	_recoil = minf(GUN_RECOIL_MAX, _recoil + GUN_RECOIL_PER_SHOT)

	var aim := get_global_mouse_position() - player_sprite.global_position
	if aim.length() < 1.0:
		aim = Vector2.RIGHT
	aim = aim.normalized()
	aim = (aim + Vector2.UP * _recoil).normalized()
	var spread_deg := GUN_SPREAD_MOVE_DEG if _is_moving else GUN_SPREAD_IDLE_DEG
	aim = aim.rotated(deg_to_rad(randf_range(-spread_deg * 0.5, spread_deg * 0.5)))

	var bullet := BulletScene.instantiate()
	bullet.global_position = player_sprite.global_position
	bullet.rotation = aim.angle()
	bullet.velocity = aim * GUN_BULLET_SPEED
	bullet.max_range = GUN_RANGE
	bullet.damage = GUN_DAMAGE
	bullet.ammo_type = _ammo_type
	add_child(bullet)


## 방향별 스프라이트(north/south/east/west)만 있으므로, 마우스가 가리키는
## 각도를 90도씩 4구간으로 나눠서 가장 가까운 방향 스프라이트로 바꿔 끼운다.
## 스프라이트 자체를 rotation으로 돌리면 정면(도트) 그림이 옆으로 눕는 것처럼
## 보여서 품질 기준을 통과하지 못했다 (스크린샷 QA로 확인, INBOX #4 참고).
func _facing_from_direction(direction: Vector2) -> String:
	var angle_deg := rad_to_deg(direction.angle())
	if angle_deg > -45.0 and angle_deg <= 45.0:
		return "east"
	elif angle_deg > 45.0 and angle_deg <= 135.0:
		return "south"
	elif angle_deg > -135.0 and angle_deg <= -45.0:
		return "north"
	else:
		return "west"


func _update_texture() -> void:
	player_sprite.texture = load("res://assets/sprites/character/%s_%s.png" % [_variant, _facing])


func _update_ammo_label() -> void:
	ammo_label.text = "탄약: 마취탄" if _ammo_type == "tranq" else "탄약: 기본탄"


func _set_paused(value: bool) -> void:
	_paused = value
	pause_menu.visible = value


func _on_resume_pressed() -> void:
	_set_paused(false)


func _on_settings_pressed() -> void:
	SettingsData.return_scene_path = "res://scenes/world/world.tscn"
	get_tree().change_scene_to_file("res://scenes/settings/settings.tscn")


func _on_quit_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
