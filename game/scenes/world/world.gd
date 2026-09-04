extends Node2D

const MOVE_SPEED := 220.0

## 기본 소총 스탯 (DESIGN.md "총기 스탯" 절 그대로 적용)
const GUN_RANGE := 800.0
const GUN_DAMAGE := 25
const GUN_FIRE_INTERVAL := 0.5  # 초당 2발
const GUN_BULLET_SPEED := 2200.0
const GUN_SPREAD_IDLE_DEG := 1.0
const GUN_SPREAD_MOVE_DEG := 8.0
const GUN_RECOIL_PER_SHOT := 0.15
const GUN_RECOIL_MAX := 0.6
const GUN_RECOIL_DECAY_PER_SEC := 2.0
const GUN_MAGAZINE_SIZE := 8
const GUN_RELOAD_TIME := 1.2  # "약간의 시간 소요" — AI가 임의로 정함, 밸런스는 나중에 조정

## 낮/밤 화면 밝기 (INBOX #13). TimeData.phase_progress()에 맞춰 두 색 사이를 보간한다.
const DAY_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const NIGHT_COLOR := Color(0.25, 0.28, 0.48, 1.0)

const BulletScene := preload("res://scenes/bullet/bullet.tscn")
const DeerScene := preload("res://scenes/deer/deer.tscn")
const GatheringPointScene := preload("res://scenes/resource_point/gathering_point.tscn")
const MiningPointScene := preload("res://scenes/resource_point/mining_point.tscn")
const MiningPointStoneScene := preload("res://scenes/resource_point/mining_point_stone.tscn")
const MiningPointSulfurScene := preload("res://scenes/resource_point/mining_point_sulfur.tscn")
const MiningPointSandScene := preload("res://scenes/resource_point/mining_point_sand.tscn")
const MiningPointCopperScene := preload("res://scenes/resource_point/mining_point_copper.tscn")
const LoggingPointScene := preload("res://scenes/resource_point/logging_point.tscn")

## 채광 포인트 종류별 스폰 가중치 (INBOX #84, #103으로 모래/구리광석 추가). DESIGN.md
## "예시 자원"이 "돌이 가장 흔하고 철광석, 유황광석 순으로 희귀해짐"이라고만 정해서,
## 정확한 수치는 재량으로 정함. 모래/구리광석은 강철/전기 테크의 기반 재료라 INBOX #103
## 원문 제안대로 유황광석과 비슷한 비중으로 잡았다(모래는 조금 더 흔하게, 구리광석은
## 조금 더 희귀하게).
const MINING_POINT_WEIGHTS := [
	{"scene": MiningPointStoneScene, "weight": 50.0},
	{"scene": MiningPointScene, "weight": 25.0},
	{"scene": MiningPointSulfurScene, "weight": 8.0},
	{"scene": MiningPointSandScene, "weight": 10.0},
	{"scene": MiningPointCopperScene, "weight": 7.0},
]
const FarmPlotScene := preload("res://scenes/farm_plot/farm_plot.tscn")
const RanchZoneScene := preload("res://scenes/ranch_zone/ranch_zone.tscn")
const ProcessingTableScene := preload("res://scenes/processing_table/processing_table.tscn")
const SmeltingFurnaceScene := preload("res://scenes/smelting_furnace/smelting_furnace.tscn")
const CookingTableScene := preload("res://scenes/cooking_table/cooking_table.tscn")
const CookingStoveScene := preload("res://scenes/cooking_stove/cooking_stove.tscn")
const StorageChestScene := preload("res://scenes/storage_chest/storage_chest.tscn")
const DroppedItemScene := preload("res://scenes/dropped_item/dropped_item.tscn")

const DEER_COUNT := 6
const DEER_SPAWN_RADIUS := 1600.0
const DEER_MIN_DISTANCE_FROM_PLAYER := 300.0

const RESOURCE_POINT_COUNT := 5
const RESOURCE_SPAWN_RADIUS := 1400.0
const RESOURCE_MIN_DISTANCE_FROM_PLAYER := 200.0
## resource_point.gd의 INTERACT_RADIUS(70) 두 개 합(140)보다 충분히 커야 두 포인트의
## Prompt 라벨/좌클릭 판정이 겹치지 않는다 (INBOX #115 — 겹쳐 스폰돼 좌클릭 한 번에
## 둘 다 채집되던 버그).
const RESOURCE_MIN_DISTANCE_BETWEEN_POINTS := 220.0

## 밭은 채집/채광 포인트처럼 흩어놓지 않고, DESIGN.md "밭(정해진 구역)" 요구대로
## 스폰 지점 기준 항상 같은 자리에 고정된 격자로 배치한다.
const FARM_PLOT_COLUMNS := 3
const FARM_PLOT_ROWS := 2
const FARM_PLOT_SPACING := 120.0
const FARM_PLOT_ORIGIN := Vector2(500.0, -400.0)

## 목장 구역도 밭과 같은 이유(DESIGN.md "정해진 구역")로 스폰 지점 기준 고정 오프셋에 둔다.
const RANCH_ZONE_ORIGIN := Vector2(-650.0, -300.0)

## 가공대(INBOX #87)도 밭/목장과 같은 이유로 스폰 지점 기준 고정 오프셋에 둔다. 위치는
## 재량 — 밭/목장 구역과 겹치지 않는 남동쪽에 둔다.
const PROCESSING_TABLE_ORIGIN := Vector2(300.0, 500.0)

## 제련로(INBOX #88)는 가공대와 같은 가공 라인이지만 별개 오브젝트라서(DESIGN.md), 가공대
## 근처(같은 남동쪽 구역)에 두되, 두 INTERACT_RADIUS(각 90)의 합보다 충분히 멀리 떨어뜨려
## 프롬프트/상호작용이 겹치지 않게 한다.
const SMELTING_FURNACE_ORIGIN := Vector2(650.0, 650.0)

## 조리대/조리용 화로(INBOX #90)는 가공 라인(가공대/제련로, 남동쪽)과 겹치지 않게 반대편
## 남서쪽에 둔다. 서로(조리대↔화로)도, 목장 구역(RANCH_ZONE_ORIGIN)과도 INTERACT_RADIUS
## 합보다 충분히 떨어뜨렸다.
const COOKING_TABLE_ORIGIN := Vector2(-300.0, 500.0)
const COOKING_STOVE_ORIGIN := Vector2(-650.0, 650.0)

## 저장 상자(INBOX #96)는 다른 작업대들(가공/조리 라인, y=500~650)과 INTERACT_RADIUS 합보다
## 충분히 떨어지도록 그 사이 남쪽 더 먼 자리에 둔다. 처음엔 비어 있다 — 재료를 미리
## 999개씩 채워 넣는 건 INBOX #97의 몫이다(DESIGN.md 결정 로그 참고).
const STORAGE_CHEST_ORIGIN := Vector2(0.0, 850.0)

## 건축 격자 배치 시스템 (INBOX #119). 충돌(그리드/방 감지)과 스프라이트 표시 크기가
## 반드시 같은 값이어야 한다(DESIGN.md "건축/방 시스템" 2026-09-05 확정, INBOX #133).
## #125(64→16)는 시각 크기까지 같이 16으로 묶여 벽이 손톱만 하게 보였고(#132로 발견),
## #132는 그걸 고치려고 시각 크기만 32로 분리했다가 이번엔 충돌 칸(16)과 표시 크기(32)가
## 어긋나서 인접(비겹침) 배치가 화면에서는 겹쳐 보이고, 반대로 실제로 안 겹치게(화면
## 기준) 놓으면 충돌 격자에 빈 칸이 생겨 방이 안 막히는 착시/버그가 났다(#133). 그래서
## 다시 값 하나로 합친다 — 벽/문/창문 원본 아이콘이 전부 32×32이므로 32.0으로 두면
## 스프라이트 scale이 정확히 1.0(확대/축소 없이 원본 해상도)이 되면서 동시에 충돌
## CollisionShape2D 크기와도 1:1로 맞아떨어진다(잔디 타일 64x64의 약수라 격자 정렬도
## 유지됨). 인접 설치가 화면에서도 이음매 없이 붙어 보이고, 그 이음매를 실제로도 지나갈
## 수 없다.
const BUILD_GRID_SIZE := 32.0

## 격자에 설치 가능한 아이템(INBOX #119가 나무벽, #120이 나무문으로 프레임워크를 검증,
## #121이 나머지 5종 — 석제벽/강철벽/강철문/창문 — 을 아이템 키만 추가해 연결). 아이콘은
## 이미 있는 아이템 아이콘(INBOX #101/#109)을 격자 칸 크기로 확대해서 재사용한다.
## `is_door: true`면 `_spawn_structure()`가 door.gd(Door)를 붙여서 여닫을 수 있는
## 구조물로 만든다(그 외에는 항상 막힌 벽 — `window`도 지금은 벽처럼 막히기만 한다,
## DESIGN.md에 "안이 보이는 벽" 취급은 나중 과제로 명시됨).
const BUILDABLE_STRUCTURES := {
	"wood_wall": {"texture": preload("res://assets/sprites/items/wood_wall.png")},
	"wood_door": {"texture": preload("res://assets/sprites/items/wood_door.png"), "is_door": true},
	"stone_wall": {"texture": preload("res://assets/sprites/items/stone_wall.png")},
	"steel_wall": {"texture": preload("res://assets/sprites/items/steel_wall.png")},
	"steel_door": {"texture": preload("res://assets/sprites/items/steel_door.png"), "is_door": true},
	"window": {"texture": preload("res://assets/sprites/items/window.png")},
}

## 플레이어는 물리 바디(CharacterBody2D)가 아니라 위치를 직접 더하는 방식으로 움직여서
## (아래 _physics_process 참고), StaticBody2D 충돌체만으로는 플레이어를 막을 수 없다 —
## deer.gd는 CharacterBody2D라 ranch_zone.gd의 담장(StaticBody2D)에 move_and_slide()로
## 자연스럽게 막히지만 플레이어는 그 경로를 안 탄다. 그래서 건축물은 (1) ranch_zone.gd와
## 같은 패턴의 실제 StaticBody2D+CollisionShape2D를 만들어 다른 물리 바디(사슴 등)와는
## 정상적으로 충돌하게 하고, (2) 플레이어 이동은 아래 _grid_occupancy를 직접 조회해
## 막는 방식을 함께 쓴다(스스로 판단해서 추가 — 근거는 이 상수 설명 참고).
const PLAYER_COLLISION_RADIUS := 16.0

## 격자 좌표(Vector2i) -> 그 칸에 설치된 건축물 Node. 벽/문 위치를 추적해서 겹침 검사와
## (나중에 #122) 방 감지가 참조할 수 있게 한다.
var _grid_occupancy: Dictionary = {}

## 방(Room) 감지 (INBOX #122, DESIGN.md "건축/방(Room) 시스템" 2026-09-05 확정).
## 벽/문이 설치되거나 제거될 때(매 프레임이 아니라 변경 시점에만) _recompute_rooms()가
## 다시 계산한다. 탐색 상한(한 방이 가질 수 있는 최대 칸 수) — 이 안에서 flood-fill이
## 스스로 끝나면 "막힌 공간"(방), 상한을 넘기면 바깥 들판으로 새는 것으로 보고 방 아님.
## (INBOX #133) BUILD_GRID_SIZE를 16→32(2배)로 되돌리면서 같은 물리적 면적이 1/4
## (=2x2)만큼 적은 칸으로 쪼개지므로, 기존과 같은 최대 방 면적을 유지하려면 상한도
## 1/4로 낮춰야 한다(6400 → 1600).
const ROOM_FLOOD_CELL_CAP := 1600
const ROOM_DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## CraftingStation.get_title() 문자열 -> 방 카테고리. "주방"은 조리대/조리용 화로 둘 다
## 이 카테고리로 묶이지만, 실제 "주방" 판정에는 둘 다 있어야 한다(아래 _classify_room 참고).
const ROOM_CATEGORY_BY_STATION_TITLE := {
	"가공대": "제작소",
	"제련로": "대장간",
	"조리대": "주방",
	"조리용 화로": "주방",
}

## 방 ID -> {"cells": Array[Vector2i], "category": String}. 카테고리는 "잡실"이면 방
## 혜택이 없는 방(둘러싸인 야외 취급, DESIGN.md 2026-09-05 확정)이다.
var _rooms: Dictionary = {}
## 격자 좌표(Vector2i) -> 방 ID. 방으로 인식되지 않은 칸(트인 들판, 벽/문이 놓인 칸
## 자신)은 이 딕셔너리에 없다.
var _cell_to_room: Dictionary = {}
var _next_room_id: int = 1
## 배치 모드 미리보기(반투명 고스트) 스프라이트.
var _build_ghost: Sprite2D = null
## 배치 모드 중 우클릭하면 true가 되어 고스트/설치를 잠깐 끈다. 핫바를 다시 고르면
## (_select_hotbar가 호출되면) 초기화된다 — "우클릭 또는 도구를 바꾸면 배치 모드를
## 취소한다" 요구사항.
var _build_placement_cancelled: bool = false

## 건설 해제 모드(INBOX #128) — X키로 토글. 배치 모드와 동시에 켜질 수 없으므로,
## `is_build_placement_active()`가 이 값을 확인해서 켜져 있는 동안은 배치 관련 동작
## (고스트 표시/설치 확정)을 전부 비활성화한다.
var _deconstruct_mode: bool = false
## 지금 마우스 아래 격자 칸에 있어서 반투명 빨간색으로 덧칠된 구조물 노드(없으면 null).
## 마우스가 다른 칸으로 옮겨가거나 모드가 꺼지면 원래 색으로 되돌리는 데 쓴다.
var _deconstruct_highlighted_node: Node = null
const DECONSTRUCT_TINT := Color(1.0, 0.35, 0.35, 1.0)

## InventoryData가 저장하는 아이템 키(내부 이름) -> 화면 표시 이름.
const ITEM_LABELS := {
	"rice_seed": "벼 씨앗",
	"rice": "벼",
	"iron_ore": "철광석",
	"stone": "돌",
	"sulfur_ore": "유황광석",
	"sand": "모래",
	"copper_ore": "구리광석",
	"wood": "나무",
	"captured_deer": "포획된 사슴",
	"meat": "고기",
	"plank": "판자",
	"stone_block": "석재",
	"iron": "철",
	"charcoal": "숯",
	"gunpowder": "화약",
	"ammo": "탄약",
	"cooked_rice": "밥",
	"cooked_meat": "익힌고기",
	"wood_wall": "나무벽",
	"wood_door": "나무문",
	"stone_wall": "석제벽",
	"steel": "강철",
	"glass": "유리",
	"copper": "구리",
	"gun": "총",
	"axe": "도끼",
	"pickaxe": "곡괭이낫",
	"fishing_rod": "낚싯대",
	"nail": "못",
	"hinge": "경첩",
	"gear": "톱니바퀴",
	"copper_wire": "구리선",
	"glass_bottle": "유리병",
	"steel_pickaxe": "강철곡괭이낫",
	"steel_axe": "강철도끼",
	"steel_fishing_rod": "강철낚싯대",
	"steel_wall": "강철벽",
	"steel_door": "강철문",
	"steel_chest": "강철 상자",
	"window": "창문",
	"steel_armor": "강철 갑옷",
	"battery": "배터리",
	"lamp": "조명",
	"generator": "발전기",
	"feed": "사료",
	"water_pump": "급수 장치",
}

