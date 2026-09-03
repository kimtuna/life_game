extends Node2D
## 조리대 (INBOX #90). DESIGN.md "생산 라인 — 작업대 2계통": 조리 라인의 "레시피 조합"
## 담당 오브젝트다 — 가열이 필요한 조리용 화로(cooking_stove.gd)와는 별개 오브젝트다.
## processing_table.gd/smelting_furnace.gd와 완전히 같은 프레임워크(근처에서 좌클릭 →
## world.gd의 범용 제작 창)를 RECIPES만 바꿔 재사용한다(DESIGN.md "코드 재사용/공통화" 지시).
## RECIPES가 비어있는 건 결함이 아니다 — DESIGN.md가 명시한 "조합 요리"(밥+익힌고기+
## 익힌채소→스테이크 등)는 채소 아이템이 아직 정해지지 않아 이번 범위 밖이라, 조리대는
## 오브젝트로만 먼저 자리잡고 레시피는 채소 추가 뒤 별도 지시로 채운다.
## 월드 그림(INBOX #91)은 파이썬 절차적 생성(Pillow)으로 만든
## assets/sprites/cooking_table/cooking_table.png를 쓴다.

const INTERACT_RADIUS := 90.0
const TABLE_TITLE := "조리대"

## {"inputs": {아이템: 개수, ...}, "output": 아이템, "amount": 개수} 목록.
## 지금은 비어있다 — 위 클래스 주석 참고.
const RECIPES := []

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
