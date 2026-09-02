extends Node2D
## 밭 한 칸 (INBOX #11). 벼 씨앗(rice_seed)을 심으면 시간이 지나 벼(rice)로 자라고
## 수확할 수 있다. INBOX #23부터는 F키 대신 좌클릭으로 상호작용한다. INBOX #27부터는
## 심기와 수확이 서로 다른 것을 손에 들어야 한다: 심기는 씨앗 아이템(rice_seed)을 손에
## 든 채 좌클릭, 수확은 곡괭이낫(pickaxe)을 손에 든 채 좌클릭 (DESIGN.md "생산 계열" 참고).

enum State { EMPTY, GROWING, READY }

const INTERACT_RADIUS := 70.0
const GROW_SECONDS := 60.0
const SEED_ITEM := "rice_seed"
const CROP_ITEM := "rice"
const CROP_YIELD := 2
const REQUIRED_TOOL := "pickaxe"

const SPROUT_TEXTURE := preload("res://assets/sprites/farm_plot/rice_sprout.png")
const GROWN_TEXTURE := preload("res://assets/sprites/farm_plot/rice_grown.png")

@onready var crop: Sprite2D = $Crop
@onready var prompt: Label = $Prompt

## world.gd가 스폰 직후 채워준다 (사슴/자원 포인트와 같은 패턴).
var player_ref: Node2D = null
## world.gd가 스폰 직후 채워준다 — get_held_item()/get_held_tool()로 지금 손에 든
## 아이템/도구를 물어본다.
var world_ref: Node2D = null

var _state: State = State.EMPTY
var _grow_timer: float = 0.0


func _ready() -> void:
	prompt.visible = false
	_update_visual()


func _process(delta: float) -> void:
	if _state == State.GROWING:
		_grow_timer -= delta
		if _grow_timer <= 0.0:
			_state = State.READY
			_update_visual()

	var in_range := player_ref != null \
			and global_position.distance_to(player_ref.global_position) <= INTERACT_RADIUS
	prompt.visible = in_range and _can_interact()


func _can_interact() -> bool:
	match _state:
		State.EMPTY:
			return InventoryData.has_item(SEED_ITEM)
		State.READY:
			return true
		_:
			return false


func _unhandled_input(event: InputEvent) -> void:
	if not prompt.visible or world_ref == null:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	match _state:
		State.EMPTY:
			if world_ref.get_held_item() == SEED_ITEM:
				_interact()
		State.READY:
			if world_ref.get_held_tool() == REQUIRED_TOOL:
				_interact()


func _interact() -> void:
	match _state:
		State.EMPTY:
			if InventoryData.remove_item(SEED_ITEM, 1):
				_state = State.GROWING
				_grow_timer = GROW_SECONDS
				_update_visual()
		State.READY:
			world_ref.spawn_dropped_item(CROP_ITEM, CROP_YIELD, global_position)
			_state = State.EMPTY
			_update_visual()


func _update_visual() -> void:
	match _state:
		State.EMPTY:
			crop.visible = false
			prompt.text = "벼 씨앗을 들고 좌클릭: 씨앗 심기"
		State.GROWING:
			crop.visible = true
			crop.texture = SPROUT_TEXTURE
		State.READY:
			crop.visible = true
			crop.texture = GROWN_TEXTURE
			prompt.text = "곡괭이낫을 들고 좌클릭: 수확"