## 아이템 키 -> 카테고리 (INBOX #83, DESIGN.md "아이템 카테고리 / 제작 테크" 절 참고).
## 식재료 하위분류(곡물/육류/채소)는 "식재료"로 묶지 않고 하위분류 이름을 그대로 카테고리
## 값으로 쓴다. "가축"은 DESIGN.md가 나열한 카테고리 목록에는 없지만, 포획된 사슴처럼
## 원재료/가공물/완성품/식재료 어디에도 맞지 않는 살아있는 사육 대상을 표현하려고
## 새로 추가했다(DESIGN.md의 "등"이 허용하는 확장).
const ITEM_CATEGORIES := {
	"rice_seed": "원재료",
	"rice": "곡물",
	"iron_ore": "원재료",
	"stone": "원재료",
	"sulfur_ore": "원재료",
	"sand": "원재료",
	"copper_ore": "원재료",
	"wood": "원재료",
	"captured_deer": "가축",
	"meat": "육류",
	"plank": "가공물",
	"stone_block": "가공물",
	"iron": "가공물",
	"charcoal": "가공물",
	"gunpowder": "가공물",
	"ammo": "완성품",
	"cooked_rice": "가공식품",
	"cooked_meat": "가공식품",
	"wood_wall": "완성품",
	"wood_door": "완성품",
	"stone_wall": "완성품",
	"steel": "가공물",
	"glass": "가공물",
	"copper": "가공물",
	"gun": "도구",
	"axe": "도구",
	"pickaxe": "도구",
	"fishing_rod": "도구",
	"nail": "가공물",
	"hinge": "가공물",
	"gear": "가공물",
	"copper_wire": "가공물",
	"glass_bottle": "가공물",
	"steel_pickaxe": "도구",
	"steel_axe": "도구",
	"steel_fishing_rod": "도구",
	"steel_wall": "완성품",
	"steel_door": "완성품",
	"steel_chest": "완성품",
	"window": "완성품",
	"steel_armor": "완성품",
	"battery": "완성품",
	"lamp": "완성품",
	"generator": "완성품",
	"feed": "가공식품",
	"water_pump": "완성품",
}

## 도구 아이템(INBOX #22). 순서대로 핫바 시작 슬롯(1~4번 키)에 지급된다.
## 곡괭이낫(pickaxe) 하나로 채집+채광을 둘 다 한다(INBOX #25 — 한때 별도 "낫" 아이템으로
## 나눴던 것을 다시 합침, DESIGN.md 참고). 도끼는 INBOX #80부터 나무(LoggingPointScene)를
## 벌목 대상으로 갖는다. 낚싯대는 아직 낚시 스팟이 없어 좌클릭 동작은 #23에서 최소
## 반응만 연결했다(DESIGN.md "범위 밖" 참고).
const TOOL_KEYS := ["gun", "axe", "pickaxe", "fishing_rod"]
const TOOL_ICONS := {
	"gun": preload("res://assets/sprites/tools/gun.png"),
	"axe": preload("res://assets/sprites/tools/axe.png"),
	"pickaxe": preload("res://assets/sprites/tools/pickaxe.png"),
	"fishing_rod": preload("res://assets/sprites/tools/fishing_rod.png"),
}

## "사용하는" 모션 텍스처가 유지되는 시간. GUN_FIRE_INTERVAL(0.5초)보다 짧아야 연사 중에도
## "들고 있는" 자세로 돌아왔다가 다시 반짝이는 것이 보인다.
const GUN_MUZZLE_FLASH_DURATION := 0.12
## 도끼로 패거나 곡괭이낫으로 채광/채집하거나 낚싯대로 낚시하는 동작이 눈에 보이는 시간.
## 총 발사보다 한 동작이 느려 보여야 자연스러워서 총의 발사열 지속 시간보다 길게 잡았다 —
## DESIGN.md에 구체적 수치가 없어 임의로 정함.
const AXE_CHOP_FLASH_DURATION := 0.25

## 다른 플레이어에게 내 위치/방향을 보내는 주기 (INBOX #14). 매 물리 프레임(60Hz)마다
## 보내면 LAN 기준으로도 낭비라, 10Hz로 줄인다 — 위치는 unreliable 채널이라 중간에
## 패킷이 빠져도 다음 것으로 자연히 보정된다.
const STATE_BROADCAST_INTERVAL := 0.1

@onready var player_sprite: AnimatedSprite2D = $Player
@onready var remote_players_root: Node2D = $RemotePlayers
@onready var camera: Camera2D = $Camera2D
@onready var pause_menu: Control = $UI/PauseMenu
@onready var ammo_panel: PanelContainer = $UI/HUD/AmmoPanel
@onready var ammo_label: Label = $UI/HUD/AmmoPanel/AmmoLabel
@onready var time_label: Label = $UI/HUD/TimePanel/TimeLabel
@onready var net_panel: PanelContainer = $UI/HUD/NetPanel
@onready var net_label: Label = $UI/HUD/NetPanel/NetLabel
@onready var room_overlay_toggle: Button = $UI/HUD/RoomOverlayToggle
@onready var deconstruct_mode_panel: PanelContainer = $UI/HUD/DeconstructModePanel
@onready var room_overlay: RoomOverlay = $RoomOverlay
@onready var fog_of_war: FogOfWar = $FogOfWar
@onready var day_night_modulate: CanvasModulate = $DayNightModulate
@onready var rain_overlay: ColorRect = $UI/RainOverlay
@onready var ui_layer: CanvasLayer = $UI
@onready var inventory_window: Control = $UI/InventoryWindow
@onready var general_grid: GridContainer = $UI/InventoryWindow/CenterContainer/Panel/VBoxContainer/GeneralGrid
@onready var equipment_grid: GridContainer = $UI/InventoryWindow/CenterContainer/Panel/VBoxContainer/EquipmentGrid
@onready var hotbar_bar: HBoxContainer = $UI/HUD/HotbarBar

## 장비 슬롯 부위 표시 이름 (InventoryData.EQUIPMENT_SLOT_TYPES와 같은 순서).
const EQUIPMENT_LABELS := ["모자", "상의", "하의", "신발", "목걸이", "목걸이", "반지", "반지", "가방"]

var _variant: String = "green"
var _facing: String = "south"
## 시야/전장의 안개(INBOX #135)가 참고하는 연속 조준 방향(정규화 벡터) — `_facing`(4방향
## 문자열)과 달리 부채꼴 콘 각도 계산에 그대로 쓸 수 있는 실제 각도를 담는다. 기본값은
## `_facing`의 기본값(south)과 맞춘다.
var _aim_direction: Vector2 = Vector2.DOWN
var _paused: bool = false
var _inventory_open: bool = false
## 가공대/제련로 등 생산 라인 작업대가 공유하는 범용 제작 창이 열려 있는지 (INBOX #87).
var _crafting_open: bool = false
## 지금 열려 있는 제작 창의 레시피 목록 (open_crafting_window()가 채운다).
var _crafting_recipes: Array = []
## 지금 열려 있는 제작 창이 보여주는 작업대 인스턴스 (CraftingStation, INBOX #99). 배치
## 시작/수령 버튼이 이 인스턴스의 start_batch()/collect_output()을 직접 호출한다 —
## _storage_chest와 같은 패턴(레시피처럼 값으로 복사하지 않고 노드 참조로 그때그때 조회).
var _crafting_station: Node = null
var _general_slot_labels: Array = []
var _equipment_slot_labels: Array = []
## 핫바 9칸 셀(각 원소 {"panel": PanelContainer, "item_label": Label, "number_label": Label}).
var _hotbar_cells: Array = []
## 범용 제작 창(코드로 조립, INBOX #87 — _build_crafting_window() 참고).
var _crafting_window: Control
var _crafting_title_label: Label
var _crafting_list: VBoxContainer
## 제작 실패(인벤토리 공간 부족) 시 잠깐 보여주는 메시지 (INBOX #98, _storage_message_label과
## 같은 패턴).
var _crafting_message_label: Label
var _crafting_message_timer: float = 0.0
## 저장 상자(INBOX #96) UI가 열려 있는지, 지금 어느 상자 인스턴스를 보여주고 있는지.
var _storage_open: bool = false
var _storage_chest: Node = null
## 범용 저장 상자 창(코드로 조립, INBOX #96 — _build_storage_window() 참고, 가공대의
## 범용 제작 창과 같은 이유로 상자마다 새 UI를 만들지 않고 이 하나를 재사용한다).
var _storage_window: Control
var _storage_title_label: Label
var _storage_list: VBoxContainer
var _storage_message_label: Label
var _storage_message_timer: float = 0.0
var _selected_hotbar_index: int = 0
## 지금 손에 든 도구 키("gun"/"axe"/"pickaxe"/"fishing_rod") 또는 빈손("").
var _held_tool: String = ""
var _hotbar_normal_style: StyleBoxFlat
var _hotbar_selected_style: StyleBoxFlat
var _ammo_type: String = "normal"
var _fire_cooldown: float = 0.0
## 이미 스폰된 리소스 포인트들의 위치 (INBOX #115 — 새 포인트가 기존 포인트와 겹치지
## 않게 거리 확인용). _spawn_resource_points() 시작 시 비우고 매번 채운다.
var _spawned_resource_positions: Array[Vector2] = []
var _recoil: float = 0.0
## 탄종별로 완전히 분리된 탄창 (INBOX #36 — 기본탄/마취탄이 잔여 발수를 공유하면 안 됨).
var _ammo_in_magazine: Dictionary = {"normal": GUN_MAGAZINE_SIZE, "tranq": GUN_MAGAZINE_SIZE}
var _is_reloading: bool = false
var _reload_timer: float = 0.0
## 재장전이 시작된 탄종 — 재장전 도중 우클릭으로 탄종을 바꿔도 엉뚱한 탄창이 채워지지 않게 기억해둔다.
var _reloading_ammo_type: String = "normal"
## 지금 "사용하는" 모션 애니메이션이 재생 중이면 0보다 크다 (INBOX #37/#38). 매 물리 프레임
## 줄어들다가 0이 되면 _current_animation_name()이 다시 지금 손에 든 도구의 "들고 있는"
## 애니메이션을 고른다.
var _tool_use_flash_timer: float = 0.0
## 곡괭이낫이 "쓰는" 모션 중일 때 채광("mining")인지 채집("gathering")인지 (INBOX #44).
## play_pickaxe_use()가 호출될 때마다 갱신되고, _current_animation_name()이
## _tool_use_flash_timer > 0인 동안 이 값으로 pickaxe_mining_*/pickaxe_gathering_* 중
## 어느 애니메이션을 재생할지 고른다.
var _pickaxe_use_kind: String = "mining"
var _is_moving: bool = false
var _was_moving: bool = false
var _state_broadcast_timer: float = 0.0
## peer id -> 그 플레이어를 대신 그리는 Sprite2D (INBOX #14, remote_players_root의 자식).
var _remote_sprites: Dictionary = {}
## peer id -> 마지막으로 그 스프라이트에 로드한 텍스처 경로 (매 프레임 load()하지 않기 위한 캐시).
var _remote_tex_paths: Dictionary = {}


func _ready() -> void:
	var character := CharacterData.get_character(CharacterData.active_slot_index)
	_variant = character.get("variant", "green")
	player_sprite.sprite_frames = _build_player_sprite_frames(_variant)
	_update_player_animation()
	_update_ammo_label()
	_spawn_deer()
	_spawn_resource_points()
	_spawn_farm_plots()
	_spawn_ranch_zone()
	_spawn_processing_table()
	_spawn_smelting_furnace()
	_spawn_cooking_table()
	_spawn_cooking_stove()
	_spawn_storage_chest()
	_ensure_starting_tools()
	_create_build_ghost()
	_build_inventory_slots()
	_build_hotbar()
	_build_crafting_window()
	_build_storage_window()
	InventoryData.changed.connect(_refresh_inventory_window)
	InventoryData.changed.connect(_refresh_hotbar)
	InventoryData.changed.connect(_revalidate_held_hotbar_slot)
	_select_hotbar(0)
	TimeData.phase_changed.connect(_on_time_phase_changed)
	TimeData.day_changed.connect(_on_time_day_changed)
	TimeData.weather_changed.connect(_on_time_weather_changed)
	_update_time_label()
	rain_overlay.visible = TimeData.is_raining
	_setup_networking()
	room_overlay.setup(self, BUILD_GRID_SIZE)
	room_overlay_toggle.toggled.connect(_on_room_overlay_toggle_toggled)
	fog_of_war.setup(self, BUILD_GRID_SIZE)


