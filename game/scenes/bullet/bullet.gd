extends Area2D

## 총알 하나의 이동/사거리 처리와 사슴 명중 판정(INBOX #9).

const NORMAL_COLOR := Color(1.0, 0.86, 0.3, 1.0)
const TRANQ_COLOR := Color(0.35, 0.85, 0.95, 1.0)

@onready var trail: Line2D = $Trail

var velocity: Vector2 = Vector2.ZERO
var max_range: float = 800.0
var damage: int = 25
var ammo_type: String = "normal"

var _traveled: float = 0.0


func _ready() -> void:
	trail.default_color = TRANQ_COLOR if ammo_type == "tranq" else NORMAL_COLOR
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	var step := velocity * delta
	position += step
	_traveled += step.length()
	if _traveled >= max_range:
		queue_free()


## collision_mask가 사슴 Hurtbox 레이어(8)만 가리키므로, 여기 들어오는 area는 항상
## 사슴의 Hurtbox다 — Hurtbox의 부모(사슴 루트 노드)에 데미지를 전달한다.
func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target != null and target.has_method("take_hit"):
		target.take_hit(damage, ammo_type)
	queue_free()
