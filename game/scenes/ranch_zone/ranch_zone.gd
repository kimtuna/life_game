extends Node2D
## 목장 구역 (INBOX #12). deer.gd에서 마취탄으로 포획하면 InventoryData의
## captured_deer 개수가 늘어난다(포획된 사슴이 즉시 필드에 나타나지 않고 "재고"로
## 쌓이는 방식 — farm_plot의 씨앗/작물처럼 InventoryData를 경유). INBOX #23부터는
## F키 대신 좌클릭으로 사슴을 풀어놓는다. DESIGN.md에 이 상호작용에 지정된 도구가
## 없으므로, "맞는 도구"를 빈손(REQUIRED_TOOL="")으로 두어 도구를 든 채로는(예: 총을
## 들고 실수로 발사되는 것과 헷갈리지 않게) 동작하지 않고 빈손일 때만 좌클릭이 먹힌다.
## 그 사슴은 deer.gd의 is_ranched 모드(도주 없음, zone_radius 안에서만 배회)로 산다.
## INBOX #26부터는 zone_radius 안에 머무는 것을 매 프레임 position clamp가 아니라
## _build_fence()가 만드는 실제 담장(StaticBody2D + CollisionShape2D 여러 개를 원형으로
## 배치)이 물리적으로 막는다(deer.gd가 CharacterBody2D로 바뀌어 move_and_slide()로
## 이 담장과 충돌한다). 완전한 원 하나짜리 CircleShape2D를 쓰지 않는 이유: 그건 속이
## 꽉 찬 디스크라서 목장 안에 스폰되는 사슴이 담장 안쪽에서부터 이미 겹친 상태가 되어
## 튕겨 나가버린다 — 그래서 원주를 따라 얇은 직사각형 조각(세그먼트)을 이어붙여 "속이
## 빈 울타리"를 만든다.

const INTERACT_RADIUS := 150.0
const ZONE_RADIUS := 100.0
const CAPTURED_ITEM := "captured_deer"
const REQUIRED_TOOL := ""

const FENCE_SEGMENTS := 16
const FENCE_THICKNESS := 12.0

const DeerScene := preload("res://scenes/deer/deer.tscn")

@onready var prompt: Label = $Prompt

## world.gd가 스폰 직후 채워준다 (사슴/자원 포인트/밭과 같은 패턴).
var player_ref: Node2D = null
## world.gd가 스폰 직후 채워준다 — get_held_tool()로 지금 손에 든 도구를 물어본다.
var world_ref: Node2D = null


func _ready() -> void:
	prompt.visible = false
	_build_fence()


## 원주를 따라 얇은 직사각형 CollisionShape2D를 겹치게 이어붙여 원형 담장을 만든다.
## 하나의 StaticBody2D 아래 세그먼트 수만큼 CollisionShape2D를 자식으로 둔다 (담장
## 기둥마다 별도 바디를 만들 필요 없음 — 정적 바디 하나에 모양만 여러 개면 충분하다).
func _build_fence() -> void:
	var fence := StaticBody2D.new()
	fence.name = "Fence"
	add_child(fence)
	# 세그먼트 사이 틈이 안 생기도록 실제 호 길이보다 15% 길게 잡아 살짝 겹친다.
	var segment_length := (TAU * ZONE_RADIUS / FENCE_SEGMENTS) * 1.15
	for i in range(FENCE_SEGMENTS):
		var angle := TAU * i / FENCE_SEGMENTS
		var shape := RectangleShape2D.new()
		shape.size = Vector2(segment_length, FENCE_THICKNESS)
		var col := CollisionShape2D.new()
		col.shape = shape
		col.position = Vector2(ZONE_RADIUS, 0.0).rotated(angle)
		col.rotation = angle + PI / 2.0
		fence.add_child(col)


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
	# 담장(반경 ZONE_RADIUS 원주에 두께 FENCE_THICKNESS로 얹힘)과 겹친 채로 스폰되면
	# move_and_slide()가 즉시 밀어내 버리므로, 담장 안쪽으로 넉넉히 여유를 두고 배치한다.
	var spawn_radius := ZONE_RADIUS - FENCE_THICKNESS
	deer.position = Vector2(randf_range(-spawn_radius, spawn_radius), randf_range(-spawn_radius, spawn_radius))
	deer.position = deer.position.limit_length(spawn_radius)
