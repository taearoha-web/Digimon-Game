class_name ChatTruth
extends RefCounted
## Checks that what a world player says is true, against the game at that moment: every
## claim a line can carry is read back and compared with the speaker's own sheet
## (WorldPlayers, WorldGear and its news window, its stall's real stock), the hero's
## public sheet, and the game's tables (fields and camps and their levels, field bosses,
## drop rates, forge odds, event and guild-war times, stall prices). The facts here are
## worked out on their own, not taken from the answer that is checked.
##
## verify(text, ctx) -> the problems found ([] = every claim holds). ctx: {index (the
## speaker, -1 none), t (real time), hero ({level, stars, guild, class, gear}), place
## (the zone name it stands in, as the chat says it), online (players online)}.
## Used by the game on every answer that did not come from its own brain (the optional
## cloud chat, ChatCloud: a reply with a problem is never shown) and by the tests on
## every answer of its own brain (chat_coverage_test).

static var _rules := {}
static var _rx := {}


static func _re(key: String, pattern: String) -> RegEx:
	if not _rx.has(key):
		var r := RegEx.new()
		r.compile(pattern)
		_rx[key] = r
	return _rx[key]


## The game's own numbers a line may state whoever says it (built once).
static func rules() -> Dictionary:
	if not _rules.is_empty():
		return _rules
	ChatLexicon.ensure()
	var levels := {}
	var bands := {}
	for v in [Game.GUILD_LEVEL, Game.MAX_LEVEL, ItemData.WING_DROP_LEVEL, 1]:
		levels[int(v)] = true
	ZoneData.ensure()
	for zid in ZoneData.ZONES:
		var z: Dictionary = ZoneData.ZONES[zid]
		for b in [z.get("level", [])] + (z.get("camps", []) as Array).map(func(c): return c.get("levels", [])):
			if b is Array and (b as Array).size() >= 2:
				levels[int(b[0])] = true
				levels[int(b[1])] = true
				bands["%d-%d" % [int(b[0]), int(b[1])]] = true
		if z.has("boss"):
			levels[int(z.boss.get("level", 0))] = true
	var stars := {}
	for v in [SkyIsleData.ENTRY_STAR, DrownedAbyssData.ENTRY_STAR, JobData.GOD_STARS, SetGearData.STARS, StarWingData.REQUIRED_STARS, ItemData.FEATHER_STARS, EndgameFields.ENTRY_STAR, Game.PARAGON_MAX]:
		stars[int(v)] = true
	for zid in ZoneData.ZONES:
		if int(ZoneData.ZONES[zid].get("star", 0)) > 0:
			stars[int(ZoneData.ZONES[zid].star)] = true
	var rates: Array = [Game.PARTY_EXP_BONUS, float(SetGearData.BONUS[4].atk), SetGearData.CRAFT_CHANCE, StarWingData.CRAFT_CHANCE,
		EndgameFields.SET_CORE_DROP, EndgameFields.SCALE_NORMAL, EndgameFields.SCALE_ELITE, SkyIsleLoot.WEAPON_DROP, SkyIsleLoot.WING_DROP,
		SkyIsleLoot.FRAGMENT_DROP, SkyIsleLoot.EGG_DROP, SkyIsleLoot.CHEST_NORMAL, SkyIsleLoot.CHEST_ELITE, WorldEvents.HALLOWEEN_DROP,
		WorldEvents.WEEKEND_GOLD - 1.0, WorldEvents.FORGE_BONUS, WorldEvents.FORGE_CAP, WorldEvents.GOLDEN_CHAOS, WorldEvents.GOLDEN_GEM]
	for k in ItemData.JEWEL_DROP:
		rates.append(float(ItemData.JEWEL_DROP[k]))
	for k in EndgameFields.JEWEL_DROP:
		rates.append(float(EndgameFields.JEWEL_DROP[k]))
	for n in range(1, 8):
		rates.append(ItemData.FEATHER_DROP * float(n))
	for id in MountData.ALL:
		rates.append(float(MountData.info(id).drop))
		rates.append(MountData.chance(id))
	for p in ItemData.MAX_PLUS + 1:
		rates.append(ItemData.enhance_chance(p))
		rates.append(minf(WorldEvents.FORGE_CAP, ItemData.enhance_chance(p) + WorldEvents.FORGE_BONUS))
	for bid in BossLootData.TABLES:
		for c in BossLootData.TABLES[bid].chase:
			rates.append(float(c.base))
	for c in ItemData.GEM_FUSE_CHANCE:
		rates.append(float(c))
	var pcts := {}
	for r in rates:
		for s in [ChatFacts.pct(float(r)), IsleLuck.percent(float(r)), str(int(round(float(r) * 100.0)))]:
			pcts[String(s)] = true
	var prices := {WorldEvents.GOLDEN_GOLD: true}
	for id in ItemData.POTIONS:
		prices[int(ItemData.POTIONS[id].price)] = true
	_rules = {"levels": levels, "bands": bands, "stars": stars, "pcts": pcts, "prices": prices}
	return _rules


