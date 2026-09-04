extends Node2D
class_name FogOfWar
## 시야/전장의 안개(Fog of War, INBOX #135, 코어키퍼 참고). DESIGN.md "시야 / 전장의
## 안개" 절 그대로: 플레이어 위치를 꼭짓점으로, 조준 방향(기존 총 조준 계산과 동일한
## world_ref.get_aim_direction())을 중심으로 한 부채꼴(콘) 밖은 안 보이고, 콘 안이라도
## 벽/닫힌 문에 가로막힌 칸은 안 보인다. 안 보이는 칸은 완전한 검은색(불투명)으로 덮는다.
## room_overlay.gd(반투명, 토글식 방 표시)와는 목적이 다른 별개의 레이어이고, 토글 없이
## 항상 켜져 있다. room_overlay.gd와 같은 패턴으로 world_ref의 공개 접근자만 쓰고 내부
## 상태(_grid_occupancy 등)를 직접 건드리지 않는다.
## 멀티플레이: 이 노드는 각 클라이언트의 World 씬 인스턴스 안에 있고 항상
## world_ref.player_sprite(자기 자신의 로컬 플레이어)만 기준으로 계산하므로, 클라이언트마다
## 독립적으로 자기 화면의 안개만 그린다(다른 플레이어 화면에 영향 없음).

## 1280x720 기준 화면 대각선의 절반(약 734)보다 살짝 크게 잡아 해상도가 달라져도
## (카메라/해상도 규칙상 시야 범위는 고정) 화면 구석까지 안개가 덮이게 한다.
const FOG_RADIUS := 820.0
## 총 110도 콘(좌우 55도씩) — DESIGN.md가 예시로 든 100~120도 범위 안에서 임의로 정함.
const FOG_HALF_ANGLE_DEG := 55.0
const FOG_COLOR := Color(0.0, 0.0, 0.0, 1.0)

var world_ref: Node2D = null
var _grid_size: float = 32.0


func setup(world: Node2D, grid_size: float) -> void:
	world_ref = world
	_grid_size = grid_size


func _process(_delta: float) -> void:
	## room_overlay.gd와 같은 이유로 _physics_process가 아니라 _process에서 매 프레임
	## 다시 그린다 — 카메라가 플레이어를 따라 움직이는 동안 화면에 보이는 칸 범위도
	## 매 프레임 바뀌고, 토글이 없어 항상 켜져 있어야 하므로 조건 없이 매번 redraw한다.
	queue_redraw()


func _draw() -> void:
	if world_ref == null:
		return
	var cam: Camera2D = world_ref.camera
	var player: Node2D = world_ref.player_sprite
	if cam == null or player == null:
		return
	var player_pos: Vector2 = player.global_position
	var aim_angle: float = world_ref.get_aim_direction().angle()
	var half_angle := deg_to_rad(FOG_HALF_ANGLE_DEG)
	var player_cell := Vector2i(floori(player_pos.x / _grid_size), floori(player_pos.y / _grid_size))

	var viewport_size: Vector2 = get_viewport_rect().size
	var top_left: Vector2 = cam.global_position - viewport_size * 0.5
	var bottom_right: Vector2 = cam.global_position + viewport_size * 0.5
	var min_cell := Vector2i(floori(top_left.x / _grid_size), floori(top_left.y / _grid_size))
	var max_cell := Vector2i(floori(bottom_right.x / _grid_size), floori(bottom_right.y / _grid_size))

	for gx in range(min_cell.x, max_cell.x + 1):
		for gy in range(min_cell.y, max_cell.y + 1):
			var cell := Vector2i(gx, gy)
			var cell_center := Vector2((gx + 0.5) * _grid_size, (gy + 0.5) * _grid_size)
			if not _is_cell_visible(cell, cell_center, player_pos, player_cell, aim_angle, half_angle):
				var rect := Rect2(Vector2(gx, gy) * _grid_size, Vector2(_grid_size, _grid_size))
				draw_rect(rect, FOG_COLOR, true)


## 콘(방향+각도)과 반경 안에 있고, 벽/닫힌 문에 가로막히지 않았는지를 함께 판정한다.
func _is_cell_visible(cell: Vector2i, cell_center: Vector2, player_pos: Vector2, player_cell: Vector2i, aim_angle: float, half_angle: float) -> bool:
	var to_cell := cell_center - player_pos
	var dist := to_cell.length()
	if dist > FOG_RADIUS:
		return false
	if dist > 1.0:
		var diff := wrapf(to_cell.angle() - aim_angle, -PI, PI)
		if absf(diff) > half_angle:
			return false
	return not _is_occluded(player_cell, cell)


## player_cell과 target_cell 사이(양 끝 제외)에 벽/닫힌 문이 하나라도 있으면 가로막힌
## 것으로 본다 — DESIGN.md가 명시한 "직선 가로막힘 판정"을 격자 기반 shadowcasting의
## 단순화판(Bresenham 정수 라인)으로 구현했다("레이캐스트든 그리드 기반 shadowcasting이든
## 구현 방식은 자유"). 대각선으로 맞닿은 두 벽 코너 사이로 시야가 살짝 새는 정도의
## 오차는 있을 수 있으나(Bresenham 특성), 이번 항목의 요구 수준(고개를 돌리면 보이는
## 범위가 바뀌고 벽 뒤가 안 보임)에는 충분하다.
func _is_occluded(player_cell: Vector2i, target_cell: Vector2i) -> bool:
	if player_cell == target_cell:
		return false
	var cells := _cells_between(player_cell, target_cell)
	for i in range(1, cells.size() - 1):
		if world_ref.is_cell_sight_blocked(cells[i]):
			return true
	return false


## 두 격자 좌표 사이를 지나는 칸들을 Bresenham 정수 라인 알고리즘으로 나열한다(양 끝 포함).
func _cells_between(from_cell: Vector2i, to_cell: Vector2i) -> Array:
	var cells: Array = []
	var x0 := from_cell.x
	var y0 := from_cell.y
	var x1 := to_cell.x
	var y1 := to_cell.y
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		cells.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	return cells
