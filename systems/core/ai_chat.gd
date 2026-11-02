class_name AiChat
extends Node
## Talking to the world players. The hero types a line (an HTML bar on the web page, so
## Thai input works on iPhone; a small box elsewhere) to one player (its card's "คุย"), to
## the world chat, or to the party or guild chat (the HUD chat's tab picks: WorldChat
## compose_channel; "/p", "/g" or "/w" in front of a line picks too), and the player
## answers above its head and in the chat.
##
## The party chat (Game.channel_chat "party") reaches only the hero's party: 1-2 members
## answer, one after another like real typing (stagger). The members also answer each
## other: a member's line (theirs here, or PartyTalk's situational lines) may get another
## member's answer (react_chance, at most once every REACT_COOLDOWN seconds), and an answer
## may get one more (follow_chance), never more than MAX_FOLLOW_UPS after one line. The
## guild chat reaches the guild's online players: 0-2 of them answer, as guild mates.
## Without a party or a guild, a note says so. A buy request in the world chat is answered
## by the stalls that have it, or by someone saying nobody sells it now (ChatTrade). The
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
const NOTE_NAME := "ระบบ"
const NOTE_COLOR := Color("c9c9c9")
const NO_PARTY := "ยังไม่มีปาร์ตี้ ชวนเพื่อนเข้าตี้ก่อน แล้วค่อยคุยในแชทปาร์ตี้นะ"
const NO_GUILD := "ยังไม่มีกิลด์ สมัครได้ที่นายทะเบียนกิลด์ตั้งแต่ Lv.%d"
const NO_GUILD_ONLINE := "ตอนนี้ไม่มีเพื่อนกิลด์ออนไลน์"
## Answers among the members after one line, at most.
const MAX_FOLLOW_UPS := 2
## A member answers another's line (not the hero's) at most this often.
const REACT_COOLDOWN := 20.0
## Prefixes that pick the channel for one line.
const PREFIXES := {"/p ": "party", "/ป ": "party", "/g ": "guild", "/ก ": "guild", "/w ": "world", "/ล ": "world"}
const TITLES := {"world": ["แชทโลก", "พิมพ์ข้อความถึงทุกคน…"], "party": ["แชทปาร์ตี้", "พิมพ์ถึงเพื่อนในตี้…"], "guild": ["แชทกิลด์", "พิมพ์ถึงเพื่อนกิลด์…"]}

## {send(json: String) -> int, poll(id: int) -> String} (WebTransport on the web page).
var transport: Object
## Talk so far per world player: [{who: "hero"/"player", text}].
var history := {}
## Requests waiting for an answer: id -> {index, channel, waited}.
var _pending := {}
## What the open typing bar is for: {index, channel} (index -1 = the world chat).
var _composing := {}
var _box: CanvasLayer
## Talk so far in the party / guild chat per player: "party|i" -> [{who, text}].
var channel_history := {}
## The share of a member's party line another member answers; after an answer, the
## share that gets one more; a second member answering the hero.
var react_chance := 0.45
var follow_chance := 0.35
var second_chance := 0.5
## Extra seconds before each further answer to the same line (one types after the other).
var stagger := Vector2(1.2, 2.6)
var rng := RandomNumberGenerator.new()
var _clock := 0.0
var _react_at := -INF
## Talk threads in the party chat: id -> answers among the members still allowed.
var _threads := {}
var _next_thread := 0
var _posting := false
## While true (WorldPresence posting the members' own banter) a party line gets no answer.
static var hold := false
## Answers due later (the stalls answering a buy request): [{at, index, speaker, text}].
var _timed: Array = []
## The last buy request the hero typed (ChatTrade.parse), {} before any.
var last_trade := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if transport == null:
		transport = ChatBrain.LocalTransport.new()
	rng.randomize()
	if not Game.channel_chat.is_connected(_on_channel_chat):
		Game.channel_chat.connect(_on_channel_chat)


# --- Asking --------------------------------------------------------------------------

