extends Node2D
## 채집 포인트/채광 포인트 공용 스크립트 (INBOX #10).
## DESIGN.md: 삽(채집)/곡괭이(채광)를 한 세트 도구로 다루므로, 도구를 따로 고르는 UI 없이
## 포인트 종류에 따라 자동으로 맞는 판정(채집 or 채광)을 적용한다.

const INTERACT_RADIUS := 70.0
const RESPAWN_SECONDS := 20.0
const DEPLETED_MODULATE := Color(0.45, 0.45, 0.45, 1.0)

@export var item_name: String = "rice_seed"
@export var item_amount: int = 1
@export var prompt_text: String = "F: 채집 (벼 씨앗)"
## 캐릭터/사슴과 같은 패턴: 변형별 텍스처는 ext_resource가 아니라 경로를 받아 load()한다.
@export var texture_path: String = ""

@onready var sprite: Sprite2D = $Sprite
@onready var prompt: Label = $Prompt

## world.gd가 스폰 직후 채워준다 (사슴과 같은 패턴, INBOX #9 참고).
var player_ref: Node2D = null

var _cooldown: float = 0.0


func _ready() -> void:
	if texture_path != "":
		sprite.texture = load(texture_path)
	prompt.text = prompt_text
	prompt.visible = false


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
		if _cooldown <= 0.0:
			_respawn()

	var in_range := _cooldown <= 0.0 and player_ref != null \
			and global_position.distance_to(player_ref.global_position) <= INTERACT_RADIUS
	prompt.visible = in_range


func _unhandled_input(event: InputEvent) -> void:
	if _cooldown > 0.0 or not prompt.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		_harvest()


func _harvest() -> void:
	InventoryData.add_item(item_name, item_amount)
	_cooldown = RESPAWN_SECONDS
	sprite.modulate = DEPLETED_MODULATE
	prompt.visible = false


func _respawn() -> void:
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
