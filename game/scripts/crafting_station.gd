extends Node2D
class_name CraftingStation
## 공용 베이스 (INBOX #99, DESIGN.md "생산 라인 — 작업대 2계통"). 가공대/제련로/조리대/
## 조리용 화로 4개가 이 클래스를 extends하고 get_title()/get_recipes()만 오버라이드한다 —
## "근처에서 좌클릭 → 제작 UI" 상호작용과, 이번에 새로 생긴 배치 제작(수량 지정 →
## 재료 선소모 → 타이머 → 이 오브젝트 내부 출력 버퍼에 쌓임 → 플레이어가 직접 수령)
## 로직은 여기 한 곳에만 있다. 이전(#87~#90)에는 네 스크립트가 이 코드를 거의 그대로
## 복붙해서 갖고 있었는데, "즉시 완성" → "타이머+수동 수령" 방식으로 전면 개편하면서
## 네 곳을 각각 고치는 대신 공통 베이스로 합쳤다(DESIGN.md "코드 재사용/공통화" 지시).

const INTERACT_RADIUS := 90.0
## 결과물 1개를 만드는 데 걸리는 시간(초). **명시적 임시값 — 나중에 밸런스 조정 시 값이
## 통째로 바뀔 예정**이라 상수로 빼서 한 곳에서 쉽게 찾을 수 있게 해둔다(INBOX #99 원문).
const CRAFT_SECONDS_PER_UNIT := 5.0

## 저장 상자(storage_chest.gd)와 같은 개념(item_name -> count)이지만 스택 제한이 없다.
## 다 만든 결과물이 여기 쌓였다가, 플레이어가 직접 "수령"해야 인벤토리로 옮겨간다(자동으로
## 인벤토리에 들어가지 않음 — INBOX #99 원문). 나중에 NPC/자동화가 여기서 직접 상자로
## 옮기게 만들 계획이라 플레이어 UI 코드에 강하게 묶여 있지 않다(공개 변수로 노출).
var output_buffer: Dictionary = {}

## 진행 중인 배치. _batch_remaining <= 0이면 진행 중인 배치가 없다는 뜻(한 번에 한 배치만
## 가능 — INBOX #99 원문, 여러 배치 동시 진행/큐잉은 범위 밖).
var _batch_recipe: Dictionary = {}
var _batch_remaining: int = 0
var _batch_timer: float = 0.0

## world.gd의 범용 제작 창(UI)이 배치 진행/버퍼 변화에 맞춰 다시 그릴 수 있도록 알린다
## (storage_chest.gd의 `changed`와 같은 패턴).
signal changed

@onready var prompt: Label = $Prompt

## world.gd가 스폰 직후 채워준다 (다른 상호작용 오브젝트와 같은 패턴).
var player_ref: Node2D = null
var world_ref: Node2D = null


func _ready() -> void:
	prompt.visible = false


## 창 제목. 하위 클래스가 오버라이드한다.
func get_title() -> String:
	return ""


## RECIPES 목록. 하위 클래스가 오버라이드한다. 형식은 DESIGN.md "생산 라인" 절 그대로:
## [{"inputs": {아이템: 개수, ...}, "output": 아이템, "amount": 개수}, ...]
func get_recipes() -> Array:
	return []


func _process(delta: float) -> void:
	_advance_batch(delta)
	var in_range := player_ref != null \
			and global_position.distance_to(player_ref.global_position) <= INTERACT_RADIUS
	# 제작 창이 이미 열려 있을 때는 프롬프트를 감춰서, 다른 좌클릭(레시피 버튼 등)이
	# 진행 중인데도 "좌클릭: ... 열기" 안내가 겹쳐 보이지 않게 한다.
	prompt.visible = in_range and world_ref != null \
			and not world_ref.is_crafting_open() and not world_ref.is_storage_open()


func _unhandled_input(event: InputEvent) -> void:
	if not prompt.visible or world_ref == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		world_ref.open_crafting_window(get_title(), get_recipes(), self)


## 타이머를 CRAFT_SECONDS_PER_UNIT 간격으로 진행시켜, 그때마다 결과물 1개를 output_buffer에
## 쌓는다. 플레이어가 창을 닫거나 자리를 떠나도 이 오브젝트가 트리에 남아있는 한
## _process()가 계속 불려서 진행이 멈추지 않는다(INBOX #99 원문 요구사항).
func _advance_batch(delta: float) -> void:
	if _batch_remaining <= 0:
		return
	_batch_timer += delta
	var produced := false
	while _batch_timer >= CRAFT_SECONDS_PER_UNIT and _batch_remaining > 0:
		_batch_timer -= CRAFT_SECONDS_PER_UNIT
		var output: String = _batch_recipe.get("output", "")
		var amount: int = int(_batch_recipe.get("amount", 1))
		output_buffer[output] = int(output_buffer.get(output, 0)) + amount
		_batch_remaining -= 1
		produced = true
	if _batch_remaining <= 0:
		_batch_timer = 0.0
		_batch_recipe = {}
	if produced:
		changed.emit()


func is_batch_active() -> bool:
	return _batch_remaining > 0


## UI가 표시할 진행 상황. seconds_left는 다음 1개가 완성되기까지 남은 시간이다.
func batch_progress() -> Dictionary:
	if not is_batch_active():
		return {"active": false, "remaining": 0, "seconds_left": 0.0}
	return {
		"active": true,
		"remaining": _batch_remaining,
		"seconds_left": CRAFT_SECONDS_PER_UNIT - _batch_timer,
	}


## 수량 qty만큼 배치를 시작한다. 이미 배치가 진행 중이거나(한 번에 한 배치만) 재료가
## 부족하면 아무것도 소모하지 않고 false를 반환한다. 성공하면 그 시점에 qty분의 재료를
## 전량 한 번에 소모한다(INBOX #99 원문 "제작 시작을 누르면... 그 시점에 전량 한 번에 소모").
func start_batch(recipe: Dictionary, qty: int) -> bool:
	if is_batch_active() or qty <= 0:
		return false
	var inputs: Dictionary = recipe.get("inputs", {})
	for item_key in inputs.keys():
		if InventoryData.get_count(item_key) < int(inputs[item_key]) * qty:
			return false
	for item_key in inputs.keys():
		InventoryData.remove_item(item_key, int(inputs[item_key]) * qty)
	_batch_recipe = recipe
	_batch_remaining = qty
	_batch_timer = 0.0
	changed.emit()
	return true


## 출력 버퍼에서 플레이어 인벤토리로 옮길 수 있는 만큼 옮긴다. InventoryData.add_item()이
## 이미 "들어가는 만큼만 넣고 실제로 넣은 개수를 반환"하므로(INBOX #98), 인벤토리 공간이
## 모자라면 옮긴 만큼만 버퍼에서 빼고 나머지는 그대로 남는다 — 아이템이 사라지지 않는다.
func collect_output() -> void:
	for item_key in output_buffer.keys().duplicate():
		var have: int = int(output_buffer[item_key])
		if have <= 0:
			continue
		var moved: int = InventoryData.add_item(item_key, have)
		var left: int = have - moved
		if left > 0:
			output_buffer[item_key] = left
		else:
			output_buffer.erase(item_key)
	changed.emit()
