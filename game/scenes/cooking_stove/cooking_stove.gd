extends CraftingStation
## 조리용 화로 (INBOX #90, 타이머+수동 수령 방식으로 개편 INBOX #99). DESIGN.md "생산
## 라인 — 작업대 2계통": 조리 라인의 가열 담당 오브젝트다 — 가공 라인의 제련로
## (smelting_furnace.gd)와는 용도가 달라 별개 오브젝트로 갈라둔다(화로를 라인별로
## 겸용하지 않는다 — 사용자 지시). 상호작용/배치 제작 프레임워크는 전부
## `scripts/crafting_station.gd`(CraftingStation) 공용 베이스에 있고, 이 스크립트는
## 제목과 레시피 목록만 제공한다.
## 월드 그림(INBOX #91)은 파이썬 절차적 생성(Pillow)으로 만든
## assets/sprites/cooking_stove/cooking_stove.png를 쓴다.

const TABLE_TITLE := "조리용 화로"

## {"inputs": {아이템: 개수, ...}, "output": 아이템, "amount": 개수} 목록.
const RECIPES := [
	{"inputs": {"rice": 1}, "output": "cooked_rice", "amount": 1},
	{"inputs": {"meat": 1}, "output": "cooked_meat", "amount": 1},
]


func get_title() -> String:
	return TABLE_TITLE


func get_recipes() -> Array:
	return RECIPES