func _process(delta: float) -> void:
	var t := TimeData.phase_progress()
	day_night_modulate.color = DAY_COLOR.lerp(NIGHT_COLOR, t) if TimeData.is_day \
		else NIGHT_COLOR.lerp(DAY_COLOR, t)
	## 건축 배치 고스트(INBOX #119)는 물리 프레임이 아니라 렌더 프레임마다 갱신한다 —
	## `_physics_process`는 QA 스크립트가 카메라를 직접 조작할 때 꺼두는 경우가 있어서
	## (물리 처리를 끄면 마우스 추종도 함께 멈추는 기존 패턴), 여기 두면 그런 상황에도
	## 고스트가 마우스를 계속 따라간다.
	if _build_ghost != null:
		if _paused or _inventory_open or _crafting_open or _storage_open:
			_build_ghost.visible = false
		else:
			_update_build_ghost()
	## 건설 해제 하이라이트(INBOX #128)도 같은 이유로 렌더 프레임마다 갱신한다.
	_update_deconstruct_highlight()
	if _storage_message_timer > 0.0:
		_storage_message_timer -= delta
		if _storage_message_timer <= 0.0:
			_storage_message_label.visible = false
	if _crafting_message_timer > 0.0:
		_crafting_message_timer -= delta
		if _crafting_message_timer <= 0.0:
			_crafting_message_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _storage_open:
			close_storage_window()
		elif _crafting_open:
			close_crafting_window()
		elif _inventory_open:
			_set_inventory_open(false)
		else:
			_set_paused(not _paused)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E \
			and not _paused and not _crafting_open and not _storage_open:
		_set_inventory_open(not _inventory_open)
	elif event is InputEventKey and event.pressed and not event.echo and not _paused and not _inventory_open \
			and not _crafting_open and not _storage_open and event.keycode >= KEY_1 and event.keycode <= KEY_9:
		_select_hotbar(event.keycode - KEY_1)
	elif event is InputEventKey and event.pressed and not event.echo and not _paused and not _inventory_open \
			and not _crafting_open and not _storage_open and event.keycode == KEY_R and _held_tool == "gun":
		_start_reload()
	elif event is InputEventKey and event.pressed and not event.echo and not _paused and not _inventory_open \
			and not _crafting_open and not _storage_open and event.keycode == KEY_X:
		## 건설 해제 모드 토글(INBOX #128). 배치 모드(BUILDABLE_STRUCTURES를 손에 든 상태)와
		## 동시에 켜질 수 없다 — `is_build_placement_active()`가 `_deconstruct_mode`를
		## 확인하므로, 여기서 켜는 순간 배치 모드의 고스트/설치 확정은 자동으로 비활성화된다.
		_deconstruct_mode = not _deconstruct_mode
		deconstruct_mode_panel.visible = _deconstruct_mode
	elif event is InputEventMouseButton and event.pressed and not _paused and not _inventory_open \
			and not _crafting_open and not _storage_open and event.button_index == MOUSE_BUTTON_RIGHT and _held_tool == "gun":
		_ammo_type = "tranq" if _ammo_type == "normal" else "normal"
		_update_ammo_label()
	elif event is InputEventMouseButton and event.pressed and not _paused and not _inventory_open \
			and not _crafting_open and not _storage_open and event.button_index == MOUSE_BUTTON_LEFT and _deconstruct_mode:
		## 건설 해제 모드 좌클릭(INBOX #128) — 다른 도구 사용/배치 확정보다 먼저 처리해서
		## 이 모드가 켜져 있는 동안은 손에 무엇을 들었든 좌클릭이 항상 철거로만 동작한다.
		_try_deconstruct_structure()
	elif event is InputEventMouseButton and event.pressed and not _paused and not _inventory_open \
			and not _crafting_open and not _storage_open and event.button_index == MOUSE_BUTTON_LEFT and _held_tool == "axe":
		## 도끼는 INBOX #43부터 옆 아이콘이 아니라 캐릭터 애니메이션 프레임 자체
		## (axe_chop_*)로 패는 모션을 보여준다 (총(#42)과 같은 패턴).
		_tool_use_flash_timer = AXE_CHOP_FLASH_DURATION
	elif event is InputEventMouseButton and event.pressed and not _paused and not _inventory_open \
			and not _crafting_open and not _storage_open and event.button_index == MOUSE_BUTTON_LEFT and _held_tool == "pickaxe":
		## 곡괭이낫은 INBOX #73부터 도끼(#43)와 같은 방식으로, 채집/채광 대상이 없어도
		## (허공에 대고) 좌클릭하면 항상 스윙 모션이 나가야 한다 (DESIGN.md "생활 스킬 —
		## 채집 계열": 총/도끼/곡괭이낫은 대상 유무와 무관하게 항상 사용 모션 — 근접무기
		## 확장 계획 근거). 실제 채광/채집 판정(어느 kind인지, 아이템 드롭 등)은 여전히
		## resource_point.gd가 담당한다 — 이 브랜치는 `_pickaxe_use_kind`를 건드리지 않고
		## 모션 타이머만 켠다. 대상이 실제로 있으면 resource_point.gd의 _harvest()가 같은
		## 입력 이벤트 처리 중에 play_pickaxe_use(kind)로 올바른 kind를 덮어써 준다.
		_tool_use_flash_timer = AXE_CHOP_FLASH_DURATION
	elif event is InputEventMouseButton and event.pressed and not _paused and not _inventory_open \
			and not _crafting_open and not _storage_open and event.button_index == MOUSE_BUTTON_LEFT and _held_tool == "fishing_rod":
		## 낚싯대는 INBOX #45부터 옆 아이콘이 아니라 캐릭터 애니메이션 프레임 자체
		## (fishing_rod_fishing_*)로 낚시하는 모션을 보여준다 (도끼(#43)와 같은 패턴).
		_tool_use_flash_timer = AXE_CHOP_FLASH_DURATION
	elif event is InputEventMouseButton and event.pressed and not _paused and not _inventory_open \
			and not _crafting_open and not _storage_open and event.button_index == MOUSE_BUTTON_LEFT \
			and not _deconstruct_mode and not _build_placement_cancelled and BUILDABLE_STRUCTURES.has(get_held_item()):
		## 건축 배치 모드(INBOX #119) — 격자에 스냅된 칸에 좌클릭으로 설치 확정.
		_try_place_structure()
	elif event is InputEventMouseButton and event.pressed and not _paused and not _inventory_open \
			and not _crafting_open and not _storage_open and event.button_index == MOUSE_BUTTON_RIGHT \
			and BUILDABLE_STRUCTURES.has(get_held_item()):
		## 우클릭으로 배치 모드 취소(INBOX #119) — 도구를 바꾸면 자동으로 취소되는 것과
		## 별개로, 같은 아이템을 손에 든 채로도 취소할 수 있어야 한다.
		_build_placement_cancelled = true


func _physics_process(delta: float) -> void:
	if _paused or _inventory_open or _crafting_open or _storage_open:
		return

	var input_dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_D):
		input_dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		input_dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		input_dir.y -= 1.0
	_is_moving = input_dir.length() > 0.0
	if _is_moving:
		input_dir = input_dir.normalized()
	_move_player_with_grid_collision(input_dir * MOVE_SPEED * delta)

	var to_mouse := get_global_mouse_position() - player_sprite.global_position
	if to_mouse.length() > 1.0:
		_facing = _facing_from_direction(to_mouse)
		_aim_direction = to_mouse.normalized()

	if _is_moving != _was_moving or player_sprite.animation != _current_animation_name():
		_was_moving = _is_moving
		_update_player_animation()

	camera.global_position = player_sprite.global_position

	_recoil = maxf(0.0, _recoil - GUN_RECOIL_DECAY_PER_SEC * delta)
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta
	if _tool_use_flash_timer > 0.0:
		_tool_use_flash_timer -= delta
	if _is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_is_reloading = false
			_ammo_in_magazine[_reloading_ammo_type] = GUN_MAGAZINE_SIZE
			_update_ammo_label()
	if _held_tool == "gun" and not _deconstruct_mode and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
			and _fire_cooldown <= 0.0 and not _is_reloading and _ammo_in_magazine[_ammo_type] > 0:
		_fire()

	if NetworkSession.is_active():
		_state_broadcast_timer -= delta
		if _state_broadcast_timer <= 0.0:
			_state_broadcast_timer = STATE_BROADCAST_INTERVAL
			_receive_state.rpc(player_sprite.position, _facing, _variant)


## 조준 방향에 반동(위로 튐)과 탄퍼짐(이동 중이면 커짐)을 섞어서 총알을 하나 쏜다.
func _fire() -> void:
	_fire_cooldown = GUN_FIRE_INTERVAL
	_ammo_in_magazine[_ammo_type] -= 1
	_update_ammo_label()

	## "들고 있는" 캐릭터 애니메이션(gun_idle_*)을 잠깐 "발사하는" 애니메이션(gun_fire_*,
	## 총구 불꽃이 그려진 프레임)으로 바꿔서 들기/쏘기가 서로 다른 그림으로 보이게 한다
	## (INBOX #37→#42, DESIGN.md "캐릭터 애니메이션" — 옆 아이콘이 아니라 캐릭터 프레임
	## 자체가 바뀐다). _current_animation_name()/_physics_process의 애니메이션 갱신 체크가
	## 이 타이머를 보고 다음 프레임에 실제로 애니메이션을 바꾼다.
	_tool_use_flash_timer = GUN_MUZZLE_FLASH_DURATION

	var aim := get_global_mouse_position() - player_sprite.global_position
	if aim.length() < 1.0:
		aim = Vector2.RIGHT
	aim = aim.normalized()
	aim = (aim + Vector2.UP * _recoil).normalized()
	var spread_deg := GUN_SPREAD_MOVE_DEG if _is_moving else GUN_SPREAD_IDLE_DEG
	aim = aim.rotated(deg_to_rad(randf_range(-spread_deg * 0.5, spread_deg * 0.5)))

	_recoil = minf(GUN_RECOIL_MAX, _recoil + GUN_RECOIL_PER_SHOT)

	var bullet := BulletScene.instantiate()
	bullet.global_position = player_sprite.global_position
	bullet.rotation = aim.angle()
	bullet.velocity = aim * GUN_BULLET_SPEED
	bullet.max_range = GUN_RANGE
	bullet.damage = GUN_DAMAGE
	bullet.ammo_type = _ammo_type
	add_child(bullet)


## 지금 손에 든 도구 키를 밖에서 읽을 수 있게 하는 공개 접근자 (INBOX #23).
## farm_plot/resource_point/ranch_zone이 "맞는 도구를 들고 좌클릭했는가"를
## 판정할 때 이걸로 조회한다.
func get_held_tool() -> String:
	return _held_tool


## 지금 선택된 핫바 슬롯의 아이템 키(도구가 아닌 아이템도 포함)를 밖에서 읽을 수
## 있게 하는 공개 접근자 (INBOX #27). get_held_tool()은 도구(TOOL_ICONS에 있는
## 아이템)만 반환하므로, 씨앗처럼 도구가 아닌 아이템을 "손에 들었는지" 확인하려면
## 이 함수를 쓴다.
func get_held_item() -> String:
	var general_slots := InventoryData.get_general_slots()
	var slot = general_slots[_selected_hotbar_index] if _selected_hotbar_index < general_slots.size() else null
	return slot["item"] if slot != null else ""


## resource_point.gd가 실제로 채광/채집이 일어나는 순간(harvest 성공 시) 호출한다
## (INBOX #39, #44부터는 옆 아이콘이 아니라 캐릭터 애니메이션 프레임 자체
## (pickaxe_mining_*/pickaxe_gathering_*)로 표현한다 — 총(#42)/도끼(#43)와 같은 패턴).
## kind는 "mining" 또는 "gathering" — 같은 곡괭이낫이라도 두 동작이 서로 다른 그림으로
## 보여야 한다(DESIGN.md "도구 동작 표현"). 지금 손에 든 도구가 곡괭이낫이 아니면(예: 이미
## 다른 도구로 바꿔 든 뒤 신호가 늦게 온 경우) 아무 것도 하지 않는다.
func play_pickaxe_use(kind: String) -> void:
	if _held_tool != "pickaxe" or (kind != "mining" and kind != "gathering"):
		return
	_pickaxe_use_kind = kind
	_tool_use_flash_timer = AXE_CHOP_FLASH_DURATION


## 방향별 스프라이트(north/south/east/west)만 있으므로, 마우스가 가리키는
## 각도를 90도씩 4구간으로 나눠서 가장 가까운 방향 스프라이트로 바꿔 끼운다.
## 스프라이트 자체를 rotation으로 돌리면 정면(도트) 그림이 옆으로 눕는 것처럼
## 보여서 품질 기준을 통과하지 못했다 (스크린샷 QA로 확인, INBOX #4 참고).
func _facing_from_direction(direction: Vector2) -> String:
	var angle_deg := rad_to_deg(direction.angle())
	if angle_deg > -45.0 and angle_deg <= 45.0:
		return "east"
	elif angle_deg > 45.0 and angle_deg <= 135.0:
		return "south"
	elif angle_deg > -135.0 and angle_deg <= -45.0:
		return "north"
	else:
		return "west"


## 필드에 사슴 몇 마리를 흩어서 배치한다 (DESIGN.md "동물 AI": 평소 배회, 접근/피격 시 도주).
func _spawn_deer() -> void:
	for i in range(DEER_COUNT):
		var deer := DeerScene.instantiate()
		var pos := Vector2.ZERO
		for attempt in range(20):
			pos = Vector2(
				randf_range(-DEER_SPAWN_RADIUS, DEER_SPAWN_RADIUS),
				randf_range(-DEER_SPAWN_RADIUS, DEER_SPAWN_RADIUS)
			)
			if pos.distance_to(player_sprite.position) >= DEER_MIN_DISTANCE_FROM_PLAYER:
				break
		deer.global_position = pos
		deer.player_ref = player_sprite
		deer.world_ref = self
		add_child(deer)


## 필드에 채집 포인트(곡괭이낫 → 벼 씨앗), 채광 포인트(곡괭이낫 → 철), 벌목 포인트
## (도끼 → 나무, INBOX #80)를 종류별로 같은 개수씩 흩어서 배치한다 (INBOX #10).
## 포인트 종류(required_tool)에 따라 알맞은 도구 판정을 자동 적용한다(도구 선택 UI
## 없음) — resource_point.gd 참고.
func _spawn_resource_points() -> void:
	_spawned_resource_positions.clear()
	for i in range(RESOURCE_POINT_COUNT):
		_spawn_one_resource_point(GatheringPointScene)
	for i in range(RESOURCE_POINT_COUNT):
		_spawn_one_resource_point(_pick_mining_point_scene())
	for i in range(RESOURCE_POINT_COUNT):
		_spawn_one_resource_point(LoggingPointScene)


## MINING_POINT_WEIGHTS 가중치로 돌/철광석/유황광석 중 하나를 골라 반환한다 (INBOX #84).
func _pick_mining_point_scene() -> PackedScene:
	var total := 0.0
	for entry in MINING_POINT_WEIGHTS:
		total += entry["weight"]
	var roll := randf() * total
	var cumulative := 0.0
	for entry in MINING_POINT_WEIGHTS:
		cumulative += entry["weight"]
		if roll < cumulative:
			return entry["scene"]
	return MINING_POINT_WEIGHTS[-1]["scene"]


func _spawn_one_resource_point(scene: PackedScene) -> void:
	var point := scene.instantiate()
	var pos := Vector2.ZERO
	for attempt in range(20):
		pos = Vector2(
			randf_range(-RESOURCE_SPAWN_RADIUS, RESOURCE_SPAWN_RADIUS),
			randf_range(-RESOURCE_SPAWN_RADIUS, RESOURCE_SPAWN_RADIUS)
		)
		if pos.distance_to(player_sprite.position) < RESOURCE_MIN_DISTANCE_FROM_PLAYER:
			continue
		if _is_too_close_to_spawned_resources(pos):
			continue
		break
	point.global_position = pos
	point.player_ref = player_sprite
	point.world_ref = self
	add_child(point)
	_spawned_resource_positions.append(pos)


## 이미 스폰된 다른 리소스 포인트와 RESOURCE_MIN_DISTANCE_BETWEEN_POINTS보다 가까운지
## 확인한다 (INBOX #115).
func _is_too_close_to_spawned_resources(pos: Vector2) -> bool:
	for other_pos in _spawned_resource_positions:
		if pos.distance_to(other_pos) < RESOURCE_MIN_DISTANCE_BETWEEN_POINTS:
			return true
	return false


## 스폰 지점에서 고정된 오프셋에 밭 칸을 격자로 배치한다 (INBOX #11).
func _spawn_farm_plots() -> void:
	var base := player_sprite.position + FARM_PLOT_ORIGIN
	for row in range(FARM_PLOT_ROWS):
		for col in range(FARM_PLOT_COLUMNS):
			var plot := FarmPlotScene.instantiate()
			plot.global_position = base + Vector2(col * FARM_PLOT_SPACING, row * FARM_PLOT_SPACING)
			plot.player_ref = player_sprite
			plot.world_ref = self
			add_child(plot)


