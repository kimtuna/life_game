extends Control
## 멀티플레이 로비 화면 (INBOX #14): 싱글플레이로 바로 입장하거나, 방을 만들어 코드를
## 발급받거나, 코드를 입력해 다른 호스트에 참가할 수 있다. 실제 접속(ENetMultiplayerPeer)은
## NetworkSession 오토로드가 맡고, 이 화면은 그 결과(신호)를 받아 화면 전환만 한다.

const WORLD_SCENE := "res://scenes/world/world.tscn"

@onready var host_button: Button = $CenterContainer/VBoxContainer/HostSection/HostButton
@onready var host_code_label: Label = $CenterContainer/VBoxContainer/HostSection/HostCodeLabel
@onready var host_status_label: Label = $CenterContainer/VBoxContainer/HostSection/HostStatusLabel
@onready var host_enter_button: Button = $CenterContainer/VBoxContainer/HostSection/HostEnterButton
@onready var code_input: LineEdit = $CenterContainer/VBoxContainer/JoinSection/CodeInput
@onready var join_button: Button = $CenterContainer/VBoxContainer/JoinSection/JoinButton
@onready var join_status_label: Label = $CenterContainer/VBoxContainer/JoinSection/JoinStatusLabel


func _ready() -> void:
	NetworkSession.join_succeeded.connect(_on_join_succeeded)
	NetworkSession.join_failed.connect(_on_join_failed)


func _on_single_player_pressed() -> void:
	NetworkSession.leave()
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_host_pressed() -> void:
	var code := NetworkSession.host_room()
	if code.is_empty():
		host_status_label.text = "방을 여는 데 실패했습니다."
		host_status_label.visible = true
		return
	host_button.disabled = true
	host_code_label.text = "방 코드: %s" % NetworkSession.format_room_code(code)
	host_code_label.visible = true
	host_status_label.text = "같은 네트워크의 다른 플레이어에게 이 코드를 알려주세요. (접속: 0명)"
	host_status_label.visible = true
	host_enter_button.visible = true
	multiplayer.peer_connected.connect(_on_host_peer_connected)


func _on_host_peer_connected(_id: int) -> void:
	var count := multiplayer.get_peers().size()
	host_status_label.text = "같은 네트워크의 다른 플레이어에게 이 코드를 알려주세요. (접속: %d명)" % count


func _on_host_enter_pressed() -> void:
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_join_pressed() -> void:
	var code := code_input.text
	if code.strip_edges().is_empty():
		join_status_label.text = "코드를 입력해주세요."
		join_status_label.visible = true
		return
	join_button.disabled = true
	join_status_label.text = "접속 중..."
	join_status_label.visible = true
	NetworkSession.join_room(code)


func _on_join_succeeded() -> void:
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_join_failed(reason: String) -> void:
	join_button.disabled = false
	join_status_label.text = reason
	join_status_label.visible = true


func _on_back_pressed() -> void:
	NetworkSession.leave()
	get_tree().change_scene_to_file("res://scenes/character_slots/character_slots.tscn")
