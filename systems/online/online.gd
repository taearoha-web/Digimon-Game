extends Node
## Online play (autoload `Online`; the contract is docs/ONLINE_PROTOCOL.md "Client API").
## Real players who are signed in meet in one world room: they see each other walk,
## chat (world / party / whisper), party up and, through the other systems listening to
## `message`, fight together, trade and duel. When the connection drops the game carries
## on alone and tries again (2, 4, 8, 16, then every 30 s).
##
## On the web build it connects by itself once the account is signed in
## (window.toonCloudStatus() has a user), a hero is playing and its zone is built
## (Zone tells zone_entered / zone_left), and only while the settings switch
## "เล่นออนไลน์" (GameSettings.online_play) is on. Desktop and headless builds stay
## offline unless a test hands it a transport (use_transport: anything with
## send_text(text) and poll() -> Array of text frames; is_open() / is_closed() when it
## has them).
##
## After `hello` it sends the hero's `state` at most STATE_HZ times a second
## (STATE_HZ_PHONE on phones and low quality), only when something changed, plus a
## heartbeat every HEARTBEAT seconds, a `look` when the gear or appearance changes and
## the zone with every state. It keeps the players, the party and the zone hosts from
## the server's frames, then emits `message(type, data)` for every frame (after its own
## handling) so the other systems can react. Players in the hero's zone are RemotePlayers
## (characters/remote_player.gd) in that zone; in an instanced zone (the tower, a ranked
## duel's arena, the guild war, the arena) only the party's. Every frame from the network
## is checked: a malformed one changes nothing.

signal connected
signal disconnected
signal message(type: String, data: Dictionary)
signal player_joined(id: String)
signal player_left(id: String)
signal party_changed
signal host_changed(zone: StringName)

const STATE_HZ := 8.0
const STATE_HZ_PHONE := 5.0
const HEARTBEAT := 2.0
## Seconds between two checks of the hero's look (a change sends `look`).
const LOOK_CHECK := 1.0
## Seconds between two looks at the account while not connected.
const STATUS_EVERY := 3.0
## How long after a cast the hero's anim says "skill:<id>" (ms).
const SKILL_SHOW_MS := 900
const NAME_MAX := 16
const CHAT_MAX := 120
const MAX_FRAME := 8192
const PARTY_TINT := Color("7dff8a")
## No position in any zone is farther from its centre than this (metres).
const WORLD_LIMIT := 5000.0
## Zones whose monsters only the party shares (as the server's INSTANCED_ZONES).
const INSTANCED_ZONES: Array[StringName] = [&"tower", &"pvp", &"guildwar", &"arena"]

var _transport: Object
var _open := false
var _me := {}
var _players := {}
var _party := {}
var _hosts := {}
var _remotes := {}
var _zone: Zone
var _attempt := 0
## Names of players seen this session (id -> name), for party members who dropped out.
var _names := {}
var _retry_in := 0.0
var _kicked := false
var _close_after := false
var _state_in := 0.0
var _beat_in := HEARTBEAT
var _look_in := LOOK_CHECK
var _look_sig := ""
## What the last `state` said, quantised (x, y, z, yaw, hp, max_hp) and as text.
var _q := PackedInt64Array([0, 0, 0, 0, 0, 0])
var _q_anim := ""
var _q_zone := ""
var _q_mount := ""
var _last_state := {}
var _skill_anim := ""
var _skill_until := 0
var _linked_hero: Hero
## A party invitation waiting for an answer: {from, name} ({} when none).
var _invite := {}
## Frames sent and received this session (the settings / tests).
var frames_out := 0
var frames_in := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Back from the background (phone unlocked, app switched back): try again at once
## instead of waiting out the backoff; the server kept the party for its grace.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		if _transport == null and not _kicked:
			_retry_in = 0.0
			_attempt = 0


func _process(delta: float) -> void:
	_tick(delta)


# --- The Client API ------------------------------------------------------------------

func is_online() -> bool:
	return _transport != null and _open


func my_id() -> String:
	return String(_me.get("id", ""))


## Sends one frame {"t": type, ...data}; nothing when offline (or the frame is too big).
func send(type: String, data := {}) -> void:
	if not is_online():
		return
	var msg := data.duplicate()
	msg["t"] = type
	var text := JSON.stringify(msg)
	if text.to_utf8_buffer().size() > MAX_FRAME:
		push_warning("Online: frame %s too big (%d bytes)" % [type, text.length()])
		return
	frames_out += 1
	_transport.call("send_text", text)