## 스폰 지점에서 고정된 오프셋에 목장 구역을 배치한다 (INBOX #12).
func _spawn_ranch_zone() -> void:
	var zone := RanchZoneScene.instantiate()
	zone.global_position = player_sprite.position + RANCH_ZONE_ORIGIN
	zone.player_ref = player_sprite
	zone.world_ref = self
	add_child(zone)


## 스폰 지점에서 고정된 오프셋에 가공대를 배치한다 (INBOX #87).
func _spawn_processing_table() -> void:
	var table := ProcessingTableScene.instantiate()
	table.global_position = player_sprite.position + PROCESSING_TABLE_ORIGIN
	table.player_ref = player_sprite
	table.world_ref = self
	add_child(table)


## 스폰 지점에서 고정된 오프셋에 제련로를 배치한다 (INBOX #88).
func _spawn_smelting_furnace() -> void:
	var furnace := SmeltingFurnaceScene.instantiate()
	furnace.global_position = player_sprite.position + SMELTING_FURNACE_ORIGIN
	furnace.player_ref = player_sprite
	furnace.world_ref = self
	add_child(furnace)


## 스폰 지점에서 고정된 오프셋에 조리대를 배치한다 (INBOX #90).
func _spawn_cooking_table() -> void:
	var table := CookingTableScene.instantiate()
	table.global_position = player_sprite.position + COOKING_TABLE_ORIGIN
	table.player_ref = player_sprite
	table.world_ref = self
	add_child(table)


## 스폰 지점에서 고정된 오프셋에 조리용 화로를 배치한다 (INBOX #90).
func _spawn_cooking_stove() -> void:
	var stove := CookingStoveScene.instantiate()
	stove.global_position = player_sprite.position + COOKING_STOVE_ORIGIN
	stove.player_ref = player_sprite
	stove.world_ref = self
	add_child(stove)


## ⚠️ 테스트/개발 편의용 — 정식 게임 밸런스가 아니다 (INBOX #97/#117, 사용자 지시
## 2026-09-04/2026-09-05). 크래프팅 재료를 채집/제작하지 않고도 가공대/제련로/조리대/
## 조리용 화로 레시피를 바로 테스트할 수 있도록, 스폰 상자에 41종을 999개씩 미리 채워둔다.
## 무료 지급 기본 도구(gun/axe/pickaxe/fishing_rod)와 생포 전용 captured_deer는 제외하지만,
## 제작 결과물인 강철 도구 3종(steel_pickaxe/steel_axe/steel_fishing_rod)은 포함한다.
## **상시 규칙(INBOX #117 이후)**: 새 아이템 종류가 하나라도 추가되면, 그 아이템을 만든
## 바퀴가 같은 바퀴 안에서 이 목록에도 추가해야 한다(loop/PROMPT_BUILD.md·PROMPT_DESIGN.md
## ③ 참고). 나중에 실제 밸런스를 잡을 시점에는 이 자동 채우기를 없애거나 디버그 전용
## 빌드로 옮기는 정리가 필요하다 — STATUS.md에도 같은 내용을 기록해뒀다.
const DEBUG_STARTER_CHEST_AMOUNT := 999
const DEBUG_STARTER_CHEST_ITEMS := [
	# 원재료
	"rice_seed", "iron_ore", "stone", "sulfur_ore", "wood", "sand", "copper_ore",
	# 곡물
	"rice",
	# 육류
	"meat",
	# 가공물
	"plank", "stone_block", "iron", "charcoal", "gunpowder",
	"steel", "glass", "copper", "nail", "hinge", "gear", "copper_wire", "glass_bottle",
	# 완성품
	"ammo", "wood_wall", "wood_door", "stone_wall",
	"steel_wall", "steel_door", "steel_chest", "window", "steel_armor",
	"battery", "lamp", "generator", "water_pump",
	# 가공식품
	"cooked_rice", "cooked_meat", "feed",
	# 도구 (제작 결과물 — 무료 지급 기본 도구와는 별개, INBOX #117)
	"steel_pickaxe", "steel_axe", "steel_fishing_rod",
]


## 스폰 지점에서 고정된 오프셋에 저장 상자를 배치한다 (INBOX #96). 테스트 편의를 위해
## 위 DEBUG_STARTER_CHEST_ITEMS를 즉시 채워둔다(INBOX #97 — 정식 밸런스 아님, 위 주석 참고).
func _spawn_storage_chest() -> void:
	var chest := StorageChestScene.instantiate()
	chest.global_position = player_sprite.position + STORAGE_CHEST_ORIGIN
	chest.player_ref = player_sprite
	chest.world_ref = self
	chest.unlimited = true  # 테스트용 상자 전용 (INBOX #116) — 일반 상자는 기본값 false로 고정 슬롯 유지
	add_child(chest)
	for item_name in DEBUG_STARTER_CHEST_ITEMS:
		chest.add_item(item_name, DEBUG_STARTER_CHEST_AMOUNT)


## 월드 좌표를 격자 칸 좌표(Vector2i)로 변환한다 (INBOX #119).
func _world_to_grid(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / BUILD_GRID_SIZE), floori(pos.y / BUILD_GRID_SIZE))


## 격자 칸 좌표를 그 칸의 중심 월드 좌표로 변환한다(설치/미리보기 위치를 여기로 스냅).
func _grid_to_world_center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * BUILD_GRID_SIZE, (cell.y + 0.5) * BUILD_GRID_SIZE)


## 배치 모드 미리보기 고스트 스프라이트를 한 번만 만들어둔다(반투명, 처음엔 숨김).
func _create_build_ghost() -> void:
	_build_ghost = Sprite2D.new()
	_build_ghost.name = "BuildGhost"
	_build_ghost.visible = false
	_build_ghost.z_index = 5
	add_child(_build_ghost)


## 지금 손에 든 아이템이 설치 가능한 건축물이면, 마우스 아래 가장 가까운 격자 칸에
## 반투명 미리보기를 표시한다. 이미 다른 건축물/오브젝트가 있거나 플레이어가 서 있는
## 칸이면 붉은색으로 경고한다(INBOX #129 — _is_cell_build_blocked()가 벽/문뿐 아니라
## 밭/채집채광포인트/목장/상자/제작대류/플레이어 칸까지 함께 확인).
func _update_build_ghost() -> void:
	var item := get_held_item()
	if _deconstruct_mode or _build_placement_cancelled or not BUILDABLE_STRUCTURES.has(item):
		_build_ghost.visible = false
		return
	var data: Dictionary = BUILDABLE_STRUCTURES[item]
	var texture: Texture2D = data["texture"]
	_build_ghost.texture = texture
	var tex_size := texture.get_size()
	if tex_size.x > 0.0 and tex_size.y > 0.0:
		_build_ghost.scale = Vector2(BUILD_GRID_SIZE, BUILD_GRID_SIZE) / tex_size
	var cell := _world_to_grid(get_global_mouse_position())
	_build_ghost.global_position = _grid_to_world_center(cell)
	_build_ghost.modulate = Color(1.0, 0.35, 0.35, 0.55) if _is_cell_build_blocked(cell) else Color(1.0, 1.0, 1.0, 0.55)
	_build_ghost.visible = true


## 격자 칸 하나가 이미 다른 무언가로 점유돼 있는지 확인한다(INBOX #129). 기존
## _grid_occupancy(벽/문 전용)뿐 아니라 (1) 플레이어가 지금 서 있는 칸, (2) 밭/채집·
## 채광 포인트/목장/상자/제작대류(가공대/제련로/조리대/조리용 화로)까지 함께 본다.
## 이 오브젝트들은 격자에 정확히 맞춰 배치돼 있지 않을 수 있으므로, 실제 시각적 크기
## (스프라이트 텍스처 크기 × scale, 없으면 사각형 UI 크기)로 사각형 범위를 잡아서 그
## 범위가 대상 칸과 조금이라도 겹치면 점유로 처리한다.
func _is_cell_build_blocked(cell: Vector2i) -> bool:
	if _grid_occupancy.has(cell):
		return true
	if _rect_overlaps_cell(player_sprite.global_position, Vector2(PLAYER_COLLISION_RADIUS, PLAYER_COLLISION_RADIUS), cell):
		return true
	for child in get_children():
		var half_extent := _occupancy_footprint(child)
		if half_extent == Vector2.ZERO:
			continue
		if _rect_overlaps_cell(child.global_position, half_extent, cell):
			return true
	return false


## 위 _is_cell_build_blocked()가 확인할 오브젝트 종류별 절반 크기(월드 단위)를 반환한다.
## 해당 종류가 아니거나 크기를 알 수 없으면 Vector2.ZERO(점유 판정 대상 아님).
func _occupancy_footprint(node: Node) -> Vector2:
	if node is RanchZone:
		var r: float = RanchZone.ZONE_RADIUS + RanchZone.FENCE_THICKNESS / 2.0
		return Vector2(r, r)
	if node is FarmPlot:
		return _node_visual_half_extent(node.get_node_or_null("Soil"))
	if node is ResourcePoint:
		return _node_visual_half_extent(node.get_node_or_null("Sprite"))
	if node is StorageChest:
		return _node_visual_half_extent(node.get_node_or_null("Placeholder"))
	if node is CraftingStation:
		return _node_visual_half_extent(node.get_node_or_null("Sprite"))
	return Vector2.ZERO


## Sprite2D(텍스처 크기 × scale)나 ColorRect(size)의 실제 화면 절반 크기를 구한다 —
## 값을 새로 하드코딩하지 않고 이미 있는 시각 자산 크기를 그대로 재사용한다.
func _node_visual_half_extent(visual: Node) -> Vector2:
	if visual == null:
		return Vector2.ZERO
	if visual is Sprite2D and visual.texture != null:
		return (visual.texture.get_size() * visual.scale) / 2.0
	if visual is ColorRect:
		return visual.size / 2.0
	return Vector2.ZERO


## 오브젝트(center를 중심으로 half_extent만큼 뻗은 사각형)가 격자 칸 하나와 겹치는지
## 확인한다(INBOX #129) — AABB 겹침 판정.
func _rect_overlaps_cell(center: Vector2, half_extent: Vector2, cell: Vector2i) -> bool:
	var cell_min := Vector2(cell.x, cell.y) * BUILD_GRID_SIZE
	var cell_max := cell_min + Vector2(BUILD_GRID_SIZE, BUILD_GRID_SIZE)
	var obj_min := center - half_extent
	var obj_max := center + half_extent
	return obj_min.x < cell_max.x and obj_max.x > cell_min.x \
			and obj_min.y < cell_max.y and obj_max.y > cell_min.y


## 지금 배치 모드 중인지(손에 설치 가능한 건축물 아이템을 들었고 취소되지 않았는지)를
## 밖에서 읽을 수 있게 하는 공개 접근자(INBOX #120). door.gd가 "배치 모드가 아닐 때만
## 열림/닫힘 토글" 조건을 판정할 때 이걸로 조회한다(resource_point.gd의
## get_held_tool() 패턴과 같음).
func is_build_placement_active() -> bool:
	return not _deconstruct_mode and not _build_placement_cancelled and BUILDABLE_STRUCTURES.has(get_held_item())


## 지금 건설 해제 모드 중인지를 밖에서 읽을 수 있게 하는 공개 접근자(INBOX #128,
## is_build_placement_active()와 같은 위상). door.gd가 이 모드 중에는 좌클릭을 자기
## 열림/닫힘 토글로 소비하지 않고 그대로 흘려보내서 world.gd의 철거 처리가 받게 한다.
func is_deconstruct_mode_active() -> bool:
	return _deconstruct_mode


## 좌클릭으로 배치 모드를 확정한다(INBOX #119) — 마우스 아래 격자 칸이 비어 있으면
## 인벤토리에서 1개를 소모하고 실제 충돌체(StaticBody2D)를 설치한다. INBOX #129부터는
## 벽/문끼리의 겹침뿐 아니라 _is_cell_build_blocked()로 다른 점유 오브젝트/플레이어
## 칸까지 함께 확인한다.
func _try_place_structure() -> void:
	var item := get_held_item()
	if not BUILDABLE_STRUCTURES.has(item):
		return
	var cell := _world_to_grid(get_global_mouse_position())
	if _is_cell_build_blocked(cell):
		return
	if not InventoryData.remove_item(item, 1):
		return
	_grid_occupancy[cell] = _spawn_structure(item, cell)
	_recompute_rooms()


## 격자 칸 중심에 실제 충돌체(StaticBody2D+CollisionShape2D)와 그림을 만든다
## (ranch_zone.gd의 담장 생성 패턴 참고 — deer.gd 같은 CharacterBody2D는 이 충돌체와
## move_and_slide()로 자연스럽게 막힌다). 플레이어 자체는 물리 바디가 아니라서
## _move_player_with_grid_collision()이 _grid_occupancy를 직접 조회해 따로 막는다.
## `is_door`가 켜진 아이템(INBOX #120)은 평범한 StaticBody2D 대신 door.gd(Door)를 붙여서
## "근처에서 좌클릭 → 열림/닫힘 토글"이 가능하게 만든다.
func _spawn_structure(item: String, cell: Vector2i) -> Node2D:
	var data: Dictionary = BUILDABLE_STRUCTURES[item]
	var is_door: bool = data.get("is_door", false)
	var body: StaticBody2D = Door.new() if is_door else StaticBody2D.new()
	body.name = "Structure_%s_%d_%d" % [item, cell.x, cell.y]
	body.position = _grid_to_world_center(cell)
	## 건설 해제(INBOX #128)가 어떤 아이템을 환급해야 하는지 알 수 있도록 아이템 키를
	## 메타데이터로 남겨둔다 — _grid_occupancy는 노드만 들고 있어서 역참조할 방법이 없었음.
	body.set_meta("structure_item", item)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(BUILD_GRID_SIZE, BUILD_GRID_SIZE)
	var col := CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)
	var sprite := Sprite2D.new()
	var texture: Texture2D = data["texture"]
	sprite.texture = texture
	var tex_size := texture.get_size()
	if tex_size.x > 0.0 and tex_size.y > 0.0:
		sprite.scale = Vector2(BUILD_GRID_SIZE, BUILD_GRID_SIZE) / tex_size
	body.add_child(sprite)
	add_child(body)
	if is_door:
		var door := body as Door
		door.setup(col, sprite, BUILD_GRID_SIZE)
		door.player_ref = player_sprite
		door.world_ref = self
	return body


## 구조물 노드(StaticBody2D 또는 Door)에서 그림을 담당하는 Sprite2D 자식을 찾는다
## (INBOX #128). Door의 `_sprite`는 밖에서 직접 접근하지 않고 이렇게 공통 방식으로 찾아서
## 벽(StaticBody2D)/문(Door) 어느 쪽이든 같은 코드로 반투명 빨간색 하이라이트를 씌운다.
func _get_structure_sprite(node: Node) -> Sprite2D:
	for child in node.get_children():
		if child is Sprite2D:
			return child
	return null


