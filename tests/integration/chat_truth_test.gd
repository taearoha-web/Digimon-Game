extends Node
## The world players only say true things (headless). Thousands of lines across many
## players and times: the world players' conversations (ChatThreads.make on the world,
## guild and party chats), their single lines (WorldChat.line_for) and their answers to
## the hero (ChatBrain.reply: about their gear, set, enhancing, wings, mount, how they
## are). Every claim in every line that could be said is read back and checked against
## the game for the speaker (and the opener, for an answer or a word back):
## - Lv.N / Lv.N ★M: the real level and stars (or a rule's level);
## - ★N alone, "อีก N ดาว": a rule's stars or what it really lacks to ★300;
## - +N: a + its gear really has, or one of its enhance events of the news window;
##   "<slot> +N" by that slot;
## - "ชิ้นที่ N", "N ชิ้น": its set / divine pieces or a forged piece's number;
## - "เลเวล N": its mount's level or a mount levelling of the window;
## - item, mount and wing names after ได้ / ดรอป / ขี่ / ใส่ / อัป / ทำ / หลอม: its real
##   finds, mount and wings (WorldGear events and gear);
## - field and boss names: its own hunting field / where it stands and that field's boss;
## - a God title after เป็น: only from a player at ★300;
## - guild names: its guild or one it meets in the war;
## - party sizes, failed tries, the boss respawn, the war's next round, percentages.
## A news topic (drop, enhance_ok, enhance_fail) is only opened with that news, and the
## old made-up lines never come back. The checks read WorldGear's answers, not how it
## makes them.
##   godot --headless --path . res://tests/integration/chat_truth_test.tscn
var checks := 0
var failures := 0
var lines_checked := 0
var stats := {}
var _rx := {}
var _zones: Array = []
var _bosses := {}
var _names := {}
var _gods := {}
## Phrases that were made up and must never come back.
const BANNED := ["ตายไปสามรอบ", "ฟาร์มทั้งวันไม่ได้สักชิ้น", "สามชั่วโมง", "ขาดอีก", "ห้ารอบ", "เน็ตกระตุก", "เป้าวันนี้", "เป้าอีก",
	"ซื้อไปรอบที่แล้ว", "ลดราคาช่วงนี้", "ของหายากเพิ่งได้มา", "เพิ่งเล่นได้ไม่กี่วัน", "กลางคืนคนน้อย", "ตื่นสาย", "วันนี้ดรอปไม่ค่อยดี"]
const SLOT_OF := {"อาวุธ": "weapon", "เกราะ": "armor", "หมวก": "helm", "รองเท้า": "boots"}
const VERBS := ["ได้", "ดรอป", "ขี่", "ใส่", "อัป", "ทำ", "หลอม"]
const QUESTIONS := ["ใส่อะไรอยู่", "ชุดเซตได้กี่ชิ้นแล้ว", "มีปีกไหม", "ขี่อะไรอยู่", "ตีบวกได้เท่าไหร่แล้ว", "เป็นไงบ้าง", "เลเวลเท่าไหร่", "สวัสดี", "อยู่ไหน"]


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		if failures <= 60:
			printerr("FAIL: ", message)


