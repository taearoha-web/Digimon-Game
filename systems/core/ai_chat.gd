class_name AiChat
extends Node
## Talking to the world players. The hero types a line (an HTML bar on the web page, so
## Thai input works on iPhone; a small box elsewhere) to one player (its card's "คุย") or
## to the world chat, and the player answers above its head and in the world chat. The
## answers are made in the game itself (ChatBrain: free, instant, offline): what the line
## is after and the player's own state decide the reply, and its action: join or leave the
## hero's party, or open the player's stall; the game's own rules still decide
## (Game.party_invite).
##
## The transport is anything with send(json) -> id and poll(id) -> answer JSON. The
## default is ChatBrain.LocalTransport. WebTransport would ask the account server's
## Claude chat instead (hosting/worker/chat.mjs, tools/web/accounts.js), which costs money
## per message and needs the owner's API key, so it is not used. Tests use a stand-in.

signal replied(index: int, text: String, action: String)
signal failed(index: int, message: String)

const HISTORY := 8
const HERO_COLOR := Color("ffe27a")
const PLAYER_COLOR := Color("8ff0ff")
const WAIT_LIMIT := 40.0

## {send(json: String) -> int, poll(id: int) -> String} (WebTransport on the web page).
var transport: Object
## Talk so far per world player: [{who: "hero"/"player", text}].
var history := {}
## Requests waiting for an answer: id -> {index, channel, waited}.
var _pending := {}
## What the open typing bar is for: {index, channel} (index -1 = the world chat).
var _composing := {}
var _box: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if transport == null:
		transport = ChatBrain.LocalTransport.new()


# --- Asking --------------------------------------------------------------------------

## Opens the typing bar to talk to world player i.
func talk_to(i: int) -> void:
	var s := WorldPlayers.state(i, WorldPresence.clock())
	_compose({"index": i, "channel": "direct"}, "คุยกับ %s" % s.name, "พิมพ์ถึง %s…" % s.name)


## Opens the typing bar for the world chat (an online player answers).
func talk_world() -> void:
	_compose({"index": -1, "channel": "world"}, "แชทโลก", "พิมพ์ข้อความถึงทุกคน…")


func _compose(target: Dictionary, title: String, placeholder: String) -> void:
	_composing = target
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.toonChatCompose && window.toonChatCompose(%s)" % JSON.stringify(JSON.stringify({"title": title, "placeholder": placeholder})), true)
	else:
		_open_box(title, placeholder)


## The hero's line, typed: shown in the world chat and sent. Returns "" when sent,
## otherwise why not.
func submit(text: String, target: Dictionary = {}) -> String:
	if target.is_empty():
		target = _composing
	_composing = {}
	text = text.strip_edges().left(200)
	if text == "" or target.is_empty():
		return "พิมพ์ข้อความก่อน"
	# An order to the party ("ตามมา", "รอตรงนี้", "กลับเมือง") is carried out, not chatted.
	if PartyTalk.route(text):
		Game.world_chat.emit(String(Game.profile.get("name", "ฮีโร่")), text, HERO_COLOR)
		return ""
	var channel := String(target.get("channel", "direct"))
	var i := int(target.get("index", -1))
	if channel == "world" or i < 0:
		channel = "world"
		i = responder(text)
	var hero_name := String(Game.profile.get("name", "ฮีโร่"))
	if i < 0:
		Game.world_chat.emit(hero_name, text, HERO_COLOR)
		return "ตอนนี้ไม่มีผู้เล่นคนอื่นออนไลน์"
	var s := WorldPlayers.state(i, WorldPresence.clock())
	if channel == "direct":
		Game.world_chat.emit(hero_name, "(ถึง %s) %s" % [s.name, text], HERO_COLOR)
	else:
		Game.world_chat.emit(hero_name, text, HERO_COLOR)
	if transport == null:
		transport = ChatBrain.LocalTransport.new()
	var body := request_body(i, text, channel)
	var id := int(transport.call("send", JSON.stringify(body)))
	_remember(i, "hero", text)
	_pending[id] = {"index": i, "channel": channel, "waited": 0.0}
	var p := _field_player(i)
	if p != null:
		p.bubble("…")
	return ""


