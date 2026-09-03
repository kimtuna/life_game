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
const FarmPlotScene := preload("res://scenes/farm_plot/farm_plot.tscn")
const RanchZoneScene := preload("res://scenes/ranch_zone/ranch_zone.tscn")
const DroppedItemScene := preload("res://scenes/dropped_item/dropped_item.tscn")

const DEER_COUNT := 6
const DEER_SPAWN_RADIUS := 1600.0
const DEER_MIN_DISTANCE_FROM_PLAYER := 300.0

const RESOURCE_POINT_COUNT := 5
const RESOURCE_SPAWN_RADIUS := 1400.0
const RESOURCE_MIN_DISTANCE_FROM_PLAYER := 200.0

## 밭은 채집/채광 포인트처럼 흩어놓지 않고, DESIGN.md "밭(정해진 구역)" 요구대로
## 스폰 지점 기준 항상 같은 자리에 고정된 격자로 배치한다.
const FARM_PLOT_COLUMNS := 3
const FARM_PLOT_ROWS := 2
const FARM_PLOT_SPACING := 120.0
const FARM_PLOT_ORIGIN := Vector2(500.0, -400.0)

## 목장 구역도 밭과 같은 이유(DESIGN.md "정해진 구역")로 스폰 지점 기준 고정 오프셋에 둔다.
const RANCH_ZONE_ORIGIN := Vector2(-650.0, -300.0)

## InventoryData가 저장하는 아이템 키(내부 이름) -> 화면 표시 이름.
const ITEM_LABELS := {
	"rice_seed": "벼 씨앗",
	"rice": "벼",
	"iron": "철",
	"captured_deer": "포획된 사슴",
	"gun": "총",
	"axe": "도끼",
	"pickaxe": "곡괭이낫",
	"fishing_rod": "낚싯대",
}

## 도구 아이템(INBOX #22). 순서대로 핫바 시작 슬롯(1~4번 키)에 지급된다.
## 곡괭이낫(pickaxe) 하나로 채집+채광을 둘 다 한다(INBOX #25 — 한때 별도 "낫" 아이템으로
## 나눴던 것을 다시 합침, DESIGN.md 참고). 도끼는 아직 벌목 대상이 없고 낚싯대도 낚시
## 스팟이 없어 좌클릭 동작은 #23에서 최소 반응만 연결했다(DESIGN.md "범위 밖" 참고).
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
@onready var ammo_label: Label = $UI/HUD/AmmoPanel/AmmoLabel
@onready var inventory_label: Label = $UI/HUD/InventoryPanel/InventoryLabel
@onready var time_label: Label = $UI/HUD/TimePanel/TimeLabel
@onready var net_panel: PanelContainer = $UI/HUD/NetPanel
@onready var net_label: Label = $UI/HUD/NetPanel/NetLabel
@onready var day_night_modulate: CanvasModulate = $DayNightModulate
@onready var rain_overlay: ColorRect = $UI/RainOverlay
@onready var inventory_window: Control = $UI/InventoryWindow
@onready var general_grid: GridContainer = $UI/InventoryWindow/CenterContainer/Panel/VBoxContainer/GeneralGrid
@onready var equipment_grid: GridContainer = $UI/InventoryWindow/CenterContainer/Panel/VBoxContainer/EquipmentGrid
@onready var hotbar_bar: HBoxContainer = $UI/HUD/HotbarBar

## 장비 슬롯 부위 표시 이름 (InventoryData.EQUIPMENT_SLOT_TYPES와 같은 순서).
const EQUIPMENT_LABELS := ["모자", "상의", "하의", "신발", "목걸이", "목걸이", "반지", "반지", "가방"]

var _variant: String = "green"
var _facing: String = "south"
var _paused: bool = false
var _inventory_open: bool = false
var _general_slot_labels: Array = []
var _equipment_slot_labels: Array = []
## 핫바 9칸 셀(각 원소 {"panel": PanelContainer, "item_label": Label, "number_label": Label}).
var _hotbar_cells: Array = []
var _selected_hotbar_index: int = 0
## 지금 손에 든 도구 키("gun"/"axe"/"pickaxe"/"fishing_rod") 또는 빈손("").
var _held_tool: String = ""
var _hotbar_normal_style: StyleBoxFlat
var _hotbar_selected_style: StyleBoxFlat
var _ammo_type: String = "normal"
var _fire_cooldown: float = 0.0
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
	_ensure_starting_tools()
	_build_inventory_slots()
	_build_hotbar()
	InventoryData.changed.connect(_update_inventory_label)
	InventoryData.changed.connect(_refresh_inventory_window)
	InventoryData.changed.connect(_refresh_hotbar)
	InventoryData.changed.connect(_revalidate_held_hotbar_slot)
	_update_inventory_label()
	_select_hotbar(0)
	TimeData.phase_changed.connect(_on_time_phase_changed)
	TimeData.day_changed.connect(_on_time_day_changed)
	TimeData.weather_changed.connect(_on_time_weather_changed)
	_update_time_label()
	rain_overlay.visible = TimeData.is_raining
	_setup_networking()