## id -> player dict (latest): {id, user, name, cls, level, stars, look, zone, pos, yaw,
## anim, hp, max_hp, mount, party}.
func players() -> Dictionary:
	return _players


func players_in_zone(zone: StringName) -> Array:
	var out: Array = []
	for p in _players.values():
		if String(p.zone) == String(zone):
			out.append(p)
	return out


## {id, leader, members:[id]}, {} when none.
func party() -> Dictionary:
	return _party


func in_party() -> bool:
	return not _party.is_empty()


## The party members (me excluded) whose player is in `zone`.
func party_members_in_zone(zone: StringName) -> Array:
	var out: Array = []
	if _party.is_empty():
		return out
	for id in _party.members:
		if id != my_id() and _players.has(id) and String(_players[id].zone) == String(zone):
			out.append(id)
	return out


func zone_host(zone: StringName) -> String:
	return String(_hosts.get(StringName(zone), ""))


func is_zone_host(zone: StringName) -> bool:
	return my_id() != "" and zone_host(zone) == my_id()


## Someone else simulates the zone (its zone host; party or not, docs "Shared world"):
## do not spawn monsters there.
func is_mirror_zone(zone: StringName) -> bool:
	var host := zone_host(zone)
	return host != "" and host != my_id()


## Zones shared within the party only (the server's INSTANCED_ZONES); every other zone is
## open: everyone in it shares the same monsters.
static func is_instanced(zone: StringName) -> bool:
	return INSTANCED_ZONES.has(StringName(zone))


## The other real players (connected, me excluded) whose player is in `zone`, party or not.
func zone_members(zone: StringName) -> Array:
	var out: Array = []
	for id in _players:
		if id != my_id() and String(_players[id].zone) == String(zone):
			out.append(id)
	return out


## Who the zone host of `zone` serves (ids, me excluded): everyone there in an open zone,
## the party members there in an instanced one.
func serves(zone: StringName) -> Array:
	return party_members_in_zone(zone) if is_instanced(zone) else zone_members(zone)


## The RemotePlayer of player `id` in the current zone, or null.
func remote_node(id: String) -> Node3D:
	var node: Variant = _remotes.get(id)
	if node != null and is_instance_valid(node) and not (node as Node).is_queued_for_deletion():
		return node as Node3D
	return null


## Swaps the socket for `transport` (tests: send_text(text), poll() -> Array of texts);
## null drops the connection. An open transport sends `hello` at once.
func use_transport(transport: Object) -> void:
	if _transport != null:
		_drop(false)
	if transport == null or not GameSettings.online_play:
		return
	_transport = transport
	_kicked = false
	_retry_in = 0.0
	if _transport_open():
		_on_open()


## Handles one server frame as if it came off the wire.
func _dispatch(msg: Dictionary) -> void:
	var t := str(msg.get("t", ""))
	if t == "":
		return
	frames_in += 1
	match t:
		"welcome":
			_on_welcome(msg)
		"join":
			_on_join(msg)
		"leave":
			_on_leave(msg)
		"state":
			_on_state(msg)
		"look":
			_on_look(msg)
		"players":
			_on_players(msg)
		"party":
			_on_party(msg)
		"host":
			_on_host(msg)
		"party_invite":
			_on_invite(msg)
		"party_answer":
			# The answer to the hero's own invitation.
			var who := display_name(player(id_of(msg.get("from"))))
			Game.say("%s ตอบรับคำชวนเข้าปาร์ตี้" % who if msg.get("ok") == true else "%s ปฏิเสธคำชวนเข้าปาร์ตี้" % who, &"info")
		"chat":
			_on_chat(msg)
		"error":
			var text := str(msg.get("text", "")).strip_edges().left(160)
			Game.say(text if text != "" else "เกิดข้อผิดพลาดในการเล่นออนไลน์", &"warning")
		"kicked":
			_on_kicked(msg)
	message.emit(t, msg)
	if _close_after:
		_close_after = false
		_drop(false)


# --- More for the game's own screens --------------------------------------------------------

## A player's name to show: the character name, else the account name.
func display_name(p: Dictionary) -> String:
	var n := str(p.get("name", "")).strip_edges()
	if n == "":
		n = str(p.get("user", "")).strip_edges()
	return n if n != "" else "ผู้เล่น"


