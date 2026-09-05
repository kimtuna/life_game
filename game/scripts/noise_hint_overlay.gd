extends Control
class_name NoiseHintOverlay
## 시야 밖으로 숨은 동물이 움직이고 있을 때(DESIGN.md "시야 / 전장의 안개" 2026-09-05,
## INBOX #136) 화면 가장자리에 대략적인 방향만 알려주는 힌트 아이콘. 정확한 위치가 아니라
## "이 방향에 뭔가 있다" 수준이면 충분하다는 게 요구사항이라, 정교한 그림 대신 간단한
## 삼각형 도형으로 임시 처리한다(새 그림 제작은 [BUILD] 하네스 범위 밖).
## world.gd의 notify_hidden_noise()가 매 프레임 notify()를 호출해 타이머를 갱신하고,
## 타이머가 0이 되면 저절로 사라진다 — 여러 동물이 동시에 숨어서 움직이면 가장 최근에
## notify()된 방향 하나만 보여준다(동시 다중 힌트는 이번 범위 밖).

const DISPLAY_SECONDS := 0.6
const EDGE_MARGIN := 48.0
const ICON_LENGTH := 22.0
const ICON_WIDTH := 14.0
const ICON_COLOR := Color(1.0, 0.85, 0.1, 0.9)
## 핫바 위/주변에 여유를 두는 간격 (INBOX #139 — 힌트가 핫바와 겹쳐 아이템처럼
## 보이던 버그 수정용).
const HOTBAR_CLEARANCE := 14.0

var _timer: float = 0.0
var _direction: Vector2 = Vector2.ZERO

## world.tscn의 UI/HUD/HotbarBar (이 노드의 조부모 아래 형제) — 없으면(예: 핫바가 없는
## 테스트 씬) null로 남고 핫바 회피 로직은 그냥 건너뛴다.
@onready var _hotbar_bar: Control = get_node_or_null("../HUD/HotbarBar") as Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## world_pos 방향으로 화면 가장자리에 힌트를 (다시) 표시하고 타이머를 리셋한다.
func notify(world_pos: Vector2, player_pos: Vector2) -> void:
	var to_target := world_pos - player_pos
	if to_target.length() < 1.0:
		return
	_direction = to_target.normalized()
	_timer = DISPLAY_SECONDS


func _process(delta: float) -> void:
	if _timer <= 0.0:
		return
	_timer -= delta
	queue_redraw()
	if _timer <= 0.0:
		queue_redraw()


## 지금 _direction 기준으로 힌트가 그려질 최종 위치(핫바 회피 적용 후)를 계산한다.
## _draw()와 QA 검증 스크립트가 같은 계산을 공유하기 위해 분리해뒀다 (INBOX #139).
func _compute_point() -> Vector2:
	var center := size * 0.5
	var half_w := maxf(size.x * 0.5 - EDGE_MARGIN, 1.0)
	var half_h := maxf(size.y * 0.5 - EDGE_MARGIN, 1.0)
	var scale: float = min(half_w / max(absf(_direction.x), 0.0001), half_h / max(absf(_direction.y), 0.0001))
	return _avoid_hotbar(center + _direction * scale)


func _draw() -> void:
	if _timer <= 0.0 or _direction.length() < 0.01:
		return
	var point := _compute_point()
	var angle := _direction.angle()
	var tip := point + Vector2(ICON_LENGTH, 0.0).rotated(angle)
	var left := point + Vector2(-ICON_LENGTH * 0.5, ICON_WIDTH * 0.5).rotated(angle)
	var right := point + Vector2(-ICON_LENGTH * 0.5, -ICON_WIDTH * 0.5).rotated(angle)
	draw_polygon(PackedVector2Array([tip, left, right]), PackedColorArray([ICON_COLOR]))


## point가 핫바 위에 겹쳐 그려질 자리라면, 같은 x(=방향 정보)는 그대로 두고 y만
## 핫바 위쪽 여유 공간으로 밀어올린다 (INBOX #139). 핫바의 실제 화면 사각형을 매번
## 새로 조회하고, 씬에 핫바가 없으면(예: 단위 테스트 씬) 아무 것도 하지 않는다.
func _avoid_hotbar(point: Vector2) -> Vector2:
	if _hotbar_bar == null or not is_instance_valid(_hotbar_bar):
		return point
	var rect := _hotbar_bar.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return point
	# 삼각형 아이콘이 point에서 어느 방향으로든 최대 ICON_LENGTH만큼 튀어나올 수 있으니,
	# 그만큼 더 넓게 잡아서 "겹칠 수 있는 자리인가"를 판정한다.
	var detect := rect.grow(HOTBAR_CLEARANCE + ICON_LENGTH)
	var safe_bottom := rect.position.y - HOTBAR_CLEARANCE - ICON_LENGTH
	if detect.has_point(point) and point.y > safe_bottom:
		point.y = safe_bottom
	return point
