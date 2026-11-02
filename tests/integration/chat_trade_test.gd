extends Node
## The world players talk to each other and sell through the chat (headless):
## - the chatter (WorldPresence.chat_tick, ChatThreads): busier than the old one line every
##   7 s, conversations where 1-3 others answer the opener a few seconds later, names and
##   real state in the lines (the field, its boss, the God title at ★300), never over the
##   rate cap nor two lines within MIN_GAP, no line twice; guild and party banter too;
## - buy requests (ChatTrade.parse) in several Thai phrasings, and lines that are not one;
## - a keeper who has it answers with the lot, the price and where its stall is (at most
##   three), through AiChat a few seconds after the hero's line; nobody has it: one answer
##   says so and where it comes from;
## - a stall's stock follows its keeper's level and stars (StallStock.lots_for / seller): a
##   low-level keeper never lays out high-tier gear, jewels or potions.
##   godot --headless --path . res://tests/integration/chat_trade_test.tscn
var checks := 0
var failures := 0
var said: Array = []


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _hear(who: String, text: String, color: Color) -> void:
	said.append({"who": who, "text": text, "color": color, "at": WorldPresence.chat_clock(), "channel": "world"})


func _hear_channel(channel: String, who: String, text: String, color: Color) -> void:
	said.append({"who": who, "text": text, "color": color, "at": WorldPresence.chat_clock(), "channel": channel})


