extends CraftingStation
## 제련로 (INBOX #88, 타이머+수동 수령 방식으로 개편 INBOX #99). DESIGN.md "생산 라인 —
## 작업대 2계통": 열이 필요한 가공(철광석→철, 목재→숯)을 담당하는 가공 라인 작업대다 —
## 열이 필요 없는 가공대(#87)와는 별개 오브젝트다(화로를 가공대와 겸용으로 쓰지 않는다 —
## 사용자 지시). 상호작용/배치 제작 프레임워크는 전부 `scripts/crafting_station.gd`
## (CraftingStation) 공용 베이스에 있고, 이 스크립트는 제목과 레시피 목록만 제공한다.
## 월드 그림(INBOX #91)은 파이썬 절차적 생성(Pillow)으로 만든
## assets/sprites/smelting_furnace/smelting_furnace.png를 쓴다.

const TABLE_TITLE := "제련로"

## {"inputs": {아이템: 개수, ...}, "output": 아이템, "amount": 개수} 목록.
## 레시피 재료는 항상 1종만 쓴다(DESIGN.md "생산 라인" 2026-09-04 규칙, INBOX #105).
const RECIPES := [
	{"inputs": {"iron_ore": 2}, "output": "iron", "amount": 1},
	{"inputs": {"wood": 2}, "output": "charcoal", "amount": 1},
	{"inputs": {"iron": 2}, "output": "steel", "amount": 1},
	{"inputs": {"sand": 2}, "output": "glass", "amount": 1},
	{"inputs": {"copper_ore": 2}, "output": "copper", "amount": 1},
]


func get_title() -> String:
	return TABLE_TITLE


func get_recipes() -> Array:
	return RECIPES
