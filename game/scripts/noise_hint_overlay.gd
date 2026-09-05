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

var _timer: float = 0.0
var _direction: Vector2 = Vector2.ZERO


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


func _draw() -> void:
	if _timer <= 0.0 or _direction.length() < 0.01:
		return
	var center := size * 0.5
	var half_w := maxf(size.x * 0.5 - EDGE_MARGIN, 1.0)
	var half_h := maxf(size.y * 0.5 - EDGE_MARGIN, 1.0)
	var scale: float = min(half_w / max(absf(_direction.x), 0.0001), half_h / max(absf(_direction.y), 0.0001))
	var point := center + _direction * scale
	var angle := _direction.angle()
	var tip := point + Vector2(ICON_LENGTH, 0.0).rotated(angle)
	var left := point + Vector2(-ICON_LENGTH * 0.5, ICON_WIDTH * 0.5).rotated(angle)
	var right := point + Vector2(-ICON_LENGTH * 0.5, -ICON_WIDTH * 0.5).rotated(angle)
	draw_polygon(PackedVector2Array([tip, left, right]), PackedColorArray([ICON_COLOR]))
