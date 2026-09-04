extends Node2D
## 사냥/채집/채광 결과물이 바닥에 떨어지는 드롭 오브젝트 (INBOX #24).
## 좌클릭은 이미 도구 동작에 쓰이므로, 습득은 플레이어와의 접촉(거리 판정)만으로 이뤄진다
## (resource_point.gd 등 기존 상호작용 오브젝트와 같은 player_ref 거리 판정 패턴).

const PICKUP_RADIUS := 40.0

## 아직 아이콘이 없던 채집/채광/포획 결과물용으로 새로 생성했다 (도구 아이콘과 같은 방식,
## PixelLab generate-image-pixflux 32x32 no_background).
const ITEM_ICONS := {
	"rice_seed": preload("res://assets/sprites/items/rice_seed.png"),
	"rice": preload("res://assets/sprites/items/rice.png"),
	"iron_ore": preload("res://assets/sprites/items/iron_ore.png"),
	# 돌/유황광석/고기(INBOX #86) 전용 아이콘.
	"stone": preload("res://assets/sprites/items/stone.png"),
	"sulfur_ore": preload("res://assets/sprites/items/sulfur_ore.png"),
	"meat": preload("res://assets/sprites/items/meat.png"),
	"captured_deer": preload("res://assets/sprites/items/captured_deer.png"),
	# 가공물/완성품/가공식품(INBOX #87~#90) 아이콘 (INBOX #91, 파이썬 절차적 생성).
	"plank": preload("res://assets/sprites/items/plank.png"),
	"stone_block": preload("res://assets/sprites/items/stone_block.png"),
	"iron": preload("res://assets/sprites/items/iron.png"),
	"charcoal": preload("res://assets/sprites/items/charcoal.png"),
	"gunpowder": preload("res://assets/sprites/items/gunpowder.png"),
	"ammo": preload("res://assets/sprites/items/ammo.png"),
	"cooked_rice": preload("res://assets/sprites/items/cooked_rice.png"),
	"cooked_meat": preload("res://assets/sprites/items/cooked_meat.png"),
	# 나무벽/나무문/석제벽(INBOX #100 레시피, #101 아이콘) — 파이썬 절차적 생성.
	"wood_wall": preload("res://assets/sprites/items/wood_wall.png"),
	"wood_door": preload("res://assets/sprites/items/wood_door.png"),
	"stone_wall": preload("res://assets/sprites/items/stone_wall.png"),
	# 도구도 인벤토리 버리기(INBOX #31)로 바닥에 떨어질 수 있어서 함께 추가했다 —
	# world.gd의 TOOL_ICONS와 같은 텍스처를 재사용한다.
	"gun": preload("res://assets/sprites/tools/gun.png"),
	"axe": preload("res://assets/sprites/tools/axe.png"),
	"pickaxe": preload("res://assets/sprites/tools/pickaxe.png"),
	"fishing_rod": preload("res://assets/sprites/tools/fishing_rod.png"),
	# 나무(INBOX #79/#80)는 32x32 아이템 아이콘이 따로 없어서, 벌목 포인트(logging_point)와
	# 같은 96x128 tree.png를 재사용한다 — 다른 아이템과 화면 크기가 맞도록 아래
	# ITEM_ICON_SCALE_OVERRIDES에서만 별도로 축소한다(새 그림을 만들지 않음).
	"wood": preload("res://assets/sprites/logging_point/tree.png"),
	# 모래/구리광석(INBOX #103 아이템, INBOX #104 전용 그림) — 파이썬 절차적 생성.
	"sand": preload("res://assets/sprites/items/sand.png"),
	"copper_ore": preload("res://assets/sprites/items/copper_ore.png"),
	# 강철/유리/구리 + 못/경첩/톱니바퀴/구리선/유리병(INBOX #105~#106 아이템, INBOX #107
	# 전용 그림) — 파이썬 절차적 생성.
	"steel": preload("res://assets/sprites/items/steel.png"),
	"glass": preload("res://assets/sprites/items/glass.png"),
	"copper": preload("res://assets/sprites/items/copper.png"),
	"nail": preload("res://assets/sprites/items/nail.png"),
	"hinge": preload("res://assets/sprites/items/hinge.png"),
	"gear": preload("res://assets/sprites/items/gear.png"),
	"copper_wire": preload("res://assets/sprites/items/copper_wire.png"),
	"glass_bottle": preload("res://assets/sprites/items/glass_bottle.png"),
}

## tree.png처럼 원본 아이콘 자체가 32px 규격이 아닌 경우에만 스프라이트 스케일을
## 덮어쓴다(다른 아이템은 씬 기본 scale=0.9를 그대로 쓴다).
const ITEM_ICON_SCALE_OVERRIDES := {
	"wood": Vector2(0.34, 0.34),
}

@export var item_name: String = ""
@export var item_amount: int = 1

@onready var sprite: Sprite2D = $Sprite

## world.gd가 스폰 직후 채워준다 (다른 상호작용 오브젝트와 같은 패턴).
var player_ref: Node2D = null

var _picked_up: bool = false


func _ready() -> void:
	if ITEM_ICONS.has(item_name):
		sprite.texture = ITEM_ICONS[item_name]
	if ITEM_ICON_SCALE_OVERRIDES.has(item_name):
		sprite.scale = ITEM_ICON_SCALE_OVERRIDES[item_name]


func _process(_delta: float) -> void:
	if _picked_up or player_ref == null:
		return
	if global_position.distance_to(player_ref.global_position) <= PICKUP_RADIUS:
		# 인벤토리 공간이 부족하면 들어가는 만큼만 줍고 나머지는 바닥에 남긴다(INBOX #98) —
		# 이전에는 공간과 무관하게 항상 queue_free()해서 다 못 들어간 만큼이 통째로
		# 증발했다. 남은 수량이 있는 한 다음 프레임에 다시 시도한다.
		var picked: int = InventoryData.add_item(item_name, item_amount)
		item_amount -= picked
		if item_amount <= 0:
			_picked_up = true
			queue_free()
