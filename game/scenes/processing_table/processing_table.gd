extends CraftingStation
## 가공대 (INBOX #87, 타이머+수동 수령 방식으로 개편 INBOX #99). DESIGN.md "생산 라인 —
## 작업대 2계통": 열이 필요 없는 가공(목재→판자, 돌→석재 등)을 담당하는 가공 라인
## 작업대다 — 열이 필요한 제련로(#88)와는 별개 오브젝트로 갈라둔다. 상호작용/배치 제작
## 프레임워크는 전부 `scripts/crafting_station.gd`(CraftingStation) 공용 베이스에 있고,
## 이 스크립트는 제목과 레시피 목록만 제공한다.
## 월드 그림(INBOX #91)은 파이썬 절차적 생성(Pillow)으로 만든
## assets/sprites/processing_table/processing_table.png를 쓴다.

const TABLE_TITLE := "가공대"

## {"inputs": {아이템: 개수, ...}, "output": 아이템, "amount": 개수} 목록.
## 화약/탄약(INBOX #89, DESIGN.md "새 테크 라인" — 유황광석+숯→화약→탄약)은 새 오브젝트가
## 아니라 이 가공대 목록만 확장한 것이다. 총 재장전(R키)이 탄약을 실제로 소비하도록
## 연동하는 건 범위 밖(INBOX 원문 명시) — 지금 총은 그대로 무한 재장전이다.
## 나무벽/나무문/석제벽(INBOX #100)은 "아이템으로 제작 가능"까지만 범위다 — 월드에
## 설치해서 방을 짓는 건 범위 밖(나중에 별도 지시). 재료 개수는 재량값이며 밸런스는
## 나중에 조정될 예정(DESIGN.md에 이미 명시됨).
const RECIPES := [
	{"inputs": {"wood": 2}, "output": "plank", "amount": 1},
	{"inputs": {"stone": 2}, "output": "stone_block", "amount": 1},
	{"inputs": {"sulfur_ore": 1, "charcoal": 1}, "output": "gunpowder", "amount": 1},
	{"inputs": {"gunpowder": 1, "iron": 1}, "output": "ammo", "amount": 3},
	{"inputs": {"plank": 4}, "output": "wood_wall", "amount": 1},
	{"inputs": {"plank": 3}, "output": "wood_door", "amount": 1},
	{"inputs": {"stone_block": 4}, "output": "stone_wall", "amount": 1},
]


func get_title() -> String:
	return TABLE_TITLE


func get_recipes() -> Array:
	return RECIPES
