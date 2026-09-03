extends CraftingStation
## 조리대 (INBOX #90, 타이머+수동 수령 방식으로 개편 INBOX #99). DESIGN.md "생산 라인 —
## 작업대 2계통": 조리 라인의 "레시피 조합" 담당 오브젝트다 — 가열이 필요한 조리용 화로
## (cooking_stove.gd)와는 별개 오브젝트다. 상호작용/배치 제작 프레임워크는 전부
## `scripts/crafting_station.gd`(CraftingStation) 공용 베이스에 있고, 이 스크립트는
## 제목과 레시피 목록만 제공한다.
## RECIPES가 비어있는 건 결함이 아니다 — DESIGN.md가 명시한 "조합 요리"(밥+익힌고기+
## 익힌채소→스테이크 등)는 채소 아이템이 아직 정해지지 않아 이번 범위 밖이라, 조리대는
## 오브젝트로만 먼저 자리잡고 레시피는 채소 추가 뒤 별도 지시로 채운다.
## 월드 그림(INBOX #91)은 파이썬 절차적 생성(Pillow)으로 만든
## assets/sprites/cooking_table/cooking_table.png를 쓴다.

const TABLE_TITLE := "조리대"

## {"inputs": {아이템: 개수, ...}, "output": 아이템, "amount": 개수} 목록.
## 지금은 비어있다 — 위 클래스 주석 참고.
const RECIPES := []


func get_title() -> String:
	return TABLE_TITLE


func get_recipes() -> Array:
	return RECIPES