func player(id: String) -> Dictionary:
	if _players.has(id):
		return _players[id]
	return {"id": id, "name": _names.get(id, "")} if _names.has(id) else {}


## Party members whose connection dropped: still in the party for the server's grace
## (15 minutes), back in it as soon as they reconnect.
func party_away() -> Array:
	return _party.get("away", [])


## The player called `who` (name or account name, any case), "" when nobody is.
func find_by_name(who: String) -> String:
	var want := who.strip_edges().to_lower()
	if want == "":
		return ""
	for id in _players:
		var p: Dictionary = _players[id]
		if display_name(p).to_lower() == want or str(p.get("user", "")).to_lower() == want:
			return id
	return ""


## "/w name text" (or "/กระซิบ name text") to a real player: {to, name, text}, or {} when
## the line is not a whisper to someone online now (the longest matching name wins).
func parse_whisper(line: String) -> Dictionary:
	var rest := ""
	for prefix in ["/w ", "/กระซิบ "]:
		if line.begins_with(prefix):
			rest = line.substr(prefix.length()).strip_edges()
	if rest == "" or not is_online():
		return {}
	var best := ""
	var best_len := 0
	var lower := rest.to_lower()
	for id in _players:
		var p: Dictionary = _players[id]
		for n in [display_name(p), str(p.get("user", ""))]:
			var name_l := String(n).to_lower()
			if name_l != "" and name_l.length() > best_len and (lower == name_l or lower.begins_with(name_l + " ")):
				best = id
				best_len = name_l.length()
	if best == "":
		return {}
	var text := rest.substr(best_len).strip_edges()
	return {"to": best, "name": display_name(_players[best]), "text": text}


## A chat line from the hero: ch "world", "party" or "whisper" (to: the target's id).
func chat(ch: String, text: String, to := "") -> void:
	text = text.strip_edges().left(CHAT_MAX)
	if text == "":
		return
	var data := {"ch": ch, "text": text}
	if ch == "whisper":
		data["to"] = to
	send("chat", data)


func invite(id: String) -> void:
	send("party_invite", {"to": id})


## The invitation waiting for an answer ({from, name}; {} when none).
func pending_invite() -> Dictionary:
	return _invite


func answer_invite(ok: bool) -> void:
	if _invite.is_empty():
		return
	send("party_answer", {"from": String(_invite.from), "ok": ok})
	_invite = {}


func leave_party() -> void:
	send("party_leave")


func kick(id: String) -> void:
	send("party_kick", {"who": id})


func is_leader() -> bool:
	return in_party() and String(_party.get("leader", "")) == my_id() and my_id() != ""


## The "เล่นออนไลน์" switch: off drops the connection and keeps the game offline.
func set_enabled(on: bool) -> void:
	GameSettings.online_play = on
	GameSettings.save_settings()
	if not on:
		_drop(false)
	else:
		_kicked = false
		_retry_in = 0.0
		_attempt = 0


## States a second the hero's moves are sent at (fewer on phones and low quality).
func state_rate() -> float:
	var phone := OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android") or MemoryGuard.ios()
	return STATE_HZ_PHONE if phone or GameSettings.quality <= 0 else STATE_HZ


## The real player drawn under a tap at `screen` (the 3D view), or null.
func remote_at(screen: Vector2) -> RemotePlayer:
	if _zone == null or not is_instance_valid(_zone):
		return null
	var camera := _zone.get_viewport().get_camera_3d()
	if camera == null:
		return null
	var best: RemotePlayer = null
	var best_d := Zone.TAP_SLOP
	for id in _remotes:
		var r := remote_node(id) as RemotePlayer
		if r == null or not r.visible:
			continue
		var d := Zone.tap_distance(camera, r.global_position, 2.3, screen)
		if d < best_d:
			best_d = d
			best = r
	return best


# --- Zones (Zone tells) ------------------------------------------------------------------

## The hero's zone is built: its players come in, the server hears the zone at once.
func zone_entered(zone: Zone) -> void:
	_zone = zone
	_free_remotes()
	_link_hero(zone.hero)
	for id in _players:
		_sync_remote(id)
	if is_online():
		_state_in = 0.0
		_beat_in = 0.0


## The zone goes (travel, the title): its RemotePlayers go with it.
func zone_left(zone: Zone) -> void:
	if zone != _zone:
		return
	_free_remotes()
	_zone = null


