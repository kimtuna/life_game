extends Node2D
## 가공대 (INBOX #87). DESIGN.md "생산 라인 — 작업대 2계통": 열이 필요 없는 가공
## (목재→판자, 돌→석재 등)을 담당하는 가공 라인 작업대다 — 열이 필요한 제련로(#88)와는
## 별개 오브젝트로 갈라둔다. farm_plot/ranch_zone과 같은 "근처에서 좌클릭" 패턴을 쓰되,
## 상호작용 결과가 즉시 일어나는 대신 world.gd의 범용 제작 창(open_crafting_window())을
## 열어서 여러 레시피 중 고르게 한다 — 이 창/레시피 목록 UI는 #88 이후의 다른 작업대도
## RECIPES만 바꿔서 그대로 재사용한다(DESIGN.md "코드 재사용/공통화" 지시).
## 월드 그림은 이번 항목 범위가 아니라(#91에서 처리) 임시 단색 사각형(Body Polygon2D)을 쓴다.

const INTERACT_RADIUS := 90.0
const TABLE_TITLE := "가공대"

## {"inputs": {아이템: 개수, ...}, "output": 아이템, "amount": 개수} 목록.
const RECIPES := [
	{"inputs": {"wood": 2}, "output": "plank", "amount": 1},
	{"inputs": {"stone": 2}, "output": "stone_block", "amount": 1},
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
	# 제작 창이 이미 열려 있을 때는 프롬프트를 감춰서, 다른 좌클릭(레시피 버튼 등)이
	# 진행 중인데도 "좌클릭: 가공대 열기" 안내가 겹쳐 보이지 않게 한다.
	prompt.visible = in_range and world_ref != null and not world_ref.is_crafting_open()


func _unhandled_input(event: InputEvent) -> void:
	if not prompt.visible or world_ref == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		world_ref.open_crafting_window(TABLE_TITLE, RECIPES)
