extends Node
## The world players answer anything, and only true things (headless). Hundreds of lines a
## real player might type (Thai greetings, small talk, feelings, jokes, slang and typos,
## English, questions about the player itself, about the hero's own sheet and about the
## game: monsters, bosses, fields, items, drop rates, the forge, events, the guild war,
## stalls; several questions in one line; follow-ups to the last answer) go to many world
## players at many times, as conversations with their memory (ChatBrain.reply with the
## history AiChat keeps, the topic of each answer in it). Checked:
## - every line gets a non-empty answer that fits the bubble (no number cut in half);
## - no answer repeats the player's last one word for word, the generic answers stay a
##   small share and the answers are varied;
## - every claim of every answer is true (ChatTruth.verify against the game at that time:
##   levels and stars, gear +, rides and wings, fields and where monsters live, bands,
##   drop rates, forge odds, prices, event and war times, play time, guilds);
## - named facts come back right: the player's real level and place, a boss's field and
##   respawn and loot, a monster's camp, an item's drop rate, the forge odds of a step, the
##   next war round, the hero's own gear, a keeper's real stock and prices, a typo or an
##   English name still found, a follow-up reading the last answer's name;
## - private details and real money are turned down;
## - the unprompted lines (WorldChat.line_for, the stall shouts) pass the same checks;
## - a reply takes a phone's frame budget (average and worst time).
## With CHAT_SAMPLES set, a sample transcript is written to that path.
##   godot --headless --path . res://tests/integration/chat_coverage_test.tscn
var checks := 0
var failures := 0
var replies := 0
var claims_failed := 0
var counts := {}
var times_us: Array = []
var samples: PackedStringArray = []
var hero := {}

