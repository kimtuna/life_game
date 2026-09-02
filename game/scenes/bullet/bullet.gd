extends Area2D

## 총알 하나의 이동/사거리 처리. 대상 명중 판정은 아직 없음(사슴이 없어서, INBOX #9 몫).

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


func _physics_process(delta: float) -> void:
	var step := velocity * delta
	position += step
	_traveled += step.length()
	if _traveled >= max_range:
		queue_free()
