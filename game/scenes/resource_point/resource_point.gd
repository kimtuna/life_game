extends Node2D
## 채집 포인트/채광 포인트 공용 스크립트 (INBOX #10).
## INBOX #23부터는 F키 대신, `required_tool`로 지정된 도구를 손에 든 채로 좌클릭해야
## 동작한다. INBOX #25부터는 채집/채광 둘 다 곡괭이낫(pickaxe) 하나로 통일됐다
## (한때 채집=낫/채광=곡괭이로 나눴던 것을 다시 합침 — DESIGN.md 참고).
## `required_tool`은 여전히 씬(.tscn)에서 지정하므로, 나중에 다른 도구가 필요한 포인트가
## 추가되면 그때 다시 나눠 지정하면 된다.

const INTERACT_RADIUS := 70.0
const RESPAWN_SECONDS := 20.0

@export var item_name: String = "rice_seed"
@export var item_amount: int = 1
@export var prompt_text: String = "곡괭이낫을 들고 좌클릭: 채집 (벼 씨앗)"
## 캐릭터/사슴과 같은 패턴: 변형별 텍스처는 ext_resource가 아니라 경로를 받아 load()한다.
@export var texture_path: String = ""
## 이 포인트를 쓰려면 손에 들고 있어야 하는 도구 키 ("pickaxe" 등).
@export var required_tool: String = "pickaxe"
## 곡괭이낫이 채광/채집 중 어느 쪽 모션을 보여줘야 하는지 ("mining" / "gathering",
## world.gd의 play_pickaxe_use()가 참고, INBOX #39 — DESIGN.md "도구 동작 표현").
@export var use_kind: String = "mining"

@onready var sprite: Sprite2D = $Sprite
@onready var prompt: Label = $Prompt

## world.gd가 스폰 직후 채워준다 (사슴과 같은 패턴, INBOX #9 참고).
var player_ref: Node2D = null
## world.gd가 스폰 직후 채워준다 — get_held_tool()로 지금 손에 든 도구를 물어본다.
var world_ref: Node2D = null

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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and world_ref != null and world_ref.get_held_tool() == required_tool:
		_harvest()
		## 겹쳐 스폰된 다른 포인트가 같은 클릭을 또 처리하지 못하게 막는다 (INBOX #115).
		get_viewport().set_input_as_handled()


func _harvest() -> void:
	world_ref.play_pickaxe_use(use_kind)
	world_ref.spawn_dropped_item(item_name, item_amount, global_position)
	_cooldown = RESPAWN_SECONDS
	sprite.visible = false
	prompt.visible = false


func _respawn() -> void:
	sprite.visible = true
