class_name OnlineSocket
extends RefCounted
## The WebSocket to the world room (docs/ONLINE_PROTOCOL.md): wss://<the page's host>/api/online/ws
## on the web build, same origin, so the account's session cookie goes along. One
## connection; Online opens a new one after a drop, waiting delay_for(attempt) first
## (2, 4, 8, 16, then every 30 s), and never while the "เล่นออนไลน์" switch is off.
## The same small interface as a test's stand-in transport: send_text(text) and
## poll() -> Array[String] (the text frames that arrived), plus is_open / is_closed.

const PATH := "/api/online/ws"
## Seconds to wait before reconnect attempt n (0-based); the last one repeats.
const BACKOFF: Array[float] = [2.0, 4.0, 8.0, 16.0, 30.0]
## Bytes a frame may have (the server's limit).
const MAX_FRAME := 8192
## An opening socket that has not opened by then is given up (and retried later).
const OPEN_TIMEOUT := 12.0
## Close codes from the room: 4000 after `kicked` (do not reconnect), 4001 an idle drop
## (reconnect as usual).
const CODE_KICKED := 4000
const CODE_IDLE := 4001

var _ws := WebSocketPeer.new()
var _opened := false
var _closed := false
var _age := 0.0
var url := ""


static func delay_for(attempt: int) -> float:
	return BACKOFF[clampi(attempt, 0, BACKOFF.size() - 1)]


## The room's address on the page's own host ("" off the web).
static func page_url() -> String:
	if not OS.has_feature("web"):
		return ""
	var raw: Variant = JavaScriptBridge.eval("(location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '%s'" % PATH, true)
	return str(raw) if raw != null else ""


func open(p_url: String) -> Error:
	url = p_url
	_ws.inbound_buffer_size = 1 << 16
	_ws.outbound_buffer_size = 1 << 16
	var err := _ws.connect_to_url(url)
	if err != OK:
		_closed = true
	return err


func is_open() -> bool:
	return _opened and not _closed


func is_closed() -> bool:
	return _closed


func send_text(text: String) -> void:
	if not is_open() or text.length() > MAX_FRAME:
		return
	_ws.send_text(text)


## Moves the socket on and returns the frames that arrived since the last call.
func poll(delta := 0.0) -> Array[String]:
	var out: Array[String] = []
	if _closed:
		return out
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			_opened = true
			while _ws.get_available_packet_count() > 0:
				var packet := _ws.get_packet()
				if _ws.was_string_packet():
					out.append(packet.get_string_from_utf8())
		WebSocketPeer.STATE_CONNECTING:
			_age += delta
			if _age > OPEN_TIMEOUT:
				_ws.close()
				_closed = true
		WebSocketPeer.STATE_CLOSED:
			_closed = true
	return out


## The code the socket was closed with (-1 while open or unknown).
func close_code() -> int:
	return _ws.get_close_code() if _closed else -1


func close() -> void:
	if not _closed:
		_ws.close(1000, "bye")
	_closed = true
