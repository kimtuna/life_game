extends Node
## 오토로드 싱글톤: 멀티플레이 "세션 서버" 연결 계층을 담당한다 (INBOX #14).
##
## DESIGN.md "멀티플레이 — 세션 서버 아키텍처": 호스트 겸용 리슨 서버(별도 전용 서버
## 프로세스 없음) + 방 코드 발급/입력. 나중에 Steam Networking Sockets로 연결 계층만
## 바꿔 낄 수 있도록, "연결 방식"(이 파일)과 "게임 로직"(world.gd)을 분리해서 만들었다 —
## world.gd는 이 파일의 host_room()/join_room()과 표준 `multiplayer` 신호만 쓰고,
## ENetMultiplayerPeer라는 사실 자체를 몰라도 되게 짰다.
##
## 진짜 매치메이킹/릴레이 서버는 DESIGN.md "범위 밖"에 있고, 지금은 로컬 네트워크
## 연결까지만 지시받았다(INBOX #14). 그래서 "방 코드"는 서버에 등록하는 게 아니라
## 호스트의 LAN IP:포트를 그대로 인코딩한 12자리 16진수 문자열이다 — 참가자가 코드를
## 입력하면 그 안에 담긴 주소로 직접 접속한다. 나중에 실제 릴레이 서버가 생기면 코드
## 발급/조회 부분만 그 서버 호출로 바꿔 끼우면 되고, host_room()/join_room()을 호출하는
## 쪽(world.gd, multiplayer_lobby.gd)은 바뀔 필요가 없다.

const PORT := 8910
const MAX_PLAYERS := 8

var is_host: bool = false
var room_code: String = ""

## join_room()은 접속 성공/실패를 즉시 알 수 없다(ENet 핸드셰이크가 몇 프레임 걸림).
## 호출한 쪽(multiplayer_lobby.gd)이 이 신호를 듣고 화면 전환을 결정한다.
signal join_succeeded
signal join_failed(reason: String)


func is_active() -> bool:
	return multiplayer.multiplayer_peer != null


## 리슨 서버를 열고 방 코드를 발급한다. 실패하면 빈 문자열을 반환한다.
func host_room() -> String:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		return ""
	multiplayer.multiplayer_peer = peer
	is_host = true
	room_code = _encode_room_code(_pick_lan_ip(), PORT)
	return room_code


## 방 코드로 호스트에 접속을 시도한다. 결과는 join_succeeded/join_failed 신호로 온다.
func join_room(code: String) -> void:
	leave()
	var info := decode_room_code(code)
	if info.is_empty():
		join_failed.emit("코드 형식이 올바르지 않습니다.")
		return
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(info["ip"], info["port"])
	if err != OK:
		join_failed.emit("접속을 시작할 수 없습니다.")
		return
	is_host = false
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(_on_connection_failed, CONNECT_ONE_SHOT)


func leave() -> void:
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	is_host = false
	room_code = ""


func _on_connected_to_server() -> void:
	join_succeeded.emit()


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	join_failed.emit("호스트에 접속하지 못했습니다. 코드를 확인해주세요.")


## IPv4 옥텟 4개(8자리 hex) + 포트(4자리 hex) = 12자리 hex 문자열.
func _encode_room_code(ip: String, port: int) -> String:
	var parts := ip.split(".")
	if parts.size() != 4:
		return ""
	var hex := ""
	for part in parts:
		hex += "%02X" % (int(part) & 0xFF)
	hex += "%04X" % (port & 0xFFFF)
	return hex


func decode_room_code(code: String) -> Dictionary:
	var cleaned := code.strip_edges().to_upper().replace("-", "").replace(" ", "")
	if cleaned.length() != 12:
		return {}
	for c in cleaned:
		if not c.is_valid_hex_number():
			return {}
	var octets: Array[String] = []
	for i in range(4):
		octets.append(str(("0x" + cleaned.substr(i * 2, 2)).hex_to_int()))
	var port := ("0x" + cleaned.substr(8, 4)).hex_to_int()
	return {"ip": ".".join(octets), "port": port}


## 화면에 보여줄 때만 4자리씩 하이픈으로 묶는다(코드 자체는 하이픈 없이 12자리).
func format_room_code(code: String) -> String:
	if code.length() != 12:
		return code
	return "%s-%s-%s" % [code.substr(0, 4), code.substr(4, 4), code.substr(8, 4)]


## 로컬 네트워크 IPv4 주소를 하나 고른다. 못 찾으면 루프백(같은 기기 테스트용)으로 대체.
func _pick_lan_ip() -> String:
	for addr in IP.get_local_addresses():
		if addr.find(":") != -1:
			continue
		if addr.begins_with("127."):
			continue
		return addr
	return "127.0.0.1"
