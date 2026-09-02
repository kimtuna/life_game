extends Node
## 오토로드 싱글톤: 그래픽 설정(현재는 해상도)을 저장/적용한다.
## `user://settings.save`에 JSON으로 저장해 앱을 껐다 켜도 선택이 유지된다.
##
## 해상도를 바꿔도 시야(카메라가 보여주는 월드 범위)는 절대 넓어지면 안 된다
## (DESIGN.md "카메라 / 해상도" 규칙). 그래서 여기서는 창 크기(get_window().size)만
## 바꾸고, 프로젝트의 기준 뷰포트 해상도(project.godot의 viewport_width/height)나
## 월드 씬의 Camera2D.zoom은 절대 건드리지 않는다. `window/stretch/mode=canvas_items`,
## `aspect=keep`(바퀴 1에 미리 설정됨)이 창 크기와 무관하게 같은 월드 범위를 같은
## 화면 비율로 보여주는 걸 보장해준다.

const SAVE_PATH := "user://settings.save"

## 프로젝트 기준 해상도(1280x720, 16:9)와 같은 종횡비만 넣는다 — 종횡비가 다르면
## "aspect=keep"이 레터박스를 만들어서 화면 구성이 목록마다 달라져 보이기 때문.
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var resolution_index: int = 0


func _ready() -> void:
	_load()
	apply_current()


func resolution_label(index: int) -> String:
	var size := RESOLUTIONS[index]
	return "%d x %d" % [size.x, size.y]


func set_resolution(index: int) -> void:
	if index < 0 or index >= RESOLUTIONS.size():
		return
	resolution_index = index
	apply_current()
	_save()


func apply_current() -> void:
	var size := RESOLUTIONS[resolution_index]
	var window := get_window()
	window.size = size
	window.move_to_center()


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"resolution_index": resolution_index}))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.has("resolution_index"):
		var index: int = parsed["resolution_index"]
		if index >= 0 and index < RESOLUTIONS.size():
			resolution_index = index