func current_zone() -> StringName:
	return _zone.zone_id if _zone != null and is_instance_valid(_zone) else Game.current_zone


# --- Helpers for frames ------------------------------------------------------------

## [x, y, z] from a frame (anything else: the origin).
func vec3(v: Variant) -> Vector3:
	return pos_of(v) if valid_pos(v) else Vector3.ZERO


## Whether v is a position [x, y, z] of numbers inside the world (WORLD_LIMIT).
func valid_pos(v: Variant) -> bool:
	if not v is Array or (v as Array).size() < 3:
		return false
	for k in 3:
		var c: Variant = v[k]
		if not (c is int or c is float) or not is_finite(float(c)) or absf(float(c)) > WORLD_LIMIT:
			return false
	return true


func pos_of(v: Array) -> Vector3:
	return Vector3(float(v[0]), float(v[1]), float(v[2]))


func num(v: Variant, fallback := 0) -> int:
	return int(v) if (v is int or v is float) and is_finite(float(v)) and absf(float(v)) < 1e12 else fallback


func num_f(v: Variant, fallback := 0.0) -> float:
	return float(v) if (v is int or v is float) and is_finite(float(v)) else fallback


## A player id from a frame ("" when it is not one).
func id_of(v: Variant) -> String:
	if v is String or v is StringName:
		return String(v).left(64)
	if v is int or (v is float and is_finite(v)):
		return str(int(v))
	return ""


# --- Each frame -------------------------------------------------------------------------

func _tick(delta: float) -> void:
	if _transport == null:
		_try_connect(delta)
		return
	if _transport is OnlineSocket and (not Game.playing or not Game.has_profile or not GameSettings.online_play):
		# Back at the title (or switched off): no hero to show.
		_drop(false)
		return
	var frames: Variant = (_transport as OnlineSocket).poll(delta) if _transport is OnlineSocket else _transport.call("poll")
	if _transport == null:
		return
	if not _open and _transport_open():
		_on_open()
	if frames is Array:
		for text in frames:
			_receive(text)
			if _transport == null:
				return
	if _transport_closed():
		# Close code 4000 follows `kicked` (another tab took over): no reconnecting.
		if _transport.has_method("close_code") and int(_transport.call("close_code")) == OnlineSocket.CODE_KICKED:
			_kicked = true
		_drop(not _kicked)
		return
	if _open:
		_tick_send(delta)


func _receive(text: Variant) -> void:
	if not (text is String) or (text as String).length() > MAX_FRAME * 4:
		return
	# JSON.parse (not parse_string): a broken frame is dropped without an error in the log.
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	var parsed: Variant = json.data
	if parsed is Dictionary:
		_dispatch(parsed)


func _transport_open() -> bool:
	if _transport == null:
		return false
	return bool(_transport.call("is_open")) if _transport.has_method("is_open") else true


func _transport_closed() -> bool:
	return _transport != null and _transport.has_method("is_closed") and bool(_transport.call("is_closed"))


## On the web, signed in, playing in a built zone, switched on: opens the room's socket
## (after the backoff since the last drop).
func _try_connect(delta: float) -> void:
	if not OS.has_feature("web") or not GameSettings.online_play or _kicked:
		return
	if not Game.has_profile or not Game.playing or _zone == null or not is_instance_valid(_zone):
		return
	_retry_in -= delta
	if _retry_in > 0.0:
		return
	if not _signed_in():
		_retry_in = STATUS_EVERY
		return
	var socket := OnlineSocket.new()
	var url := OnlineSocket.page_url()
	if url == "" or socket.open(url) != OK:
		_retry_in = OnlineSocket.delay_for(_attempt)
		_attempt += 1
		return
	_transport = socket


## The page's account (tools/web/accounts.js): signed in and not in airplane mode.
func _signed_in() -> bool:
	var raw: Variant = JavaScriptBridge.eval("typeof window.toonCloudStatus === 'function' ? window.toonCloudStatus() : ''", true)
	var status: Variant = JSON.parse_string(str(raw)) if raw != null and str(raw) != "" else null
	return status is Dictionary and status.get("user") is Dictionary and not bool(status.get("offline", false))


func _on_open() -> void:
	_open = true
	_state_in = 0.0
	_beat_in = HEARTBEAT
	_look_in = LOOK_CHECK
	send("hello", _hello())
	connected.emit()