## Times of day (HH:MM) a line may name at time t: the events, the guild war rounds, the
## rare dragon's windows and the dates the event screens show.
static func times(t: float) -> Dictionary:
	var out := {}
	for s in [WorldEvents.EXP_START, WorldEvents.EXP_END, WorldEvents.BOSS_START, WorldEvents.BOSS_START + WorldEvents.BOSS_LENGTH]:
		out["%02d:%02d" % [int(s) / 3600, (int(s) % 3600) / 60]] = true
	for at in GuildLeague.SLOTS:
		out["%02d:%02d" % [int(at) / 3600, (int(at) % 3600) / 60]] = true
	out[GuildLeague.clock_text(GuildLeague.next_slot(t))] = true
	var day := WorldEvents.day_of(t)
	for d in [day, day + 1]:
		for w in WorldEvents.rare_windows(d):
			var s := WorldEvents.time_of_day(float(w))
			out["%02d:%02d" % [s / 3600, (s % 3600) / 60]] = true
	var dates: Array = [DragonHunt.date_text(DragonHunt.next_start(t)), DragonHunt.date_text(DragonHunt.end_of(DragonHunt.index(t))),
		DragonHunt.date_text(float(WorldEvents.FESTIVAL_END)), DragonHunt.date_text(float(WorldEvents.FESTIVAL5_START)), DragonHunt.date_text(float(WorldEvents.FESTIVAL5_END)),
		DragonHunt.date_text(float(WorldEvents.FESTIVAL3_START)), DragonHunt.date_text(float(WorldEvents.FESTIVAL3_END)),
		LoyKrathong.chat_answer(-1, t), WeeklyCollect.chat_answer(-1, t), ChatBrain.help_text("events")]
	for d in dates:
		for m in _re("hhmm", "(\\d\\d):(\\d\\d)").search_all(String(d)):
			out[m.get_string(0)] = true
	return out


