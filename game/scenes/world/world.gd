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

## 낮/밤 화면 밝기 (INBOX #13). TimeData.phase_progress()에 맞춰 두 색 사이를 보간한다.
const DAY_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const NIGHT_COLOR := Color(0.25, 0.28, 0.48, 1.0)

const BulletScene := preload("res://scenes/bullet/bullet.tscn")
const DeerScene := preload("res://scenes/deer/deer.tscn")
const GatheringPointScene := preload("res://scenes/resource_point/gathering_point.tscn")
const MiningPointScene := preload("res://scenes/resource_point/mining_point.tscn")
const FarmPlotScene := preload("res://scenes/farm_plot/farm_plot.tscn")
const RanchZoneScene := preload("res://scenes/ranch_zone/ranch_zone.tscn")

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
	"pickaxe": "곡괭이",
	"sickle": "낫",
	"fishing_rod": "낚싯대",
}

## 도구 아이템(INBOX #22). 순서대로 핫바 시작 슬롯(1~5번 키)에 지급된다.
## 도끼는 아직 벌목 대상이 없고 낚싯대도 낚시 스팟이 없어 좌클릭 동작은 #23에서 연결한다
## (DESIGN.md "범위 밖" 참고) — 이번 바퀴는 손에 드는 것(스프라이트 전환)까지만.
const TOOL_KEYS := ["gun", "axe", "pickaxe", "sickle", "fishing_rod"]
const TOOL_ICONS := {
	"gun": preload("res://assets/sprites/tools/gun.png"),
	"axe": preload("res://assets/sprites/tools/axe.png"),
	"pickaxe": preload("res://assets/sprites/tools/pickaxe.png"),
	"sickle": preload("res://assets/sprites/tools/sickle.png"),
	"fishing_rod": preload("res://assets/sprites/tools/fishing_rod.png"),
}

## 손에 든 도구 아이콘을 캐릭터 옆 어디에 띄울지, 바라보는 방향별 오프셋(플레이어 로컬 좌표계).
const HELD_ITEM_OFFSETS := {
	"east": Vector2(15.0, 3.0),
	"west": Vector2(-15.0, 3.0),
	"north": Vector2(3.0, -15.0),
	"south": Vector2(3.0, 15.0),
}

## 다른 플레이어에게 내 위치/방향을 보내는 주기 (INBOX #14). 매 물리 프레임(60Hz)마다
## 보내면 LAN 기준으로도 낭비라, 10Hz로 줄인다 — 위치는 unreliable 채널이라 중간에
## 패킷이 빠져도 다음 것으로 자연히 보정된다.
const STATE_BROADCAST_INTERVAL := 0.1

@onready var player_sprite: Sprite2D = $Player
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
## 지금 손에 든 도구 키("gun"/"axe"/"pickaxe"/"sickle"/"fishing_rod") 또는 빈손("").
var _held_tool: String = ""
var _held_item_sprite: Sprite2D
var _hotbar_normal_style: StyleBoxFlat
var _hotbar_selected_style: StyleBoxFlat
var _ammo_type: String = "normal"
var _fire_cooldown: float = 0.0
var _recoil: float = 0.0
var _is_moving: bool = false
var _state_broadcast_timer: float = 0.0
## peer id -> 그 플레이어를 대신 그리는 Sprite2D (INBOX #14, remote_players_root의 자식).
var _remote_sprites: Dictionary = {}
## peer id -> 마지막으로 그 스프라이트에 로드한 텍스처 경로 (매 프레임 load()하지 않기 위한 캐시).
var _remote_tex_paths: Dictionary = {}


func _ready() -> void:
	var character := CharacterData.get_character(CharacterData.active_slot_index)
	_variant = character.get("variant", "green")
	_update_texture()
	_update_ammo_label()
	_spawn_deer()
	_spawn_resource_points()
	_spawn_farm_plots()
	_spawn_ranch_zone()
	_ensure_starting_tools()
	_build_inventory_slots()
	_build_held_item_sprite()
	_build_hotbar()
	InventoryData.changed.connect(_update_inventory_label)
	InventoryData.changed.connect(_refresh_inventory_window)
	InventoryData.changed.connect(_refresh_hotbar)
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
	elif event is InputEventMouseButton and event.pressed and not _paused and not _inventory_open \
			and event.button_index == MOUSE_BUTTON_RIGHT and _held_tool == "gun":
		_ammo_type = "tranq" if _ammo_type == "normal" else "normal"
		_update_ammo_label()
	elif event is InputEventMouseButton and event.pressed and not _paused and not _inventory_open \
			and event.button_index == MOUSE_BUTTON_LEFT and (_held_tool == "axe" or _held_tool == "fishing_rod"):
		_play_tool_swing()


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
		var new_facing := _facing_from_direction(to_mouse)
		if new_facing != _facing:
			_facing = new_facing
			_update_texture()
			_update_held_item_transform()

	camera.global_position = player_sprite.global_position

	_recoil = maxf(0.0, _recoil - GUN_RECOIL_DECAY_PER_SEC * delta)
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta
	if _held_tool == "gun" and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _fire_cooldown <= 0.0:
		_fire()

	if NetworkSession.is_active():
		_state_broadcast_timer -= delta
		if _state_broadcast_timer <= 0.0:
			_state_broadcast_timer = STATE_BROADCAST_INTERVAL
			_receive_state.rpc(player_sprite.position, _facing, _variant)


