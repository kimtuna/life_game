extends Node2D
## 사슴 한 마리의 AI(배회/도주)와 사냥/포획 판정을 맡는다. (INBOX #9)

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
const WANDER_MOVE_MIN := 1.0
const WANDER_MOVE_MAX := 2.5
const WANDER_IDLE_MIN := 1.0
const WANDER_IDLE_MAX := 3.0
const WORLD_BOUNDS := 3800.0
const FLEE_WALL_MARGIN := 80.0

@onready var sprite: Sprite2D = $Sprite

## world.gd가 스폰 직후 채워준다 (플레이어 접근 감지용).
var player_ref: Node2D = null

## 목장에 풀어놓은 사슴이면 true (INBOX #12). ranch_zone.gd가 스폰 직후 채워준다.
## 배회만 하고 도주하지 않으며, 이동 범위가 WORLD_BOUNDS 대신 zone_center 기준
## zone_radius 원형 범위로 제한된다.
var is_ranched: bool = false
var zone_center: Vector2 = Vector2.ZERO
var zone_radius: float = 0.0

var health: int = MAX_HEALTH
var _facing: String = "south"
var _state: String = "idle"  # idle, wander, flee
var _state_timer: float = 0.0
var _wander_dir: Vector2 = Vector2.ZERO
var _flee_timer: float = 0.0
var _dead: bool = false


func _ready() -> void:
	_update_texture()
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
			var away := Vector2.RIGHT
			if player_ref != null:
				var to_deer := global_position - player_ref.global_position
				if to_deer.length() > 1.0:
					away = to_deer.normalized()
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
	if health <= 0:
		_die()
	else:
		_start_flee()


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


func _move(direction: Vector2, speed: float, delta: float) -> void:
	if direction.length() < 0.01:
		return
	position += direction * speed * delta
	if is_ranched:
		var offset := position - zone_center
		if offset.length() > zone_radius:
			position = zone_center + offset.normalized() * zone_radius
	else:
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


func _die() -> void:
	_dead = true
	queue_free()


func _capture() -> void:
	_dead = true
	InventoryData.add_item(CAPTURED_ITEM, 1)
	queue_free()
