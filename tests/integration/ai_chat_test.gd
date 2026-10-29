extends Node
## Talking to the world players (AiChat) without the web page or the server: a stand-in
## transport records what would be sent to the account server and answers like it. The
## request carries who the player is and the talk so far, the answer shows in the world
## chat, its action goes through the game's own party rules, errors and silence are told.

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


## Records sends; answers each id with what `answers` holds for it (none = still waiting).
class FakeTransport:
	extends RefCounted
	var sent: Array = []
	var answers := {}

	func send(json: String) -> int:
		sent.append(JSON.parse_string(json))
		return sent.size()

	func poll(id: int) -> String:
		if not answers.has(id):
			return ""
		var value: String = answers[id]
		answers.erase(id)
		return value


func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	WorldPlayers.persist = false
	WorldPresence.enabled = true
	WorldPresence.clock_offset = float(WorldPlayers.START_UNIX) + 2.4 * 86400.0 - WorldPlayers.now()
	Game.new_profile(&"mage", "แชทQA", FaceKit.default_look())
	var t := WorldPresence.clock()
	# An online player to talk to; the hero at its level so a stranger may join.
	var target := -1
	for i in WorldPlayers.size():
		var s := WorldPlayers.state(i, t)
		if bool(s.online) and int(s.guild) == 0:
			target = i
			break
	check(target >= 0, "someone is online to talk to")
	if target < 0:
		_finish()
		return
	var st := WorldPlayers.state(target, t)
	Game.profile.level = int(st.level)
	var lines: Array = []
	Game.world_chat.connect(func(speaker: String, text: String, _c: Color): lines.append([speaker, text]))
	var chat := AiChat.new()
	add_child(chat)
	# The game's own answers (ChatBrain): free and offline, after a short pause.
	check(chat.transport is ChatBrain.LocalTransport, "the chat answers in the game by default")
	(chat.transport as ChatBrain.LocalTransport).delay = Vector2.ZERO
	var local := []
	var on_local := func(i: int, text: String, action: String): local.append([i, text, action])
	chat.replied.connect(on_local)
	check(chat.submit("สวัสดี", {"index": target, "channel": "direct"}) == "", "a line is sent to the game's own answers")
	await get_tree().process_frame
	chat._process(0.1)
	check(local.size() == 1 and String(local[0][1]) != "" and String(local[0][2]) == "none", "a greeting is answered (%s)" % str(local))
	chat.replied.disconnect(on_local)
	chat.history.clear()
	var fake := FakeTransport.new()
	chat.transport = fake
	lines.clear()
	# A direct line: what is sent, and the world chat shows it.
	check(chat.submit("ไปปาร์ตี้กันไหม", {"index": target, "channel": "direct"}) == "", "a direct line is sent")
	check(fake.sent.size() == 1, "one request (%d)" % fake.sent.size())
	var body: Dictionary = fake.sent[0]
	check(String(body.text) == "ไปปาร์ตี้กันไหม" and String(body.channel) == "direct", "the line and channel are sent")
	check(String(body.player.name) == String(st.name) and int(body.player.level) == int(st.level), "the player is described (%s)" % JSON.stringify(body.player))
	check(String(body.player.class) != "" and String(body.player.style) != "", "with its class and play style")
	check(String(body.hero.name) == "แชทQA" and int(body.hero.level) == int(st.level), "and the hero (%s)" % JSON.stringify(body.hero))
	check((body.history as Array).is_empty(), "the first line has no history")
	check(lines.size() == 1 and String(lines[0][1]).contains("ไปปาร์ตี้กันไหม"), "the hero's line shows in the world chat (%s)" % str(lines))
	# The answer: shown, remembered, and the player joins through the party rules.
	var got := []
	chat.replied.connect(func(i: int, text: String, action: String): got.append([i, text, action]))
	fake.answers[1] = JSON.stringify({"reply": "ได้เลย ไปล่าด้วยกัน!", "action": "join_party"})
	chat._process(0.1)
	check(got.size() == 1 and int(got[0][0]) == target and String(got[0][2]) == "join_party", "the answer arrives (%s)" % str(got))
	check(Game.in_party(target), "the player joined the hero's party")
	check(lines.size() == 2 and String(lines[1][1]) == "ได้เลย ไปล่าด้วยกัน!", "the answer shows in the world chat (%s)" % str(lines))
	# The next line carries the talk so far, and the party is told.
	chat.submit("ขอบคุณนะ ไปก่อนนะ", {"index": target, "channel": "direct"})
	var second: Dictionary = fake.sent[1]
	check((second.history as Array).size() == 2 and String(second.history[0].who) == "hero" and String(second.history[1].who) == "player", "the talk so far is sent (%s)" % JSON.stringify(second.history))
	check(String(second.player.doing) == "party" and bool(second.player.inParty), "a party member is told it is in the party")
	fake.answers[2] = JSON.stringify({"reply": "ไว้เจอกันนะ", "action": "leave_party"})
	chat._process(0.1)
	check(not Game.in_party(target), "a goodbye lets the player leave")
	# A refused or failed answer is told, nothing else happens.
	var fails := []
	chat.failed.connect(func(i: int, message: String): fails.append([i, message]))
	chat.submit("สวัสดีอีกที", {"index": target, "channel": "direct"})
	fake.answers[3] = JSON.stringify({"error": "too_many_messages", "message": "คุยเร็วไปหน่อย"})
	chat._process(0.1)
	check(fails.size() == 1 and String(fails[0][1]) == "คุยเร็วไปหน่อย", "an error is told (%s)" % str(fails))
	# Silence: given up after the wait limit.
	chat.submit("มีใครอยู่ไหม", {"index": target, "channel": "direct"})
	chat._process(AiChat.WAIT_LIMIT + 1.0)
	check(fails.size() == 2, "no answer in time is told")
	# The world chat: a player named in the line answers, otherwise someone near the level.
	check(chat.responder("%s อยู่ไหน" % st.name) == target, "a named player answers in the world chat")
	var someone := chat.responder("มีใครไปสนามถัดไปบ้าง")
	check(someone >= 0 and bool(WorldPlayers.state(someone, t).online), "someone online answers an open line")
	chat.submit("มีใครไปสนามถัดไปบ้าง", {"index": -1, "channel": "world"})
	var world: Dictionary = fake.sent[-1]
	check(String(world.channel) == "world", "a world line goes out as one")
	# The game's own answers read what a line is after.
	var hunter := {"name": "Kaito", "class": "สายดาบ", "level": 20, "stars": 0, "doing": "hunt", "place": "ป่าเงาม่วง", "guild": "", "inParty": false}
	var seller := hunter.duplicate()
	seller["doing"] = "stall"
	var hero := {"name": "แชทQA", "class": "นักเวทย์", "level": 9, "stars": 0}
	var ask := func(text: String, who: Dictionary) -> Dictionary:
		return ChatBrain.reply({"text": text, "player": who, "hero": hero, "history": []})
	check(String(ask.call("ไปปาร์ตี้กันไหม", hunter).action) == "join_party", "a hunter agrees to party")
	check(String(ask.call("ไปปาร์ตี้กันไหม", seller).action) == "none", "a stall keeper stays at its stall")
	check(String(ask.call("มีอะไรขายบ้าง", seller).action) == "open_stall", "a stall keeper opens its stall")
	check(String(ask.call("มีอะไรขายบ้าง", hunter).action) == "none", "a hunter has no stall")
	var mate := hunter.duplicate()
	mate["inParty"] = true
	check(String(ask.call("บาย ไปก่อนนะ", mate).action) == "leave_party", "a goodbye lets a member leave")
	check(String(ask.call("ไปปาร์ตี้ไหม", mate).action) == "none", "a member is already in the party")
	check(String(ask.call("เลเวลเท่าไหร่แล้ว", hunter).reply).contains("Lv.20"), "a player tells its level")
	var fit := String(ZoneData.get_zone(WorldPlayers.hunting_zone(9, 0)).get("name", ""))
	check(fit != "" and String(ask.call("เก็บเลเวลที่ไหนดี", hunter).reply).contains(fit), "where to hunt names the field for the hero's level (%s)" % fit)
	check(String(ask.call("เป็นบอทเหรอ", hunter).reply).contains("AI"), "a player says it is one of the game's AI players")
	check(String(ask.call("อากาศดีจัง", hunter).reply) != "", "anything else gets small talk")
	# Long lines are cut before they leave.
	chat.submit("ก".repeat(500), {"index": target, "channel": "direct"})
	check(String((fake.sent[-1] as Dictionary).text).length() == 200, "a long line is cut to 200 characters")
	_finish()


func _finish() -> void:
	print("AI CHAT: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