## 조준 방향에 반동(위로 튐)과 탄퍼짐(이동 중이면 커짐)을 섞어서 총알을 하나 쏜다.
func _fire() -> void:
	_fire_cooldown = GUN_FIRE_INTERVAL
	_recoil = minf(GUN_RECOIL_MAX, _recoil + GUN_RECOIL_PER_SHOT)

	var aim := get_global_mouse_position() - player_sprite.global_position
	if aim.length() < 1.0:
		aim = Vector2.RIGHT
	aim = aim.normalized()
	aim = (aim + Vector2.UP * _recoil).normalized()
	var spread_deg := GUN_SPREAD_MOVE_DEG if _is_moving else GUN_SPREAD_IDLE_DEG
	aim = aim.rotated(deg_to_rad(randf_range(-spread_deg * 0.5, spread_deg * 0.5)))

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


## 도끼/낚싯대는 아직 벌목 대상(나무)·낚시 스팟이 없어 실제 동작을 만들 수 없다
## (DESIGN.md "범위 밖"). INBOX #23이 요구한 "좌클릭 애니메이션/동작만 연결"을
## 위해 손에 든 아이콘을 짧게 확대했다 줄이는 최소한의 스윙 반응만 재생한다.
func _play_tool_swing() -> void:
	if _held_item_sprite == null or not _held_item_sprite.visible:
		return
	var base_scale := Vector2(0.85, 0.85)
	var tween := create_tween()
	tween.tween_property(_held_item_sprite, "scale", base_scale * 1.35, 0.08)
	tween.tween_property(_held_item_sprite, "scale", base_scale, 0.12)


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


## 아직 도구를 얻는 채집/제작 경로가 없으므로(DESIGN.md 범위 밖), 캐릭터가 처음
## 월드에 들어올 때 도구 5종을 한 벌씩 지급해 핫바 1~5번에서 바로 시험해볼 수 있게 한다
## (INBOX #22, 스스로 판단해서 추가). 이미 총을 갖고 있으면(재입장) 다시 지급하지 않는다.
func _ensure_starting_tools() -> void:
	if InventoryData.has_item("gun", 1):
		return
	for tool_key in TOOL_KEYS:
		InventoryData.add_item(tool_key, 1)


## 손에 든 도구 아이콘을 보여줄 Sprite2D를 Player의 자식으로 만든다. Player의 스케일을
## 그대로 물려받으므로 캐릭터 크기와 비례가 맞는다.
func _build_held_item_sprite() -> void:
	_held_item_sprite = Sprite2D.new()
	_held_item_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_held_item_sprite.scale = Vector2(0.85, 0.85)
	_held_item_sprite.visible = false
	player_sprite.add_child(_held_item_sprite)


## 바라보는 방향에 맞춰 손에 든 아이콘의 위치/좌우반전을 갱신한다.
func _update_held_item_transform() -> void:
	if _held_item_sprite == null:
		return
	_held_item_sprite.position = HELD_ITEM_OFFSETS.get(_facing, Vector2.ZERO)
	_held_item_sprite.flip_h = _facing == "west"


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
	item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_label.add_theme_font_size_override("font_size", 11)
	panel.add_child(item_label)
	var number_label := Label.new()
	number_label.text = str(number)
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
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


## 숫자키 1~9로 핫바 슬롯을 고른다. 도구 아이템이면 손에 들고(아이콘 스프라이트 전환),
## 빈 슬롯이거나 도구가 아닌 아이템이면 빈손으로 되돌린다 (INBOX #22 요구사항 그대로).
func _select_hotbar(index: int) -> void:
	if index < 0 or index >= InventoryData.HOTBAR_SIZE:
		return
	_selected_hotbar_index = index
	var general_slots := InventoryData.get_general_slots()
	var slot = general_slots[index] if index < general_slots.size() else null
	if slot != null and TOOL_ICONS.has(slot["item"]):
		_held_tool = slot["item"]
		_held_item_sprite.texture = TOOL_ICONS[_held_tool]
		_held_item_sprite.visible = true
		_update_held_item_transform()
	else:
		_held_tool = ""
		_held_item_sprite.visible = false
	_refresh_hotbar()


## 인벤토리 창의 일반 18칸 + 장비 9칸 슬롯 셀을 한 번만 만들어둔다 (INBOX #21).
## 슬롯 배경색으로 핫바(맨 위 9칸)와 일반 슬롯을 구분한다.
func _build_inventory_slots() -> void:
	var hotbar_style := _make_slot_style(Color(0.22, 0.32, 0.22, 1))
	var normal_style := _make_slot_style(Color(0.157, 0.212, 0.184, 1))
	for i in range(InventoryData.GENERAL_SLOT_COUNT):
		var style := hotbar_style if i < InventoryData.HOTBAR_SIZE else normal_style
		var cell := _make_slot_cell(style)
		general_grid.add_child(cell)
		_general_slot_labels.append(cell.get_node("Label"))
	for i in range(InventoryData.EQUIPMENT_SLOT_TYPES.size()):
		var cell := _make_slot_cell(normal_style)
		equipment_grid.add_child(cell)
		_equipment_slot_labels.append(cell.get_node("Label"))


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


func _make_slot_cell(style: StyleBoxFlat) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(72, 72)
	cell.add_theme_stylebox_override("panel", style)
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


func _update_texture() -> void:
	player_sprite.texture = load("res://assets/sprites/character/%s_%s.png" % [_variant, _facing])


func _update_ammo_label() -> void:
	ammo_label.text = "탄약: 마취탄" if _ammo_type == "tranq" else "탄약: 기본탄"


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
