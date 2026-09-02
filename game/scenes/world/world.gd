extends Node2D

const MOVE_SPEED := 220.0

@onready var player_sprite: Sprite2D = $Player
@onready var camera: Camera2D = $Camera2D

var _variant: String = "green"
var _facing: String = "south"


func _ready() -> void:
	var character := CharacterData.get_character(CharacterData.active_slot_index)
	_variant = character.get("variant", "green")
	_update_texture()


func _physics_process(delta: float) -> void:
	var input_dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_D):
		input_dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		input_dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		input_dir.y -= 1.0
	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()
	player_sprite.position += input_dir * MOVE_SPEED * delta

	var to_mouse := get_global_mouse_position() - player_sprite.global_position
	if to_mouse.length() > 1.0:
		var new_facing := _facing_from_direction(to_mouse)
		if new_facing != _facing:
			_facing = new_facing
			_update_texture()

	camera.global_position = player_sprite.global_position


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


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
