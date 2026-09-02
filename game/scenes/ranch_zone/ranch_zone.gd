extends Node2D
## 목장 구역 (INBOX #12). deer.gd에서 마취탄으로 포획하면 InventoryData의
## captured_deer 개수가 늘어난다(포획된 사슴이 즉시 필드에 나타나지 않고 "재고"로
## 쌓이는 방식 — farm_plot의 씨앗/작물처럼 InventoryData를 경유). 이 구역에서
## F키로 상호작용하면 captured_deer를 하나 소비해 사슴을 이 구역 안에 풀어놓고,
## 그 사슴은 deer.gd의 is_ranched 모드(도주 없음, zone_radius 안에서만 배회)로 산다.

const INTERACT_RADIUS := 150.0
const ZONE_RADIUS := 100.0
const CAPTURED_ITEM := "captured_deer"

const DeerScene := preload("res://scenes/deer/deer.tscn")

@onready var prompt: Label = $Prompt

## world.gd가 스폰 직후 채워준다 (사슴/자원 포인트/밭과 같은 패턴).
var player_ref: Node2D = null


func _ready() -> void:
	prompt.visible = false


func _process(_delta: float) -> void:
	var in_range := player_ref != null \
			and global_position.distance_to(player_ref.global_position) <= INTERACT_RADIUS
	prompt.visible = in_range and InventoryData.has_item(CAPTURED_ITEM)


func _unhandled_input(event: InputEvent) -> void:
	if not prompt.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
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