func _process(_delta: float) -> void:
	var t := TimeData.phase_progress()
	day_night_modulate.color = DAY_COLOR.lerp(NIGHT_COLOR, t) if TimeData.is_day \
		else NIGHT_COLOR.lerp(DAY_COLOR, t)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _inventory_open:
			_set_inventory_open(false)
		else:
			_set_paused(not _paused)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E \
			and not _paused:
		_set_inventory_open(not _inventory_open)
	elif event is InputEventKey and event.pressed and not event.echo and not _paused and not _inventory_open \
			and event.keycode >= KEY_1 and event.keycode <= KEY_9:
		_select_hotbar(event.keycode - KEY_1)
	elif event is InputEventKey and event.pressed and not event.echo and not _paused and not _inventory_open \
			and event.keycode == KEY_R and _held_tool == "gun":
		_start_reload()
	elif event is InputEventMouseButton and event.pressed and not _paused and not _inventory_open \
			and event.button_index == MOUSE_BUTTON_RIGHT and _held_tool == "gun":
		_ammo_type = "tranq" if _ammo_type == "normal" else "normal"
		_update_ammo_label()
	elif event is InputEventMouseButton and event.pressed and not _paused and not _inventory_open \
			and event.button_index == MOUSE_BUTTON_LEFT and _held_tool == "axe":
		## 도끼는 INBOX #43부터 옆 아이콘이 아니라 캐릭터 애니메이션 프레임 자체
		## (axe_chop_*)로 패는 모션을 보여준다 (총(#42)과 같은 패턴).
		_tool_use_flash_timer = AXE_CHOP_FLASH_DURATION
	elif event is InputEventMouseButton and event.pressed and not _paused and not _inventory_open \
			and event.button_index == MOUSE_BUTTON_LEFT and _held_tool == "pickaxe":
		## 곡괭이낫은 INBOX #73부터 도끼(#43)와 같은 방식으로, 채집/채광 대상이 없어도
		## (허공에 대고) 좌클릭하면 항상 스윙 모션이 나가야 한다 (DESIGN.md "생활 스킬 —
		## 채집 계열": 총/도끼/곡괭이낫은 대상 유무와 무관하게 항상 사용 모션 — 근접무기
		## 확장 계획 근거). 실제 채광/채집 판정(어느 kind인지, 아이템 드롭 등)은 여전히
		## resource_point.gd가 담당한다 — 이 브랜치는 `_pickaxe_use_kind`를 건드리지 않고
		## 모션 타이머만 켠다. 대상이 실제로 있으면 resource_point.gd의 _harvest()가 같은
		## 입력 이벤트 처리 중에 play_pickaxe_use(kind)로 올바른 kind를 덮어써 준다.
		_tool_use_flash_timer = AXE_CHOP_FLASH_DURATION
	elif event is InputEventMouseButton and event.pressed and not _paused and not _inventory_open \
			and event.button_index == MOUSE_BUTTON_LEFT and _held_tool == "fishing_rod":
		## 낚싯대는 INBOX #45부터 옆 아이콘이 아니라 캐릭터 애니메이션 프레임 자체
		## (fishing_rod_fishing_*)로 낚시하는 모션을 보여준다 (도끼(#43)와 같은 패턴).
		_tool_use_flash_timer = AXE_CHOP_FLASH_DURATION


func _physics_process(delta: float) -> void:
	if _paused or _inventory_open:
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
	player_sprite.position += input_dir * MOVE_SPEED * delta

	var to_mouse := get_global_mouse_position() - player_sprite.global_position
	if to_mouse.length() > 1.0:
		_facing = _facing_from_direction(to_mouse)

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
	if _held_tool == "gun" and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _fire_cooldown <= 0.0 \
			and not _is_reloading and _ammo_in_magazine[_ammo_type] > 0:
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


## 필드에 채집 포인트(삽 → 벼 씨앗)와 채광 포인트(곡괭이 → 철)를 절반씩 흩어서 배치한다
## (INBOX #10). DESIGN.md대로 삽/곡괭이를 한 세트로 다루므로, 포인트 종류에 따라
## 알맞은 판정을 자동 적용한다(도구 선택 UI 없음) — resource_point.gd 참고.
func _spawn_resource_points() -> void:
	for i in range(RESOURCE_POINT_COUNT):
		_spawn_one_resource_point(GatheringPointScene)
	for i in range(RESOURCE_POINT_COUNT):
		_spawn_one_resource_point(MiningPointScene)


func _spawn_one_resource_point(scene: PackedScene) -> void:
	var point := scene.instantiate()
	var pos := Vector2.ZERO
	for attempt in range(20):
		pos = Vector2(
			randf_range(-RESOURCE_SPAWN_RADIUS, RESOURCE_SPAWN_RADIUS),
			randf_range(-RESOURCE_SPAWN_RADIUS, RESOURCE_SPAWN_RADIUS)
		)
		if pos.distance_to(player_sprite.position) >= RESOURCE_MIN_DISTANCE_FROM_PLAYER:
			break
	point.global_position = pos
	point.player_ref = player_sprite
	point.world_ref = self
	add_child(point)


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


func _update_inventory_label() -> void:
	var counts := InventoryData.all_counts()
	if counts.is_empty():
		inventory_label.text = "인벤토리: (비어 있음)"
		return
	var parts: Array[String] = []
	for item_key in ITEM_LABELS.keys():
		var count: int = counts.get(item_key, 0)
		if count > 0:
			parts.append("%s x%d" % [ITEM_LABELS[item_key], count])
	inventory_label.text = "인벤토리: " + (", ".join(parts) if not parts.is_empty() else "(비어 있음)")


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
