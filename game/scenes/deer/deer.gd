extends CharacterBody2D
## 사슴 한 마리의 AI(배회/도주)와 사냥/포획 판정을 맡는다. (INBOX #9)
## INBOX #26부터 CharacterBody2D로 바뀌었다 — move_and_slide()가 목장 담장
## (ranch_zone.gd가 만드는 StaticBody2D+CollisionShape2D)과 실제로 충돌하게
## 하기 위함. 이전에는 순수 Node2D + 직접 position 대입 방식이라 목장 경계를
## "밀어내는" 물리 충돌이 불가능해서 매 프레임 위치를 강제로 되돌리는 clamp로
## 대신했었다.

const MAX_HEALTH := 100
## DESIGN.md "포획": 체력이 10%(=10) 미만으로 떨어지는 상태에서 마취탄에 맞으면 포획.
## 100체력/25데미지 조합에서는 정확히 10% 지점을 "지나치는" 한 방(예: 25→0)만 가능하므로,
## "이 한 발을 맞은 결과 체력이 10% 이하로 떨어지는가"를 기준으로 판정한다.
const CAPTURE_HEALTH_THRESHOLD := MAX_HEALTH * 0.1
## 포획 성공 시 InventoryData에 쌓이는 아이템 키 (INBOX #12: 목장에 풀어놓을 때 소비됨).
const CAPTURED_ITEM := "captured_deer"

const WANDER_SPEED := 60.0
const FLEE_SPEED := 200.0
const DETECT_RADIUS := 260.0
const FLEE_CLEAR_RADIUS := 360.0
const FLEE_MIN_DURATION := 3.0
## INBOX #30: 도주가 플레이어 반대 방향으로 일직선이면 맞추기 너무 쉬워서, 일정 시간마다
## 반대 방향에 무작위 각도 편차를 섞어 지그재그로 만든다. 편차 범위를 90도 이내로 제한해
## "대체로 플레이어에게서 멀어지는" 방향성 자체는 유지한다.
const FLEE_ZIGZAG_MIN_INTERVAL := 0.3
const FLEE_ZIGZAG_MAX_INTERVAL := 0.6
const FLEE_ZIGZAG_MAX_ANGLE_DEG := 60.0
const WANDER_MOVE_MIN := 1.0
const WANDER_MOVE_MAX := 2.5
const WANDER_IDLE_MIN := 1.0
const WANDER_IDLE_MAX := 3.0
const WORLD_BOUNDS := 3800.0
const FLEE_WALL_MARGIN := 80.0

@onready var sprite: Sprite2D = $Sprite
@onready var health_bar: Node2D = $HealthBar
@onready var health_bar_fill: ColorRect = $HealthBar/Fill

const HEALTH_BAR_WIDTH := 40.0
## 포획 가능 구간(체력 10% 이하)을 색으로 구분해서, 마취탄 포획 타이밍을
## 체력바만 보고도 알 수 있게 한다 (INBOX #19가 요구하지 않은 추가 UX).
const HEALTH_BAR_COLOR_NORMAL := Color(0.2, 0.8, 0.2, 1.0)
const HEALTH_BAR_COLOR_CAPTURABLE := Color(0.95, 0.85, 0.15, 1.0)

## world.gd가 스폰 직후 채워준다 (플레이어 접근 감지용).
var player_ref: Node2D = null
## world.gd가 스폰 직후 채워준다 — 포획 시 바닥 드롭 오브젝트를 스폰하기 위해 필요
## (INBOX #24). 목장에서 풀려난 사슴(is_ranched)은 _capture()가 호출되지 않으므로
## world_ref 없이도 안전하다.
var world_ref: Node2D = null

## 목장에 풀어놓은 사슴이면 true (INBOX #12). ranch_zone.gd가 스폰 직후 채워준다.
## 배회만 하고 도주하지 않는다. 이동 범위는 (INBOX #26부터) zone_center/zone_radius로
## 더 이상 코드로 clamp하지 않고, ranch_zone.gd가 세운 실제 담장(StaticBody2D)이
## move_and_slide()로 물리적으로 막아준다 — 두 값은 이제 ranch_zone.gd가 담장 반경과
## 일치시켜 초기 스폰 위치를 무작위로 고를 때만 참고용으로 쓴다.
var is_ranched: bool = false
var zone_center: Vector2 = Vector2.ZERO
var zone_radius: float = 0.0

var health: int = MAX_HEALTH
var _facing: String = "south"
var _state: String = "idle"  # idle, wander, flee
var _state_timer: float = 0.0
var _wander_dir: Vector2 = Vector2.ZERO
var _flee_timer: float = 0.0
var _flee_zigzag_angle: float = 0.0
var _flee_zigzag_timer: float = 0.0
var _dead: bool = false


func _ready() -> void:
	_update_texture()
	_update_health_bar()
	_pick_idle()