## The connection is gone (or dropped on purpose): everyone else leaves the screen, the
## party and hosts are forgotten; `retry` waits the backoff before the next try.
func _drop(retry: bool) -> void:
	var was_open := _open
	var t := _transport
	_transport = null
	_open = false
	if t != null and t.has_method("close"):
		t.call("close")
	_free_remotes()
	_players.clear()
	_invite = {}
	_me = {}
	var had_party := not _party.is_empty()
	_party = {}
	var zones := _hosts.keys()
	_hosts.clear()
	for z in zones:
		host_changed.emit(z)
	if had_party:
		party_changed.emit()
	if retry:
		_retry_in = OnlineSocket.delay_for(_attempt)
		_attempt += 1
	if was_open:
		disconnected.emit()


# --- What the hero sends ------------------------------------------------------------------

func _hero() -> Hero:
	if _zone == null or not is_instance_valid(_zone):
		return null
	var h := _zone.hero
	return h if h != null and is_instance_valid(h) and h.is_inside_tree() else null


func _hello() -> Dictionary:
	var p := Game.profile
	var look := _hero_look()
	_look_sig = PlayerLook.signature(look)
	var data := {
		"name": String(p.get("name", "")).strip_edges().left(NAME_MAX),
		"cls": String(p.get("class", ClassData.START)),
		"level": int(p.get("level", 1)),
		"stars": int((p.get("paragon", {}) as Dictionary).get("level", 0)) if p.get("paragon") is Dictionary else 0,
		"look": look,
	}
	data.merge(_state_now(), true)
	return data


## The hero's look with the wing pose it shows right now.
func _hero_look() -> Dictionary:
	var look := Game.hero_look()
	var h := _hero()
	if h != null and h.visual != null and not look.is_empty():
		look["wing_mode"] = h.visual.wing_mode
	return look


## Where the hero is and what it does: {pos, yaw, anim, hp, max_hp, zone, mount}.
func _state_now() -> Dictionary:
	var h := _hero()
	var p := Game.profile
	var hp := int(p.get("hp", 1))
	var max_hp := maxi(hp, 1)
	var pos := Vector3.ZERO
	var yaw := 0.0
	var anim := "idle"
	var mount := ""
	if h != null:
		pos = h.global_position
		yaw = wrapf(h.facing(), -PI, PI)
		anim = _hero_anim(h)
		max_hp = maxi(1, int(h.stats.get("max_hp", max_hp)))
		mount = h.mount.id if h.mount != null else ""
	return {"pos": [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01)], "yaw": snappedf(yaw, 0.01),
		"anim": anim, "hp": hp, "max_hp": max_hp, "zone": String(current_zone()), "mount": mount}


func _hero_anim(h: Hero) -> String:
	if h.is_dead():
		return "dead"
	var now := Time.get_ticks_msec()
	if now < _skill_until:
		return _skill_anim
	if now < h._cast_until:
		return "attack"
	return "run" if Vector2(h.velocity.x, h.velocity.z).length() > 0.6 else "idle"


func _link_hero(h: Hero) -> void:
	if _linked_hero != null and is_instance_valid(_linked_hero) and _linked_hero.skill_fired.is_connected(_on_skill):
		_linked_hero.skill_fired.disconnect(_on_skill)
	_linked_hero = h
	if h != null and not h.skill_fired.is_connected(_on_skill):
		h.skill_fired.connect(_on_skill)


func _on_skill(_index: int) -> void:
	var h := _linked_hero
	if h == null or not is_instance_valid(h) or h.last_cast_id == "":
		return
	_skill_anim = "skill:%s" % h.last_cast_id
	_skill_until = Time.get_ticks_msec() + SKILL_SHOW_MS
	_state_in = minf(_state_in, 0.0)


