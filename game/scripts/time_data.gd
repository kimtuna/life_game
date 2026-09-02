extends Node
## 낮/밤·계절·날씨 시계 (INBOX #13). DESIGN.md "시간 / 계절 / 날씨" 절 그대로 구현.

signal phase_changed(is_day: bool)
signal day_changed(day_number: int)
signal weather_changed(is_raining: bool)

const DAY_PHASE_SECONDS := 600.0  # 낮 10분
const NIGHT_PHASE_SECONDS := 600.0  # 밤 10분

## DESIGN.md는 월/계절 매핑(1·2·3월=봄 ...)만 정하고 한 달이 며칠인지는 정하지 않았다.
## 임의로 30일/월(1년=360일)로 정함 — STATUS.md 결정 로그 참고.
const DAYS_PER_MONTH := 30
const MONTHS_PER_YEAR := 12

const SEASON_BASE_RAIN := {
	"spring": 0.01,
	"summer": 0.30,
	"fall": 0.01,
	"winter": 0.01,
}

const SEASON_LABELS := {
	"spring": "봄",
	"summer": "여름",
	"fall": "가을",
	"winter": "겨울",
}

var day_number: int = 1  # 1부터 시작
var is_day: bool = true
var is_raining: bool = false
var days_since_last_rain: int = 0

var _phase_elapsed: float = 0.0
var _day_rain_roll: bool = false
var _night_rain_roll: bool = false


func _ready() -> void:
	_roll_day_weather()


func _process(delta: float) -> void:
	_phase_elapsed += delta
	var phase_len := DAY_PHASE_SECONDS if is_day else NIGHT_PHASE_SECONDS
	if _phase_elapsed >= phase_len:
		_phase_elapsed -= phase_len
		_advance_phase()


## 현재 진행 중인 낮/밤 구간의 진행률 (0.0 ~ 1.0).
func phase_progress() -> float:
	var phase_len := DAY_PHASE_SECONDS if is_day else NIGHT_PHASE_SECONDS
	return clampf(_phase_elapsed / phase_len, 0.0, 1.0)


func current_month() -> int:
	return int((day_number - 1) / float(DAYS_PER_MONTH)) % MONTHS_PER_YEAR + 1


func current_day_of_month() -> int:
	return (day_number - 1) % DAYS_PER_MONTH + 1


func season_name() -> String:
	var month := current_month()
	if month <= 3:
		return "spring"
	elif month <= 6:
		return "summer"
	elif month <= 9:
		return "fall"
	else:
		return "winter"


func season_label() -> String:
	return SEASON_LABELS[season_name()]


func _advance_phase() -> void:
	if is_day:
		is_day = false
		is_raining = _night_rain_roll
		phase_changed.emit(false)
		weather_changed.emit(is_raining)
		return

	# 밤이 끝나고 새 날짜로 넘어간다 (DESIGN.md 강수 공식: 비 온 날은 스트릭 리셋).
	if _day_rain_roll or _night_rain_roll:
		days_since_last_rain = 0
	else:
		days_since_last_rain += 1
	day_number += 1
	is_day = true
	_roll_day_weather()
	day_changed.emit(day_number)
	phase_changed.emit(true)
	weather_changed.emit(is_raining)


## 그날의 강수확률 = 계절 기본값 + 마지막 비 이후 지난 날 수 x 1%p.
## 낮/밤을 그 확률로 각각 독립적으로 굴린다 (DESIGN.md "강수 확률 공식").
func _roll_day_weather() -> void:
	var chance := clampf(SEASON_BASE_RAIN[season_name()] + days_since_last_rain * 0.01, 0.0, 1.0)
	_day_rain_roll = randf() < chance
	_night_rain_roll = randf() < chance
	is_raining = _day_rain_roll