const CORPUS := [
	# Greetings and small talk.
	"สวัสดี", "หวัดดีครับ", "ดีจ้าาา", "สวัสดีีีีค่ะ", "hi", "hello there", "yo", "อรุณสวัสดิ์", "ฝันดีนะ", "ไปก่อนนะ บาย",
	"เป็นไงบ้าง", "สบายดีมั้ย", "เหนื่อยไหม", "ทำอะไรอยู่", "ทำไรอยู่อ่ะ", "wyd", "ว่างไหม", "อากาศดีจัง", "วันนี้ฝนตก", "เบื่อจัง",
	"เศร้าอ่ะ ตีบวกแตก", "ดีใจมาก ได้ของดี", "หิวข้าว", "ง่วงแล้ว", "เล่าเรื่องตลกหน่อย", "มีมุกไหม", "555555", "ฮ่าๆๆ", "lol",
	"น่ารักจัง", "ชุดสวยจัง", "เก่งจัง", "เทพมาก", "gg", "ขอบคุณนะ", "thx", "ขอโทษนะ", "sorry", "รักนะ", "เป็นแฟนกันไหม",
	"โง่", "กากจัง", "noob", "เป็นบอทเหรอ", "are you a bot", "เป็นคนจริงไหม", "ชื่ออะไร", "what's your name",
	# Private and real money.
	"อายุเท่าไหร่", "บ้านอยู่จังหวัดไหน", "ขอเบอร์หน่อย", "ขอไลน์หน่อย", "ชื่อจริงชื่ออะไร", "ขายไอดีไหม", "ขายของเป็นเงินจริงไหม",
	# About the player.
	"เลเวลเท่าไหร่", "กี่เวลแล้ว", "lv?", "what level are you", "กี่ดาวแล้ว", "อาชีพอะไร", "เล่นสายไหน", "อยู่ไหน", "where are you",
	"อยู่แมพไหน", "ใส่อะไรอยู่", "ตีบวกได้เท่าไหร่แล้ว", "อาวุธบวกเท่าไหร่", "มีปีกไหม", "ขี่อะไรอยู่", "มีกริฟฟินไหม", "มีมังกรน้อยเพลิงยัง",
	"ฝังอัญมณีอะไร", "ชุดเซตได้กี่ชิ้น", "อยู่กิลด์ไหน", "มีสัตว์เลี้ยงไหม", "เล่นมากี่วันแล้ว", "เล่นมานานยัง", "มีฉายาไหม", "เป็นเทพเจ้ายัง",
	"ขายอะไรบ้าง", "มีอะไรขาย", "ร้านมีอะไร", "อีเว้นสัปดาห์นี้เก็บได้กี่แบบ", "ลอยกระทงไปยัง",
	# About the hero.
	"ชุดฉันสวยไหม", "ฉันเก่งไหม", "ผมเลเวลเท่าไหร่", "ดูอาวุธผมหน่อย", "ฉันอยู่กิลด์อะไร", "ฉันเล่นอาชีพอะไร", "เราเก่งกว่าไหม",
	# The game.
	"ราชาเห็ดยักษ์อยู่ไหน", "ราชาเหดยักษ์อยุ่ไหน", "where is mush king", "มังกรเพลิงผู้พิทักษ์ดรอปอะไร", "บอสป่าเงาม่วงคือใคร",
	"สไลม์ชมพูอยู่ไหน", "ฟาร์มไก่ป่าที่ไหน", "เยติอยู่ไหน", "ทุ่งหญ้ามิสต์วูดมีมอนอะไร", "ทะเลทรายตะวันเดือดเลเวลเท่าไหร่", "ภูเขาน้ำแข็งนิรันดร์มีบอสอะไร",
	"เพชรม่วงดรอปที่ไหน", "เพชรชาออสหายังไง", "ขนนกได้จากไหน", "ขนปีกกริฟฟินดรอปที่ไหน", "แก่นเทพหลอมเซตดรอปเรทเท่าไหร่",
	"ไข่มังกรฟ้าเทพดรอปกี่%", "อาวุธเทพมังกรได้จากไหน", "ยาเลือดใหญ่ราคาเท่าไหร่", "เพชรม่วงราคาเท่าไหร่", "ทับทิมหาได้ที่ไหน",
	"กริฟฟินทำยังไง", "ชุดซากุระบานได้ยังไง", "where to farm purple", "chaos drop rate?",
	"ตีบวกยังไง", "ตีบวก +10 ติดกี่%", "+13 โอกาสติดเท่าไหร่", "สุดสัปดาห์ตีบวกคืออะไร", "enhance rate +8?",
	"อีเวนต์มีตอนไหน", "ตอนนี้มีอีเว้นอะไร", "บอสโลกกี่โมง", "มอนทองคืออะไร", "เทศกาลexpเมื่อไหร่", "ล่ามังกรเริ่มเมื่อไหร่",
	"กิลด์วอรอบหน้ากี่โมง", "ใครชนะกิลด์วอ", "ปราสาทอยู่กับใคร", "ลีกสัปดาห์นี้ใครนำ",
	"อาชีพไหนเก่งสุด", "นักบวชเป็นไง", "assassin เก่งไหม", "เล่นนักเวทย์ดีไหม", "Lv 35 ไปไหนดี", "เลเวล 60 เก็บที่ไหนดี", "เก็บเลเวลที่ไหนดี",
	"กิลด์เข้ายังไง", "ปาร์ตี้ทำยังไง", "ดาวคืออะไร", "สกิลอัปที่ไหน", "ฝากขายทำไง", "เกาะลอยฟ้าเทพมังกรไปยังไง",
	"ตอนนี้คนออนกี่คน", "ราคายาเลือดเล็ก",
	# Invitations and trades.
	"ไปปาร์ตี้กันไหม", "จอยตี้หน่อย", "party?", "มากิลด์เราไหม", "เทรดของกันไหม", "ดวลกันไหม", "pvp ไหม", "มาหาหน่อย",
	# Several at once.
	"สวัสดี เลเวลเท่าไหร่ อยู่ไหน", "หวัดดี ทำอะไรอยู่ ไปตี้ไหม", "ขี่อะไร แล้วมีปีกยัง", "ราชาเห็ดยักษ์อยู่ไหน ดรอปอะไร",
	"เพชรม่วงดรอปที่ไหน แล้วตีบวก +8 ติดกี่%", "hi what level are you and where are you", "ขอบคุณนะ บาย",
	# Odd lines.
	"?", "...", "อืม", "เออ", "จริงดิ", "ทำไม", "แล้วไง", "ไม่รู้สิ", "asdfgh", "ฟหกด", "🙂", "ok", "555 ตลก", "พรุ่งนี้มาไหม",
	"ชอบเพลงอะไร", "กินอะไรยัง", "ไปเที่ยวไหนมา", "แมวน่ารัก", "ฝันร้ายเมื่อคืน", "เกมนี้สนุกไหม", "แนะนำอะไรหน่อย",
]
## Follow-ups after a question, with what the second answer must hold.
const FOLLOWS := [["ราชาเห็ดยักษ์อยู่ไหน", "ดรอปอะไร"], ["เพชรม่วงดรอปที่ไหน", "ราคาเท่าไหร่"], ["เลเวลเท่าไหร่", "ทำไม"], ["เยติอยู่ไหน", "จริงเหรอ"],
	["ขนนกได้จากไหน", "แล้วเพชรชาออสล่ะ"]]


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		if failures <= 60:
			printerr("FAIL: ", message)