## 상자/제작대류/밭/목장(INBOX #130, 상태를 가진 다른 설치물)에서 하이라이트를 씌울
## 시각 노드를 반환한다. 벽/문(StaticBody2D/Door)과 달리 이 4종류는 자식 노드 이름이
## 서로 달라서(_occupancy_footprint()가 겹침 판정에 쓰는 것과 같은 자식들) 종류별로
## 지정해준다. 이 4종류가 아니면 null(벽/문 쪽은 계속 _get_structure_sprite()가 처리).
func _fixture_visual(node: Node) -> CanvasItem:
	if node is StorageChest:
		return node.get_node_or_null("Placeholder")
	if node is CraftingStation:
		return node.get_node_or_null("Sprite")
	if node is FarmPlot:
		return node.get_node_or_null("Soil")
	if node is RanchZone:
		return node.get_node_or_null("Pasture")
	return null


## 건설 해제 하이라이트가 씌울 시각 노드를 찾는다 — 벽/문이면 _get_structure_sprite(),
## 상자/제작대류/밭/목장(INBOX #130)이면 _fixture_visual()로 위임한다.
func _deconstruct_visual(node: Node) -> CanvasItem:
	var fixture := _fixture_visual(node)
	if fixture != null:
		return fixture
	return _get_structure_sprite(node)


## 하이라이트를 걷어낼 때 되돌려야 할 "평소" modulate. 문은 열려 있으면 반투명(door.gd의
## _toggle()이 alpha=0.35로 표현)이므로, 하이라이트를 벗겨도 그 반투명함은 유지해야 한다.
func _structure_normal_modulate(node: Node) -> Color:
	if node is Door and node.is_open:
		return Color(1.0, 1.0, 1.0, 0.35)
	return Color(1.0, 1.0, 1.0, 1.0)


## 건설 해제 모드(INBOX #128)일 때 매 프레임 마우스 아래 격자 칸을 확인해서, 철거 가능한
## 구조물이 있으면 그 스프라이트를 반투명 빨간색으로 덧칠한다. 모드가 꺼지거나 마우스가
## 빈 칸/다른 칸으로 옮겨가면 이전에 칠했던 노드를 평소 색으로 되돌린다.
## (INBOX #130) 벽/문(_grid_occupancy)이 없는 칸이면 상자/제작대류/밭/목장 중 하나가
## 그 칸을 차지하는지도 확인한다 — 실제로 철거 가능한 상태인지(내용물 비었는지 등)와
## 무관하게 하이라이트는 항상 보여준다(막힌 이유는 좌클릭했을 때 아무 일도 안 일어나는
## 것으로만 알 수 있음, #130 원문 — "어떤 칸인지는 알 수 있게" 하이라이트 자체는 유지).
func _update_deconstruct_highlight() -> void:
	var target_node: Node = null
	if _deconstruct_mode and not _paused and not _inventory_open and not _crafting_open and not _storage_open:
		var cell := _world_to_grid(get_global_mouse_position())
		if _grid_occupancy.has(cell):
			target_node = _grid_occupancy[cell]
		else:
			target_node = _find_fixture_at_cell(cell)
	if target_node == _deconstruct_highlighted_node:
		return
	if _deconstruct_highlighted_node != null and is_instance_valid(_deconstruct_highlighted_node):
		var old_visual := _deconstruct_visual(_deconstruct_highlighted_node)
		if old_visual != null:
			old_visual.modulate = _structure_normal_modulate(_deconstruct_highlighted_node)
	_deconstruct_highlighted_node = target_node
	if _deconstruct_highlighted_node != null:
		var new_visual := _deconstruct_visual(_deconstruct_highlighted_node)
		if new_visual != null:
			var base := _structure_normal_modulate(_deconstruct_highlighted_node)
			new_visual.modulate = Color(DECONSTRUCT_TINT.r, DECONSTRUCT_TINT.g, DECONSTRUCT_TINT.b, base.a)


## 마우스 아래 격자 칸에 철거 가능한 "상태 있는 설치물"(상자/제작대류/밭/목장, INBOX
## #130)이 있는지 찾는다. #129의 _occupancy_footprint()를 재사용해 이 4종류의 실제
## 시각적 범위가 대상 칸과 겹치는지 확인한다 — 채집/채광 포인트(ResourcePoint)는 이번
## 항목 범위가 아니므로 제외한다(같은 footprint 함수가 반환값을 주더라도 무시).
func _find_fixture_at_cell(cell: Vector2i) -> Node:
	for child in get_children():
		if not (child is StorageChest or child is CraftingStation or child is FarmPlot or child is RanchZone):
			continue
		var half_extent := _occupancy_footprint(child)
		if half_extent == Vector2.ZERO:
			continue
		if _rect_overlaps_cell(child.global_position, half_extent, cell):
			return child
	return null


## node(상자/제작대류/밭/목장)를 지금 철거해도 되는지 판정한다(INBOX #130 원문 규칙).
## 상자=슬롯이 전부 비어있을 때만, 제작대류=진행 중인 배치가 없을 때만, 목장=사육 중인
## 동물이 없을 때만, 밭=언제든 가능(자라는 중/수확 가능한 작물도 함께 사라짐 — 의도된
## 단순화, 되돌려주지 않음).
func _can_deconstruct_fixture(node: Node) -> bool:
	if node is StorageChest:
		return node.is_empty()
	if node is CraftingStation:
		return not node.is_batch_active()
	if node is RanchZone:
		return not node.has_animal()
	if node is FarmPlot:
		return true
	return false


## 건설 해제 모드에서 좌클릭했을 때 실행된다(INBOX #128) — 마우스 아래 격자 칸에 벽/문이
## 있으면 그쪽을 철거하고, 없으면 상자/제작대류/밭/목장(INBOX #130) 중 하나가 그 칸을
## 차지하는지 확인해서 그쪽을 철거한다.
func _try_deconstruct_structure() -> void:
	var cell := _world_to_grid(get_global_mouse_position())
	if _grid_occupancy.has(cell):
		_deconstruct_wall_or_door(cell)
		return
	var fixture := _find_fixture_at_cell(cell)
	if fixture != null:
		_deconstruct_fixture(fixture)


## 벽/문을 철거하고, 설치 때 소모했던 아이템을 100% 환급한다(문은 열려있든 닫혀있든
## 철거 가능 — DESIGN.md/INBOX #128 원문). 인벤토리가 가득 차 있으면 #24의 바닥 드롭
## 패턴으로 대체해서 손실이 없게 한다.
func _deconstruct_wall_or_door(cell: Vector2i) -> void:
	var node: Node = _grid_occupancy[cell]
	var item: String = node.get_meta("structure_item", "")
	_grid_occupancy.erase(cell)
	if _deconstruct_highlighted_node == node:
		_deconstruct_highlighted_node = null
	node.queue_free()
	if item != "" and InventoryData.add_item(item, 1) < 1:
		spawn_dropped_item(item, 1, _grid_to_world_center(cell))
	_recompute_rooms()


## 상태를 가진 다른 설치물(상자/제작대류/밭/목장)을 철거한다(INBOX #130). _can_deconstruct_fixture()
## 조건을 못 채우면 아무 일도 하지 않는다(하이라이트만 유지 — #130 원문). 이 4종류는
## 벽/문과 달리 플레이어가 크래프팅해서 손에 들고 설치하는 아이템이 아니라 world.gd가
## 스폰 시점에 고정 배치하는 오브젝트라(스폰 코드 참고) 대응하는 인벤토리 아이템 자체가
## 없다 — DESIGN.md에 없는 새 아이템(예: "storage_chest" 아이템)을 이 항목에서 임의로
## 지어내지 않기로 판단해서(PROMPT_BUILD.md ④ 규칙), 철거하면 그냥 사라지고 인벤토리로
## 돌아오는 아이템은 없다(STATUS.md에 이 판단을 기록해둠). 방 안의 핵심 오브젝트 구성이
## 바뀔 수 있으므로(#122) 벽 변경이 아니어도 항상 방 판정을 다시 계산한다.
func _deconstruct_fixture(node: Node) -> void:
	if not _can_deconstruct_fixture(node):
		return
	if _deconstruct_highlighted_node == node:
		_deconstruct_highlighted_node = null
	## queue_free()만 부르고 바로 _recompute_rooms()를 호출하면, 실제 트리 제거는 이번
	## 프레임 끝에 지연되기 때문에 _classify_room()의 get_children() 스캔이 아직 트리에
	## 남아있는(막 지우기로 예약된) 이 노드를 그대로 다시 세어버려 카테고리가 안 바뀌는
	## 실제 버그가 있었다(QA 검증 중 발견 — INBOX #130). remove_child()로 먼저 트리에서
	## 동기적으로 떼어낸 뒤 queue_free()해야 재계산이 이 노드를 안 보게 된다.
	remove_child(node)
	node.queue_free()
	_recompute_rooms()


## 플레이어 이동에 건축물 격자 충돌을 적용한다(INBOX #119, 위 PLAYER_COLLISION_RADIUS
## 설명 참고). 축을 분리해서 확인해야 벽을 따라 미끄러지듯 이동할 수 있다(한 번에 XY를
## 같이 검사하면 대각선으로 다가갈 때 아예 못 움직이는 것처럼 느껴진다).
func _move_player_with_grid_collision(motion: Vector2) -> void:
	var pos := player_sprite.position
	var try_x := pos + Vector2(motion.x, 0.0)
	if not _is_position_blocked(try_x):
		pos = try_x
	var try_y := pos + Vector2(0.0, motion.y)
	if not _is_position_blocked(try_y):
		pos = try_y
	player_sprite.position = pos


## pos를 중심으로 한 작은 사각형(플레이어 폭 근사, 한 변 2*PLAYER_COLLISION_RADIUS)이
## 걸치는 모든 격자 칸을 확인해서, 그중 하나라도 건축물이 설치된 칸이면 막힌 것으로
## 본다. 열린 문(INBOX #120)이 있는 칸은 예외 — `_grid_occupancy`에는 여전히 문 노드가
## 남아있지만(방 감지가 "문이 있다"는 사실 자체를 볼 수 있어야 하므로) 지나갈 수는
## 있어야 한다.
## (INBOX #125 수정) 예전엔 네 대각선 모서리 점만 표본으로 확인했는데, BUILD_GRID_SIZE를
## 64→16으로 줄이면서 PLAYER_COLLISION_RADIUS(16)와 값이 같아져 대각선 모서리가 항상
## 옆 행/열로 어긋나 버려 정면으로 다가오는 벽을 아예 못 보는 실제 버그가 됐다(실측:
## 닫힌 문을 정면으로 통과해버림). 표본 점 대신 겹치는 칸 범위 전체를 스캔하도록 고쳐서
## 격자 크기와 충돌 반경의 비율에 관계없이 항상 정확하게 판정한다.
func _is_position_blocked(pos: Vector2) -> bool:
	if _grid_occupancy.is_empty():
		return false
	var r := PLAYER_COLLISION_RADIUS
	var min_cell := _world_to_grid(pos - Vector2(r, r))
	var max_cell := _world_to_grid(pos + Vector2(r, r))
	for gx in range(min_cell.x, max_cell.x + 1):
		for gy in range(min_cell.y, max_cell.y + 1):
			var cell := Vector2i(gx, gy)
			if not _grid_occupancy.has(cell):
				continue
			var node = _grid_occupancy[cell]
			if node is Door and node.is_open:
				continue
			return true
	return false


## 벽/문이 새로 설치되거나 제거될 때 호출한다(INBOX #122). _grid_occupancy를 기준으로
## 막힌(둘러싸인) 공간을 전부 다시 찾아서 _rooms/_cell_to_room을 새로 만든다 — 매 프레임
## 도는 게 아니라 변경 시점에만 호출되므로 매번 전부 다시 계산해도 비용이 크지 않다.
func _recompute_rooms() -> void:
	_rooms.clear()
	_cell_to_room.clear()
	## 벽/문에 바로 붙어있는 열린 칸만 시작점 후보로 삼는다 — 방은 항상 벽에 둘러싸여야
	## 하므로, 벽과 전혀 안 닿은 트인 들판 한복판에서부터 굳이 flood-fill을 시작할
	## 필요가 없다(불필요한 탐색을 줄임).
	var candidates: Dictionary = {}
	for cell in _grid_occupancy.keys():
		for dir in ROOM_DIRS:
			var neighbor: Vector2i = cell + dir
			if not _grid_occupancy.has(neighbor):
				candidates[neighbor] = true
	var confirmed_open: Dictionary = {}
	for seed_cell in candidates.keys():
		if _cell_to_room.has(seed_cell) or confirmed_open.has(seed_cell):
			continue
		var result := _flood_fill_room(seed_cell)
		if result["bounded"]:
			var room_id := _next_room_id
			_next_room_id += 1
			var cells: Array = result["cells"]
			_rooms[room_id] = {"cells": cells, "category": ""}
			for cell in cells:
				_cell_to_room[cell] = room_id
		else:
			for cell in result["cells"]:
				confirmed_open[cell] = true
	for room_id in _rooms.keys():
		_rooms[room_id]["category"] = _classify_room(_rooms[room_id]["cells"])
	if not _rooms.is_empty():
		for room_id in _rooms.keys():
			print("[Room] #%d: %d칸, 판정: %s" % [room_id, _rooms[room_id]["cells"].size(), _rooms[room_id]["category"]])


## seed_cell에서 시작해 점유되지 않은(벽/문이 없는) 칸들을 BFS로 퍼뜨린다. 방문한 칸
## 수가 ROOM_FLOOD_CELL_CAP을 넘기기 전에 스스로 더 못 퍼져나가면(막힌 공간) bounded
## true, 상한을 넘기면(바깥 들판으로 샘) false를 반환한다.
func _flood_fill_room(seed_cell: Vector2i) -> Dictionary:
	var visited: Dictionary = {seed_cell: true}
	var queue: Array = [seed_cell]
	var bounded := true
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for dir in ROOM_DIRS:
			var neighbor: Vector2i = current + dir
			if visited.has(neighbor) or _grid_occupancy.has(neighbor):
				continue
			visited[neighbor] = true
			if visited.size() > ROOM_FLOOD_CELL_CAP:
				bounded = false
				break
			queue.append(neighbor)
		if not bounded:
			break
	return {"bounded": bounded, "cells": visited.keys()}