## What the speaker (world player i) really is and has at time t.
static func speaker(i: int, t: float) -> Dictionary:
	if i < 0 or i >= WorldPlayers.size():
		return {}
	var s := WorldPlayers.state(i, t)
	var level := int(s.level)
	var stars := int(s.stars) if level >= Game.MAX_LEVEL else 0
	var g: Dictionary = WorldGear.gear(i, t)
	var pluses := {0: true}
	for slot in ["weapon", "armor", "helm", "boots", "wings"]:
		pluses[int((g.get(slot, {}) as Dictionary).get("plus", 0))] = true
	pluses[int(g.get("divine_plus", 0))] = true
	var owned := {}
	var mount: Dictionary = g.get("mount", {})
	if not mount.is_empty():
		owned[String(mount.name)] = int(mount.get("level", 1))
	var wings: Dictionary = g.get("wings", {})
	if int(wings.get("tier", 0)) > 0:
		owned[String(wings.name)] = 0
	var pieces := {int(g.get("set_pieces", 0)): true, int(g.get("divine_pieces", 0)): true}
	for e in WorldGear.events(i, t - ChatThreads.window(), t):
		for v in [int(e.get("from", 0)), int(e.get("to", 0)), int(e.get("from", 0)) + 1]:
			pluses[v] = true
		if String(e.kind) in ["set_piece", "divine_piece"]:
			pieces[int(e.to)] = true
		if String(e.get("item", "")) != "":
			owned[String(e.item)] = int(e.get("to", 0))
	var prices := {}
	var lot_plus := {}
	if String(s.doing) == "stall":
		for e in StallStock.stock(i, t):
			prices[int(e.price)] = true
			lot_plus[int(e.item.get("plus", 0))] = true
	var place := StringName(s.place)
	var fields := {WorldPlayers.hunting_zone(level, stars): true}
	if place != &"" and place != &"town":
		fields[place] = true
	return {"level": level, "stars": stars, "pluses": pluses, "owned": owned, "pieces": pieces, "prices": prices, "lot_plus": lot_plus,
		"guild": WorldPlayers.guild_name(int(s.guild)), "place": place, "fields": fields, "doing": String(s.doing),
		"god": WorldPlayers.is_god({"level": level, "stars": stars}), "class": StringName(s["class"]),
		"played": int(WorldPlayers.played_minutes(i, t) / 60.0), "days": int((t - WorldPlayers.joined_at(i)) / 86400.0)}