func _ready() -> void:
	WorldPlayers.persist = false
	WorldPlayers.clear_bonus()
	Game.new_profile(&"mage", "คุยจริงQA", FaceKit.default_look())
	Game.profile.level = 47
	if Game.profile.equip.get("weapon") is Dictionary and not (Game.profile.equip.weapon as Dictionary).is_empty():
		Game.profile.equip.weapon["plus"] = 7
	var sheet := ChatFacts.hero_sheet()
	hero = {"name": "คุยจริงQA", "class": "นักเวทย์", "level": 47, "stars": 0, "guild": "", "gear": sheet.gear, "costume": sheet.costume}
	var t0 := Time.get_ticks_msec()
	ChatLexicon.ensure()
	ChatTruth.rules()
	print("chat_coverage_test: index built in %d ms" % (Time.get_ticks_msec() - t0))
	_lexicon()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var spoken := 0
	for day in [3, 6, 9, 13]:
		for hour in [12, 20, 23]:
			var t := float(WorldPlayers.START_UNIX) + float(day) * 86400.0 + float(hour) * 3600.0 + rng.randf() * 1800.0
			WorldPresence.clock_offset = t - WorldPlayers.now()
			var online: Array = []
			for i in WorldPlayers.size():
				var s := WorldPlayers.state(i, t)
				if bool(s.online):
					online.append(s)
			if online.is_empty():
				continue
			online.shuffle()
			# Keepers and hunters both.
			online.sort_custom(func(a, b): return String(a.doing) == "stall" and String(b.doing) != "stall")
			var keepers := online.filter(func(s): return String(s.doing) == "stall").slice(0, 2)
			var others := online.filter(func(s): return String(s.doing) != "stall").slice(0, 4)
			for s in keepers + others:
				spoken += 1
				_conversation(s, t, online.size(), rng)
				_named(s, t, online.size())
			_unprompted(online, t, rng)
	WorldPresence.clock_offset = 0.0
	var generic := 0
	for line in counts:
		if ChatMind.SMALL.any(func(x): return String(line).begins_with(String(x))) or ChatMind.UNSURE.any(func(x): return String(line).begins_with(String(x))):
			generic += int(counts[line])
	var top := 0
	for line in counts:
		top = maxi(top, int(counts[line]))
	times_us.sort()
	var avg := 0.0
	for v in times_us:
		avg += float(v)
	avg /= maxf(1.0, float(times_us.size()))
	var worst := int(times_us[times_us.size() - 1]) if not times_us.is_empty() else 0
	var p99 := int(times_us[int(times_us.size() * 0.99)]) if not times_us.is_empty() else 0
	print("chat_coverage_test: %d players, %d replies, %d distinct, generic %d, most repeated %d, claims failed %d, avg %.2f ms, p99 %.2f ms, worst %.2f ms" % [
		spoken, replies, counts.size(), generic, top, claims_failed, avg / 1000.0, p99 / 1000.0, worst / 1000.0])
	check(spoken >= 20, "many players talked to (%d)" % spoken)
	check(replies >= 5000, "thousands of replies checked (%d)" % replies)
	check(float(generic) / float(maxi(1, replies)) <= 0.12, "generic answers stay a small share (%d of %d)" % [generic, replies])
	check(avg <= 8000.0, "a reply takes well under a frame on average (%.2f ms)" % (avg / 1000.0))
	check(p99 <= 40000.0, "and almost never more than a few frames (%.2f ms)" % (p99 / 1000.0))
	var path := OS.get_environment("CHAT_SAMPLES")
	if path != "":
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(samples))
	if OS.get_environment("CHAT_TOP") != "":
		_debug_top()
	print("CHAT COVERAGE: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


## The world player's sheet as AiChat sends it.
func _player(s: Dictionary) -> Dictionary:
	var place := String(s.place)
	return {"index": int(s.index), "name": String(s.name), "class": String(ClassData.get_class_data(StringName(s["class"])).get("name", "")),
		"level": int(s.level), "stars": int(s.stars), "style": String(WorldPlayers.STYLES.get(String(s.get("voice", s.style)), {}).get("label", "")),
		"doing": String(s.doing), "place": "หมู่บ้าน" if place == "town" else String(ZoneData.get_zone(StringName(place)).get("name", "")) if place != "" else "",
		"guild": WorldPlayers.guild_name(int(s.guild)), "gender": int(s.gender), "inParty": false, "online": true}


func _ask(s: Dictionary, text: String, history: Array, t: float, online: int, channel := "direct") -> Dictionary:
	var body := {"text": text, "player": _player(s), "hero": hero, "history": history.duplicate(true), "t": t, "channel": channel, "hour": WorldEvents.time_of_day(t) / 3600}
	var t0 := Time.get_ticks_usec()
	var out := ChatBrain.reply(body)
	times_us.append(Time.get_ticks_usec() - t0)
	if OS.get_environment("CHAT_TOP") != "" and Time.get_ticks_usec() - t0 > 30000:
		print("SLOW %d ms: %s / %s" % [(Time.get_ticks_usec() - t0) / 1000, text, s.name])
	var reply := String(out.get("reply", ""))
	replies += 1
	counts[reply] = int(counts.get(reply, 0)) + 1
	check(reply.strip_edges() != "", "%s answers '%s'" % [s.name, text])
	check(reply.length() <= 160, "the answer fits the bubble (%d: %s)" % [reply.length(), reply])
	var place_name := String(body.player.place)
	var bad := ChatTruth.verify(reply, {"index": int(s.index), "t": t, "hero": hero, "place": place_name, "online": online, "said": text})
	if not bad.is_empty():
		claims_failed += 1
	check(bad.is_empty(), "%s (Lv.%d %s) to '%s': %s -> %s" % [s.name, int(s.level), String(s.doing), text, reply, bad])
	return out


func _remember(history: Array, who: String, text: String, about := {}) -> void:
	var line := {"who": who, "text": text}
	line.merge(about)
	history.append(line)
	while history.size() > AiChat.HISTORY:
		history.remove_at(0)


## The whole corpus to one player as one long talk, then the follow-ups.
func _conversation(s: Dictionary, t: float, online: int, rng: RandomNumberGenerator) -> void:
	var history: Array = []
	var last := ""
	var mine := {}
	var order := CORPUS.duplicate()
	order.shuffle()
	for k in order.size():
		var text := String(order[k])
		var out := _ask(s, text, history, t, online, ["direct", "direct", "world", "guild"][k % 4])
		var reply := String(out.reply)
		check(reply != last, "%s does not say the same twice in a row (%s)" % [s.name, reply])
		last = reply
		mine[reply] = int(mine.get(reply, 0)) + 1
		if samples.size() < 400 and rng.randf() < 0.05:
			samples.append("- **คุณ → %s** (%s Lv.%d%s · %s): %s\n  - **%s:** %s" % [s.name, _player(s)["class"], int(s.level), " ★%d" % int(s.stars) if int(s.stars) > 0 else "", String(s.doing), text, s.name, reply])
		_remember(history, "hero", text)
		var about := {}
		for key in ["topic", "slot"]:
			if out.has(key):
				about[key] = out[key]
		_remember(history, "player", reply, about)
	# Over a whole talk of the corpus no answer comes back again and again, and most differ.
	var most := 0
	for line in mine:
		most = maxi(most, int(mine[line]))
	var most_line := ""
	for line in mine:
		if int(mine[line]) == most:
			most_line = String(line)
	check(most <= 4, "%s repeats no answer in one talk (%d times: %s)" % [s.name, most, most_line])
	check(float(mine.size()) >= float(order.size()) * 0.75, "%s answers a talk with varied lines (%d of %d)" % [s.name, mine.size(), order.size()])
	for pair in FOLLOWS:
		var h: Array = []
		var first := _ask(s, String(pair[0]), h, t, online)
		_remember(h, "hero", String(pair[0]))
		_remember(h, "player", String(first.reply), {"topic": first.get("topic", ""), "slot": first.get("slot", {})})
		var second := _ask(s, String(pair[1]), h, t, online)
		check(String(second.reply) != String(first.reply), "a follow-up gets a new answer (%s / %s)" % [first.reply, second.reply])
		if samples.size() < 400 and String(pair[0]).begins_with("ราชา"):
			samples.append("- **คุณ → %s:** %s\n  - **%s:** %s\n- **คุณ:** %s\n  - **%s:** %s" % [s.name, pair[0], s.name, first.reply, pair[1], s.name, second.reply])


## Named facts come back right.
func _named(s: Dictionary, t: float, online: int) -> void:
	var i := int(s.index)
	var lv := int(s.level)
	var st := int(s.stars) if lv >= Game.MAX_LEVEL else 0
	var r := func(text: String) -> String: return String(_ask(s, text, [], t, online).reply)
	check(r.call("เลเวลเท่าไหร่").contains("Lv.%d%s" % [lv, " ★%d" % st if st > 0 else ""]), "%s tells its real level" % s.name)
	var multi: String = r.call("สวัสดี เลเวลเท่าไหร่ อยู่ไหน")
	check(multi.contains("Lv.%d" % lv), "a line of several questions gets the level too (%s)" % multi)
	var boss: String = r.call("ราชาเห็ดยักษ์อยู่ไหน")
	check(boss.contains("ทุ่งหญ้ามิสต์วูด") and boss.contains("2 นาที"), "the boss's field and respawn (%s)" % boss)
	check(String(r.call("ราชาเหดยักษอยู่ไหน")).contains("ทุ่งหญ้ามิสต์วูด"), "a boss typed wrong is still found")
	check(String(r.call("where is mush king")).contains("ทุ่งหญ้ามิสต์วูด"), "a boss named in English is found")
	check(String(r.call("สไลม์ชมพูอยู่ไหน")).contains("ลานสไลม์"), "a monster's camp")
	var purple: String = r.call("เพชรม่วงดรอปที่ไหน")
	check(purple.contains("%s%%" % ChatFacts.pct(float(ItemData.JEWEL_DROP.purple))), "the purple jewel's real rate (%s)" % purple)
	var p10: String = r.call("ตีบวก +10 ติดกี่%")
	check(p10.contains("%s%%" % ChatFacts.pct(WorldEvents.enhance_chance_at(9, t))), "the forge odds of +10 at this time (%s)" % p10)
	var war: String = r.call("กิลด์วอรอบหน้ากี่โมง")
	check(war.contains(GuildLeague.clock_text(GuildLeague.next_slot(t))), "the next war round (%s)" % war)
	var me: String = r.call("ดูอาวุธผมหน่อย")
	var hp := int((hero.gear.get("weapon", {}) as Dictionary).get("plus", 0))
	check(hp <= 0 or me.contains("+%d" % hp), "the hero's own weapon + (%s)" % me)
	for text in ["ขอเบอร์หน่อย", "บ้านอยู่จังหวัดไหน"]:
		check(ChatMind.PRIVACY.any(func(x): return String(r.call(text)).begins_with(String(x))), "private details are turned down (%s)" % text)
	check(ChatMind.MONEY.any(func(x): return String(r.call("ขายไอดีไหม")).begins_with(String(x))), "real money is turned down")
	if String(s.doing) == "stall":
		var shop := _ask(s, "มีอะไรขาย", [], t, online)
		var lots := StallStock.stock(i, t)
		if not lots.is_empty():
			check(String(shop.reply).contains(ItemData.name_of(lots[0].item)) or lots.any(func(e): return String(shop.reply).contains(ItemData.name_of(e.item))), "a keeper names its real stock (%s)" % shop.reply)
			check(String(shop.action) == "open_stall", "and opens its stall")
		else:
			check(String(shop.action) == "open_stall", "a keeper with an empty stall still opens it")
	var fu: Array = []
	var a := _ask(s, "ราชาเห็ดยักษ์อยู่ไหน", fu, t, online)
	_remember(fu, "hero", "ราชาเห็ดยักษ์อยู่ไหน")
	_remember(fu, "player", String(a.reply), {"topic": a.get("topic", ""), "slot": a.get("slot", {})})
	var loot := String(_ask(s, "ดรอปอะไร", fu, t, online).reply)
	check(loot.contains(String(ItemData.GEMS[String(BossLootData.TABLES[&"mush_king"].gem)].name)), "a follow-up reads the last answer's boss (%s)" % loot)


## The unprompted lines: what players say on their own and the stalls' shouts.
func _unprompted(online: Array, t: float, rng: RandomNumberGenerator) -> void:
	for s in online.slice(0, 20):
		for k in 3:
			var line := WorldChat.line_for(s, rng.randi(), t)
			var bad := ChatTruth.verify(line, {"index": int(s.index), "t": t, "place": String(ZoneData.get_zone(StringName(s.place)).get("name", "")) if String(s.place) not in ["", "town"] else "หมู่บ้าน"})
			check(bad.is_empty(), "%s on its own: %s -> %s" % [s.name, line, bad])
		if String(s.doing) == "stall":
			var shout := StallStock.announcement(int(s.index), t)
			if shout != "":
				var bad := ChatTruth.verify(shout, {"index": int(s.index), "t": t})
				check(bad.is_empty(), "%s's shout: %s -> %s" % [s.name, shout, bad])


## The name index: names typed right, wrong and in English are found.
func _lexicon() -> void:
	var f := func(text: String) -> Array: return ChatLexicon.find(ChatLexicon.normalize(text))
	check(f.call("ราชาเห็ดยักษ์").size() == 1 and String(f.call("ราชาเห็ดยักษ์")[0].id) == "mush_king", "an exact name")
	check(not f.call("ราชาเหดยักษ์อยู่ไหน").is_empty() and String(f.call("ราชาเหดยักษ์อยู่ไหน")[0].id) == "mush_king", "a name without its tone mark")
	check(not f.call("ขนนกกริฟฟินอยู่ไหน").is_empty(), "a name one letter off")
	check(not f.call("where is pink slime").is_empty() and String(f.call("where is pink slime")[0].id) == "pink_slime", "an English name")
	check(f.call("อากาศดีจัง").is_empty(), "small talk names nothing")
	check(ChatLexicon.normalize("สวัสดีีีีี") == "สวัสดี", "a held key is read once (%s)" % ChatLexicon.normalize("สวัสดีีีีี"))
	check(ChatLexicon.normalize("55555555").begins_with("555"), "a laugh stays a laugh")
	check(ChatLexicon.normalize("where r u lvl").contains("อยู่ไหน") and ChatLexicon.normalize("where r u lvl").contains("เลเวล"), "English is read as Thai (%s)" % ChatLexicon.normalize("where r u lvl"))
	check(ChatLexicon.normalize("where to farm").contains("ที่ไหน"), "an English word is read as Thai")


func _debug_top() -> void:
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return int(counts[a]) > int(counts[b]))
	for k in keys.slice(0, 25):
		print("TOP %d: %s" % [int(counts[k]), k])