## The state goes out when it changed (at most state_rate() a second) and every
## HEARTBEAT seconds anyway; a new look once a LOOK_CHECK.
func _tick_send(delta: float) -> void:
	_state_in -= delta
	_beat_in -= delta
	_look_in -= delta
	if _look_in <= 0.0:
		_look_in = LOOK_CHECK
		_check_look()
	if _state_in > 0.0:
		return
	var h := _hero()
	var changed := false
	if h != null:
		var at := h.global_position
		var anim := _hero_anim(h)
		var max_hp := maxi(1, int(h.stats.get("max_hp", 1)))
		var hp := int(Game.profile.get("hp", 0))
		var mount := h.mount.id if h.mount != null else ""
		var zone := String(current_zone())
		changed = roundi(at.x * 20.0) != _q[0] or roundi(at.y * 10.0) != _q[1] or roundi(at.z * 20.0) != _q[2] \
			or roundi(wrapf(h.facing(), -PI, PI) * 20.0) != _q[3] or hp != _q[4] or max_hp != _q[5] \
			or anim != _q_anim or mount != _q_mount or zone != _q_zone
		if changed:
			_q[0] = roundi(at.x * 20.0)
			_q[1] = roundi(at.y * 10.0)
			_q[2] = roundi(at.z * 20.0)
			_q[3] = roundi(wrapf(h.facing(), -PI, PI) * 20.0)
			_q[4] = hp
			_q[5] = max_hp
			_q_anim = anim
			_q_mount = mount
			_q_zone = zone
	if not changed and _beat_in > 0.0:
		return
	_last_state = _state_now()
	send("state", _last_state)
	_state_in = 1.0 / state_rate()
	_beat_in = HEARTBEAT


func _check_look() -> void:
	var look := _hero_look()
	if look.is_empty():
		return
	var sig := PlayerLook.signature(look)
	if sig == _look_sig:
		return
	_look_sig = sig
	send("look", {"look": look, "level": int(look.get("level", 1)), "stars": int(look.get("stars", 0))})


# --- What the server says --------------------------------------------------------------------