func _physics_process(delta: float) -> void:
	if _dead:
		return

	if not is_ranched and _state != "flee" and player_ref != null \
			and global_position.distance_to(player_ref.global_position) < DETECT_RADIUS:
		_start_flee()

	match _state:
		"flee":
			_flee_timer -= delta
			_flee_zigzag_timer -= delta
			if _flee_zigzag_timer <= 0.0:
				_flee_zigzag_timer = randf_range(FLEE_ZIGZAG_MIN_INTERVAL, FLEE_ZIGZAG_MAX_INTERVAL)
				_flee_zigzag_angle = deg_to_rad(randf_range(-FLEE_ZIGZAG_MAX_ANGLE_DEG, FLEE_ZIGZAG_MAX_ANGLE_DEG))
			var away := Vector2.RIGHT
			if player_ref != null:
				var to_deer := global_position - player_ref.global_position
				if to_deer.length() > 1.0:
					away = to_deer.normalized()
			away = away.rotated(_flee_zigzag_angle)
			away = _wall_slide_direction(away)
			_move(away, FLEE_SPEED, delta)
			var far_enough := player_ref == null \
					or global_position.distance_to(player_ref.global_position) > FLEE_CLEAR_RADIUS
			if _flee_timer <= 0.0 and far_enough:
				_pick_idle()
		"wander":
			_state_timer -= delta
			_move(_wander_dir, WANDER_SPEED, delta)
			if _state_timer <= 0.0:
				_pick_idle()
		"idle":
			_state_timer -= delta
			if _state_timer <= 0.0:
				_pick_wander()


## 총알에 맞았을 때 world.gd/bullet.gd가 호출한다.
## 목장에 풀어놓은 사슴은 이미 길들여진 가축이므로 다시 사냥/포획 대상이 되지 않는다.
func take_hit(damage: int, ammo_type: String) -> void:
	if _dead or is_ranched:
		return
	var resulting := health - damage
	if ammo_type == "tranq" and resulting <= CAPTURE_HEALTH_THRESHOLD:
		_capture()
		return
	health = maxi(0, resulting)
	_update_health_bar()
	if health <= 0:
		_die()
	else:
		_start_flee()


## 체력바는 만피(다치지 않은 상태)일 때는 숨기고, 한 번이라도 맞으면 보여준다 (INBOX #19).
## 포획 가능 구간(체력 10% 이하)에서는 색을 바꿔 마취탄 포획 타이밍을 강조한다.
func _update_health_bar() -> void:
	health_bar.visible = health < MAX_HEALTH
	var ratio := float(health) / float(MAX_HEALTH)
	health_bar_fill.offset_right = health_bar_fill.offset_left + HEALTH_BAR_WIDTH * ratio
	if health <= CAPTURE_HEALTH_THRESHOLD:
		health_bar_fill.color = HEALTH_BAR_COLOR_CAPTURABLE
	else:
		health_bar_fill.color = HEALTH_BAR_COLOR_NORMAL


## 도주 방향 중 월드 경계 쪽으로 파고드는 성분을 0으로 눌러(벽을 따라 미끄러지듯) 실제로
## 움직일 수 있는 방향으로 바꿔준다. 두 축 다 막힌 구석에서는 원래 방향에 수직인 방향으로
## 벽을 타고 피한다. INBOX #18: 구석에 몰리면 그대로 멈춰버리던 버그 수정.
func _wall_slide_direction(preferred: Vector2) -> Vector2:
	if is_ranched or preferred.length() < 0.01:
		return preferred
	var adjusted := preferred
	if position.x <= -WORLD_BOUNDS + FLEE_WALL_MARGIN and adjusted.x < 0.0:
		adjusted.x = 0.0
	elif position.x >= WORLD_BOUNDS - FLEE_WALL_MARGIN and adjusted.x > 0.0:
		adjusted.x = 0.0
	if position.y <= -WORLD_BOUNDS + FLEE_WALL_MARGIN and adjusted.y < 0.0:
		adjusted.y = 0.0
	elif position.y >= WORLD_BOUNDS - FLEE_WALL_MARGIN and adjusted.y > 0.0:
		adjusted.y = 0.0
	if adjusted.length() < 0.01:
		# 두 축 다 막힌 구석: 원래 방향에 수직인 방향(벽을 타고 옆으로)으로 피한다.
		adjusted = Vector2(-preferred.y, preferred.x)
	return adjusted.normalized()


func _move(direction: Vector2, speed: float, _delta: float) -> void:
	if direction.length() < 0.01:
		velocity = Vector2.ZERO
		return
	velocity = direction * speed
	move_and_slide()
	if not is_ranched:
		position.x = clampf(position.x, -WORLD_BOUNDS, WORLD_BOUNDS)
		position.y = clampf(position.y, -WORLD_BOUNDS, WORLD_BOUNDS)
	var new_facing := _facing_from_direction(direction)
	if new_facing != _facing:
		_facing = new_facing
		_update_texture()


## world.gd의 플레이어와 같은 4방향 판정을 쓴다 (DESIGN.md 조작 절 참고 방식).
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


## west 스프라이트는 따로 생성하지 않고 east를 좌우 반전해서 쓴다 (사슴은 좌우 대칭 실루엣).
func _update_texture() -> void:
	if _facing == "west":
		sprite.texture = load("res://assets/sprites/deer/deer_east.png")
		sprite.flip_h = true
	else:
		sprite.texture = load("res://assets/sprites/deer/deer_%s.png" % _facing)
		sprite.flip_h = false


func _pick_idle() -> void:
	_state = "idle"
	_state_timer = randf_range(WANDER_IDLE_MIN, WANDER_IDLE_MAX)


func _pick_wander() -> void:
	_state = "wander"
	_state_timer = randf_range(WANDER_MOVE_MIN, WANDER_MOVE_MAX)
	_wander_dir = Vector2.RIGHT.rotated(randf_range(0.0, TAU))


func _start_flee() -> void:
	_state = "flee"
	_flee_timer = FLEE_MIN_DURATION
	_flee_zigzag_timer = 0.0


func _die() -> void:
	_dead = true
	queue_free()


func _capture() -> void:
	_dead = true
	if world_ref != null:
		world_ref.spawn_dropped_item(CAPTURED_ITEM, 1, global_position)
	queue_free()
