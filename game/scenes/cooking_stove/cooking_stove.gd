extends Node2D
## 조리용 화로 (INBOX #90). DESIGN.md "생산 라인 — 작업대 2계통": 조리 라인의 가열 담당
## 오브젝트다 — 가공 라인의 제련로(smelting_furnace.gd)와는 용도가 달라 별개 오브젝트로
## 갈라둔다(화로를 라인별로 겸용하지 않는다 — 사용자 지시). processing_table.gd/
## smelting_furnace.gd와 완전히 같은 프레임워크(근처에서 좌클릭 → world.gd의 범용 제작
## 창)를 RECIPES만 바꿔 재사용한다(DESIGN.md "코드 재사용/공통화" 지시).
## 월드 그림은 이번 항목 범위가 아니라(#91에서 처리) 임시 단색 사각형(Body Polygon2D)을 쓴다.

const INTERACT_RADIUS := 90.0
const TABLE_TITLE := "조리용 화로"

## {"inputs": {아이템: 개수, ...}, "output": 아이템, "amount": 개수} 목록.
const RECIPES := [
	{"inputs": {"rice": 1}, "output": "cooked_rice", "amount": 1},
	{"inputs": {"meat": 1}, "output": "cooked_meat", "amount": 1},
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
	prompt.visible = in_range and world_ref != null and not world_ref.is_crafting_open()


func _unhandled_input(event: InputEvent) -> void:
	if not prompt.visible or world_ref == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		world_ref.open_crafting_window(TABLE_TITLE, RECIPES)