## The problems with `text` said by ctx.index at ctx.t ([] when every claim holds).
static func verify(text: String, ctx: Dictionary) -> Array[String]:
	var bad: Array[String] = []
	var t := float(ctx.get("t", WorldPresence.clock()))
	var i := int(ctx.get("index", -1))
	var me := speaker(i, t)
	var hero: Dictionary = ctx.get("hero", {})
	var R := rules()
	if text.contains("%s") or text.contains("%d") or _re("ph", "%[a-z]").search(text) != null:
		bad.append("a placeholder is left")
	var hero_lv := int(hero.get("level", -1))
	var hero_st := int(hero.get("stars", 0))
	var stall_text := String(me.get("doing", "")) == "stall" or text.contains("ทอง")
	# Levels and stars.
	for m in _re("band", "Lv\\.(\\d+)-(\\d+)").search_all(text):
		if not (R.bands as Dictionary).has("%s-%s" % [m.get_string(1), m.get_string(2)]):
			bad.append("Lv.%s-%s is no field's band" % [m.get_string(1), m.get_string(2)])
	for m in _re("lv", "Lv\\.(\\d++)(?!-)( ★(\\d+))?").search_all(text):
		var lv := int(m.get_string(1))
		var st := int(m.get_string(3)) if m.get_string(3) != "" else 0
		var own := not me.is_empty() and int(me.level) == lv and int(me.stars) == st
		var his := hero_lv == lv and (st == 0 or hero_st == st)
		var told := ctx.has("said") and String(ctx.said).contains(str(lv))
		if not (own or his or told or (st == 0 and (R.levels as Dictionary).has(lv)) or (st > 0 and lv == Game.MAX_LEVEL and (R.stars as Dictionary).has(st))):
			bad.append("Lv.%d%s is nobody's here" % [lv, " ★%d" % st if st > 0 else ""])
	var no_lv := _re("lvall", "Lv\\.\\d+(-\\d+)?( ★\\d+)?").sub(text, "", true)
	for m in _re("star", "★(\\d+)").search_all(no_lv):
		var st := int(m.get_string(1))
		if not ((R.stars as Dictionary).has(st) or (not me.is_empty() and int(me.stars) == st) or hero_st == st):
			bad.append("★%d is no rule's nor anyone's" % st)
	# + of gear: its own, the hero's, a lot of its stall, or a forge rule.
	var forge_rule := text.contains("ตีบวก") or text.contains("ตีจาก") or text.contains("ติดชัวร์") or text.contains("โอกาส") or text.contains("ต้องใช้ชิ้นชุดเทพ")
	var hero_plus := {}
	for slot in (hero.get("gear", {}) as Dictionary):
		hero_plus[int(hero.gear[slot].get("plus", 0))] = true
	for m in _re("plus", "\\+(\\d++)(?![%.]| ?เปอร์เซ็นต์)").search_all(text):
		var v := int(m.get_string(1))
		var ok := (forge_rule and v <= ItemData.MAX_PLUS) or hero_plus.has(v) or (not me.is_empty() and ((me.pluses as Dictionary).has(v) or (me.lot_plus as Dictionary).has(v)))
		if not ok:
			bad.append("+%d is not its gear's" % v)
	# Percentages and prices.
	for m in _re("pct", "([\\d.]+) ?(%|เปอร์เซ็นต์)").search_all(text):
		if not (R.pcts as Dictionary).has(m.get_string(1)):
			bad.append("%s%% is no rate of the game" % m.get_string(1))
	for m in _re("gold", "([\\d,]+) ทอง").search_all(text):
		var v := int(m.get_string(1).replace(",", ""))
		if not ((R.prices as Dictionary).has(v) or (not me.is_empty() and (me.prices as Dictionary).has(v)) or _any_stall_price(v, t)):
			bad.append("%d ทอง is no price of now" % v)
	# Times.
	var ok_times := times(t)
	# A boss's countdown ("เกิดใหม่ใน 02:15") is checked with the boss below.
	var timed := _re("countdown", "เกิดใหม่ใน \\d\\d:\\d\\d").sub(text, "#", true)
	for m in _re("hhmm", "(\\d\\d):(\\d\\d)").search_all(timed):
		if not ok_times.has(m.get_string(0)):
			bad.append("%s is no event's time" % m.get_string(0))
	# A field boss said to be down, up or brought down by someone: BossWorld's own state.
	for zid in BossWorld.zones():
		var bname := BossWorld.boss_name(zid)
		if bname == "" or not text.contains(bname):
			continue
		for m in _re("killed|" + bname, bname + "ถูก (.+?) ปราบ").search_all(text):
			var by := m.get_string(1)
			var any := BossWorld.zones().any(func(z): return String(BossWorld.state(z, t).name) == bname and BossWorld.killer_text(BossWorld.state(z, t)) == by)
			if not any:
				bad.append("%s was not brought down by %s" % [bname, by])
		if text.contains(bname + "ยังอยู่ ยังไม่มีใครล้ม") and not BossWorld.zones().any(func(z): return String(BossWorld.state(z, t).name) == bname and bool(BossWorld.state(z, t).alive) and float(BossWorld.state(z, t).killed_at) <= 0.0):
			bad.append("%s is not untouched" % bname)
		for m in _re("down|" + bname, bname + "ถูก .+? ปราบไป.*?เกิดใหม่ใน (\\d\\d):(\\d\\d)").search_all(text):
			var left := int(m.get_string(1)) * 60 + int(m.get_string(2))
			var ok := BossWorld.zones().any(func(z): return String(BossWorld.state(z, t).name) == bname and not bool(BossWorld.state(z, t).alive) and absf(float(BossWorld.state(z, t).respawn_at) - t - float(left)) <= 1.5)
			if not ok:
				bad.append("%s is not back in %s" % [bname, m.get_string(0)])
	if me.is_empty():
		return bad
	# Its own things.
	for m in _re("mountlv", "ขี่(\\S+) เลเวล (\\d+)").search_all(text):
		if not ((me.owned as Dictionary).has(m.get_string(1)) and int(me.owned[m.get_string(1)]) == int(m.get_string(2))):
			bad.append("it does not ride %s at level %s" % [m.get_string(1), m.get_string(2)])
	for m in _re("wears", "ใส่(ปีก\\S*)").search_all(text):
		var w := m.get_string(1)
		if not (me.owned as Dictionary).keys().any(func(k): return String(k).begins_with(w) or w.begins_with(String(k))):
			bad.append("it does not wear %s" % w)
	for m in _re("hours", "เล่นไป(?:ราว )? ?(\\d+) ชั่วโมง").search_all(text):
		if int(m.get_string(1)) != int(me.played):
			bad.append("it played %d hours, not %s" % [int(me.played), m.get_string(1)])
	for m in _re("days", "เล่นมา (\\d+) วัน").search_all(text):
		if int(m.get_string(1)) != int(me.days):
			bad.append("it joined %d days ago, not %s" % [int(me.days), m.get_string(1)])
	for m in _re("online", "ออนไลน์อยู่ (\\d+) คน").search_all(text):
		if ctx.has("online") and int(m.get_string(1)) != int(ctx.online):
			bad.append("%s online, not %d" % [m.get_string(1), int(ctx.online)])
	for m in _re("guild", "(?<!คุณ)อยู่กิลด์ (\\S+)").search_all(text):
		if m.get_string(1) != String(me.guild):
			bad.append("its guild is not %s" % m.get_string(1))
	for m in _re("heroguild", "คุณอยู่กิลด์ (\\S+)").search_all(text):
		if m.get_string(1) != String(hero.get("guild", "")):
			bad.append("the hero's guild is not %s" % m.get_string(1))
	for cls in ClassData.IDS:
		if text.contains("เป็น" + JobData.god_name(cls)) and not (bool(me.god) and me["class"] == cls):
			bad.append("only a God says it is %s" % JobData.god_name(cls))
	# Where it is: "อยู่ที่<field>" / "อยู่<field>" (not "ไม่ได้อยู่") is where it stands.
	var place_name := String(ctx.get("place", ""))
	for z in ChatLexicon.zones:
		var zname := String(ChatLexicon.zones[z].name)
		for pre in ["ตอนนี้อยู่ที่", "ตอนนี้อยู่", "อยู่ที่", "ใช่ อยู่"]:
			var at := text.find(pre + zname)
			if at < 0 or text.substr(maxi(0, at - 6), 6).contains("ไม่ได้") or text.substr(maxi(0, at - 4), 4).contains("มอน"):
				continue
			if zname != place_name and StringName(z) != StringName(me.place):
				bad.append("it is not at %s" % zname)
	# A monster said to live in a field lives there.
	for mid in ChatLexicon.monsters:
		var m: Dictionary = ChatLexicon.monsters[mid]
		var mname := String(m.name)
		if mname.length() < 3 or not text.contains(mname + " อยู่"):
			continue
		var homes: Array = (m.homes as Array).map(func(h): return String(ChatLexicon.zones[h.zone].name)) + (m.boss_of as Array).map(func(z): return String(ChatLexicon.zones[z].name))
		var named := ChatLexicon.zones.keys().map(func(z): return String(ChatLexicon.zones[z].name)).filter(func(zn): return text.contains(zn))
		if not named.is_empty() and not named.any(func(zn): return homes.has(zn)):
			bad.append("%s does not live in %s" % [mname, named])
	return bad


static func _any_stall_price(v: int, t: float) -> bool:
	for k in WorldPlayers.size():
		if WorldPlayers.session_at(k, t).is_empty():
			continue
		var s := WorldPlayers.state(k, t)
		if String(s.doing) != "stall":
			continue
		for e in StallStock.stock(k, t):
			if int(e.price) == v:
				return true
	return false


## A reply from outside the game's brain (the cloud chat): every claim must hold
## (verify) and every number and every name of the game it carries must be one the facts
## it was given (or the hero's own line) hold; true when it may be shown.
static func grounded(reply: String, facts: String, said: String, ctx: Dictionary) -> bool:
	var c := ctx.duplicate()
	c["said"] = said
	if not verify(reply, c).is_empty():
		return false
	for m in _re("num", "\\d[\\d,.]*").search_all(reply):
		var n := m.get_string(0).trim_suffix(".").trim_suffix(",")
		if n == "555" or n.begins_with("555"):
			continue
		if not facts.contains(n) and not said.contains(n):
			return false
	var names := ChatLexicon.all_names()
	for name in names:
		if String(name).length() >= 3 and reply.contains(String(name)) and not facts.contains(String(name)) and not said.contains(String(name)):
			return false
	return true
