extends Node2D
## 목장 구역 (INBOX #12). deer.gd에서 마취탄으로 포획하면 InventoryData의
## captured_deer 개수가 늘어난다(포획된 사슴이 즉시 필드에 나타나지 않고 "재고"로
## 쌓이는 방식 — farm_plot의 씨앗/작물처럼 InventoryData를 경유). INBOX #23부터는
## F키 대신 좌클릭으로 사슴을 풀어놓는다. DESIGN.md에 이 상호작용에 지정된 도구가
## 없으므로, "맞는 도구"를 빈손(REQUIRED_TOOL="")으로 두어 도구를 든 채로는(예: 총을
## 들고 실수로 발사되는 것과 헷갈리지 않게) 동작하지 않고 빈손일 때만 좌클릭이 먹힌다.
## 그 사슴은 deer.gd의 is_ranched 모드(도주 없음, zone_radius 안에서만 배회)로 산다.

const INTERACT_RADIUS := 150.0
const ZONE_RADIUS := 100.0
const CAPTURED_ITEM := "captured_deer"
const REQUIRED_TOOL := ""

const DeerScene := preload("res://scenes/deer/deer.tscn")

@onready var prompt: Label = $Prompt

## world.gd가 스폰 직후 채워준다 (사슴/자원 포인트/밭과 같은 패턴).
var player_ref: Node2D = null
## world.gd가 스폰 직후 채워준다 — get_held_tool()로 지금 손에 든 도구를 물어본다.
var world_ref: Node2D = null


func _ready() -> void:
	prompt.visible = false


func _process(_delta: float) -> void:
	var in_range := player_ref != null \
			and global_position.distance_to(player_ref.global_position) <= INTERACT_RADIUS
	prompt.visible = in_range and InventoryData.has_item(CAPTURED_ITEM)


func _unhandled_input(event: InputEvent) -> void:
	if not prompt.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and world_ref != null and world_ref.get_held_tool() == REQUIRED_TOOL:
		_release_one()


func _release_one() -> void:
	if not InventoryData.remove_item(CAPTURED_ITEM, 1):
		return
	var deer := DeerScene.instantiate()
	add_child(deer)
	deer.is_ranched = true
	deer.zone_center = Vector2.ZERO
	deer.zone_radius = ZONE_RADIUS
	deer.position = Vector2(randf_range(-ZONE_RADIUS, ZONE_RADIUS), randf_range(-ZONE_RADIUS, ZONE_RADIUS))
	deer.position = deer.position.limit_length(ZONE_RADIUS)