## Opens the typing bar to talk to world player i.
func talk_to(i: int) -> void:
	var s := WorldPlayers.state(i, WorldPresence.clock())
	_compose({"index": i, "channel": "direct"}, "คุยกับ %s" % s.name, "พิมพ์ถึง %s…" % s.name)


## Opens the typing bar for the world chat (an online player answers).
func talk_world() -> void:
	talk_channel("world")


## Opens the typing bar for `channel`: "world", "party" or "guild".
func talk_channel(channel: String) -> void:
	if not TITLES.has(channel):
		channel = "world"
	_compose({"index": -1, "channel": channel}, String(TITLES[channel][0]), String(TITLES[channel][1]))


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
	text = text.strip_edges()
	var channel := String(target.get("channel", "direct"))
	for prefix in PREFIXES:
		if (text + " ").begins_with(String(prefix)) and not target.is_empty():
			channel = String(PREFIXES[prefix])
			target = {"index": -1, "channel": channel}
			text = text.substr(String(prefix).length() - 1).strip_edges()
			break
	text = text.left(200)
	if text == "" or target.is_empty():
		return "พิมพ์ข้อความก่อน"
	# An order to the party ("ตามมา", "รอตรงนี้", "กลับเมือง") is carried out, not chatted;
	# the party sees it.
	if PartyTalk.route(text):
		_post("party", String(Game.profile.get("name", "ฮีโร่")), text, HERO_COLOR)
		return ""
	if channel == "party":
		return _submit_party(text)
	if channel == "guild":
		return _submit_guild(text)
	var i := int(target.get("index", -1))
	if channel == "world" or i < 0:
		channel = "world"
		i = responder(text)
	var hero_name := String(Game.profile.get("name", "ฮีโร่"))
	# A buy request ("หาซื้อเพชรม่วง", "มีใครขายปีกไหม") is answered by the stalls that have
	# it, or by someone saying nobody sells it now (ChatTrade).
	if channel == "world":
		var req := ChatTrade.parse(text)
		if not req.is_empty():
			return _submit_buy(text, req)
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


## The hero's buy request in the world chat: the keepers who have it answer a few seconds
## apart (at most ChatTrade.MAX_SELLERS), naming the lot, its price and where their stall
## is (a bubble over the keeper when it stands here); otherwise one says nobody sells it.
func _submit_buy(text: String, req: Dictionary) -> String:
	var hero_name := String(Game.profile.get("name", "ฮีโร่"))
	Game.world_chat.emit(hero_name, text, HERO_COLOR)
	last_trade = req
	for a in ChatTrade.answers(req, WorldPresence.clock(), rng.randi(), hero_name):
		_timed.append({"at": _clock + float(a.delay), "index": int(a.index), "speaker": String(a.speaker), "text": String(a.text)})
	return ""


## Says the answers that are due.
func _flush_timed() -> void:
	var k := 0
	while k < _timed.size():
		var e: Dictionary = _timed[k]
		if _clock < float(e.at):
			k += 1
			continue
		_timed.remove_at(k)
		var i := int(e.index)
		Game.world_chat.emit(String(e.speaker), String(e.text), ChatTrade.SELLER_COLOR if i >= 0 else NOTE_COLOR)
		if i >= 0:
			_remember(i, "player", String(e.text))
			var p := _field_player(i)
			if p != null:
				p.bubble(String(e.text))


## Answers still to come (tests).
func timed_count() -> int:
	return _timed.size()


# --- The party and guild chats ----------------------------------------------------------

## The hero's line in the party chat: 1-2 members answer, one after the other.
func _submit_party(text: String) -> String:
	var hero_name := String(Game.profile.get("name", "ฮีโร่"))
	var members := party_members()
	if members.is_empty():
		_note("party", NO_PARTY)
		return NO_PARTY
	_post("party", hero_name, text, HERO_COLOR)
	var who := party_responders(text, members)
	var thread := _new_thread(MAX_FOLLOW_UPS)
	var wait := 0.0
	for i in who:
		_ask(i, text, "party", "", wait, thread)
		wait += rng.randf_range(stagger.x, stagger.y)
	return ""


