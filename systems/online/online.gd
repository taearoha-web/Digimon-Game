extends Node
## STUB of the autoload `Online` (docs/ONLINE_PROTOCOL.md, "Client API"), only so the
## trade and duel code (OnlineTrade, OnlineDuel) and their tests run before the client
## core lands. It has the spec's signals and functions and keeps the player list and the
## party from `welcome` / `join` / `leave` / `state` / `look` / `party` / `host` frames;
## no socket, no feature logic. Replaced by the client core's online.gd at integration.

signal connected
signal disconnected
signal message(type: String, data: Dictionary)
signal player_joined(id: String)
signal player_left(id: String)
signal party_changed
signal host_changed(zone: StringName)

var _transport: Object
var _me := ""
var _players := {}
var _party := {}
var _hosts := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if _transport == null or not _transport.has_method("poll"):
		return
	for text in _transport.poll():
		var parsed: Variant = JSON.parse_string(String(text))
		if parsed is Dictionary:
			_dispatch(parsed)


func is_online() -> bool:
	return _transport != null and _me != ""


func my_id() -> String:
	return _me


func send(type: String, data := {}) -> void:
	if not is_online():
		return
	var frame: Dictionary = data.duplicate(true)
	frame["t"] = type
	_transport.send_text(JSON.stringify(frame))


func players() -> Dictionary:
	return _players


func players_in_zone(zone: StringName) -> Array:
	var list := []
	for id in _players:
		if StringName(String(_players[id].get("zone", ""))) == zone:
			list.append(_players[id])
	return list


func party() -> Dictionary:
	return _party


func in_party() -> bool:
	return not _party.is_empty()


func party_members_in_zone(zone: StringName) -> Array:
	var ids := []
	for id in _party.get("members", []):
		var key := String(id)
		if key != _me and _players.has(key) and StringName(String(_players[key].get("zone", ""))) == zone:
			ids.append(key)
	return ids


func zone_host(zone: StringName) -> String:
	return String(_hosts.get(zone, ""))


func is_zone_host(zone: StringName) -> bool:
	return zone_host(zone) == _me and _me != ""


func is_mirror_zone(zone: StringName) -> bool:
	return in_party() and zone_host(zone) != "" and not is_zone_host(zone)


## The RemotePlayer of [param id] in the current zone (group `remote_players`, its
## `player_id` property or "online_id" meta), or null.
func remote_node(id: String) -> Node3D:
	if not is_inside_tree():
		return null
	for node in get_tree().get_nodes_in_group("remote_players"):
		if node is Node3D and (String(node.get("player_id")) == id or String(node.get_meta("online_id", "")) == id):
			return node
	return null


func use_transport(transport: Object) -> void:
	_transport = transport
	if transport == null:
		var was := _me != ""
		_me = ""
		_players.clear()
		_party = {}
		_hosts.clear()
		if was:
			disconnected.emit()


func _dispatch(msg: Dictionary) -> void:
	var t := String(msg.get("t", ""))
	match t:
		"welcome":
			_me = String(msg.get("you", {}).get("id", ""))
			_players.clear()
			for p in msg.get("players", []):
				if p is Dictionary and String(p.get("id", "")) != _me:
					_players[String(p.id)] = p
			_party = msg.get("party") if msg.get("party") is Dictionary else {}
			connected.emit()
		"join":
			var p: Variant = msg.get("player")
			if p is Dictionary and String(p.get("id", "")) != "":
				_players[String(p.id)] = p
				player_joined.emit(String(p.id))
		"players":
			for p in msg.get("players", []):
				if p is Dictionary and String(p.get("id", "")) != _me:
					_players[String(p.id)] = p
		"leave":
			var id := String(msg.get("id", ""))
			if _players.erase(id):
				player_left.emit(id)
		"state", "look":
			var id := String(msg.get("id", ""))
			if _players.has(id):
				for key in msg:
					if key != "t" and key != "id":
						_players[id][key] = msg[key]
		"party":
			_party = msg.get("party") if msg.get("party") is Dictionary else {}
			party_changed.emit()
		"host":
			var zone := StringName(String(msg.get("zone", "")))
			_hosts[zone] = String(msg.get("id", "")) if msg.get("id") != null else ""
			host_changed.emit(zone)
		"kicked":
			use_transport(null)
	message.emit(t, msg)
