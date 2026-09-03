extends Node2D
## 제련로 (INBOX #88). DESIGN.md "생산 라인 — 작업대 2계통": 열이 필요한 가공
## (철광석→철, 목재→숯)을 담당하는 가공 라인 작업대다 — 열이 필요 없는 가공대(#87)와는
## 별개 오브젝트다(화로를 가공대와 겸용으로 쓰지 않는다 — 사용자 지시). processing_table.gd와
## 완전히 같은 프레임워크(근처에서 좌클릭 → world.gd의 범용 제작 창)를 RECIPES만 바꿔
## 재사용한다(DESIGN.md "코드 재사용/공통화" 지시).
## 월드 그림(INBOX #91)은 파이썬 절차적 생성(Pillow)으로 만든
## assets/sprites/smelting_furnace/smelting_furnace.png를 쓴다.

const INTERACT_RADIUS := 90.0
const TABLE_TITLE := "제련로"

## {"inputs": {아이템: 개수, ...}, "output": 아이템, "amount": 개수} 목록.
const RECIPES := [
	{"inputs": {"iron_ore": 2}, "output": "iron", "amount": 1},
	{"inputs": {"wood": 2}, "output": "charcoal", "amount": 1},
]

@onready var prompt: Label = $Prompt

## world.gd가 스폰 직후 채워준다 (다른 상호작용 오브젝트와 같은 패턴).
var player_ref: Node2D = null
var world_ref: Node2D = null


func _ready() -> void:
	prompt.visible = false


func _process(_delta: float) -> void:
	var in_range := player_ref != null \
			and global_position.distance_to(player_ref.global_position) <= INTERACT_RADIUS
	prompt.visible = in_range and world_ref != null \
			and not world_ref.is_crafting_open() and not world_ref.is_storage_open()


func _unhandled_input(event: InputEvent) -> void:
	if not prompt.visible or world_ref == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		world_ref.open_crafting_window(TABLE_TITLE, RECIPES)