## The hero's line in the guild chat: 0-2 online guild mates answer.
func _submit_guild(text: String) -> String:
	var g := Game.guild()
	if g == 0:
		var why := NO_GUILD % Game.GUILD_LEVEL
		_note("guild", why)
		return why
	_post("guild", String(Game.profile.get("name", "ฮีโร่")), text, HERO_COLOR)
	var mates := guild_online(g)
	if mates.is_empty():
		_note("guild", NO_GUILD_ONLINE)
		return NO_GUILD_ONLINE
	var t := WorldPresence.clock()
	var lower := text.to_lower()
	var who: Array[int] = []
	for i in mates:
		if lower.contains(String(WorldPlayers.state(i, t).name).to_lower()):
			who.append(i)
			break
	var order := mates.duplicate()
	order.sort_custom(func(a: int, b: int) -> bool: return hash("%d|%s" % [a, text]) < hash("%d|%s" % [b, text]))
	var roll := rng.randf()
	var count := maxi(who.size(), 0 if roll < 0.15 else (1 if roll < 0.6 else 2))
	for i in order:
		if who.size() >= count:
			break
		if not who.has(i):
			who.append(i)
	var wait := 0.0
	for i in who:
		_ask(i, text, "guild", "", wait, -1)
		wait += rng.randf_range(stagger.x, stagger.y)
	return ""


## The hero's party members (world player indices).
func party_members() -> Array[int]:
	var out: Array[int] = []
	for i in Game.world_party:
		out.append(int(i))
	return out


## Who answers the hero in the party chat: a member named first, otherwise one picked by
## the line; a second one now and then (always when the line is to everyone).
func party_responders(text: String, members: Array[int]) -> Array[int]:
	var out: Array[int] = []
	var lower := text.to_lower()
	for i in members:
		if lower.contains(String(WorldPlayers.entry(i).name).to_lower()):
			out.append(i)
			break
	var order := members.duplicate()
	order.sort_custom(func(a: int, b: int) -> bool: return hash("%d|%s" % [a, text]) < hash("%d|%s" % [b, text]))
	if out.is_empty():
		out.append(order[0])
	if members.size() > 1 and (text.contains("ทุกคน") or rng.randf() < second_chance):
		for i in order:
			if not out.has(i):
				out.append(i)
				break
	return out


## The online players in guild g (not the hero).
func guild_online(g: int) -> Array[int]:
	var out: Array[int] = []
	var t := WorldPresence.clock()
	for i in WorldPlayers.size():
		var s := WorldPlayers.state(i, t)
		if bool(s.online) and int(s.get("guild", 0)) == g:
			out.append(i)
	return out


## A member's line in the party chat (PartyTalk's, or a member's answer): another member
## may answer it, now and then.
func _on_channel_chat(channel: String, speaker: String, text: String, _color: Color) -> void:
	if _posting or hold or channel != "party" or _clock < _react_at:
		return
	var from := _member_named(speaker)
	if from < 0 or _is_order_answer(text):
		return
	if rng.randf() >= react_chance:
		return
	var other := _other_member(from)
	if other < 0:
		return
	_react_at = _clock + REACT_COOLDOWN
	var thread := _new_thread(MAX_FOLLOW_UPS - 1)
	_ask(other, text, "party", speaker, rng.randf_range(stagger.x, stagger.y), thread)


## After member i's answer in the party chat, another member may answer it in turn
## (within the thread's MAX_FOLLOW_UPS).
func _follow(i: int, text: String, thread: int) -> void:
	if int(_threads.get(thread, 0)) <= 0:
		_threads.erase(thread)
		return
	if rng.randf() >= follow_chance:
		return
	var other := _other_member(i)
	if other < 0:
		return
	_threads[thread] = int(_threads[thread]) - 1
	_ask(other, text, "party", String(WorldPlayers.entry(i).name), rng.randf_range(stagger.x, stagger.y), thread)