## 방 칸 목록 안에 있는 "핵심 오브젝트"를 스캔해서 DESIGN.md 규칙표대로 방 이름을
## 판정한다. 카테고리가 정확히 1종류고 요구 수량을 채우면 그 이름, 아니면(0개 또는
## 2개 이상 섞임) "잡실". 저장 상자 등은 어느 카테고리에도 속하지 않아 스캔에서
## 무시된다(DESIGN.md "저장 상자는 중립").
func _classify_room(cells: Array) -> String:
	var cell_set: Dictionary = {}
	for cell in cells:
		cell_set[cell] = true
	var categories: Dictionary = {}
	var has_cooking_table := false
	var has_cooking_stove := false
	for node in get_children():
		if not (node is Node2D) or not node.is_inside_tree():
			continue
		var cell := _world_to_grid(node.global_position)
		if not cell_set.has(cell):
			continue
		if node is CraftingStation:
			var title: String = node.get_title()
			if not ROOM_CATEGORY_BY_STATION_TITLE.has(title):
				continue
			categories[ROOM_CATEGORY_BY_STATION_TITLE[title]] = true
			if title == "조리대":
				has_cooking_table = true
			elif title == "조리용 화로":
				has_cooking_stove = true
		elif node is FarmPlot:
			categories["농장"] = true
		elif node is RanchZone:
			categories["목장"] = true
	if categories.size() != 1:
		return "잡실"
	var only_category: String = categories.keys()[0]
	if only_category == "주방" and not (has_cooking_table and has_cooking_stove):
		return "잡실"
	return only_category


## world_pos가 속한 방의 ID를 반환한다. 방이 없거나(트인 들판, 아직 인식 안 됨) 그
## 칸이 벽/문 자신이면 -1을 반환한다(#123이 사용할 공개 API).
func get_room_id_at(world_pos: Vector2) -> int:
	return _cell_to_room.get(_world_to_grid(world_pos), -1)


## room_id의 판정된 카테고리("잡실" 포함)를 반환한다. 존재하지 않는 방 ID면 빈 문자열.
func get_room_category(room_id: int) -> String:
	if not _rooms.has(room_id):
		return ""
	return _rooms[room_id]["category"]


## 플레이어의 연속 조준 방향(정규화 벡터)을 밖에서 읽을 수 있게 하는 공개 접근자
## (INBOX #135, fog_of_war.gd가 사용) — 총 조준에 이미 쓰는 `_aim_direction`을 그대로
## 재사용해서 시야 콘 계산 로직을 중복 구현하지 않는다.
func get_aim_direction() -> Vector2:
	return _aim_direction


## 격자 칸에 벽이나 닫힌 문이 있어 시야가 가로막히는지 밖에서 조회하는 공개 접근자
## (INBOX #135, fog_of_war.gd가 사용) — `_is_position_blocked()`의 이동 충돌 판정과
## 같은 "열린 문은 막지 않는다" 규칙을 시야 판정에도 그대로 적용한다.
func is_cell_sight_blocked(cell: Vector2i) -> bool:
	if not _grid_occupancy.has(cell):
		return false
	var node = _grid_occupancy[cell]
	if node is Door and node.is_open:
		return false
	return true


## world_pos가 속한, 잡실이 아닌 정상 인식된 방 안에 있는 저장 상자 목록을 반환한다
## (INBOX #123, DESIGN.md "방-상자 자동 연동" — 판정 기준은 거리가 아니라 방 ID 일치
## 여부). world_pos가 방에 속하지 않았거나 그 방이 잡실이면 빈 배열을 반환한다 — 호출부
## (CraftingStation.start_batch())는 빈 배열이면 지금처럼 플레이어 인벤토리만 본다(회귀
## 없음). 방 ID는 벽/문이 바뀔 때마다 다시 부여되므로 캐싱하지 않고 매번 새로 조회한다.
func get_room_chests(world_pos: Vector2) -> Array:
	var room_id := get_room_id_at(world_pos)
	if room_id == -1 or get_room_category(room_id) == "잡실":
		return []
	var chests: Array = []
	for child in get_children():
		if child is StorageChest and get_room_id_at(child.global_position) == room_id:
			chests.append(child)
	return chests


## 사냥/채집/채광 결과물을 바닥에 드롭 오브젝트로 스폰한다 (INBOX #24, DESIGN.md
## "아이템 획득 방식 — 바닥 드롭"). 드롭 오브젝트가 player_ref로 플레이어와의 거리를
## 직접 재서 접촉하면 스스로 인벤토리에 들어가고 사라진다.
func spawn_dropped_item(item_name: String, amount: int, pos: Vector2) -> void:
	var drop := DroppedItemScene.instantiate()
	drop.global_position = pos
	drop.item_name = item_name
	drop.item_amount = amount
	drop.player_ref = player_sprite
	add_child(drop)


## 사거리(방향별 단위 벡터). 버리기(discard_inventory_slot)가 플레이어 발밑이 아니라
## 바라보는 방향 앞쪽에 드롭 오브젝트를 놓는 데 쓴다.
const FACING_VECTORS := {
	"north": Vector2(0, -1), "south": Vector2(0, 1),
	"east": Vector2(1, 0), "west": Vector2(-1, 0),
}
## DroppedItemScene의 PICKUP_RADIUS(40)보다 커야 놓자마자 바로 다시 주워지지 않는다.
const DISCARD_OFFSET := 60.0


## 인벤토리 창 바깥으로 아이템을 드래그해서 놓았을 때 호출된다 (INBOX #31,
## inventory_discard_zone.gd → 여기). 슬롯을 비우고 바로 앞쪽에 드롭 오브젝트를 놓는다
## (플레이어 발밑에 놓으면 접촉 판정 때문에 그 자리에서 바로 다시 주워져 버려지지 않는다).
func discard_inventory_slot(kind: String, index: int) -> void:
	var slot := InventoryData.take_slot(kind, index)
	if slot.is_empty():
		return
	var offset: Vector2 = FACING_VECTORS.get(_facing, Vector2.DOWN) * DISCARD_OFFSET
	spawn_dropped_item(slot["item"], int(slot.get("count", 1)), player_sprite.global_position + offset)


## 아직 도구를 얻는 채집/제작 경로가 없으므로(DESIGN.md 범위 밖), 캐릭터가 처음
## 월드에 들어올 때 도구 5종을 한 벌씩 지급해 핫바 1~5번에서 바로 시험해볼 수 있게 한다
## (INBOX #22, 스스로 판단해서 추가). 이미 총을 갖고 있으면(재입장) 다시 지급하지 않는다.
func _ensure_starting_tools() -> void:
	if InventoryData.has_item("gun", 1):
		return
	for tool_key in TOOL_KEYS:
		InventoryData.add_item(tool_key, 1)


## 화면 아래 중앙에 핫바 9칸을 만든다 (INBOX #22). 인벤토리 창의 맨 위 9칸(핫바)과
## 같은 슬롯을 그대로 보여주는 별도 뷰다 — 데이터는 항상 InventoryData.get_general_slots()
## 에서 다시 읽어오므로 두 UI가 따로 놀 일이 없다.
func _build_hotbar() -> void:
	_hotbar_normal_style = _make_slot_style(Color(0.157, 0.212, 0.184, 1))
	_hotbar_selected_style = _make_slot_style(Color(0.22, 0.32, 0.22, 1))
	_hotbar_selected_style.border_width_left = 4
	_hotbar_selected_style.border_width_top = 4
	_hotbar_selected_style.border_width_right = 4
	_hotbar_selected_style.border_width_bottom = 4
	_hotbar_selected_style.border_color = Color(0.95, 0.85, 0.3, 1)
	for i in range(InventoryData.HOTBAR_SIZE):
		var cell := _make_hotbar_cell(i + 1)
		hotbar_bar.add_child(cell["panel"])
		_hotbar_cells.append(cell)
	_refresh_hotbar()


func _make_hotbar_cell(number: int) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(56, 56)
	panel.add_theme_stylebox_override("panel", _hotbar_normal_style)
	var item_label := Label.new()
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	## 번호 라벨(왼쪽 위 고정)과 절대 겹치지 않도록 아이템 이름/개수는 칸 아래쪽에
	## 붙인다 (INBOX #62 — "곡괭이낫" 같은 4글자 이상 도구 이름이 번호 라벨과 같은
	## 줄에 겹쳐 보이던 문제). Label의 세로 size flag 기본값이 SHRINK_CENTER라서
	## vertical_alignment만 바꿔서는 칸 높이 전체를 못 쓰고 항상 셀 중앙의 좁은
	## 한 줄 영역에만 딱 붙는다 — size_flags_vertical을 FILL로 바꿔 칸 전체 높이를
	## 실제로 차지하게 해야 vertical_alignment(BOTTOM/TOP)가 눈에 보이는 차이를 만든다.
	item_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	item_label.add_theme_font_size_override("font_size", 11)
	panel.add_child(item_label)
	var number_label := Label.new()
	number_label.text = str(number)
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	number_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	number_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	number_label.add_theme_font_size_override("font_size", 11)
	number_label.modulate = Color(1, 1, 1, 0.55)
	panel.add_child(number_label)
	return {"panel": panel, "item_label": item_label, "number_label": number_label}


## 핫바 칸의 아이템 표시와 선택 테두리를 InventoryData 상태에 맞춰 다시 그린다.
func _refresh_hotbar() -> void:
	var general_slots := InventoryData.get_general_slots()
	for i in range(_hotbar_cells.size()):
		var slot = general_slots[i] if i < general_slots.size() else null
		var cell: Dictionary = _hotbar_cells[i]
		var item_label: Label = cell["item_label"]
		if slot == null:
			item_label.text = ""
		else:
			var display: String = ITEM_LABELS.get(slot["item"], slot["item"])
			item_label.text = display if TOOL_ICONS.has(slot["item"]) else "%s\nx%d" % [display, slot["count"]]
		var panel: PanelContainer = cell["panel"]
		panel.add_theme_stylebox_override(
			"panel", _hotbar_selected_style if i == _selected_hotbar_index else _hotbar_normal_style
		)


## 숫자키 1~9로 핫바 슬롯을 고른다. 도구 아이템이면 손에 들고, 빈 슬롯이거나 도구가
## 아닌 아이템이면 빈손으로 되돌린다 (INBOX #22 요구사항 그대로). #45부터 TOOL_KEYS의
## 모든 도구(gun/axe/pickaxe/fishing_rod)가 옆 아이콘 오버레이 없이 캐릭터 애니메이션
## 프레임 자체(gun_idle_*/gun_fire_*, axe_idle_*/axe_chop_*, pickaxe_idle_*/
## pickaxe_mining_*/pickaxe_gathering_*, fishing_rod_idle_*/fishing_rod_fishing_*)로
## 든 모습을 보여주므로, 여기서는 _held_tool만 갱신하면 된다.
func _select_hotbar(index: int) -> void:
	if index < 0 or index >= InventoryData.HOTBAR_SIZE:
		return
	_selected_hotbar_index = index
	var general_slots := InventoryData.get_general_slots()
	var slot = general_slots[index] if index < general_slots.size() else null
	_held_tool = slot["item"] if slot != null and TOOL_ICONS.has(slot["item"]) else ""
	## 총을 들었을 때만 탄약 패널을 보여준다 (INBOX #127 — 다른 도구/빈손이면 숨김).
	ammo_panel.visible = _held_tool == "gun"
	## 핫바를 다시 고르면(숫자키를 새로 누르거나 인벤토리 변경으로 재검증되면) 건축
	## 배치 모드 취소 상태를 초기화한다(INBOX #119 — "도구를 바꾸면 배치 모드를 취소").
	_build_placement_cancelled = false
	_refresh_hotbar()
	_update_player_animation()


## 인벤토리 내용이 바뀔 때마다(드래그로 슬롯이 비워지거나 아이템이 바뀌는 등) 지금
## 선택된 핫바 슬롯을 다시 확인한다. 숫자키를 새로 누르지 않아도 그 슬롯이 비었거나
## 도구가 아니게 되면 빈손으로 되돌아간다 (INBOX #32 — 총을 버려도 계속 들고 있던 버그).
func _revalidate_held_hotbar_slot() -> void:
	_select_hotbar(_selected_hotbar_index)


## 인벤토리 창의 일반 18칸 + 장비 9칸 슬롯 셀을 한 번만 만들어둔다 (INBOX #21).
## 슬롯 배경색으로 핫바(맨 위 9칸)와 일반 슬롯을 구분한다.
func _build_inventory_slots() -> void:
	var hotbar_style := _make_slot_style(Color(0.22, 0.32, 0.22, 1))
	var normal_style := _make_slot_style(Color(0.157, 0.212, 0.184, 1))
	for i in range(InventoryData.GENERAL_SLOT_COUNT):
		var style := hotbar_style if i < InventoryData.HOTBAR_SIZE else normal_style
		var cell := _make_slot_cell(style, "general", i)
		general_grid.add_child(cell)
		_general_slot_labels.append(cell.get_node("Label"))
	for i in range(InventoryData.EQUIPMENT_SLOT_TYPES.size()):
		var cell := _make_slot_cell(normal_style, "equipment", i)
		equipment_grid.add_child(cell)
		_equipment_slot_labels.append(cell.get_node("Label"))
	# 인벤토리 창 바깥(빈 배경)으로 드래그해서 놓으면 버려지도록, 창 루트 Control에도
	# 드롭 처리를 붙인다 — 슬롯 셀이 먼저 드롭을 못 받았을 때만 여기까지 올라온다.
	inventory_window.set_script(load("res://scripts/inventory_discard_zone.gd"))
	inventory_window.world_ref = self


## 코드로 조립하는 팝업 창(가공대/저장 상자 등)의 PanelContainer가 쓸 불투명 배경
## (INBOX #112 — `PanelContainer.new()`에 스타일을 안 넣으면 엔진 기본 테마의 패널
## 스타일로 대체되는데, 이게 이 프로젝트 테마와 안 맞아 사실상 배경이 거의 안 보이는
## 수준이었다. `world.tscn`의 인벤토리 창 `Panel`(StyleBoxFlat_pause_panel)과 같은
## 값으로 맞춰서 재사용 — 새 색을 지어내지 않는다).
func _make_window_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.157, 0.212, 0.184, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.49, 0.44, 1)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	style.content_margin_left = 36.0
	style.content_margin_top = 28.0
	style.content_margin_right = 36.0
	style.content_margin_bottom = 28.0
	return style


func _make_slot_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.49, 0.44, 1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style


## slot_kind/slot_index는 드래그 앤 드롭(INBOX #31)이 "어느 슬롯인지" 알아야 해서 필요하다
## — inventory_slot_cell.gd가 InventoryData.move_slot()을 호출할 때 이 값을 그대로 쓴다.
func _make_slot_cell(style: StyleBoxFlat, slot_kind: String, slot_index: int) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(72, 72)
	cell.add_theme_stylebox_override("panel", style)
	cell.set_script(load("res://scripts/inventory_slot_cell.gd"))
	cell.slot_kind = slot_kind
	cell.slot_index = slot_index
	var label := Label.new()
	label.name = "Label"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	cell.add_child(label)
	return cell


func _set_inventory_open(value: bool) -> void:
	_inventory_open = value
	inventory_window.visible = value
	if value:
		_refresh_inventory_window()