## Who answers a line in the world chat: an online player named in it, otherwise an
## online player near the hero's level (the same one for the same line). -1 if nobody.
func responder(text: String) -> int:
	var t := WorldPresence.clock()
	var online: Array[int] = []
	var lower := text.to_lower()
	for i in WorldPlayers.size():
		var s := WorldPlayers.state(i, t)
		if not bool(s.online):
			continue
		if lower.contains(String(s.name).to_lower()):
			return i
		online.append(i)
	if online.is_empty():
		return -1
	var level := int(Game.profile.get("level", 1))
	online.sort_custom(func(a: int, b: int) -> bool:
		return absi(int(WorldPlayers.state(a, t).level) - level) < absi(int(WorldPlayers.state(b, t).level) - level))
	var near := online.slice(0, mini(5, online.size()))
	return near[absi(hash(text)) % near.size()]


## What the player is told: the line, who it is and who the hero is, the talk so far
## and the Thai hour (ChatBrain.reply reads it; the same shape as hosting/worker/chat.mjs
## readChat, plus `hour`).
func request_body(i: int, text: String, channel: String) -> Dictionary:
	var t := WorldPresence.clock()
	var s := WorldPlayers.state(i, t)
	var place := StringName(s.get("place", ""))
	var place_name := ""
	if place == &"town":
		place_name = "หมู่บ้าน"
	elif place != &"":
		place_name = String(ZoneData.get_zone(place).get("name", ""))
	var doing := String(s.get("doing", ""))
	if Game.in_party(i):
		doing = "party"
		place_name = String(ZoneData.get_zone(Game.current_zone).get("name", "")) if Game.current_zone != &"" else place_name
	var hero_class := StringName(Game.profile.get("class", ClassData.START))
	return {
		"text": text,
		"channel": channel,
		"hour": WorldEvents.time_of_day(t) / 3600,
		"player": {
			"name": String(s.name),
			"class": String(ClassData.get_class_data(StringName(s["class"])).get("name", "")),
			"level": int(s.level),
			"stars": int(s.get("stars", 0)),
			"style": String(WorldPlayers.STYLES.get(String(s.style), {}).get("label", "")),
			"doing": doing,
			"place": place_name,
			"guild": WorldPlayers.guild_name(int(s.get("guild", 0))),
			"gender": int(s.get("gender", 0)),
			"inParty": Game.in_party(i),
			"divine": bool(s.get("divine", false)),
		},
		"hero": {
			"name": String(Game.profile.get("name", "")),
			"class": String(ClassData.get_class_data(hero_class).get("name", "")),
			"level": int(Game.profile.get("level", 1)),
			"stars": int(Game.paragon().get("level", 0)),
			"guild": WorldPlayers.guild_name(Game.guild()),
		},
		"history": (history.get(i, []) as Array).duplicate(true),
	}


# --- Answers -------------------------------------------------------------------------

func _process(delta: float) -> void:
	if OS.has_feature("web") and not _composing.is_empty():
		var raw := str(JavaScriptBridge.eval("window.toonChatComposed ? window.toonChatComposed() : ''", true))
		if raw != "" and raw != "null":
			var typed: Variant = JSON.parse_string(raw)
			if typed is Dictionary and typed.has("text"):
				submit(String(typed.text))
			else:
				_composing = {}
	if transport == null or _pending.is_empty():
		return
	for id in _pending.keys():
		var wait: Dictionary = _pending[id]
		wait.waited = float(wait.waited) + delta
		var raw := str(transport.call("poll", int(id)))
		if raw == "" or raw == "null":
			if float(wait.waited) > WAIT_LIMIT:
				_pending.erase(id)
				failed.emit(int(wait.index), "ไม่มีคำตอบ ลองใหม่อีกครั้งนะ")
				Game.say("ไม่มีคำตอบ ลองใหม่อีกครั้งนะ", &"warning")
			continue
		_pending.erase(id)
		var answer: Variant = JSON.parse_string(raw)
		if answer is Dictionary:
			receive(int(wait.index), answer, String(wait.channel))


