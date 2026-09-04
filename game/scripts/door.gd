extends StaticBody2D
class_name Door
## 격자에 설치된 문(나무문 등, INBOX #120). world.gd의 `_spawn_structure()`가 코드로
## 조립해서(패키지 씬이 아님) `setup()`으로 자기 자식 노드 참조를 넘겨준다.
## resource_point.gd와 같은 "근처에서 좌클릭" 패턴으로 열림/닫힘을 토글하되, 특정
## 도구를 요구하지 않고 "배치 모드가 아닐 때"만 반응한다(DESIGN.md "건축/방 시스템").

const INTERACT_RADIUS := 70.0

## 방 감지(INBOX #122)는 열림/닫힘과 무관하게 "이 칸에 문이 있다"는 사실만 보면
## 되므로, world.gd의 `_grid_occupancy`에는 이 Door 노드 자체가 계속 남아있는다 —
## `is_open`은 그중 "지금 지나갈 수 있는가"만 나타낸다(닫힘 = 기본 상태 = 못 지나감).
var is_open: bool = false

var _col: CollisionShape2D = null
var _sprite: Sprite2D = null
## (INBOX #132) 예전엔 격자 칸 크기(BUILD_GRID_SIZE)를 그대로 받아 슬라이드 거리를
## 정했지만, 이제 벽/문의 시각적 크기(BUILD_STRUCTURE_VISUAL_SIZE)가 격자 크기와
## 분리됐으므로 문이 실제로 보이는 크기에 비례해서 슬라이드하도록 그 값을 받는다.
var _visual_size: float = 32.0

## 사슴 등 스폰 오브젝트와 같은 패턴(world.gd가 스폰 직후 채워줌).
var player_ref: Node2D = null
var world_ref: Node2D = null


func setup(col: CollisionShape2D, sprite: Sprite2D, visual_size: float) -> void:
	_col = col
	_sprite = sprite
	_visual_size = visual_size


func _unhandled_input(event: InputEvent) -> void:
	if player_ref == null or world_ref == null:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if global_position.distance_to(player_ref.global_position) > INTERACT_RADIUS:
		return
	if world_ref.is_build_placement_active():
		return
	if world_ref.is_deconstruct_mode_active():
		## 건설 해제 모드(INBOX #128)에서는 좌클릭이 문 열림/닫힘 토글이 아니라 철거로
		## 소비돼야 하므로, 여기서 입력을 handled 처리하지 않고 그대로 흘려보내
		## world.gd의 _unhandled_input이 대신 받게 한다.
		return
	_toggle()
	get_viewport().set_input_as_handled()


func _toggle() -> void:
	is_open = not is_open
	_col.disabled = is_open
	## 새 그림을 만들지 않고 기존 스프라이트를 변형해서 열림 상태를 표현한다(INBOX #120
	## 원문 — 반투명 + 옆으로 밀린 것처럼).
	if is_open:
		_sprite.modulate.a = 0.35
		_sprite.position.x = _visual_size * 0.35
	else:
		_sprite.modulate.a = 1.0
		_sprite.position.x = 0.0