## Asks player i to answer `text` on `channel` (`from`: the member who said it, "" for the
## hero), after `wait` more seconds.
func _ask(i: int, text: String, channel: String, from: String, wait: float, thread: int) -> void:
	if transport == null:
		transport = ChatBrain.LocalTransport.new()
	var body := request_body(i, text, channel)
	var key := "%s|%d" % [channel, i]
	body["history"] = (channel_history.get(key, []) as Array).duplicate(true)
	if from != "":
		body["from"] = from
	var id := int(transport.call("send", JSON.stringify(body)))
	_remember_in(key, "hero" if from == "" else "mate", text)
	_pending[id] = {"index": i, "channel": channel, "waited": 0.0, "after": wait, "thread": thread}


func _new_thread(follow_ups: int) -> int:
	_next_thread += 1
	_threads[_next_thread] = follow_ups
	return _next_thread


## The party member (world player index) named `speaker`, -1 if none.
func _member_named(speaker: String) -> int:
	for i in party_members():
		if String(WorldPlayers.entry(i).name) == speaker:
			return i
	return -1


## Another member than i, picked at random; -1 when i is alone.
func _other_member(i: int) -> int:
	var others := party_members().filter(func(k: int) -> bool: return k != i)
	return -1 if others.is_empty() else int(others[rng.randi() % others.size()])


## PartyTalk's answers to the hero's orders are not talk to answer.
static func _is_order_answer(text: String) -> bool:
	for pool in [PartyTalk.REGROUP_LINES, PartyTalk.HOLD_LINES, PartyTalk.HOME_LINES, PartyTalk.IN_TOWN_LINES]:
		if (pool as Array).has(text):
			return true
	return false


func _post(channel: String, speaker: String, text: String, color: Color) -> void:
	_posting = true
	Game.post_chat(channel, speaker, text, color)
	_posting = false


## A note from the game on a channel (no party, no guild...).
func _note(channel: String, text: String) -> void:
	_post(channel, NOTE_NAME, text, NOTE_COLOR)


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
	_clock += delta
	if not _timed.is_empty():
		_flush_timed()
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
		# A further answer to the same line waits its turn (typing after the first).
		if float(wait.waited) < float(wait.get("after", 0.0)):
			continue
		var raw := str(transport.call("poll", int(id)))
		if raw == "" or raw == "null":
			if float(wait.waited) - float(wait.get("after", 0.0)) > WAIT_LIMIT:
				_pending.erase(id)
				failed.emit(int(wait.index), "ไม่มีคำตอบ ลองใหม่อีกครั้งนะ")
				Game.say("ไม่มีคำตอบ ลองใหม่อีกครั้งนะ", &"warning")
			continue
		_pending.erase(id)
		var answer: Variant = JSON.parse_string(raw)
		if answer is Dictionary:
			receive(int(wait.index), answer, String(wait.channel), int(wait.get("thread", -1)))


## An answer for world player i: {reply, action} or {error, message}.
func receive(i: int, answer: Dictionary, channel := "direct", thread := -1) -> void:
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
	if channel == "party" or channel == "guild":
		_remember_in("%s|%d" % [channel, i], "player", reply)
		var g := WorldPlayers.guild_at(i, int(s.level))
		_post(channel, String(s.name), reply, WorldPlayers.GUILD_COLORS.get(g, PLAYER_COLOR))
		var mate := _field_player(i)
		if mate != null:
			mate.bubble(reply)
		_act(i, action)
		replied.emit(i, reply, action)
		if channel == "party" and Game.in_party(i):
			_follow(i, reply, thread)
		return
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


func _remember_in(key: String, who: String, text: String) -> void:
	var talk: Array = channel_history.get(key, [])
	talk.append({"who": who, "text": text})
	while talk.size() > HISTORY:
		talk.remove_at(0)
	channel_history[key] = talk


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