## An answer for world player i: {reply, action} or {error, message}.
func receive(i: int, answer: Dictionary, channel := "direct") -> void:
	if answer.has("error"):
		var message := String(answer.get("message", "ส่งข้อความไม่สำเร็จ"))
		failed.emit(i, message)
		Game.say(message, &"warning")
		return
	var s := WorldPlayers.state(i, WorldPresence.clock())
	var reply := String(answer.get("reply", "")).strip_edges().left(160)
	if reply == "":
		reply = "..."
	var action := String(answer.get("action", "none"))
	_remember(i, "player", reply)
	var name_text := String(s.name)
	Game.world_chat.emit(name_text if channel == "world" else "%s (ถึงคุณ)" % name_text, reply, PLAYER_COLOR)
	var p := _field_player(i)
	if p != null:
		p.bubble(reply)
	_act(i, action)
	replied.emit(i, reply, action)


## What the player does about the talk; the game's rules have the last word.
func _act(i: int, action: String) -> void:
	match action:
		"join_party":
			if not Game.in_party(i):
				var why := Game.party_invite(i)
				if why != "":
					Game.say(why, &"warning")
		"leave_party":
			if Game.in_party(i):
				var s := WorldPlayers.state(i, WorldPresence.clock())
				Game.party_kick(i, "%s ออกจากปาร์ตี้แล้ว" % s.name)
		"open_stall":
			var s := WorldPlayers.state(i, WorldPresence.clock())
			var main := get_parent()
			if String(s.get("doing", "")) == "stall" and main != null and "shop" in main and main.shop != null and main.shop.has_method("open_stall"):
				main.shop.open_stall(i)


func _remember(i: int, who: String, text: String) -> void:
	var talk: Array = history.get(i, [])
	talk.append({"who": who, "text": text})
	while talk.size() > HISTORY:
		talk.remove_at(0)
	history[i] = talk


## World player i's body in the current zone, or null.
func _field_player(i: int) -> FieldPlayer:
	if not is_inside_tree():
		return null
	for node in get_tree().get_nodes_in_group("world_players"):
		var p := node as FieldPlayer
		if p != null and p.world_index == i and is_instance_valid(p):
			return p
	return null


# --- The typing box away from the web page -------------------------------------------

func _open_box(title: String, placeholder: String) -> void:
	if _box != null:
		_box.queue_free()
	_box = CanvasLayer.new()
	_box.layer = 70
	add_child(_box)
	var panel := UIUtil.panel(&"GlassPanel")
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -340
	panel.offset_right = 340
	panel.offset_top = 16
	_box.add_child(panel)
	var column := UIUtil.vbox(8)
	panel.add_child(column)
	column.add_child(UIUtil.label(title, &"BoldLabel"))
	var row := UIUtil.hbox(8)
	column.add_child(row)
	var edit := LineEdit.new()
	edit.name = "ChatText"
	edit.placeholder_text = placeholder
	edit.max_length = 200
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0, 52)
	row.add_child(edit)
	var send := UIUtil.button("ส่ง", &"PrimaryButton", Vector2(110, 52))
	row.add_child(send)
	var shut := UIUtil.button("ปิด", &"", Vector2(90, 52))
	row.add_child(shut)
	var finish := func(text: String):
		if is_instance_valid(_box):
			_box.queue_free()
		_box = null
		if text != "":
			submit(text)
		else:
			_composing = {}
	send.pressed.connect(func(): finish.call(edit.text))
	edit.text_submitted.connect(func(t: String): finish.call(t))
	shut.pressed.connect(func(): finish.call(""))
	edit.grab_focus()


## The account server's Claude chat through the web page (tools/web/accounts.js); not
## used by default (it costs money per message).
class WebTransport:
	extends RefCounted

	func send(json: String) -> int:
		return int(JavaScriptBridge.eval("window.toonChatSend ? window.toonChatSend(%s) : -1" % JSON.stringify(json), true))

	func poll(id: int) -> String:
		if id < 0:
			return JSON.stringify({"error": "unavailable", "message": "รีเฟรชหน้าเกมแล้วลองใหม่อีกครั้ง"})
		return str(JavaScriptBridge.eval("window.toonChatPoll ? window.toonChatPoll(%d) : ''" % id, true))