## 일반 슬롯은 담긴 아이템 이름/개수를, 장비 슬롯은 부위 이름(비었을 때) 또는
## 부위+아이템 이름(찼을 때)을 보여준다.
func _refresh_inventory_window() -> void:
	var general_slots := InventoryData.get_general_slots()
	for i in range(general_slots.size()):
		var slot = general_slots[i]
		var label: Label = _general_slot_labels[i]
		if slot == null:
			label.text = ""
		else:
			var display: String = ITEM_LABELS.get(slot["item"], slot["item"])
			label.text = "%s\nx%d" % [display, slot["count"]]
	var equipment_slots := InventoryData.get_equipment_slots()
	for i in range(equipment_slots.size()):
		var slot = equipment_slots[i]
		var label: Label = _equipment_slot_labels[i]
		var part_name: String = EQUIPMENT_LABELS[i]
		if slot == null:
			label.text = part_name
		else:
			var display: String = ITEM_LABELS.get(slot["item"], slot["item"])
			label.text = "%s\n%s" % [part_name, display]


## 가공대(#87)/제련로(#88 이후) 등 생산 라인 작업대가 공유하는 범용 제작 창을 코드로
## 한 번만 조립해둔다(인벤토리 창처럼 .tscn에 미리 심어두지 않고, 핫바 셀처럼 런타임에
## 만든다 — 작업대마다 레시피만 다를 뿐 UI 구조는 완전히 같아서, 새 작업대가 추가될 때마다
## .tscn을 새로 만들 필요 없이 open_crafting_window()만 호출하면 되게 하기 위함).
func _build_crafting_window() -> void:
	var window := Control.new()
	window.name = "CraftingWindow"
	window.visible = false
	window.set_anchors_preset(Control.PRESET_FULL_RECT)
	window.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	window.add_child(center)

	var panel := PanelContainer.new()
	# INBOX #99: 레시피 줄에 수량 SpinBox+"제작 시작" 버튼이 추가되고 진행 상황/수령
	# 버튼 섹션도 새로 생겨서 이전(380)보다 더 넓혀야 안 잘린다.
	panel.custom_minimum_size = Vector2(460, 0)
	panel.add_theme_stylebox_override("panel", _make_window_panel_style())
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	_crafting_title_label = Label.new()
	_crafting_title_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_crafting_title_label)

	## INBOX #110: 레시피 수가 20개까지 늘어나면서 스크롤 없이는 화면(720px) 밖으로
	## 넘쳐 아래쪽 레시피(가공대의 전기 계열/사료/급수 장치 등)를 클릭할 수 없었다 —
	## storage_list(#96)와 같은 패턴으로 ScrollContainer로 감싼다.
	var crafting_scroll := ScrollContainer.new()
	crafting_scroll.custom_minimum_size = Vector2(0, 420)
	vbox.add_child(crafting_scroll)

	_crafting_list = VBoxContainer.new()
	_crafting_list.add_theme_constant_override("separation", 6)
	_crafting_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crafting_scroll.add_child(_crafting_list)

	_crafting_message_label = Label.new()
	_crafting_message_label.visible = false
	_crafting_message_label.modulate = Color(1, 0.55, 0.55, 1)
	vbox.add_child(_crafting_message_label)

	var close_hint := Label.new()
	close_hint.text = "ESC: 닫기 / 수량 지정 후 제작 시작 → 완성되면 수령 버튼으로 받기"
	close_hint.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(close_hint)

	ui_layer.add_child(window)
	_crafting_window = window
	InventoryData.changed.connect(_refresh_crafting_window)


## RECIPES 형식: [{"inputs": {아이템: 개수, ...}, "output": 아이템, "amount": 개수}, ...]
## (DESIGN.md "생산 라인" 절 그대로). 상호작용 오브젝트(가공대 등, CraftingStation)가
## 근처에서 좌클릭됐을 때 호출한다. station은 그 오브젝트 자신(self) — 배치 시작/수령
## 버튼이 이 인스턴스를 직접 조작하고, 타이머가 진행될 때마다(_advance_batch()) 보내는
## `changed` 신호를 받아 창을 다시 그린다(INBOX #99 — open_storage_window()와 같은 패턴).
func open_crafting_window(title: String, recipes: Array, station: Node) -> void:
	if _paused or _inventory_open or _storage_open:
		return
	if _crafting_station != null and _crafting_station.changed.is_connected(_refresh_crafting_window):
		_crafting_station.changed.disconnect(_refresh_crafting_window)
	_crafting_station = station
	_crafting_station.changed.connect(_refresh_crafting_window)
	_crafting_title_label.text = title
	_crafting_recipes = recipes
	_crafting_open = true
	_crafting_message_label.visible = false
	_crafting_window.visible = true
	_refresh_crafting_window()


func close_crafting_window() -> void:
	_crafting_open = false
	_crafting_window.visible = false


## processing_table.gd 등이 "지금 다른 작업대 창이 이미 열려 있는지" 확인할 때 쓴다
## (get_held_tool()/get_held_item()과 같은 공개 접근자 패턴).
func is_crafting_open() -> bool:
	return _crafting_open


## 레시피 목록을 다시 그린다 — 창이 열려 있는 동안 인벤토리가 바뀔 때마다(재료를 다 써서
## 더 이상 제작 못 하게 되는 등) 버튼의 활성/비활성 상태가 즉시 갱신돼야 하므로
## InventoryData.changed에도 연결돼 있다.
func _refresh_crafting_window() -> void:
	if not _crafting_open or _crafting_station == null:
		return
	for child in _crafting_list.get_children():
		child.queue_free()
	for recipe in _crafting_recipes:
		_crafting_list.add_child(_make_recipe_row(recipe))
	_crafting_list.add_child(_make_batch_status_row())


## 레시피 한 줄: 설명 + 수량 지정(SpinBox) + "제작 시작" 버튼(INBOX #99, 이전의 "누르면
## 즉시 완성" 단일 버튼에서 바뀜). 배치가 이미 하나 진행 중이면(한 번에 한 배치만 —
## CraftingStation.start_batch() 참고) 버튼을 비활성화한다. 재료 부족은 버튼을 누른
## 시점에 start_batch()가 다시 확인하고 실패하면 메시지로 알린다(수량을 바꿀 때마다
## 매번 버튼 상태를 다시 계산하지 않아도 되게, 클릭 시점 검증으로 단순화).
func _make_recipe_row(recipe: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var inputs: Dictionary = recipe.get("inputs", {})
	var input_parts: Array[String] = []
	for item_key in inputs.keys():
		input_parts.append("%s x%d" % [ITEM_LABELS.get(item_key, item_key), int(inputs[item_key])])
	var output: String = recipe.get("output", "")
	var amount: int = int(recipe.get("amount", 1))

	var desc := Label.new()
	desc.text = "%s → %s x%d (개당 %.0f초)" % [
		", ".join(input_parts), ITEM_LABELS.get(output, output), amount, CraftingStation.CRAFT_SECONDS_PER_UNIT,
	]
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	row.add_child(desc)

	var qty_spin := SpinBox.new()
	qty_spin.min_value = 1
	qty_spin.max_value = 99
	qty_spin.value = 1
	qty_spin.custom_minimum_size = Vector2(70, 0)
	row.add_child(qty_spin)

	var button := Button.new()
	button.text = "제작 시작"
	button.disabled = _crafting_station.is_batch_active()
	button.pressed.connect(_on_craft_start_pressed.bind(recipe, qty_spin))
	row.add_child(button)
	return row


## 진행 중인 배치의 남은 수량/시간과, 지금까지 쌓인 출력 버퍼(item -> count, INBOX #99)를
## 보여주고 항목별로 "수령" 버튼을 둔다.
func _make_batch_status_row() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(HSeparator.new())

	var progress: Dictionary = _crafting_station.batch_progress()
	var status := Label.new()
	if progress["active"]:
		status.text = "제작 중: %d개 남음 (다음 완성까지 %.1f초)" % [progress["remaining"], progress["seconds_left"]]
	else:
		status.text = "진행 중인 제작 없음"
	box.add_child(status)

	var buffer: Dictionary = _crafting_station.output_buffer
	if buffer.is_empty():
		var empty_label := Label.new()
		empty_label.text = "수령할 결과물 없음"
		empty_label.modulate = Color(1, 1, 1, 0.6)
		box.add_child(empty_label)
	else:
		for item_key in buffer.keys():
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			var label := Label.new()
			label.text = "%s x%d" % [ITEM_LABELS.get(item_key, item_key), int(buffer[item_key])]
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)
			var collect_btn := Button.new()
			collect_btn.text = "수령"
			collect_btn.pressed.connect(_on_collect_pressed)
			row.add_child(collect_btn)
			box.add_child(row)
	return box


## 지정한 수량만큼 배치를 시작한다(INBOX #99 — 시작 시점에 그 수량 전체분의 재료를 한
## 번에 소모하고, 이후 타이머로 결과물이 하나씩 작업대 내부 출력 버퍼에 쌓인다).
## start_batch()가 이미 배치가 진행 중이거나 재료가 부족하면 아무것도 소모하지 않고
## false를 반환하므로 그 경우에만 메시지를 보여준다.
func _on_craft_start_pressed(recipe: Dictionary, qty_spin: SpinBox) -> void:
	if _crafting_station == null:
		return
	var qty := int(qty_spin.value)
	if not _crafting_station.start_batch(recipe, qty):
		_crafting_message_label.text = "재료가 부족하거나 이미 다른 제작이 진행 중입니다"
		_crafting_message_label.visible = true
		_crafting_message_timer = 1.5


## 작업대 출력 버퍼를 플레이어 인벤토리로 수령한다(INBOX #99). CraftingStation.
## collect_output()이 이미 InventoryData.add_item()의 반환값으로 "들어간 만큼만 빼고
## 나머지는 버퍼에 남기는" 안전 패턴(INBOX #98)을 쓰므로, 여기서는 결과를 보고 인벤토리가
## 꽉 차서 일부만 수령됐는지 확인해 메시지만 보여준다.
func _on_collect_pressed() -> void:
	if _crafting_station == null:
		return
	var had_items: bool = not _crafting_station.output_buffer.is_empty()
	_crafting_station.collect_output()
	if had_items and not _crafting_station.output_buffer.is_empty():
		_crafting_message_label.text = "인벤토리에 공간이 없어 일부만 수령했습니다"
		_crafting_message_label.visible = true
		_crafting_message_timer = 1.5


## 저장 상자(INBOX #96)가 공유하는 범용 상자 창을 코드로 한 번만 조립해둔다
## (_build_crafting_window()와 같은 이유 — 상자마다 새 UI를 만들지 않고
## open_storage_window()만 호출하면 되게 하기 위함).
func _build_storage_window() -> void:
	var window := Control.new()
	window.name = "StorageWindow"
	window.visible = false
	window.set_anchors_preset(Control.PRESET_FULL_RECT)
	window.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	window.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.add_theme_stylebox_override("panel", _make_window_panel_style())
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	_storage_title_label = Label.new()
	_storage_title_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_storage_title_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 320)
	vbox.add_child(scroll)

	_storage_list = VBoxContainer.new()
	_storage_list.add_theme_constant_override("separation", 6)
	_storage_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_storage_list)

	_storage_message_label = Label.new()
	_storage_message_label.visible = false
	_storage_message_label.modulate = Color(1, 0.55, 0.55, 1)
	vbox.add_child(_storage_message_label)

	var close_hint := Label.new()
	# "99개씩"은 storage_chest.gd의 TRANSFER_AMOUNT 상수와 같은 값이어야 한다(노드를
	# 만들지 않고 상수만 읽을 방법이 마땅치 않아 문구로 하드코딩 — 값을 바꾸면 이 문구도
	# 같이 바꿀 것).
	close_hint.text = "ESC: 닫기 / 슬롯 클릭: 인벤토리로 옮기기(최대 99개씩)"
	close_hint.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(close_hint)

	ui_layer.add_child(window)
	_storage_window = window
	InventoryData.changed.connect(_refresh_storage_window)


## 상자 UI를 연다. chest는 storage_chest.gd 인스턴스 — 가공대의 RECIPES(값 전달)와 달리
## 상자는 슬롯 상태를 자기 자신이 들고 있으므로 노드 참조로 받아 그때그때 조회한다.
func open_storage_window(title: String, chest: Node) -> void:
	if _paused or _inventory_open or _crafting_open:
		return
	if _storage_chest != null and _storage_chest.changed.is_connected(_refresh_storage_window):
		_storage_chest.changed.disconnect(_refresh_storage_window)
	_storage_chest = chest
	_storage_chest.changed.connect(_refresh_storage_window)
	_storage_title_label.text = title
	_storage_open = true
	_storage_message_label.visible = false
	_storage_window.visible = true
	_refresh_storage_window()


func close_storage_window() -> void:
	_storage_open = false
	_storage_window.visible = false


## storage_chest.gd가 "지금 다른 상자/제작 창이 이미 열려 있는지" 확인할 때 쓴다
## (is_crafting_open()과 같은 공개 접근자 패턴).
func is_storage_open() -> bool:
	return _storage_open


func _refresh_storage_window() -> void:
	if not _storage_open or _storage_chest == null:
		return
	for child in _storage_list.get_children():
		child.queue_free()
	var slots: Array = _storage_chest.get_slots()
	var has_item := false
	for i in range(slots.size()):
		var slot = slots[i]
		if slot == null:
			continue
		has_item = true
		_storage_list.add_child(_make_storage_slot_row(i, slot))
	if not has_item:
		var empty_label := Label.new()
		empty_label.text = "(비어 있음)"
		empty_label.modulate = Color(1, 1, 1, 0.6)
		_storage_list.add_child(empty_label)