func _ready() -> void:
	WorldPlayers.persist = false
	WorldPlayers.clear_bonus()
	Game.new_profile(&"warrior", "ความจริงQA", FaceKit.default_look())
	Game.profile.level = 60
	_setup()
	_rules()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var threads := 0
	for day in range(2, 16):
		for hour in [11, 13, 19, 21, 23]:
			var t := float(WorldPlayers.START_UNIX) + float(day) * 86400.0 + float(hour) * 3600.0 + rng.randf() * 1800.0
			WorldPresence.clock_offset = t - WorldPlayers.now()
			var online: Array = []
			for i in WorldPlayers.size():
				var s := WorldPlayers.state(i, t)
				if bool(s.online):
					online.append(s)
			if online.size() < 2:
				continue
			threads += _threads(online, t, rng)
			_singles(online, t, rng)
			_answers(online, t, rng)
	WorldPresence.clock_offset = 0.0
	print("chat_truth_test: %d threads, %d lines checked, claims %s" % [threads, lines_checked, stats])
	check(lines_checked >= 2000, "thousands of lines checked (%d)" % lines_checked)
	for key in ["Lv", "plus", "drop", "field", "boss"]:
		check(int(stats.get(key, 0)) > 0, "lines with %s claims were checked (%d)" % [key, int(stats.get(key, 0))])
	print("CHAT TRUTH: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _setup() -> void:
	for key in {"lv": "Lv\\.(\\d+)( ★(\\d+))?", "star": "★(\\d+)", "plus": "\\+(\\d+)", "slot_plus": "(อาวุธ|เกราะ|หมวก|รองเท้า) \\+(\\d+)",
			"nth": "ชิ้นที่ (\\d+)", "pieces": "(ครบ |จาก )?(\\d+) ชิ้น", "mountlv": "เลเวล (\\d+)", "left": "อีก (\\d+) ดาว",
			"fails": "พลาด (\\d+) รอบ", "party": "ตี้(?:เรา)? (\\d+) คน", "room": "อีก (\\d+) คน", "respawn": "ราว (\\d+) นาที",
			"regmin": "ถึง (\\d+) นาทีก่อนเริ่ม", "war": "กิลด์วอรอบหน้า (\\d\\d:\\d\\d)", "pct": "([\\d.]+) เปอร์เซ็นต์", "online": "เยอะเลย (\\d+) คน"}:
		var rx := RegEx.new()
		rx.compile(String({"lv": "Lv\\.(\\d+)( ★(\\d+))?", "star": "★(\\d+)", "plus": "\\+(\\d+)", "slot_plus": "(อาวุธ|เกราะ|หมวก|รองเท้า) \\+(\\d+)",
			"nth": "ชิ้นที่ (\\d+)", "pieces": "(ครบ |จาก )?(\\d+) ชิ้น", "mountlv": "เลเวล (\\d+)", "left": "อีก (\\d+) ดาว",
			"fails": "พลาด (\\d+) รอบ", "party": "ตี้(?:เรา)? (\\d+) คน", "room": "อีก (\\d+) คน", "respawn": "ราว (\\d+) นาที",
			"regmin": "ถึง (\\d+) นาทีก่อนเริ่ม", "war": "กิลด์วอรอบหน้า (\\d\\d:\\d\\d)", "pct": "([\\d.]+) เปอร์เซ็นต์", "online": "เยอะเลย (\\d+) คน"}[key]))
		_rx[key] = rx
	ZoneData.ensure()
	for id in ZoneData.ZONES:
		var z: Dictionary = ZoneData.ZONES[id]
		var name := String(z.get("name", ""))
		if name.length() >= 3:
			_zones.append([name, StringName(id)])
		if z.has("boss"):
			var boss := String(MonsterData.get_monster(StringName(z.boss.monster)).get("name", ""))
			if boss != "":
				_bosses[boss] = StringName(id)
	_zones.sort_custom(func(a, b): return String(a[0]).length() > String(b[0]).length())
	# Names a claim may carry: every jewel, potion and gem, every mount; wings, sets and
	# finds join as WorldGear names them.
	for id in ItemData.JEWELS:
		_names[String(ItemData.JEWELS[id].name)] = true
	for id in ItemData.POTIONS:
		_names[String(ItemData.POTIONS[id].name)] = true
	for id in MountData.ORDER:
		_names[String(MountData.info(id).name)] = true
	for cls in ClassData.IDS:
		_gods[JobData.god_name(cls)] = cls


## The rules the chat states, against the game's constants.
func _rules() -> void:
	check(ItemData.enhance_chance(ChatBrain.SAFE_PLUS - 1) >= 1.0 and ItemData.enhance_chance(ChatBrain.SAFE_PLUS) < 1.0, "enhancing is sure up to +%d only" % ChatBrain.SAFE_PLUS)
	check(int(round(ItemData.enhance_chance(9) * 100.0)) == int(round(ItemData.enhance_chance(ChatBrain.SAFE_PLUS) * 100.0)), "+7 to +10 share their odds, as the help says")
	check(float(DrownedAbyssData.JEWEL_DROP.purple) > float(ItemData.JEWEL_DROP.purple) and float(DrownedAbyssData.JEWEL_DROP.chaos) > float(ItemData.JEWEL_DROP.chaos), "the abyss drops jewels more often than elsewhere")
	check(StallStock.POTION_DISCOUNT < 1.0 and StallStock.SELL_BONUS > 1.0, "stall potions are cheaper and a stall pays more than the merchant")
	check(SetGearData.BONUS.has(4) and is_equal_approx(float(SetGearData.BONUS[4].atk), float(SetGearData.BONUS[4].def)), "the 4-piece set bonus lifts attack and defence alike")
	check(JobData.TIER_COSTS.size() >= JobData.GOD_ADV, "the God step has a fee")
	var help := ChatBrain.help_text("guild")
	for at in GuildLeague.SLOTS:
		check(help.contains("%02d:%02d" % [int(at) / 3600, (int(at) % 3600) / 60]), "the guild help names the war round at %d" % at)
	check(not help.contains("ข้างสนามประลอง"), "the guild registrar is not said to stand by the arena")
	check(ChatBrain.help_text("skill").contains("ปรมาจารย์สกิล"), "skills are learned from the skill master")
	check(ChatTrade.hint({"kind": "equip", "slot": "wings"}).contains("Lv.%d" % ItemData.WING_DROP_LEVEL), "wings drop from the boss at the wing level")
	for text in ChatBrain.HELP_TOPICS.map(func(e): return ChatBrain.help_text(String(e[0]))):
		check(String(text).length() <= 160, "an explanation fits the bubble (%d: %s)" % [String(text).length(), text])


## Conversations among the online players; returns how many.
func _threads(online: Array, t: float, rng: RandomNumberGenerator) -> int:
	var made := 0
	var names: Array = online.map(func(o): return String(o.name))
	for n in 24:
		var pool := online.duplicate()
		pool.shuffle()
		var group := pool.slice(0, mini(4, pool.size()))
		var channel: String = ["world", "world", "guild", "party"][n % 4]
		var ctx := {"online": online.size(), "names": names, "t": t}
		if n % 6 == 5:
			ctx["topic"] = ["drop", "enhance_ok", "enhance_fail", "set", "mount", "wings"][rng.randi() % 6]
		var lines := ChatThreads.make(channel, group, rng, ctx)
		if lines.is_empty():
			continue
		made += 1
		var opener: Dictionary = group[0]
		var topic := String(lines[0].get("topic", ""))
		var news := ChatThreads.news(int(opener.index), t)
		if topic in ["drop", "enhance_ok", "enhance_fail"]:
			check(not (news.get(topic, {}) as Dictionary).is_empty(), "%s opens %s only with that news" % [opener.name, topic])
		if topic == "wings" and not ctx.has("topic"):
			check(not (news.get("wings_up", {}) as Dictionary).is_empty() or int((news.gear.get("wings", {}) as Dictionary).get("tier", 0)) > 0, "%s talks of wings only with wings" % opener.name)
		for k in lines.size():
			var line: Dictionary = lines[k]
			var who: Dictionary = group[int(line.who)]
			var people := [who] if int(line.who) == 0 and k == 0 else [who, opener]
			for text in line.options:
				_verify(String(text), people, t, {"online": online.size(), "topic": topic, "opener": opener})
	return made


## Single lines (WorldChat.line_for) of every online player.
func _singles(online: Array, t: float, rng: RandomNumberGenerator) -> void:
	for s in online:
		for k in 4:
			var text := WorldChat.line_for(s, rng.randi(), t)
			_verify(text, [s], t, {"single": true})


## Answers to the hero (ChatBrain.reply) about gear and how they are.
func _answers(online: Array, t: float, rng: RandomNumberGenerator) -> void:
	var hero := {"name": "ความจริงQA", "class": "นักรบ", "level": 60, "stars": 0}
	for n in mini(10, online.size()):
		var s: Dictionary = online[rng.randi() % online.size()]
		var place := String(s.place)
		var player := {"index": int(s.index), "name": String(s.name), "class": String(ClassData.get_class_data(StringName(s["class"])).get("name", "")),
			"level": int(s.level), "stars": int(s.stars), "style": "", "doing": String(s.doing),
			"place": "หมู่บ้าน" if place == "town" else String(ZoneData.get_zone(StringName(place)).get("name", "")) if place != "" else "",
			"guild": WorldPlayers.guild_name(int(s.guild)), "gender": int(s.gender), "inParty": false}
		var g: Dictionary = WorldGear.gear(int(s.index), t)
		for q in QUESTIONS:
			var said := ChatBrain.reply({"text": q, "player": player, "hero": hero, "history": [], "t": t, "channel": "direct"})
			var text := String(said.reply)
			_verify(text, [s], t, {"brain": true})
			match q:
				"ขี่อะไรอยู่":
					var m: Dictionary = g.get("mount", {})
					check(text.contains(String(m.name)) and text.contains("เลเวล %d" % int(m.level)) if not m.is_empty() else text.contains("ยังไม่มี"), "%s tells its real mount (%s: %s)" % [s.name, m, text])
				"ใส่อะไรอยู่":
					for slot in ["weapon", "armor", "helm", "boots"]:
						check(text.contains("%s +%d" % [ItemData.SLOT_NAMES[slot], int(g[slot].plus)]), "%s tells its real %s (+%d: %s)" % [s.name, slot, int(g[slot].plus), text])
				"ชุดเซตได้กี่ชิ้นแล้ว":
					check(text.contains("%d ชิ้น" % int(g.set_pieces)) if int(g.set_pieces) > 0 else text.contains("ยังไม่มี"), "%s tells its real set (%d: %s)" % [s.name, int(g.set_pieces), text])
				"มีปีกไหม":
					check(text.contains(String(g.wings.name)) if int(g.wings.tier) > 0 else text.contains("ยังไม่มี"), "%s tells its real wings (%s: %s)" % [s.name, g.wings, text])


## What a person really has, for the checks: its level, stars, gear and news.
func _facts(s: Dictionary, t: float) -> Dictionary:
	var i := int(s.get("index", -1))
	var level := int(s.get("level", 1))
	var stars := int(s.get("stars", 0)) if level >= Game.MAX_LEVEL else 0
	var g: Dictionary = WorldGear.gear(i, t)
	var ev: Array = WorldGear.events(i, t - ChatThreads.window(), t)
	var pluses := {}
	var slot_plus := {}
	for slot in ["weapon", "armor", "helm", "boots"]:
		var p := int((g.get(slot, {}) as Dictionary).get("plus", 0))
		pluses[p] = true
		slot_plus[slot] = {p: true}
	pluses[int(g.get("divine_plus", 0))] = true
	var pieces := {int(g.get("set_pieces", 0)): true, int(g.get("divine_pieces", 0)): true}
	var mount_lv := {}
	var named := {}
	var mount: Dictionary = g.get("mount", {})
	if not mount.is_empty():
		mount_lv[int(mount.level)] = true
		named[String(mount.name)] = true
	if int((g.get("wings", {}) as Dictionary).get("tier", 0)) > 0:
		named[String(g.wings.name)] = true
	named[String(g.get("set_name", ""))] = true
	var fails := 0
	var fchance := {}
	for e in ev:
		var kind := String(e.kind)
		match kind:
			"enhance_ok", "enhance_fail":
				for v in [int(e.from), int(e.to), int(e.from) + 1]:
					pluses[v] = true
					if SLOT_OF.values().has(String(e.slot)):
						(slot_plus[String(e.slot)] as Dictionary)[v] = true
				if kind == "enhance_fail":
					fails += 1
					fchance[str(int(round(ItemData.enhance_chance(int(e.from)) * 100.0)))] = true
			"set_piece", "divine_piece":
				pieces[int(e.to)] = true
			"mount_up":
				mount_lv[int(e.to)] = true
				named[String(e.item)] = true
			"wings_up", "drop":
				named[String(e.item)] = true
	for n in named.keys():
		if String(n) != "":
			_names[String(n)] = true
	var fields := {WorldPlayers.hunting_zone(level, stars): true}
	var place := StringName(s.get("place", ""))
	if place != &"" and place != &"town":
		fields[place] = true
	return {"level": level, "stars": stars, "pluses": pluses, "slot_plus": slot_plus, "pieces": pieces, "mount_lv": mount_lv,
		"named": named, "fails": fails, "fchance": fchance, "fields": fields, "guild": int(s.get("guild", 0)),
		"god": WorldPlayers.is_god({"level": level, "stars": stars}), "class": StringName(s.get("class", "")),
		"party": (s.get("party_members", []) as Array).size(), "doing": String(s.get("doing", ""))}


## Checks every claim of `text` said by people[0] (people[1]: the opener it answers).
func _verify(text: String, people: Array, t: float, ctx: Dictionary) -> void:
	lines_checked += 1
	var facts: Array = people.map(func(p): return _facts(p, t))
	var me: Dictionary = facts[0]
	var who := String(people[0].get("name", ""))
	var tag := "%s: %s" % [who, text]
	check(not text.contains("%"), "no placeholder left (%s)" % tag)
	for word in BANNED:
		check(not text.contains(word), "a made-up phrase is gone (%s)" % tag)
	var stall := String(me.doing) == "stall"
	var rule_lv := [Game.GUILD_LEVEL, Game.MAX_LEVEL, ItemData.WING_DROP_LEVEL, ClassData.LINE_LEVEL]
	for m in (_rx.lv as RegEx).search_all(text):
		_count("Lv")
		var lv := int(m.get_string(1))
		var st := int(m.get_string(3)) if m.get_string(3) != "" else 0
		var ok := facts.any(func(f): return int(f.level) == lv and int(f.stars) == st) or (st == 0 and lv in rule_lv)
		check(ok, "Lv.%d%s is the speaker's own (or a rule's) (%s)" % [lv, " ★%d" % st if st > 0 else "", tag])
	var plain := (_rx.lv as RegEx).sub(text, "", true)
	for m in (_rx.star as RegEx).search_all(plain):
		var st := int(m.get_string(1))
		check(st in [DrownedAbyssData.ENTRY_STAR, JobData.GOD_STARS, SetGearData.STARS, StarWingData.REQUIRED_STARS, ItemData.FEATHER_STARS] or facts.any(func(f): return int(f.stars) == st), "★%d is a rule's or the speaker's (%s)" % [st, tag])
	for m in (_rx.left as RegEx).search_all(text):
		check(int(m.get_string(1)) == maxi(1, JobData.GOD_STARS - int(me.stars)), "the stars it lacks are real (%s)" % tag)
	if not stall and not ChatBrain.ENHANCE.any(func(x): return text.begins_with(String(x))) and not text.contains("ต้องใช้ชิ้นชุดเทพ +%d" % ChatThreads.SET_DIVINE_PLUS):
		for m in (_rx.plus as RegEx).search_all(text):
			_count("plus")
			var v := int(m.get_string(1))
			check(facts.any(func(f): return (f.pluses as Dictionary).has(v)), "+%d is in its gear or its enhance news (%s)" % [v, tag])
		for m in (_rx.slot_plus as RegEx).search_all(text):
			var slot := String(SLOT_OF[m.get_string(1)])
			var v := int(m.get_string(2))
			check(facts.any(func(f): return ((f.slot_plus as Dictionary).get(slot, {}) as Dictionary).has(v)), "%s +%d is that slot's real + (%s)" % [slot, v, tag])
		for m in (_rx.nth as RegEx).search_all(text):
			_count("pieces")
			check(facts.any(func(f): return (f.pieces as Dictionary).has(int(m.get_string(1)))), "piece no. %s is real (%s)" % [m.get_string(1), tag])
		for m in (_rx.pieces as RegEx).search_all(text):
			var v := int(m.get_string(2))
			var rule := m.get_string(1) != "" and v in SetGearData.BONUS.keys() + [SetGearData.SLOTS.size()]
			check(rule or facts.any(func(f): return (f.pieces as Dictionary).has(v)), "%d pieces are real (%s)" % [v, tag])
		for m in (_rx.mountlv as RegEx).search_all(text):
			_count("mount")
			check(facts.any(func(f): return (f.mount_lv as Dictionary).has(int(m.get_string(1)))), "mount level %s is real (%s)" % [m.get_string(1), tag])
	for m in (_rx.fails as RegEx).search_all(text):
		check(int(m.get_string(1)) == int(me.fails) or (people.size() > 1 and int(m.get_string(1)) == int(facts[1].fails)), "the failed tries are counted (%s)" % tag)
	for m in (_rx.party as RegEx).search_all(text):
		check(int(m.get_string(1)) == int(me.party), "the party size is real (%s)" % tag)
	for m in (_rx.room as RegEx).search_all(text):
		check(int(m.get_string(1)) == WorldParties.SIZE_MAX - int(me.party), "the places left are real (%s)" % tag)
	for m in (_rx.regmin as RegEx).search_all(text):
		check(int(m.get_string(1)) == GuildLeague.REGISTER_CLOSE / 60, "the registration closes as the rules say (%s)" % tag)
	for m in (_rx.war as RegEx).search_all(text):
		check(m.get_string(1) == GuildLeague.clock_text(GuildLeague.next_slot(t)), "the next war round is the real one (%s)" % tag)
	for m in (_rx.online as RegEx).search_all(text):
		check(int(m.get_string(1)) == int(ctx.get("online", -1)), "the players online are counted (%s)" % tag)
	for m in (_rx.pct as RegEx).search_all(text):
		var allowed := {str(int(round(Game.PARTY_EXP_BONUS * 100.0))): true, str(int(round(float(SetGearData.BONUS[4].atk) * 100.0))): true,
			str(int(round(SetGearData.CRAFT_CHANCE * 100.0))): true, str(snappedf(DrownedAbyssData.SET_CORE_DROP * 100.0, 0.01)): true}
		check(allowed.has(m.get_string(1)) or facts.any(func(f): return (f.fchance as Dictionary).has(m.get_string(1))), "a percentage is the game's (%s)" % tag)
	if ctx.has("opener") and String(ctx.get("topic", "")) == "boss":
		for m in (_rx.respawn as RegEx).search_all(text):
			var o: Dictionary = ctx.opener
			var z: Dictionary = ZoneData.get_zone(WorldPlayers.hunting_zone(int(o.level), int(o.stars) if int(o.level) >= Game.MAX_LEVEL else 0))
			check(int(m.get_string(1)) == maxi(1, int(round(float(z.boss.get("respawn", 0.0)) / 60.0))), "the boss respawn is the field's (%s)" % tag)
	# Names: fields and bosses (its own), finds / mounts / wings after a claim verb.
	var rest := text
	for z in _zones:
		if rest.contains(String(z[0])):
			_count("field")
			var id: StringName = z[1]
			check(id == DrownedAbyssData.ID or id == DivineRegionData.ID or facts.any(func(f): return (f.fields as Dictionary).has(id)), "%s is the speaker's field (%s)" % [z[0], tag])
			rest = rest.replace(String(z[0]), "#")
	for boss in _bosses:
		if rest.contains(String(boss)):
			_count("boss")
			var zone: StringName = _bosses[boss]
			check(facts.any(func(f): return (f.fields as Dictionary).has(zone)), "%s is the boss of the speaker's field (%s)" % [boss, tag])
	if not stall:
		for name in _names:
			for verb in VERBS:
				if text.contains(String(verb) + String(name)) and not text.contains("ใคร" + String(verb) + String(name)) and not text.contains("ถ้า" + String(verb)):
					_count("drop" if verb in ["ได้", "ดรอป"] else "named")
					check(facts.any(func(f): return (f.named as Dictionary).has(String(name))), "%s really has %s (%s)" % [who, name, tag])
	for title in _gods:
		if text.contains("เป็น" + String(title)):
			check(bool(me.god) and _gods[title] == me["class"], "only a God says it is %s (%s)" % [title, tag])
	for g in WorldPlayers.GUILDS:
		var gname := WorldPlayers.guild_name(g)
		if text.contains(gname):
			var ok := facts.any(func(f): return int(f.guild) == g or (int(f.guild) > 0 and GuildLeague.next_rivals(int(f.guild), t).has(g)))
			check(ok, "%s is its guild or one it meets (%s)" % [gname, tag])


func _count(key: String) -> void:
	stats[key] = int(stats.get(key, 0)) + 1