func _norm_player(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var id := id_of(raw.get("id"))
	if id == "":
		return {}
	var p := {"id": id, "user": str(raw.get("user", "")).left(32), "name": str(raw.get("name", "")).strip_edges().left(NAME_MAX),
		"cls": "", "level": 1, "stars": 0, "look": {}, "zone": "", "pos": [0.0, 0.0, 0.0], "yaw": 0.0, "anim": "idle",
		"hp": 1, "max_hp": 1, "mount": "", "party": null}
	_merge(p, raw)
	return p


## Copies the valid fields of a frame into player p.
func _merge(p: Dictionary, raw: Dictionary) -> void:
	if raw.has("name") and raw.name is String and String(raw.name).strip_edges() != "":
		p["name"] = String(raw.name).strip_edges().left(NAME_MAX)
	if raw.has("cls") and (raw.cls is String or raw.cls is StringName) and ClassData.CLASSES.has(StringName(raw.cls)):
		p["cls"] = String(raw.cls)
	if raw.has("level"):
		p["level"] = clampi(num(raw.level, int(p.level)), 1, Game.MAX_LEVEL)
	if raw.has("stars"):
		p["stars"] = clampi(num(raw.stars, int(p.stars)), 0, Game.PARAGON_MAX)
	if raw.has("look") and raw.look is Dictionary:
		p["look"] = raw.look
	if raw.has("zone") and (raw.zone is String or raw.zone is StringName):
		p["zone"] = String(raw.zone).left(48)
	if raw.has("pos") and valid_pos(raw.pos):
		var v := pos_of(raw.pos)
		p["pos"] = [v.x, v.y, v.z]
	if raw.has("yaw"):
		p["yaw"] = num_f(raw.yaw, float(p.yaw))
	if raw.has("anim") and raw.anim is String:
		p["anim"] = String(raw.anim).left(48)
	if raw.has("max_hp"):
		p["max_hp"] = maxi(1, num(raw.max_hp, int(p.max_hp)))
	if raw.has("hp"):
		p["hp"] = clampi(num(raw.hp, int(p.hp)), 0, int(p.max_hp))
	if raw.has("mount"):
		p["mount"] = String(raw.mount).left(32) if raw.mount is String else ""
	if raw.has("party"):
		p["party"] = raw.party if (raw.party == null or raw.party is String or raw.party is int or raw.party is float) else null


func _on_welcome(msg: Dictionary) -> void:
	var you: Variant = msg.get("you")
	if you is Dictionary:
		_me = {"id": id_of(you.get("id")), "user": str(you.get("user", ""))}
	_attempt = 0
	_set_players(msg.get("players"))
	_set_party(msg.get("party"), true)
	var others := _players.size()
	Game.say("เชื่อมต่อออนไลน์แล้ว · ผู้เล่นจริงออนไลน์ %d คน" % others if others > 0 else "เชื่อมต่อออนไลน์แล้ว", &"success")
	if not _party.is_empty():
		# Back within the server's grace: the party kept this hero's place.
		Game.say("กลับเข้าปาร์ตี้เดิมแล้ว (%d คน)" % (_party.members as Array).size(), &"success")


func _on_players(msg: Dictionary) -> void:
	if msg.get("players") is Array:
		_set_players(msg.players)


## The whole list: newcomers join, the missing leave.
func _set_players(list: Variant) -> void:
	if not list is Array:
		return
	var seen := {}
	for raw in list:
		var p := _norm_player(raw)
		if p.is_empty() or p.id == my_id():
			continue
		seen[p.id] = true
		var fresh: bool = not _players.has(p.id)
		_players[p.id] = p
		_names[p.id] = display_name(p)
		_sync_remote(p.id, true)
		if fresh:
			player_joined.emit(p.id)
	for id in _players.keys():
		if not seen.has(id):
			_players.erase(id)
			_sync_remote(id)
			player_left.emit(id)


func _on_join(msg: Dictionary) -> void:
	var p := _norm_player(msg.get("player"))
	if p.is_empty() or p.id == my_id():
		return
	var fresh: bool = not _players.has(p.id)
	_players[p.id] = p
	_names[p.id] = display_name(p)
	_sync_remote(p.id, true)
	if fresh:
		if _is_member(p.id):
			Game.say("%s (ปาร์ตี้) เข้าเกมแล้ว" % display_name(p), &"info")
		player_joined.emit(p.id)


func _on_leave(msg: Dictionary) -> void:
	var id := id_of(msg.get("id"))
	if id == "" or not _players.has(id):
		return
	var p: Dictionary = _players[id]
	_names[id] = display_name(p)
	_players.erase(id)
	_sync_remote(id)
	if _is_member(id) and not party_away().has(id):
		Game.say("%s (ปาร์ตี้) ออกจากเกมแล้ว" % display_name(p), &"info")
	player_left.emit(id)


func _on_state(msg: Dictionary) -> void:
	var id := id_of(msg.get("id"))
	if id == "" or not _players.has(id):
		return
	var p: Dictionary = _players[id]
	var zone_before := String(p.zone)
	_merge(p, msg)
	if String(p.zone) != zone_before:
		_sync_remote(id)
		return
	var r := remote_node(id) as RemotePlayer
	if r != null:
		r.player = p
		# What this frame said, checked (_merge), for the RemotePlayer.
		var view := {}
		for key in ["pos", "yaw", "anim", "hp", "max_hp", "mount"]:
			if msg.has(key):
				view[key] = p[key]
		r.apply_state(view)
	else:
		_sync_remote(id)


func _on_look(msg: Dictionary) -> void:
	var id := id_of(msg.get("id"))
	if id == "" or not _players.has(id) or not msg.get("look") is Dictionary:
		return
	var p: Dictionary = _players[id]
	_merge(p, {"look": msg.look, "level": msg.get("level", p.level), "stars": msg.get("stars", p.stars)})
	var r := remote_node(id) as RemotePlayer
	if r != null:
		r.player = p
		r.apply_look(p.look, int(p.level), int(p.stars))


func _on_party(msg: Dictionary) -> void:
	if msg.has("party"):
		_set_party(msg.party, false)


func _set_party(raw: Variant, quiet: bool) -> void:
	var now := {}
	if raw is Dictionary:
		var members: Array = []
		var list: Variant = raw.get("members", [])
		if list is Array:
			for m in list:
				var id := id_of(m)
				if id != "" and not members.has(id):
					members.append(id)
		var away: Array = []
		var gone: Variant = raw.get("away", [])
		if gone is Array:
			for m in gone:
				var id := id_of(m)
				if id != "" and members.has(id) and not away.has(id):
					away.append(id)
		now = {"id": id_of(raw.get("id")), "leader": id_of(raw.get("leader")), "members": members, "away": away}
	var before: Array = _party.get("members", [])
	var away_before: Array = _party.get("away", [])
	var had := not _party.is_empty()
	_party = now
	var after: Array = now.get("members", [])
	if not quiet:
		if not had and not now.is_empty():
			Game.say("เข้าร่วมปาร์ตี้แล้ว (%d คน)" % after.size(), &"success")
		else:
			for id in after:
				if id != my_id() and not before.has(id):
					Game.say("%s เข้าร่วมปาร์ตี้แล้ว" % display_name(player(id)), &"info")
		for id in now.get("away", []):
			if id != my_id() and not away_before.has(id):
				Game.say("%s หลุดการเชื่อมต่อ ยังอยู่ในปาร์ตี้ รอกลับมาได้ 15 นาที" % display_name(player(id)), &"warning")
		for id in away_before:
			if id != my_id() and after.has(id) and not (now.get("away", []) as Array).has(id):
				Game.say("%s กลับมาแล้ว" % display_name(player(id)), &"info")
		for id in before:
			if id != my_id() and not after.has(id):
				Game.say("%s ออกจากปาร์ตี้แล้ว" % display_name(player(id)), &"info")
		if had and now.is_empty():
			Game.say("ออกจากปาร์ตี้แล้ว", &"info")
	# Out of the party: the party-scoped hosts (instanced zones) are gone; an open zone's
	# host is the zone's, not the party's, and stays.
	if now.is_empty() and not _hosts.is_empty():
		for z in _hosts.keys():
			if is_instanced(z):
				_hosts.erase(z)
				host_changed.emit(z)
	for id in _players:
		_sync_remote(id)
		var r := remote_node(id) as RemotePlayer
		if r != null and r.in_party != _is_member(id):
			r.set_party(_is_member(id))
	party_changed.emit()


func _on_host(msg: Dictionary) -> void:
	if not (msg.get("zone") is String or msg.get("zone") is StringName):
		return
	var zone := StringName(String(msg.zone))
	var id := id_of(msg.get("id"))
	if id == "":
		_hosts.erase(zone)
	else:
		_hosts[zone] = id
	host_changed.emit(zone)


func _on_invite(msg: Dictionary) -> void:
	var from := id_of(msg.get("from"))
	if from == "":
		return
	var who := str(msg.get("name", "")).strip_edges().left(NAME_MAX)
	if who == "":
		who = display_name(player(from))
	_invite = {"from": from, "name": who}
	Game.say("%s ชวนคุณเข้าปาร์ตี้" % who, &"quest")


func _on_chat(msg: Dictionary) -> void:
	var from := id_of(msg.get("from"))
	var ch := str(msg.get("ch", ""))
	if from == "" or from == my_id() or ch == "whisper" or not msg.get("text") is String:
		return
	var r := remote_node(from) as RemotePlayer
	if r != null:
		r.bubble(String(msg.text).left(CHAT_MAX))


func _on_kicked(msg: Dictionary) -> void:
	var reason := str(msg.get("reason", ""))
	Game.say("บัญชีนี้เข้าเล่นออนไลน์จากที่อื่น จึงตัดการเชื่อมต่อที่นี่" if reason == "elsewhere" else "ถูกตัดการเชื่อมต่อออนไลน์", &"warning")
	_kicked = true
	_close_after = true


func _is_member(id: String) -> bool:
	return not _party.is_empty() and (_party.members as Array).has(id)


# --- RemotePlayers ---------------------------------------------------------------------

## Whether player p shows in the hero's zone: the same zone, and in an instanced one
## (tower, duel arena, guild war, arena) only a party member.
func _shows_here(p: Dictionary) -> bool:
	if _zone == null or not is_instance_valid(_zone) or not _zone.is_built or _zone.is_queued_for_deletion():
		return false
	if String(p.zone) != String(_zone.zone_id) or String(p.id) == my_id():
		return false
	var instanced := _zone.is_pvp or _zone.is_tower or bool(_zone.data.get("arena", false))
	return not instanced or _is_member(String(p.id))


## Adds or removes player id's RemotePlayer so it matches where the player is; `fresh`
## re-dresses an existing one from the player's dict (a join or a new list).
func _sync_remote(id: String, fresh := false) -> void:
	var p: Dictionary = _players.get(id, {})
	var want := not p.is_empty() and _shows_here(p)
	var node := remote_node(id) as RemotePlayer
	if node == null:
		_remotes.erase(id)
	if want and node == null:
		var r := RemotePlayer.new()
		r.setup(p)
		r.hero = _zone.hero
		_zone.add_child(r)
		_remotes[id] = r
		if _is_member(id):
			r.set_party(true)
	elif not want and node != null:
		node.queue_free()
		_remotes.erase(id)
	elif want and fresh:
		node.player = p
		node.apply_look(p.look, int(p.level), int(p.stars))
		node.apply_state(p)


func _free_remotes() -> void:
	for id in _remotes:
		var node: Variant = _remotes[id]
		if node != null and is_instance_valid(node):
			(node as Node).queue_free()
	_remotes.clear()
