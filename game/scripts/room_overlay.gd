extends Node2D
class_name RoomOverlay
## 방(Room) 오버레이(INBOX #126, 산소미포함 참고): 화면 우상단 툴바 버튼으로 켜고 끄면,
## 화면에 보이는 격자 칸 위에 방 종류별 반투명 색을 겹쳐 그린다. world.gd가 setup()으로
## 자기 참조와 격자 크기를 넘겨주고(door.gd와 같은 패턴), 실제 방 판정은
## world_ref.get_room_id_at()/get_room_category()를 그대로 재사용한다(판정 로직 중복 없음).

## 방 종류별 색(카테고리 색은 서로 뚜렷이 구분되게, 전부 낮은 알파로 뒤가 비쳐 보이게 함).
const CATEGORY_COLORS := {
	"주방": Color(0.95, 0.55, 0.2, 0.35),
	"제작소": Color(0.3, 0.55, 0.95, 0.35),
	"대장간": Color(0.85, 0.25, 0.2, 0.35),
	"연구소": Color(0.6, 0.35, 0.9, 0.35),
	"농장": Color(0.35, 0.8, 0.3, 0.35),
	"목장": Color(0.9, 0.75, 0.2, 0.35),
}
## 잡실이거나 방 자체가 없는 칸(벽 밖 야외 포함).
const UNCLASSIFIED_COLOR := Color(0.5, 0.5, 0.5, 0.3)

var active: bool = false

var world_ref: Node2D = null
var _grid_size: float = 16.0


func setup(world: Node2D, grid_size: float) -> void:
	world_ref = world
	_grid_size = grid_size


func set_active(value: bool) -> void:
	active = value
	visible = value
	queue_redraw()


func _process(_delta: float) -> void:
	## 카메라가 플레이어를 따라 매 프레임 움직이므로, 켜져 있는 동안은 화면에 보이는
	## 칸 범위도 매 프레임 다시 계산해야 한다("방 배치가 바뀔 때만" 갱신하면 충분한 건
	## 방 판정 자체지, 화면에 어느 칸이 보이는지는 그것과 별개다).
	if active:
		queue_redraw()


func _draw() -> void:
	if not active or world_ref == null:
		return
	var cam: Camera2D = world_ref.camera
	if cam == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var top_left: Vector2 = cam.global_position - viewport_size * 0.5
	var bottom_right: Vector2 = cam.global_position + viewport_size * 0.5
	var min_cell := Vector2i(floori(top_left.x / _grid_size), floori(top_left.y / _grid_size))
	var max_cell := Vector2i(floori(bottom_right.x / _grid_size), floori(bottom_right.y / _grid_size))
	for gx in range(min_cell.x, max_cell.x + 1):
		for gy in range(min_cell.y, max_cell.y + 1):
			var cell_world := Vector2((gx + 0.5) * _grid_size, (gy + 0.5) * _grid_size)
			var room_id: int = world_ref.get_room_id_at(cell_world)
			var color := UNCLASSIFIED_COLOR
			if room_id != -1:
				var category: String = world_ref.get_room_category(room_id)
				if CATEGORY_COLORS.has(category):
					color = CATEGORY_COLORS[category]
			var rect := Rect2(Vector2(gx, gy) * _grid_size, Vector2(_grid_size, _grid_size))
			draw_rect(rect, color, true)
