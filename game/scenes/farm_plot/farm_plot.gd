extends Node2D
## 밭 한 칸 (INBOX #11). 벼 씨앗(rice_seed)을 심으면 시간이 지나 벼(rice)로 자라고
## 수확할 수 있다. 자원 채집 포인트(resource_point.gd)와 같은 F키 상호작용 패턴을 쓴다.

enum State { EMPTY, GROWING, READY }

const INTERACT_RADIUS := 70.0
const GROW_SECONDS := 60.0
const SEED_ITEM := "rice_seed"
const CROP_ITEM := "rice"
const CROP_YIELD := 2

const SPROUT_TEXTURE := preload("res://assets/sprites/farm_plot/rice_sprout.png")
const GROWN_TEXTURE := preload("res://assets/sprites/farm_plot/rice_grown.png")

@onready var crop: Sprite2D = $Crop
@onready var prompt: Label = $Prompt

## world.gd가 스폰 직후 채워준다 (사슴/자원 포인트와 같은 패턴).
var player_ref: Node2D = null

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
	if not prompt.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		_interact()


func _interact() -> void:
	match _state:
		State.EMPTY:
			if InventoryData.remove_item(SEED_ITEM, 1):
				_state = State.GROWING
				_grow_timer = GROW_SECONDS
				_update_visual()
		State.READY:
			InventoryData.add_item(CROP_ITEM, CROP_YIELD)
			_state = State.EMPTY
			_update_visual()


func _update_visual() -> void:
	match _state:
		State.EMPTY:
			crop.visible = false
			prompt.text = "F: 씨앗 심기"
		State.GROWING:
			crop.visible = true
			crop.texture = SPROUT_TEXTURE
		State.READY:
			crop.visible = true
			crop.texture = GROWN_TEXTURE
			prompt.text = "F: 수확"
