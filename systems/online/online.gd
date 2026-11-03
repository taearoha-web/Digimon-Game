extends Node
## Online play (autoload `Online`): the client API of docs/ONLINE_PROTOCOL.md.
##
## MINIMAL STUB for the shared-combat branch. It only keeps the players, the party and
## the zone hosts from the server frames and relays every frame on [signal message];
## there is no socket, no UI and no feature logic here. At integration this file is
## replaced by the client core's real one (same signals and functions).

signal connected
signal disconnected
signal message(type: String, data: Dictionary)
signal player_joined(id: String)
signal player_left(id: String)
signal party_changed
signal host_changed(zone: StringName)

var _transport: Object
var _me := ""
var _players: Dictionary = {}
var _party: Dictionary = {}
## zone (String) -> host id ("" nobody shares).
var _hosts: Dictionary = {}


func is_online() -> bool:
	return _transport != null


func my_id() -> String:
	return _me


func send(type: String, data := {}) -> void:
	if _transport == null:
		return
	var frame: Dictionary = data.duplicate()
	frame["t"] = type
	_transport.call("send_text", JSON.stringify(frame))


func players() -> Dictionary:
	return _players


func players_in_zone(zone: StringName) -> Array:
	var out: Array = []
	for id in _players:
		var p: Dictionary = _players[id]
		if String(p.get("zone", "")) == String(zone):
			out.append(p)
	return out


func party() -> Dictionary:
	return _party


func in_party() -> bool:
	return not _party.is_empty()


func party_members_in_zone(zone: StringName) -> Array:
	var out: Array = []
	for id in _party.get("members", []):
		var key := String(id)
		if key == _me or not _players.has(key):
			continue
		if String((_players[key] as Dictionary).get("zone", "")) == String(zone):
			out.append(key)
	return out


func zone_host(zone: StringName) -> String:
	return String(_hosts.get(String(zone), ""))


func is_zone_host(zone: StringName) -> bool:
	return in_party() and _me != "" and zone_host(zone) == _me


func is_mirror_zone(zone: StringName) -> bool:
	var host := zone_host(zone)
	return in_party() and host != "" and host != _me


func remote_node(id: String) -> Node3D:
	if id == "" or not is_inside_tree():
		return null
	for node in get_tree().get_nodes_in_group("remote_players"):
		if is_instance_valid(node) and String(node.get_meta("online_id", node.get("player_id") if "player_id" in node else "")) == id:
			return node as Node3D
	return null


## Tests: swap the socket for an object with send_text(text) and poll() -> Array[String].
func use_transport(transport: Object) -> void:
	var was := _transport != null
	_transport = transport
	if transport == null:
		_me = ""
		_players.clear()
		_party = {}
		_hosts.clear()
		if was:
			disconnected.emit()
			party_changed.emit()
	elif not was:
		connected.emit()


func _process(_delta: float) -> void:
	if _transport == null or not _transport.has_method("poll"):
		return
	for text in _transport.call("poll"):
		var msg: Variant = JSON.parse_string(String(text))
		if msg is Dictionary:
			_dispatch(msg)


## Handles one server frame as if it came off the wire.
func _dispatch(msg: Dictionary) -> void:
	var type := String(msg.get("t", ""))
	match type:
		"welcome":
			_me = String((msg.get("you", {}) as Dictionary).get("id", ""))
			_players.clear()
			for p in msg.get("players", []):
				if p is Dictionary and String(p.get("id", "")) != _me:
					_players[String(p.id)] = p
			_party = msg.get("party") if msg.get("party") is Dictionary else {}
			party_changed.emit()
		"join":
			var p: Variant = msg.get("player")
			if p is Dictionary and String(p.get("id", "")) != "":
				_players[String(p.id)] = p
				player_joined.emit(String(p.id))
		"leave":
			var id := String(msg.get("id", ""))
			if _players.erase(id):
				player_left.emit(id)
		"state":
			var id := String(msg.get("id", ""))
			if _players.has(id):
				var p: Dictionary = _players[id]
				for key in msg:
					if key != "t" and key != "id":
						p[key] = msg[key]
		"party":
			_party = msg.get("party") if msg.get("party") is Dictionary else {}
			party_changed.emit()
		"host":
			var zone := String(msg.get("zone", ""))
			var id: Variant = msg.get("id")
			_hosts[zone] = String(id) if id != null else ""
			host_changed.emit(StringName(zone))
	message.emit(type, msg)