func _make_storage_slot_row(index: int, slot: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var display: String = ITEM_LABELS.get(slot["item"], slot["item"])
	var desc := Label.new()
	desc.text = "%s x%d" % [display, int(slot["count"])]
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(desc)

	var button := Button.new()
	button.text = "인벤토리로"
	button.pressed.connect(_on_storage_slot_pressed.bind(index))
	row.add_child(button)
	return row


## 상자 슬롯 버튼을 누르면 호출된다. 인벤토리에 공간이 없으면 조용히 무시하는 대신 잠깐
## 실패 메시지를 보여준다(INBOX #96 원문 "인벤토리에 공간이 없으면 실패 표시" 요구사항).
func _on_storage_slot_pressed(index: int) -> void:
	if _storage_chest == null:
		return
	if not _storage_chest.try_transfer_to_player(index):
		_storage_message_label.text = "인벤토리에 공간이 없습니다"
		_storage_message_label.visible = true
		_storage_message_timer = 1.5


func _on_time_phase_changed(_is_day: bool) -> void:
	_update_time_label()


func _on_time_day_changed(_day_number: int) -> void:
	_update_time_label()


func _on_time_weather_changed(is_raining: bool) -> void:
	rain_overlay.visible = is_raining


func _update_time_label() -> void:
	var phase_text := "낮" if TimeData.is_day else "밤"
	time_label.text = "%s %d일차 · %s" % [TimeData.season_label(), TimeData.current_day_of_month(), phase_text]


## 방향별 idle(1프레임) + walk(방향별 프레임 수가 다름, SpriteCook animate-sync로
## 생성) 애니메이션을 담은 SpriteFrames를 만든다. 도구별 들기/사용 모션은 아직
## 없다(#52~#54가 다시 만들 것).
## walk 프레임 수가 방향마다 다른 이유(INBOX #50 결과): south/north(정면/후면)는
## SpriteCook animate-sync가 8프레임을 요청하면 프레임 간 다리 위치가 거의
## 구분되지 않는 실패가 반복돼(같은 문제가 4프레임 요청에서는 완화됨) 4프레임으로
## 생성했고, east(측면, west는 east를 좌우반전한 것 — green_west.png가 기존에도
## green_east.png의 반전이었던 것과 같은 패턴)는 8프레임에서도 자연스러운 좌우
## 교차 보행이 나와 8프레임을 그대로 썼다.
const WALK_FRAME_COUNTS := {"south": 4, "north": 4, "east": 8, "west": 8}
const WALK_FPS := 6.0

func _build_player_sprite_frames(variant: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	for direction in ["south", "north", "east", "west"]:
		var idle_anim := "idle_%s" % direction
		frames.add_animation(idle_anim)
		frames.set_animation_speed(idle_anim, 1.0)
		frames.add_frame(idle_anim, load("res://assets/sprites/character/%s_%s.png" % [variant, direction]))

		var walk_anim := "walk_%s" % direction
		frames.add_animation(walk_anim)
		frames.set_animation_speed(walk_anim, WALK_FPS)
		var frame_count: int = WALK_FRAME_COUNTS[direction]
		for i in range(frame_count):
			frames.add_frame(walk_anim, load("res://assets/sprites/character/walk/%s_%s_walk_%d.png" % [variant, direction, i]))

		## 총의 "들고 있는"/"발사하는" 모션(INBOX #52). 캐릭터 그림 자체에 총을 쥔 손이
		## 그려져 있다(별도 아이콘 오버레이가 아님, DESIGN.md "캐릭터 애니메이션" 규칙).
		## 아직 green 색상만 이 자산이 있을 수 있어(#53이 blue/red를 채울 예정)
		## ResourceLoader.exists()로 확인해서, 없는 색상은 조용히 건너뛴다 — 그 색상은
		## _current_animation_name()에서 자동으로 맨손 idle/walk로 대체된다.
		var gun_idle_path := "res://assets/sprites/character/gun/%s_%s_idle.png" % [variant, direction]
		if ResourceLoader.exists(gun_idle_path):
			var gun_idle_anim := "gun_idle_%s" % direction
			frames.add_animation(gun_idle_anim)
			frames.set_animation_speed(gun_idle_anim, 1.0)
			frames.add_frame(gun_idle_anim, load(gun_idle_path))
		var gun_fire_path := "res://assets/sprites/character/gun/%s_%s_fire.png" % [variant, direction]
		if ResourceLoader.exists(gun_fire_path):
			var gun_fire_anim := "gun_fire_%s" % direction
			frames.add_animation(gun_fire_anim)
			frames.set_animation_speed(gun_fire_anim, 1.0)
			frames.add_frame(gun_fire_anim, load(gun_fire_path))

		## 곡괭이낫의 "들고 있는"/"채광하는"/"채집하는" 모션(INBOX #54). 총(#42)과 같은
		## 패턴 — 아직 green 색상만 이 자산이 있을 수 있어 ResourceLoader.exists()로
		## 확인해서, 없는 색상은 조용히 건너뛴다.
		var pickaxe_idle_path := "res://assets/sprites/character/pickaxe/%s_%s_idle.png" % [variant, direction]
		if ResourceLoader.exists(pickaxe_idle_path):
			var pickaxe_idle_anim := "pickaxe_idle_%s" % direction
			frames.add_animation(pickaxe_idle_anim)
			frames.set_animation_speed(pickaxe_idle_anim, 1.0)
			frames.add_frame(pickaxe_idle_anim, load(pickaxe_idle_path))
		var pickaxe_mining_path := "res://assets/sprites/character/pickaxe/%s_%s_mining.png" % [variant, direction]
		if ResourceLoader.exists(pickaxe_mining_path):
			var pickaxe_mining_anim := "pickaxe_mining_%s" % direction
			frames.add_animation(pickaxe_mining_anim)
			frames.set_animation_speed(pickaxe_mining_anim, 1.0)
			frames.add_frame(pickaxe_mining_anim, load(pickaxe_mining_path))
		var pickaxe_gathering_path := "res://assets/sprites/character/pickaxe/%s_%s_gathering.png" % [variant, direction]
		if ResourceLoader.exists(pickaxe_gathering_path):
			var pickaxe_gathering_anim := "pickaxe_gathering_%s" % direction
			frames.add_animation(pickaxe_gathering_anim)
			frames.set_animation_speed(pickaxe_gathering_anim, 1.0)
			frames.add_frame(pickaxe_gathering_anim, load(pickaxe_gathering_path))

		## 도끼의 "들고 있는"/"패는" 모션(INBOX #57, 자산 초기화로 삭제됐던 #43을
		## SpriteCook `generate-sync`+`edit_asset_id`로 재작업). 총/곡괭이낫과 같은
		## 패턴 — 아직 green 색상만 이 자산이 있을 수 있어 ResourceLoader.exists()로
		## 확인해서, 없는 색상은 조용히 건너뛴다.
		var axe_idle_path := "res://assets/sprites/character/axe/%s_%s_idle.png" % [variant, direction]
		if ResourceLoader.exists(axe_idle_path):
			var axe_idle_anim := "axe_idle_%s" % direction
			frames.add_animation(axe_idle_anim)
			frames.set_animation_speed(axe_idle_anim, 1.0)
			frames.add_frame(axe_idle_anim, load(axe_idle_path))
		var axe_chop_path := "res://assets/sprites/character/axe/%s_%s_chop.png" % [variant, direction]
		if ResourceLoader.exists(axe_chop_path):
			var axe_chop_anim := "axe_chop_%s" % direction
			frames.add_animation(axe_chop_anim)
			frames.set_animation_speed(axe_chop_anim, 1.0)
			frames.add_frame(axe_chop_anim, load(axe_chop_path))

		## 낚싯대의 "들고 있는"/"낚시하는" 모션(INBOX #59, 자산 초기화로 삭제됐던 #45를
		## SpriteCook `generate-sync`+`edit_asset_id`로 재작업). 총/도끼/곡괭이낫과 같은
		## 패턴 — 아직 green 색상만 이 자산이 있을 수 있어 ResourceLoader.exists()로
		## 확인해서, 없는 색상은 조용히 건너뛴다.
		var fishing_rod_idle_path := "res://assets/sprites/character/fishing_rod/%s_%s_idle.png" % [variant, direction]
		if ResourceLoader.exists(fishing_rod_idle_path):
			var fishing_rod_idle_anim := "fishing_rod_idle_%s" % direction
			frames.add_animation(fishing_rod_idle_anim)
			frames.set_animation_speed(fishing_rod_idle_anim, 1.0)
			frames.add_frame(fishing_rod_idle_anim, load(fishing_rod_idle_path))
		var fishing_rod_fishing_path := "res://assets/sprites/character/fishing_rod/%s_%s_fishing.png" % [variant, direction]
		if ResourceLoader.exists(fishing_rod_fishing_path):
			var fishing_rod_fishing_anim := "fishing_rod_fishing_%s" % direction
			frames.add_animation(fishing_rod_fishing_anim)
			frames.set_animation_speed(fishing_rod_fishing_anim, 1.0)
			frames.add_frame(fishing_rod_fishing_anim, load(fishing_rod_fishing_path))
	return frames


## 이동 중이면 방향별 walk 애니메이션, 멈춰 있으면 idle 애니메이션을 재생한다
## (INBOX #50). 총을 들고 있으면(INBOX #52) gun_idle_*/gun_fire_* 중
## _tool_use_flash_timer(발사 직후 잠깐 >0) 여부로 하나를 고른다 — 해당 색상의
## 총 애니메이션 자산이 아직 없으면(예: #53 전의 blue/red) 조용히 맨손 idle/walk로
## 대체된다.
func _current_animation_name() -> String:
	## 이동 중에는 도구 "idle" 포즈 대신 맨손 walk를 재생한다 (INBOX #65) — 도구별 walk
	## 프레임 세트가 아직 없어서, 들고 있어도 얼어붙은 채 미끄러지는 문제를 막기 위함.
	## 다만 "사용 중"(발사/패기/채광/채집/낚시, _tool_use_flash_timer > 0)이면 이동
	## 여부와 무관하게 항상 사용 모션을 보여준다 — #65가 이 조건 없이 "이동 중이면
	## 무조건 walk"로 막아버려서, 움직이면서 쏘거나 캐도 모션이 전혀 안 나가는 버그가
	## 있었다(사용자가 실제로 발견).
	var using_tool := _tool_use_flash_timer > 0.0
	if using_tool or not _is_moving:
		if _held_tool == "gun":
			var gun_anim := ("gun_fire_%s" if _tool_use_flash_timer > 0.0 else "gun_idle_%s") % _facing
			if player_sprite.sprite_frames.has_animation(gun_anim):
				return gun_anim
		elif _held_tool == "pickaxe":
			var pickaxe_suffix := ("pickaxe_%s_%s" % [_pickaxe_use_kind, _facing]) if _tool_use_flash_timer > 0.0 \
				else ("pickaxe_idle_%s" % _facing)
			if player_sprite.sprite_frames.has_animation(pickaxe_suffix):
				return pickaxe_suffix
		elif _held_tool == "axe":
			var axe_anim := ("axe_chop_%s" if _tool_use_flash_timer > 0.0 else "axe_idle_%s") % _facing
			if player_sprite.sprite_frames.has_animation(axe_anim):
				return axe_anim
		elif _held_tool == "fishing_rod":
			var fishing_rod_anim := ("fishing_rod_fishing_%s" if _tool_use_flash_timer > 0.0 else "fishing_rod_idle_%s") % _facing
			if player_sprite.sprite_frames.has_animation(fishing_rod_anim):
				return fishing_rod_anim
	var prefix := "walk_" if _is_moving else "idle_"
	return prefix + _facing


func _update_player_animation() -> void:
	var anim := _current_animation_name()
	if player_sprite.animation != anim or not player_sprite.is_playing():
		player_sprite.play(anim)


func _update_ammo_label() -> void:
	var ammo_name := "마취탄" if _ammo_type == "tranq" else "기본탄"
	if _is_reloading and _reloading_ammo_type == _ammo_type:
		ammo_label.text = "탄약: %s 재장전 중..." % ammo_name
	else:
		ammo_label.text = "탄약: %s %d/%d" % [ammo_name, _ammo_in_magazine[_ammo_type], GUN_MAGAZINE_SIZE]


## 총을 든 채 R키를 누르면 호출된다 (DESIGN.md "탄창: 8발... R키로 재장전").
## 예비 탄약 제한은 없어서 누르면 항상 가득 차게 재장전되고, 재장전 중에는 좌클릭
## 발사가 막힌다(위 _physics_process의 발사 조건 참고). 기본탄/마취탄은 서로 다른
## 탄창이라(INBOX #36) 지금 선택된 탄종의 탄창만 채운다.
func _start_reload() -> void:
	if _is_reloading or _ammo_in_magazine[_ammo_type] >= GUN_MAGAZINE_SIZE:
		return
	_is_reloading = true
	_reloading_ammo_type = _ammo_type
	_reload_timer = GUN_RELOAD_TIME
	_update_ammo_label()


func _set_paused(value: bool) -> void:
	_paused = value
	pause_menu.visible = value


func _on_resume_pressed() -> void:
	_set_paused(false)


func _on_settings_pressed() -> void:
	SettingsData.return_scene_path = "res://scenes/world/world.tscn"
	get_tree().change_scene_to_file("res://scenes/settings/settings.tscn")


func _on_quit_pressed() -> void:
	NetworkSession.leave()
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")


## 방 오버레이 토글(INBOX #126, 산소미포함 참고) — HUD 우상단 버튼.
func _on_room_overlay_toggle_toggled(pressed: bool) -> void:
	room_overlay.set_active(pressed)


## 멀티플레이 세션(INBOX #14)이 열려 있으면(NetworkSession.host_room/join_room을 거쳐
## 들어온 경우) 다른 플레이어의 접속/해제를 반영하고 위치 방송을 시작한다. 싱글플레이로
## 곧장 들어온 경우(NetworkSession.is_active() == false)는 아무것도 하지 않아 기존 동작과
## 완전히 동일하다.
func _setup_networking() -> void:
	if not NetworkSession.is_active():
		return
	net_panel.visible = true
	_update_net_label()
	multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	for id in multiplayer.get_peers():
		_ensure_remote_sprite(id)


func _update_net_label() -> void:
	var player_count := multiplayer.get_peers().size() + 1
	if NetworkSession.is_host:
		net_label.text = "방 코드: %s (접속 %d명)" % [
			NetworkSession.format_room_code(NetworkSession.room_code), player_count
		]
	else:
		net_label.text = "참가 중 (접속 %d명)" % player_count


func _on_multiplayer_peer_connected(id: int) -> void:
	_ensure_remote_sprite(id)
	_update_net_label()


func _on_multiplayer_peer_disconnected(id: int) -> void:
	if _remote_sprites.has(id):
		_remote_sprites[id].queue_free()
		_remote_sprites.erase(id)
		_remote_tex_paths.erase(id)
	_update_net_label()


## 호스트가 세션을 닫으면(방 나가기/종료) 참가자는 더 이상 할 게 없으니 메인 메뉴로 보낸다.
func _on_server_disconnected() -> void:
	NetworkSession.leave()
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")


func _ensure_remote_sprite(id: int) -> Sprite2D:
	if _remote_sprites.has(id):
		return _remote_sprites[id]
	var sprite := Sprite2D.new()
	sprite.scale = Vector2(1.5, 1.5)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	remote_players_root.add_child(sprite)
	_remote_sprites[id] = sprite
	return sprite


## 다른 플레이어(호스트든 참가자든)로부터 위치/방향/외형을 받아 그 자리에 있는 스프라이트를
## 옮긴다. 브로드캐스트 RPC라 나를 보낸 사람도 포함해 모두에게 도착하지만, `call_local`을
## 안 붙였으므로 내 클라이언트에서는 내가 보낸 것이 다시 나에게 실행되지 않는다.
@rpc("any_peer", "unreliable_ordered")
func _receive_state(pos: Vector2, facing: String, variant: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	var sprite := _ensure_remote_sprite(sender_id)
	sprite.position = pos
	var tex_path := "res://assets/sprites/character/%s_%s.png" % [variant, facing]
	if _remote_tex_paths.get(sender_id, "") != tex_path:
		sprite.texture = load(tex_path)
		_remote_tex_paths[sender_id] = tex_path