func _ready() -> void:
	WorldPlayers.persist = false
	WorldPlayers.clear_bonus()
	WorldPresence.enabled = true
	Game.new_profile(&"warrior", "ผู้ซื้อQA", FaceKit.default_look())
	Game.profile.level = 60
	Game.world_chat.connect(_hear)
	Game.channel_chat.connect(_hear_channel)
	_parse()
	_stock_by_level()
	_busy_time()
	_sellers()
	_nobody()
	await _through_chat()
	_threads()
	_chatter()
	_guild_and_party()
	WorldPresence.clock_offset = 0.0
	WorldPresence.chat_clock_override = -1.0
	print("CHAT TRADE: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


## A time with many players online (and every stall kept), days into the world.
func _busy_time() -> void:
	var best := 0
	var best_t := 0.0
	for h in 24:
		var t := float(WorldPlayers.START_UNIX) + 6.0 * 86400.0 + h * 3600.0
		var n := WorldPresence.online_count(t)
		if n > best:
			best = n
			best_t = t
	WorldPresence.clock_offset = best_t - WorldPlayers.now()
	check(best >= 6, "a busy hour has players online (%d)" % best)


func _parse() -> void:
	var cases := [
		["หาซื้อเพชรม่วง", "jewel", ["purple"]],
		["ซื้อยาแดง 50 ขวด", "potion", ["hp_s", "hp_m", "hp_l", "hp_xl", "hp_war", "hp_xxl", "hp_god"]],
		["มีใครขายเพชรชมพูไหม", "jewel", ["pink"]],
		["ใครมีเพชรชาออสบ้าง", "jewel", ["chaos"]],
		["WTB chaos", "jewel", ["chaos"]],
		["ขอซื้อยาเลือดมหาเทพ", "potion", ["hp_god"]],
		["อยากได้ hp_god 10 ขวด", "potion", ["hp_god"]],
		["หาซื้อขนปีกกริฟฟิน", "jewel", ["griffin_plume"]],
		["หาซื้อแก่นเทพหลอมเซต", "jewel", ["set_core"]],
		["อยากได้ของทำมอนท์", "jewel", ["wolf_fang", "stag_antler", "griffin_plume", "drake_scale"]],
		["ใครขายยามานาบ้าง", "potion", ["mp_s", "mp_m", "mp_l", "mp_xl", "mp_xxl"]],
		["หาซื้อทับทิม", "gem", ["ruby"]],
	]
	for c in cases:
		var req := ChatTrade.parse(String(c[0]))
		check(String(req.get("kind", "")) == String(c[1]) and Array(req.get("ids", [])) == Array(c[2]), "parse '%s' -> %s %s (%s)" % [c[0], c[1], c[2], req])
	var wings := ChatTrade.parse("มีใครขายปีกไหม")
	check(String(wings.get("kind", "")) == "equip" and String(wings.get("slot", "")) == "wings", "parse 'มีใครขายปีกไหม' -> wings (%s)" % wings)
	var sword := ChatTrade.parse("อยากได้ดาบ lv 100")
	check(String(sword.get("slot", "")) == "weapon" and Array(sword.get("bases", [])) == ["sword"] and int(sword.get("level", 0)) == 100, "parse 'อยากได้ดาบ lv 100' -> a sword near Lv.100 (%s)" % sword)
	var bow := ChatTrade.parse("รับซื้อธนู")
	check(Array(bow.get("bases", [])) == ["bow"], "parse 'รับซื้อธนู' -> a bow (%s)" % bow)
	var armor := ChatTrade.parse("หาซื้อเกราะ")
	check(String(armor.get("slot", "")) == "armor", "parse 'หาซื้อเกราะ' -> armour (%s)" % armor)
	var archer := ChatTrade.parse("หาซื้ออาวุธสายธนู")
	check(String(archer.get("class", "")) == "archer" and String(archer.get("slot", "")) == "weapon", "parse 'หาซื้ออาวุธสายธนู' -> an archer's weapon (%s)" % archer)
	for text in ["สวัสดีทุกคน", "หาตี้ไปล่าบอส", "ขายเพชรม่วงราคาถูก", "ซื้ออะไรดี", "เพชรม่วงดรอปที่ไหน", ""]:
		check(ChatTrade.parse(text).is_empty(), "'%s' is not a buy request" % text)
	# A buy request matches only what it names.
	var purple := ChatTrade.parse("หาซื้อเพชรม่วง")
	check(ChatTrade.matches(purple, ItemData.jewel("purple", 3)) and not ChatTrade.matches(purple, ItemData.jewel("pink", 3)) and not ChatTrade.matches(purple, ItemData.potion("hp_s", 3)), "เพชรม่วง matches purple jewels only")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var blade := ItemData.generate(100, &"warrior", rng, 3, "weapon")
	var low_blade := ItemData.generate(40, &"warrior", rng, 3, "weapon")
	check(ChatTrade.matches(sword, blade) and not ChatTrade.matches(sword, low_blade) and not ChatTrade.matches(bow, blade), "a sword near Lv.100 matches, a Lv.40 one or a bow request does not")


func _stock_by_level() -> void:
	# Pure stock rule: a low-level keeper never lays out high-tier goods.
	var high_jewels := ["chaos", "feather", "set_core", "drake_scale", "drill", "griffin_plume"]
	for spec in StallStock.KINDS:
		for n in 60:
			var key := "Low|%s|%d" % [spec, n]
			var lots := StallStock.lots_for(key, spec, 8, 0, &"warrior")
			check(_summary(lots) == _summary(StallStock.lots_for(key, spec, 8, 0, &"warrior")), "the same stock for the same keeper and window (%s)" % key)
			for e in lots:
				var item: Dictionary = e.item
				match String(item.get("kind", "")):
					"equip":
						check(int(item.level) <= 8 and int(item.level) >= 5 and int(item.rarity) < 4 and String(item.slot) != "wings", "Lv.8 keeper: %s Lv.%d rarity %d" % [item.name, int(item.level), int(item.rarity)])
					"potion":
						check(String(item.id) in ["hp_s", "mp_s", "hp_m", "mp_m"], "Lv.8 keeper: no strong potion (%s)" % item.id)
					"jewel":
						check(not high_jewels.has(String(item.id)), "Lv.8 keeper: no high-tier jewel (%s)" % item.id)
					"gem":
						check(ItemData.gem_info(item).size == 0, "Lv.8 keeper: small gems only (%s)" % item.id)
			var mid := StallStock.lots_for(key, spec, 50, 0, &"warrior")
			for e in mid:
				var item: Dictionary = e.item
				if String(item.get("kind", "")) == "equip":
					check(int(item.level) <= 50 and int(item.level) >= 47, "Lv.50 keeper: gear of its level (Lv.%d)" % int(item.level))
				elif String(item.get("kind", "")) == "potion":
					check(not String(item.id) in ["hp_god", "hp_xxl", "mp_xxl", "hp_war"], "Lv.50 keeper: no endgame potion (%s)" % item.id)
				elif String(item.get("kind", "")) == "jewel":
					check(not String(item.id) in ["chaos", "feather", "set_core", "drake_scale"], "Lv.50 keeper: no Lv.100 jewel (%s)" % item.id)
	# A ★250 keeper has the endgame's goods somewhere among its windows.
	var seen := {}
	for n in 80:
		for e in StallStock.lots_for("Top|%d" % n, ["mixed", "jewel", "potion", "weapon"][n % 4], 100, 250, &"warrior"):
			var item: Dictionary = e.item
			var kind := String(item.get("kind", ""))
			if kind == "equip":
				check(int(item.level) <= StallStock.gear_cap(100, 250), "★250 keeper: gear up to its stars (Lv.%d)" % int(item.level))
				seen["star_gear"] = seen.get("star_gear", false) or int(item.level) > 100
				seen["wings"] = seen.get("wings", false) or String(item.slot) == "wings"
				seen["mythic"] = seen.get("mythic", false) or int(item.rarity) == 4
			elif kind == "jewel" or kind == "potion":
				seen[String(item.id)] = true
	check(bool(seen.get("star_gear", false)) and bool(seen.get("wings", false)) and bool(seen.get("mythic", false)), "a ★250 keeper lays out star gear, wings and mythic pieces (%s)" % [seen.keys()])
	check(seen.has("set_core") and seen.has("chaos") and seen.has("hp_god"), "and set cores, chaos jewels and the god potion (%s)" % [seen.keys()])
	# The real keepers early in the world are low level: their stalls follow.
	var t := float(WorldPlayers.START_UNIX) + 0.3 * 86400.0
	var keepers := 0
	for i in WorldPlayers.size():
		if not WorldPlayers.in_town_style(i):
			continue
		var who := StallStock.seller(i, t)
		check(int(who.level) < Game.MAX_LEVEL, "%s is still under Lv.100 on the first day (Lv.%d)" % [WorldPlayers.entry(i).name, int(who.level)])
		for e in StallStock.full_stock(i, t):
			var item: Dictionary = e.item
			if String(item.get("kind", "")) == "equip":
				check(int(item.level) <= int(who.level) and String(item.slot) != "wings", "%s (Lv.%d) sells %s Lv.%d" % [WorldPlayers.entry(i).name, int(who.level), item.name, int(item.level)])
			elif String(item.get("kind", "")) == "jewel":
				check(not high_jewels.has(String(item.id)), "%s (Lv.%d) has no %s" % [WorldPlayers.entry(i).name, int(who.level), item.id])
		keepers += 1
	check(keepers >= 10, "every keeper checked (%d)" % keepers)


static func _summary(lots: Array[Dictionary]) -> Array:
	return lots.map(func(e): return "%s|%s|%d|%d" % [ItemData.name_of(e.item), JSON.stringify(e.item.get("stats", {})), int(e.item.get("count", 1)), int(e.price)])


## A request some stall now has: the first jewel or potion lot of the first keeper.
func _wanted() -> Dictionary:
	var t := WorldPresence.clock()
	for i in WorldPlayers.size():
		var s := WorldPlayers.state(i, t)
		if not bool(s.online) or String(s.doing) != "stall":
			continue
		for e in StallStock.stock(i, t):
			var kind := String(e.item.get("kind", ""))
			if kind == "jewel" or kind == "potion":
				return {"text": "หาซื้อ" + ItemData.name_of(e.item), "name": ItemData.name_of(e.item)}
	return {}


func _sellers() -> void:
	var want := _wanted()
	check(not want.is_empty(), "some stall has a jewel or a potion")
	if want.is_empty():
		return
	var req := ChatTrade.parse(String(want.text))
	var found := ChatTrade.offers(req)
	check(not found.is_empty(), "the stalls that have %s are found" % want.name)
	var t := WorldPresence.clock()
	for o in found:
		var s := WorldPlayers.state(int(o.index), t)
		check(bool(s.online) and String(s.doing) == "stall", "%s keeps a stall now" % o.name)
		check((o.lots as Array).all(func(e): return ChatTrade.matches(req, e.item)), "%s's lots all match" % o.name)
	var lines := ChatTrade.answers(req, -1.0, 7, "ผู้ซื้อQA")
	check(lines.size() >= 1 and lines.size() <= ChatTrade.MAX_SELLERS and lines.size() == mini(ChatTrade.MAX_SELLERS, found.size()), "1-%d keepers answer (%d of %d)" % [ChatTrade.MAX_SELLERS, lines.size(), found.size()])
	var last := 0.0
	for k in lines.size():
		var a: Dictionary = lines[k]
		var o: Dictionary = found[k]
		var text := String(a.text)
		print("chat_trade_test: %s: %s" % [a.speaker, text])
		check(int(a.index) == int(o.index) and String(a.speaker) == String(o.name), "the keeper with it answers (%s)" % a.speaker)
		check(text.contains(String(want.name)) and text.contains(StallStock._thousands(int(o.price))), "it names the lot and its price (%s)" % text)
		check(text.contains("หมู่บ้าน") or text.contains("ลาน") or text.contains("ถนน") or text.contains("ทาง"), "it says where its stall is (%s)" % text)
		check(float(a.delay) > last and float(a.delay) < 12.0, "a few seconds after the one before (%.1f s)" % float(a.delay))
		last = float(a.delay)
	# Where words for every stall spot.
	for spot in JapanVillage.STALLS:
		check(ChatTrade.place_words(spot) != "", "a stall at %s has words" % spot)


func _nobody() -> void:
	var req := ChatTrade.parse("หาซื้อแก่นเทพหลอมเซต")
	# Nobody has it: every matching lot already bought from the stalls.
	var t := WorldPresence.clock()
	for o in ChatTrade.offers(req, t):
		for e in o.lots:
			Game.profile.flags["stall|%s|%d|%d" % [o.name, StallStock.window(int(o.index), t), int(e.k)]] = 1
	check(ChatTrade.offers(req, t).is_empty(), "no stall has a set core now")
	var lines := ChatTrade.answers(req, t, 3, "ผู้ซื้อQA")
	check(lines.size() == 1, "one answer when nobody sells it (%d)" % lines.size())
	var text := String(lines[0].text)
	print("chat_trade_test: %s: %s" % [lines[0].speaker, text])
	check(text.contains("ไม่มีใครขาย") and text.contains("แก่นเทพหลอมเซต"), "it says nobody sells it (%s)" % text)
	check(text.contains(DrownedAbyssData.TITLE), "and where it drops (%s)" % text)
	var who := int(lines[0].index)
	check(who < 0 or (bool(WorldPlayers.state(who, t).online) and String(WorldPlayers.state(who, t).doing) != "stall"), "said by an online player who keeps no stall, or the system")


func _through_chat() -> void:
	var chat := AiChat.new()
	add_child(chat)
	await get_tree().process_frame
	var want := _wanted()
	said.clear()
	var why := chat.submit(String(want.get("text", "หาซื้อเพชรม่วง")), {"index": -1, "channel": "world"})
	check(why == "" and said.size() == 1 and String(said[0].who) == "ผู้ซื้อQA", "the hero's buy request is in the world chat (%s)" % [said])
	check(not chat.last_trade.is_empty() and chat.timed_count() >= 1, "it is read as a buy request and answers are coming (%d)" % chat.timed_count())
	chat._process(0.5)
	check(said.size() == 1, "nobody answers in the same instant")
	for n in 30:
		chat._process(0.5)
	check(said.size() >= 2 and said.size() <= 1 + ChatTrade.MAX_SELLERS and chat.timed_count() == 0, "the keepers answer within seconds (%d lines)" % (said.size() - 1))
	for k in range(1, said.size()):
		check(said[k].color == ChatTrade.SELLER_COLOR and WorldPlayers.index_of(String(said[k].who)) >= 0 and String(said[k].text).contains(String(want.get("name", ""))), "a keeper's answer: %s: %s" % [said[k].who, said[k].text])
	# Not a buy request: the usual answer (ChatBrain), not the stalls.
	said.clear()
	chat.last_trade = {}
	chat.submit("สวัสดีทุกคน", {"index": -1, "channel": "world"})
	check(chat.last_trade.is_empty(), "a greeting is not a buy request")
	chat.queue_free()
	await get_tree().process_frame


func _threads() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var t := WorldPresence.clock()
	var people: Array = []
	for i in WorldPlayers.size():
		var s := WorldPlayers.state(i, t)
		if bool(s.online):
			people.append(s)
	check(people.size() >= 4, "players online for the conversations (%d)" % people.size())
	var replies := {}
	var backs := 0
	for n in 200:
		people.shuffle()
		var group := people.slice(0, 4)
		var lines := ChatThreads.make("world", group, rng, {"online": people.size(), "names": ["Kaito"]})
		check(lines.size() >= 2 and int(lines[0].who) == 0, "a conversation has an opener and answers")
		var answers := 0
		for k in range(1, lines.size()):
			var line: Dictionary = lines[k]
			check(float(line.delay) >= ChatThreads.GAP.x and float(line.delay) <= ChatThreads.GAP.y, "an answer comes a few seconds later (%.1f)" % float(line.delay))
			check((line.options as Array).size() > 0 and (line.options as Array).all(func(x): return not String(x).contains("%")), "no placeholder left (%s)" % [line.options])
			if int(line.who) != 0:
				answers += 1
			else:
				backs += 1
		replies[answers] = int(replies.get(answers, 0)) + 1
	print("chat_trade_test: answers per conversation %s, %d words back" % [replies, backs])
	check(replies.has(1) and replies.has(2) and replies.has(3) and not replies.has(0), "1 to 3 answer a line (%s)" % [replies])
	check(backs > 40, "the opener often answers back (%d of 200)" % backs)
	# The lines carry real state: the opener's field and its boss, the God title, names.
	var hunter := {"name": "QA_Hunter", "index": 0, "level": 30, "stars": 0, "class": "archer", "guild": 0, "style": "regular", "place": &""}
	var field_id := WorldPlayers.hunting_zone(30, 0)
	var boss := String(MonsterData.get_monster(StringName(ZoneData.get_zone(field_id).boss.monster)).name)
	var lines := ChatThreads.make("world", [hunter, {"name": "QA_Friend", "index": 1, "level": 32}], rng, {"topic": "boss"})
	check((lines[0].options as Array).any(func(x): return String(x).contains(boss)), "a boss line names the field's real boss (%s: %s)" % [boss, lines[0].options])
	check(String(lines[1].options[0]) != "" and (lines[1].options as Array).any(func(x): return not String(x).contains("%")), "the answer is filled")
	var god := {"name": "QA_God", "index": 2, "level": 100, "stars": 300, "class": "darklord", "guild": 1, "style": "hardcore"}
	lines = ChatThreads.make("world", [god, hunter], rng, {"topic": "god_done"})
	check((lines[0].options as Array).any(func(x): return String(x).contains(JobData.god_name(&"darklord"))), "a ★300 player talks of being %s (%s)" % [JobData.god_name(&"darklord"), lines[0].options])
	var picked := {}
	for n in 300:
		picked[ChatThreads.topic_for("world", god, rng)] = true
		check(ChatThreads.topic_for("world", hunter, rng) not in ["god_done", "abyss", "set"], "a Lv.30 player does not talk of the endgame")
	check(picked.has("god_done") and picked.has("abyss") and picked.has("set") and picked.has("war"), "a ★300 guild member talks of its God step, the abyss, the set and the war (%s)" % [picked.keys()])
	lines = ChatThreads.make("world", [hunter, god], rng, {"topic": "party"})
	check((lines[1].options as Array).any(func(x): return String(x).contains("QA_Hunter")), "an answer names who it answers (%s)" % [lines[1].options])


func _chatter() -> void:
	WorldPresence._said.clear()
	WorldPresence.chat_clock_override = 10000.0
	var presence := WorldPresence.new()
	var t := WorldPresence.clock()
	for i in WorldPlayers.size():
		var s := WorldPlayers.state(i, t)
		if bool(s.online):
			presence._online.append(s)
	said.clear()
	var minutes := 10.0
	var step := 0.25
	for n in int(minutes * 60.0 / step):
		WorldPresence.chat_clock_override += step
		presence.chat_tick(step)
	var world := said.filter(func(x): return String(x.channel) == "world")
	var per_minute := float(world.size()) / minutes
	print("chat_trade_test: %.1f world lines a minute (was %.1f), cap %d" % [per_minute, 60.0 / 7.0, WorldPresence.RATE_CAP])
	for x in world.slice(0, 14):
		print("  %s: %s" % [x.who, x.text])
	check(per_minute >= 12.0, "the chat is busier than one line every 7 s (%.1f a minute)" % per_minute)
	check(per_minute <= float(WorldPresence.RATE_CAP), "never over the cap (%.1f a minute)" % per_minute)
	var worst := 0
	var close := 0
	var answered := 0
	var repeats := 0
	for k in world.size():
		repeats += world.slice(0, k).filter(func(x): return String(x.text) == String(world[k].text) and float(world[k].at) - float(x.at) <= WorldPresence.REPEAT_WINDOW).size()
		var inside := world.filter(func(x): return float(x.at) > float(world[k].at) - WorldPresence.RATE_WINDOW and float(x.at) <= float(world[k].at)).size()
		worst = maxi(worst, inside)
		if k > 0:
			var gap := float(world[k].at) - float(world[k - 1].at)
			close += 1 if gap < WorldPresence.MIN_GAP - 0.01 else 0
			if gap < 4.5 and String(world[k].who) != String(world[k - 1].who):
				answered += 1
	check(worst <= WorldPresence.RATE_CAP, "at most %d lines in any minute (%d)" % [WorldPresence.RATE_CAP, worst])
	check(close == 0, "never two lines within %.1f s (%d)" % [WorldPresence.MIN_GAP, close])
	check(repeats == 0, "no line twice within %d s (%d repeats of %d lines)" % [int(WorldPresence.REPEAT_WINDOW), repeats, world.size()])
	check(answered >= world.size() / 4, "many lines are answers seconds later from someone else (%d of %d)" % [answered, world.size()])
	var named := world.filter(func(x): return presence._online.any(func(o): return String(o.name) != String(x.who) and String(x.text).contains(String(o.name))))
	check(named.size() >= 5, "players name each other (%d lines)" % named.size())
	# The hero speaks: the players hold their talk a moment.
	presence._quiet_until = WorldPresence.chat_clock() + WorldPresence.HERO_QUIET
	presence._queue.clear()
	var before := said.size()
	presence.chat_once()
	check(said.size() == before, "quiet right after the hero speaks")
	presence.free()


func _guild_and_party() -> void:
	WorldPresence._said.clear()
	var presence := WorldPresence.new()
	var t := WorldPresence.clock()
	var by_guild := {}
	for i in WorldPlayers.size():
		var s := WorldPlayers.state(i, t)
		if bool(s.online):
			presence._online.append(s)
			by_guild[int(s.guild)] = int(by_guild.get(int(s.guild), 0)) + 1
	var g := WorldPlayers.ALPHA if int(by_guild.get(WorldPlayers.ALPHA, 0)) >= int(by_guild.get(WorldPlayers.NEVERDIE, 0)) else WorldPlayers.NEVERDIE
	Game.profile.level = 100
	Game.profile.flags[Game.GUILD_FLAG] = g
	said.clear()
	var ok := false
	for n in 10:
		ok = presence.guild_once() or ok
		for k in 40:
			WorldPresence.chat_clock_override += 0.5
			presence.chat_tick(0.0)
	var guild := said.filter(func(x): return String(x.channel) == "guild")
	for x in guild.slice(0, 6):
		print("  [guild] %s: %s" % [x.who, x.text])
	check(int(by_guild.get(g, 0)) == 0 or (ok and guild.size() >= 2), "guild mates talk in the guild chat (%d lines)" % guild.size())
	check(guild.all(func(x): return WorldPlayers.guild_at(WorldPlayers.index_of(String(x.who)), 100) == g or int(WorldPlayers.state(WorldPlayers.index_of(String(x.who)), t).guild) == g), "only the hero's guild mates (%s)" % [guild.map(func(x): return x.who)])
	Game.profile.flags.erase(Game.GUILD_FLAG)
	# Party members banter among themselves now and then.
	var members: Array[int] = []
	for s in presence._online:
		if members.size() < 2:
			members.append(int(s.index))
	Game.world_party.assign(members)
	said.clear()
	WorldPresence.chat_clock_override += 100.0
	ok = presence.party_once()
	for k in 40:
		WorldPresence.chat_clock_override += 0.5
		presence.chat_tick(0.0)
	var party := said.filter(func(x): return String(x.channel) == "party")
	for x in party:
		print("  [party] %s: %s" % [x.who, x.text])
	check(ok and party.size() >= 1 and party.all(func(x): return members.has(WorldPlayers.index_of(String(x.who)))), "party members talk in the party chat (%s)" % [party.map(func(x): return "%s: %s" % [x.who, x.text])])
	Game.world_party.clear()
	presence.free()
