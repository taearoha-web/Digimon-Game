extends Node
## The party and guild chats, apart from the world chat (headless, no main scene): each
## line goes only to its channel (Game.world_chat for the world, Game.channel_chat for the
## party and guild); the HUD chat's tabs (WorldChat: ทั้งหมด / โลก / ปาร์ตี้ / กิลด์) show
## only theirs, tagged [ปาร์ตี้] / [กิลด์]; the hero's party line gets 1-2 members' answers
## (ChatBrain, about what was said), one after the other; a member's line gets another's
## answer, never more than AiChat.MAX_FOLLOW_UPS and not again within the cooldown; with
## no party or no guild a note says so; the guild's online players answer as guild mates.
##   godot --headless --path . res://tests/integration/chat_channels_test.tscn

var checks := 0
var failures := 0
var world_lines: Array = []
var channel_lines: Array = []


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	WorldPlayers.persist = false
	WorldPresence.enabled = true
	Game.new_profile(&"mage", "ช่องQA", FaceKit.default_look())
	Game.profile.level = 120
	# A time weeks into the world when a guild has players online.
	var guild := 0
	for h in 24 * 20:
		WorldPresence.clock_offset = float(WorldPlayers.START_UNIX) + 40.0 * 86400.0 + h * 3600.0 - WorldPlayers.now()
		for g in WorldPlayers.GUILD_NAMES:
			if _online_in(int(g)).size() >= 1:
				guild = int(g)
				break
		if guild != 0:
			break
	check(guild != 0, "a guild has players online")
	Game.world_chat.connect(func(speaker: String, text: String, _c: Color): world_lines.append([speaker, text]))
	Game.channel_chat.connect(func(channel: String, speaker: String, text: String, _c: Color): channel_lines.append([channel, speaker, text]))
	var box := WorldChat.new()
	add_child(box)
	var chat := AiChat.new()
	add_child(chat)
	# Time only moves when the test says so.
	chat.set_process(false)
	check(chat.transport is ChatBrain.LocalTransport, "the answers are the game's own (free, offline)")
	(chat.transport as ChatBrain.LocalTransport).delay = Vector2.ZERO
	chat.react_chance = 0.0
	chat.follow_chance = 0.0
	chat.second_chance = 0.0
	chat.stagger = Vector2(1.0, 1.0)

	# --- No party, no guild: a note on that channel, nothing sent. --------------------
	var why := chat.submit("สวัสดีทุกคน", {"index": -1, "channel": "party"})
	check(why == AiChat.NO_PARTY, "no party: the hero is told (%s)" % why)
	check(_last_channel("party") == AiChat.NO_PARTY and world_lines.is_empty(), "the note is in the party chat, not the world's")
	check(chat._pending.is_empty(), "nothing is asked without a party")
	why = chat.submit("สวัสดีชาวกิลด์", {"index": -1, "channel": "guild"})
	check(Game.guild() == 0 and why == AiChat.NO_GUILD % Game.GUILD_LEVEL, "no guild: the hero is told (%s)" % why)
	check(_last_channel("guild") == why and chat._pending.is_empty(), "the note is in the guild chat, nothing asked")

	# --- The party. ----------------------------------------------------------------------
	var t := WorldPresence.clock()
	var picks: Array[int] = []
	for i in WorldPlayers.size():
		if bool(WorldPlayers.state(i, t).online) and int(WorldPlayers.state(i, t).guild) != guild:
			picks.append(i)
		if picks.size() == 2:
			break
	check(picks.size() == 2, "two players to party with")
	if picks.size() < 2:
		_finish()
		return
	for i in picks:
		check(Game.party_invite(i, true) == "", "%s joins the party" % WorldPlayers.entry(i).name)
	var names := picks.map(func(i: int) -> String: return String(WorldPlayers.entry(i).name))

	# Routing: a world line reaches only the world chat, a party line only the party.
	world_lines.clear()
	channel_lines.clear()
	check(chat.submit("ไปตีบอสกัน", {"index": -1, "channel": "party"}) == "", "a party line is sent")
	check(world_lines.is_empty() and channel_lines.size() == 1 and channel_lines[0][0] == "party" and channel_lines[0][2] == "ไปตีบอสกัน", "the hero's party line is only in the party chat (%s / %s)" % [world_lines, channel_lines])
	var sent := (chat._pending.values() as Array)
	check(sent.size() == 1 and picks.has(int(sent[0].index)) and String(sent[0].channel) == "party", "one party member is asked (%s)" % [sent])
	chat._process(0.1)
	var answer := _replies("party", names)
	check(answer.size() == 1, "a party member answers (%s)" % [channel_lines])
	check(answer.size() == 1 and String(answer[0][2]).contains("บอส"), "the answer is about the boss (%s)" % [answer])
	check(world_lines.is_empty(), "the answer stays out of the world chat")

	# Relevance: low HP, thanks, a level question.
	for line in [["เลือดน้อยแล้ว ช่วยด้วย", ChatBrain.PARTY_LOWHP + ChatBrain.PARTY_LOWHP_PRIEST], ["ขอบคุณที่ช่วยนะ", ChatBrain.THANKS_PARTY]]:
		channel_lines.clear()
		chat.submit(String(line[0]), {"index": -1, "channel": "party"})
		chat._process(0.1)
		var got := _replies("party", names)
		check(got.size() == 1 and (line[1] as Array).any(func(x): return String(got[0][2]).contains(String(x))), "\"%s\" is answered to the point (%s)" % [line[0], got])
	channel_lines.clear()
	chat.submit("เลเวลเท่าไหร่แล้ว", {"index": -1, "channel": "party"})
	chat._process(0.1)
	var lv := _replies("party", names)
	check(lv.size() == 1 and String(lv[0][2]).contains("Lv."), "a member tells its level (%s)" % [lv])
	channel_lines.clear()
	chat.submit("สวัสดีทุกคน %s" % names[1], {"index": -1, "channel": "party"})
	var asked := (chat._pending.values() as Array)
	check(asked.size() == 2 and int(asked.filter(func(w): return float(w.after) == 0.0)[0].index) == picks[1], "to everyone: both answer, the one named first (%s)" % [asked])
	# Staggered: the second answer comes a while after the first.
	chat._process(0.1)
	check(_replies("party", names).size() == 1, "one answer at first")
	chat._process(1.0)
	var both := _replies("party", names)
	check(both.size() == 2 and both[0][1] != both[1][1], "the other member answers after a pause (%s)" % [both])
	check(both.size() == 2 and ChatBrain.PARTY_GREET.any(func(x): return String(both[0][2]) == x), "a greeting to the party is greeted back (%s)" % [both])

	# --- The members answer each other, within the cap and the cooldown. ---------------
	chat.react_chance = 1.0
	chat.follow_chance = 1.0
	chat._clock += AiChat.REACT_COOLDOWN + 1.0
	channel_lines.clear()
	# A PartyTalk line (PartyTalk._speak posts it like this).
	Game.post_chat("party", names[0], "บอสมาแล้ว ระวัง!", Color.WHITE)
	check(chat._pending.size() == 1 and int((chat._pending.values()[0] as Dictionary).index) == picks[1], "another member answers a member's line")
	Game.post_chat("party", names[0], "ตีมันส์มาก 555", Color.WHITE)
	check(chat._pending.size() == 1, "not again within the cooldown")
	for n in 10:
		chat._process(3.0)
	var chain := _replies("party", names).filter(func(r): return not ["บอสมาแล้ว ระวัง!", "ตีมันส์มาก 555"].has(String(r[2])))
	check(chain.size() == AiChat.MAX_FOLLOW_UPS, "the members' talk stops after %d answers (%s)" % [AiChat.MAX_FOLLOW_UPS, chain])
	check(chain.size() >= 1 and chain[0][1] == names[1] and String(chain[0][2]).contains("บอส"), "the answer is about the boss it saw (%s)" % [chain])
	check(chain.size() == 2 and chain[1][1] == names[0], "and the first member answers back once (%s)" % [chain])
	check(chat._pending.is_empty(), "nothing more is waiting")
	# The order answers are not talk.
	chat._clock += AiChat.REACT_COOLDOWN + 1.0
	Game.post_chat("party", names[0], PartyTalk.HOLD_LINES[0], Color.WHITE)
	check(chat._pending.is_empty(), "an answer to an order gets no answer")
	# The hero's line: both answer, then no more than the cap among them.
	channel_lines.clear()
	chat.second_chance = 1.0
	chat.submit("เมื่อกี้ดรอปของหายากด้วย", {"index": -1, "channel": "party"})
	for n in 10:
		chat._process(3.0)
	var talk := _replies("party", names)
	check(talk.size() == 2 + AiChat.MAX_FOLLOW_UPS, "the hero's line: 2 answers and at most %d more (%s)" % [AiChat.MAX_FOLLOW_UPS, talk])
	check(talk.size() >= 1 and ChatBrain.PARTY_ITEM.any(func(x): return String(talk[0][2]) == x), "about the loot (%s)" % [talk])
	check(world_lines.is_empty(), "the party's talk never reaches the world chat (%s)" % [world_lines])
	chat.react_chance = 0.0
	chat.follow_chance = 0.0
	chat.second_chance = 0.0

	# A "/g" or "/p" in front picks the channel; the world chat works as before.
	channel_lines.clear()
	world_lines.clear()
	chat.submit("/p ไปต่อกัน", {"index": -1, "channel": "world"})
	check(channel_lines.size() == 1 and channel_lines[0][0] == "party" and channel_lines[0][2] == "ไปต่อกัน" and world_lines.is_empty(), "\"/p\" sends to the party (%s)" % [channel_lines])
	chat._process(0.1)
	channel_lines.clear()
	world_lines.clear()
	check(chat.submit("มีใครไปสนามถัดไปบ้าง", {"index": -1, "channel": "world"}) == "", "a world line is sent")
	check(world_lines.size() == 1 and channel_lines.is_empty(), "the world line is only in the world chat")
	chat._process(0.1)
	check(world_lines.size() == 2 and channel_lines.is_empty(), "and answered there (%s)" % [world_lines])

	# --- The guild. ----------------------------------------------------------------------
	check(Game.join_guild(guild), "the hero joins %s" % WorldPlayers.guild_name(guild))
	var mates := chat.guild_online(guild)
	check(not mates.is_empty() and mates.all(func(i: int) -> bool: return int(WorldPlayers.state(i, WorldPresence.clock()).guild) == guild), "the guild's online players (%s)" % [mates])
	var mate_names := mates.map(func(i: int) -> String: return String(WorldPlayers.entry(i).name))
	var answered := 0
	var most := 0
	for n in 12:
		channel_lines.clear()
		world_lines.clear()
		chat.submit("สวัสดีเพื่อนกิลด์ รอบ %d" % n, {"index": -1, "channel": "guild"})
		check(channel_lines.size() >= 1 and channel_lines[0][0] == "guild" and world_lines.is_empty(), "the guild line is only in the guild chat")
		for k in 4:
			chat._process(3.0)
		var got := _replies("guild", mate_names)
		answered += got.size()
		most = maxi(most, got.size())
		check(got.all(func(r): return ChatBrain.GUILD_GREET.any(func(x): return String(r[2]) == ChatBrain._fill(x, "", {"guild": WorldPlayers.guild_name(guild)}))), "guild mates greet as guild mates (%s)" % [got])
		check(_replies("party", names).is_empty(), "the party does not hear the guild")
	check(answered > 0 and most <= 2, "0-2 guild mates answer each line (%d answers, at most %d)" % [answered, most])

	# --- The HUD's tabs. -----------------------------------------------------------------
	check(is_equal_approx(box.custom_minimum_size.y, WorldChat.HEIGHT), "the chat box keeps its height")
	check(box.tab == "all" and box.compose_channel() == "world", "ทั้งหมด types to the world chat")
	var all_lines := "\n".join(box.lines())
	check(all_lines.contains("[lb]กิลด์[rb]"), "everything shows on ทั้งหมด")
	box.set_tab("party")
	check(box.compose_channel() == "party" and box.lines().size() > 0 and Array(box.lines()).all(func(l: String) -> bool: return l.contains("[lb]ปาร์ตี้[rb]")), "ปาร์ตี้ shows only the party (%s)" % [box.lines()])
	check(box._text.get_parsed_text().contains("[ปาร์ตี้]"), "party lines read [ปาร์ตี้]")
	check(Array(box.lines()).all(func(l: String) -> bool: return l.contains(WorldChat.PARTY_COLOR.to_html(false))), "in the party's colour")
	box.set_tab("guild")
	check(box.compose_channel() == "guild" and box.lines().size() > 0 and Array(box.lines()).all(func(l: String) -> bool: return l.contains("[lb]กิลด์[rb]") and l.contains(WorldChat.GUILD_COLOR.to_html(false))), "กิลด์ shows only the guild, in orange")
	box.set_tab("world")
	check(box.compose_channel() == "world" and box.lines().size() > 0 and Array(box.lines()).all(func(l: String) -> bool: return not l.contains("[lb]")), "โลก shows only the world chat")
	Game.post_chat("party", names[0], "ไปต่อไหม?", Color.WHITE)
	check(String((box._tabs["party"] as Button).text).contains("•") and not Array(box.lines()).any(func(l: String) -> bool: return l.contains("ไปต่อไหม")), "a party line on the world tab marks the party tab, not the box")
	box.set_tab("party")
	check(not String((box._tabs["party"] as Button).text).contains("•") and box.lines()[-1].contains("ไปต่อไหม"), "the party tab shows it, and the mark goes")
	check(box.lines().size() <= WorldChat.LINES, "the box shows at most %d lines" % WorldChat.LINES)
	_finish()


func _online_in(g: int) -> Array[int]:
	var out: Array[int] = []
	var t := WorldPresence.clock()
	for i in WorldPlayers.size():
		var s := WorldPlayers.state(i, t)
		if bool(s.online) and int(s.get("guild", 0)) == g:
			out.append(i)
	return out


## The lines on `channel` said by the players in `names`, in order.
func _replies(channel: String, names: Array) -> Array:
	return channel_lines.filter(func(l): return l[0] == channel and names.has(l[1]))


func _last_channel(channel: String) -> String:
	for n in range(channel_lines.size() - 1, -1, -1):
		if channel_lines[n][0] == channel:
			return String(channel_lines[n][2])
	return ""


func _finish() -> void:
	print("CHAT CHANNELS: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
