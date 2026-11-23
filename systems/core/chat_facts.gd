class_name ChatFacts
extends RefCounted
## What a world player can truthfully say about the game, read off the game's own tables
## at the moment it is asked: where a monster lives, a field's levels and boss, a boss's
## respawn and loot, where an item comes from and its drop rate (with the event that is
## multiplying it now), the forge's odds (the forge weekend included), the events running
## and the next one, the festival dates, the guild war's next round and this week's table,
## a class, a stall's real stock and prices, the hero's public sheet. Every number and
## name comes from a constant or a function of the game; when the game cannot answer, the
## text says so instead of guessing ("" lets the caller answer "ไม่แน่ใจ").
## ChatMind picks the answer; ChatTruth checks every claim against the same tables.

const MAX := 150


## A drop chance (0-1) as a chat says it: "1", "0.5", "0.01" (percent, no trailing zeros).
static func pct(rate: float) -> String:
	var v := snappedf(rate * 100.0, 0.01)
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	var s := "%.2f" % v
	while s.ends_with("0"):
		s = s.left(s.length() - 1)
	return s


static func thousands(n: int) -> String:
	return StallStock._thousands(n)


## "Lv.a-b" of a band.
static func band(levels: Variant) -> String:
	if not levels is Array or (levels as Array).size() < 2:
		return ""
	var a := int(levels[0])
	var b := int(levels[1])
	return "Lv.%d" % a if a == b else "Lv.%d-%d" % [a, b]


# --- Monsters, bosses and fields ----------------------------------------------------------

## Where monster `id` lives (up to two camps), or its boss field.
static func monster_where(id: StringName) -> String:
	ChatLexicon.ensure()
	var m: Dictionary = ChatLexicon.monsters.get(id, {})
	if m.is_empty():
		return ""
	if not (m.boss_of as Array).is_empty():
		return boss_info(id)
	var homes: Array = m.homes
	var parts: PackedStringArray = []
	var seen := {}
	for h in homes:
		var zname := String(ChatLexicon.zones[h.zone].name)
		var key := "%s|%s" % [zname, h.camp]
		if seen.has(key) or parts.size() >= 2:
			continue
		seen[key] = true
		parts.append("%sใน%s %s" % [h.camp, zname, band(h.levels)])
	if parts.is_empty():
		return ""
	return "%s อยู่%s" % [m.name, " กับ".join(parts)]


## A field boss: its field, level, respawn and what it drops (BossLootData).
static func boss_info(id: StringName) -> String:
	ChatLexicon.ensure()
	var m: Dictionary = ChatLexicon.monsters.get(id, {})
	if m.is_empty() or (m.boss_of as Array).is_empty():
		return ""
	var zid: StringName = m.boss_of[0]
	var z: Dictionary = ChatLexicon.zones[zid]
	var out := "%s เป็นบอสของ%s Lv.%d เกิดใหม่ราว %d นาที" % [m.name, z.name, int(z.get("boss_level", 0)), maxi(1, int(round(float(z.get("respawn", 0.0)) / 60.0)))]
	var loot := boss_loot(id)
	if loot != "" and (out + " " + loot).length() <= MAX:
		out += " " + loot
	return out


## Whether boss `id` stands now (BossWorld.state: the one truth of who brought a field
## boss down and when it is back), in its first field (or `zid`): "" when it never fell.
static func boss_status(id: StringName, t: float, zid := &"") -> String:
	ChatLexicon.ensure()
	var m: Dictionary = ChatLexicon.monsters.get(id, {})
	if m.is_empty() or (m.boss_of as Array).is_empty():
		return ""
	if zid == &"" or not (m.boss_of as Array).has(zid):
		zid = m.boss_of[0]
	if not BossWorld.has_boss(zid):
		return ""
	var s := BossWorld.state(zid, t)
	if not bool(s.alive):
		return "ตอนนี้%sถูก %s ปราบไป%s เกิดใหม่ใน %s" % [String(s.name), BossWorld.killer_text(s), BossWorld.ago_text(t - float(s.killed_at)), BossWorld.clock_text(float(s.respawn_at) - t)]
	if float(s.killed_at) > 0.0:
		return "ตอนนี้%sเกิดใหม่แล้ว รอบก่อนถูก %s ปราบ%s" % [String(s.name), BossWorld.killer_text(s), BossWorld.ago_text(t - float(s.killed_at))]
	return "ตอนนี้%sยังอยู่ ยังไม่มีใครล้ม" % String(s.name)


## The field bosses brought down lately (BossWorld.recent), newest first, up to two.
static func boss_kills(t: float) -> String:
	var parts: PackedStringArray = []
	for s in BossWorld.recent(t, 900.0):
		if parts.size() >= 2:
			break
		parts.append("%sถูก %s ปราบ%s" % [String(s.name), BossWorld.killer_text(s), BossWorld.ago_text(t - float(s.killed_at))])
	if parts.is_empty():
		return "ช่วงนี้ยังไม่เห็นใครล้มบอสสนามเลย"
	return "ล่าสุด " + " · ".join(parts)


## What a field boss drops: its slots, its favourite gem, its chase piece's odds.
static func boss_loot(id: StringName) -> String:
	if not BossLootData.has(id):
		return ""
	var tab: Dictionary = BossLootData.TABLES[id]
	var slots: PackedStringArray = []
	for s in tab.slots:
		slots.append(String(ItemData.SLOT_NAMES.get(String(s), s)))
	var chase: Dictionary = tab.chase[0]
	return "ดรอป%s ชอบดรอป%s ของ%s ลุ้น %s%% ครบ %d ตัวได้แน่" % ["/".join(slots), String(ItemData.GEMS[String(tab.gem)].name),
		ItemData.RARITY_NAMES[int(chase.rarity)], pct(float(chase.base)), int(chase.hard)]


## A field: its levels (or the stars it takes), its monsters and its boss.
static func zone_info(zid: StringName) -> String:
	ChatLexicon.ensure()
	if zid == &"town":
		return "หมู่บ้านมีร้านค้า ช่างตีเหล็ก ปรมาจารย์สกิล นายทะเบียนกิลด์ แล้วก็ร้านของผู้เล่นที่ตั้งขาย"
	var z: Dictionary = ChatLexicon.zones.get(zid, {})
	if z.is_empty():
		return ""
	var need := ""
	if int(z.star) > 0:
		need = "ต้อง Lv.%d ★%d" % [Game.MAX_LEVEL, int(z.star)]
	elif not (z.level as Array).is_empty():
		need = band(z.level)
	var mobs: PackedStringArray = []
	for mid in z.monsters:
		if mobs.size() >= 3:
			break
		mobs.append(String(ChatLexicon.monsters[mid].name))
	var out := "%s %s" % [z.name, need]
	if not mobs.is_empty():
		out += " มี" + " ".join(mobs)
	if StringName(z.boss) != &"":
		var b := "บอส%s" % String(ChatLexicon.monsters[z.boss].name)
		if (out + " " + b).length() <= MAX:
			out += " " + b
	return out.strip_edges()


## The field for a level and stars (the one the world players hunt in).
static func field_for(level: int, stars: int) -> String:
	var zid := WorldPlayers.hunting_zone(level, stars if level >= Game.MAX_LEVEL else 0)
	return String(ZoneData.get_zone(zid).get("name", ""))


# --- Items -------------------------------------------------------------------------------

## Where item `key` (ChatLexicon.items: "jewel:purple", "potion:hp_s", "gem:ruby",
## "mount:griffin", "costume:sakura", "isle:weapon") comes from, at time t.
static func item_source(key: String, t: float) -> String:
	ChatLexicon.ensure()
	var it: Dictionary = ChatLexicon.items.get(key, {})
	if it.is_empty():
		return ""
	var id := String(it.id)
	var name := String(it.name)
	match String(it.kind):
		"jewel":
			return jewel_source(id, t)
		"potion":
			var p: Dictionary = ItemData.POTIONS.get(id, {})
			if id == "halloween":
				return "%sดรอปเฉพาะช่วงอีเวนต์ฮาโลวีน ร้านไม่ขาย" % name
			if id == "hp_god":
				return ChatTrade.hint({"kind": "potion", "ids": [id]})
			return "%sร้านค้าในหมู่บ้านขาย %s ทอง ร้านผู้เล่นมักถูกกว่า" % [name, thousands(int(p.get("price", 0)))]
		"gem":
			return "%s %s" % [name, ChatTrade.hint({"kind": "gem", "ids": [id]})]
		"mount":
			var m := MountData.info(id)
			if id == SkyIsleLoot.MOUNT:
				return "%s ต้องใช้%s ดรอปที่%s %s%% ต่อตัว" % [name, String(ItemData.JEWELS[SkyIsleLoot.EGG].name), SkyIsleData.TITLE, pct(SkyIsleLoot.EGG_DROP)]
			return "%s ทำในเมนูสัตว์ขี่ ขั้นแรกใช้%s 1 กับเพชรชาออส %d ติด %s%% วัตถุดิบดรอป %s%% ต่อตัว" % [name, String(ItemData.JEWELS[MountData.mat_of(id)].name),
				int(m.chaos), MountData.chance_text(id).trim_suffix("%"), pct(float(m.drop))]
		"costume":
			var c: Dictionary = RewardShop.COSTUMES.get(id, {})
			var cost := "เหรียญลีก %d" % int(c.get("lc", 0))
			if int(c.get("ep", 0)) > 0:
				cost += " แต้มกิจกรรม %d" % int(c.ep)
			return "%s แลกที่ร้านแลกของรางวัล ใช้%s" % [name, cost]
		"isle":
			var rate := SkyIsleLoot.WEAPON_DROP if id == "weapon" else SkyIsleLoot.WING_DROP
			return "%sดรอปที่%s (★%d) %s%% ต่อตัว" % [name, SkyIsleData.TITLE, SkyIsleData.ENTRY_STAR, pct(rate)]
	return ""


## A forge jewel, a mount material, a set material, the isle's goods, a weekly piece or a
## Loy Krathong material: where it drops and how often.
static func jewel_source(id: String, t: float) -> String:
	var j: Dictionary = ItemData.JEWELS.get(id, {})
	if j.is_empty():
		return ""
	var name := String(j.name)
	if ItemData.JEWEL_DROP.has(id):
		var out := "%sดรอปจากมอนทุกสนามเก็บเลเวล %s%% ต่อตัว ที่%sกับ%s %s%%" % [name, pct(float(ItemData.JEWEL_DROP[id])),
			DrownedAbyssData.TITLE, DivineRegionData.TITLE, pct(float(EndgameFields.JEWEL_DROP[id]))]
		var mult := WorldEvents.jewel_multiplier(t)
		if mult > 1.0:
			out += " ตอนนี้ดรอป x%d" % int(round(mult))
		return out
	if id == "feather":
		return "%sดรอปในสนามดาว ★%d ขึ้นไป %s%% ต่อตัว ทุก %d ดาวเพิ่มอีก %s%%" % [name, ItemData.FEATHER_STARS, pct(ItemData.FEATHER_DROP), ItemData.FEATHER_STARS, pct(ItemData.FEATHER_DROP)]
	var mount := MountData.mount_of_mat(id)
	if mount != "" and mount != SkyIsleLoot.MOUNT:
		return "%sดรอปจากมอนตอนล่า %s%% ต่อตัว ใช้ทำ%s" % [name, pct(float(MountData.info(mount).drop)), String(MountData.info(mount).name)]
	match id:
		"set_core":
			return "%sดรอปที่%sกับ%s (★%d) %s%% ต่อตัว ใช้หลอมชุดเซต" % [name, DrownedAbyssData.TITLE, DivineRegionData.TITLE, EndgameFields.ENTRY_STAR, pct(EndgameFields.SET_CORE_DROP)]
		"lotus_scale":
			return "%sดรอปที่%sกับ%s (★%d) %s%% ต่อตัว มอนเอลีท %s%%" % [name, DrownedAbyssData.TITLE, DivineRegionData.TITLE, EndgameFields.ENTRY_STAR, pct(EndgameFields.SCALE_NORMAL), pct(EndgameFields.SCALE_ELITE)]
		"dragon_chest":
			return "%sดรอปที่%s %s%% ต่อตัว มอนเอลีท %s%% บอสให้ %d กล่อง" % [name, SkyIsleData.TITLE, pct(SkyIsleLoot.CHEST_NORMAL), pct(SkyIsleLoot.CHEST_ELITE), SkyIsleLoot.CHEST_BOSS]
		"dragon_fragment":
			return "%sดรอปที่%s %s%% ต่อตัว ครบ %d ชิ้นแลกชุดเทพมังกรได้" % [name, SkyIsleData.TITLE, pct(SkyIsleLoot.FRAGMENT_DROP), SkyIsleLoot.COSTUME_FRAGMENTS]
		"sky_dragon_egg":
			return "%sดรอปที่%s %s%% ต่อตัว ฟักเป็น%sได้" % [name, SkyIsleData.TITLE, pct(SkyIsleLoot.EGG_DROP), String(MountData.info(SkyIsleLoot.MOUNT).name)]
	if id.begins_with("wk"):
		return "%sเป็นของสะสมประจำสัปดาห์ ดรอปช่วงสัปดาห์ที่เป็นธีมของมัน %s" % [name, WeeklyCollect.chat_answer(-1, t)]
	if id.begins_with("lk_"):
		return LoyKrathong.chat_answer(-1, t)
	var hint := ChatTrade.hint({"kind": "jewel", "ids": [id]})
	return hint if hint != "" and not hint.begins_with("เพชรดรอป") else ""


## The forge's odds at time t (the forge weekend's bonus in); `plus`: the step asked about
## (the try from +plus to +plus+1), -1 for the whole table.
static func forge(t: float, plus := -1) -> String:
	var weekend := WorldEvents.forge_weekend_on(t)
	if plus >= 0 and plus < ItemData.MAX_PLUS:
		var c := WorldEvents.enhance_chance_at(plus, t)
		var cost := ItemData.enhance_cost({"plus": plus})
		var need: PackedStringArray = []
		for k in ["purple", "pink", "chaos"]:
			if int(cost.get(k, 0)) > 0:
				need.append("%s %d" % [String(ItemData.JEWELS[k].name), int(cost[k])])
		var out := "ตีจาก +%d ไป +%d ใช้%s โอกาส %s%%" % [plus, plus + 1, " ".join(need), pct(c)]
		if c >= 1.0:
			out = "ตีจาก +%d ไป +%d ใช้%s ติดชัวร์" % [plus, plus + 1, " ".join(need)]
		elif weekend:
			out += " (%sรวมโบนัสแล้ว)" % WorldEvents.NAME_FORGE
		return out + " พลาดแค่เสียเพชร ของไม่ลดขั้น"
	var steps: PackedStringArray = ["+1 ถึง +6 ติดชัวร์"]
	steps.append("+7 ถึง +9 %s%%" % pct(WorldEvents.enhance_chance_at(6, t)))
	for p in range(9, ItemData.MAX_PLUS):
		steps.append("+%d %s%%" % [p + 1, pct(WorldEvents.enhance_chance_at(p, t))])
	var out := "ตีบวก " + " ".join(steps)
	if weekend:
		out += " ตอนนี้%sอยู่ บวกเพิ่มแล้ว" % WorldEvents.NAME_FORGE
	elif WorldEvents.forge_weekend_enabled and t >= float(WorldEvents.FORGE_START) - 14.0 * 86400.0:
		out += " เสาร์อาทิตย์มี%s +%d%%" % [WorldEvents.NAME_FORGE, int(round(WorldEvents.FORGE_BONUS * 100.0))]
	return out


# --- Events -------------------------------------------------------------------------------

## What runs now and what comes next (WorldEvents, the festivals, the dragon hunt...).
static func events(t: float) -> String:
	var now: PackedStringArray = []
	for e in WorldEvents.current(t):
		if now.size() >= 3:
			break
		now.append(String(e.name_th))
	if WorldEvents.forge_weekend_on(t):
		now.append(WorldEvents.NAME_FORGE)
	if DragonHunt.is_on(t):
		now.append(DragonHunt.NAME)
	var out := ChatBrain.help_text("events")
	if now.is_empty():
		return out
	# The times of the daily events stay in: the later names give way first.
	for k in range(now.size(), 0, -1):
		var part := "ตอนนี้มี " + " · ".join(now.slice(0, k))
		if (part + " " + out).length() <= MAX:
			return part + " " + out
	return "ตอนนี้มี " + " · ".join(now)


## The golden monster (มอนทองคำ): how often, how long, what it pays (WorldEvents).
static func golden(t: float) -> String:
	var out := "%sโผล่ทุก %d นาทีในสนามเก็บเลเวล อยู่ %d นาที เลือด x%d ให้ทอง %s ต่อขั้นสนาม เพชรม่วงกับเพชรชมพู ลุ้นเพชรชาออส %s%% อัญมณี %s%%" % [
		WorldEvents.NAME_GOLDEN, WorldEvents.GOLDEN_PERIOD / 60, WorldEvents.GOLDEN_LENGTH / 60, int(WorldEvents.GOLDEN_HP),
		thousands(WorldEvents.GOLDEN_GOLD), pct(WorldEvents.GOLDEN_CHAOS), pct(WorldEvents.GOLDEN_GEM)]
	if not WorldEvents.golden_now(t).is_empty() and out.length() < MAX - 12:
		out += " ตอนนี้โผล่อยู่"
	return out


## The forge weekend (สุดสัปดาห์ตีบวก): on now or not, and what it gives.
static func forge_weekend(t: float) -> String:
	if not WorldEvents.forge_weekend_enabled or t < float(WorldEvents.FORGE_START):
		return "ตอนนี้ยังไม่มี%sนะ" % WorldEvents.NAME_FORGE
	var what := "%sมีทุกเสาร์อาทิตย์ ตีบวกขั้นที่ลุ้นได้โอกาสเพิ่ม %d%% สูงสุด %d%%" % [WorldEvents.NAME_FORGE, int(round(WorldEvents.FORGE_BONUS * 100.0)), int(round(WorldEvents.FORGE_CAP * 100.0))]
	return what + (" ตอนนี้กำลังมีอยู่เลย" if WorldEvents.forge_weekend_on(t) else " ตอนนี้ยังไม่ถึงเสาร์อาทิตย์")


## The dragon hunt (ล่ามังกรแก้วเจ็ดสี): on now, or when the next one starts.
static func dragon_hunt(t: float) -> String:
	if DragonHunt.is_on(t):
		return "%sอยู่ตอนนี้ มังกรแก้วมาสองเท่า จบ %s ล่าได้แต้มแลกของที่เมนูอีเวนต์" % [DragonHunt.NAME, DragonHunt.date_text(DragonHunt.end_of(DragonHunt.index(t)))]
	return "%sรอบหน้าเริ่ม %s ยาว %d วัน" % [DragonHunt.NAME, DragonHunt.date_text(DragonHunt.next_start(t)), int(DragonHunt.LENGTH / WorldEvents.DAY)]


## The festivals (EXP x3 / x5): on now, coming or over.
static func festival(t: float) -> String:
	if WorldEvents.festival3_on(t):
		return "%s อยู่ตอนนี้ จบ %s" % [WorldEvents.NAME_FESTIVAL3, DragonHunt.date_text(float(WorldEvents.FESTIVAL3_END))]
	if WorldEvents.festival5_on(t):
		return "%s อยู่ตอนนี้ จบ %s" % [WorldEvents.NAME_FESTIVAL5, DragonHunt.date_text(float(WorldEvents.FESTIVAL5_END))]
	if WorldEvents.festival_on(t):
		return "%s อยู่ตอนนี้ จบ %s" % [WorldEvents.NAME_FESTIVAL, DragonHunt.date_text(float(WorldEvents.FESTIVAL_END))]
	if t < float(WorldEvents.FESTIVAL5_START) and WorldEvents.festival_enabled:
		return "%s เริ่ม %s" % [WorldEvents.NAME_FESTIVAL5, DragonHunt.date_text(float(WorldEvents.FESTIVAL5_START))]
	if t < float(WorldEvents.FESTIVAL3_START) and WorldEvents.festival_enabled:
		return "%s เริ่ม %s" % [WorldEvents.NAME_FESTIVAL3, DragonHunt.date_text(float(WorldEvents.FESTIVAL3_START))]
	return "ตอนนี้ไม่มีเทศกาล EXP นะ " + events(t)


# --- The guild war -------------------------------------------------------------------------

## The next round (and who guild g meets), this week's leader and the castle holder.
static func guild_war(t: float, g: int, results := false) -> String:
	var next := GuildLeague.next_slot(t)
	var out := "กิลด์วอรอบหน้า %s" % GuildLeague.clock_text(next)
	if g > 0:
		var rivals := GuildLeague.next_rivals(g, t)
		if not rivals.is_empty():
			out += " %s ชนกับ %s" % [GuildLeague.name_of(g), ", ".join(PackedStringArray(rivals.map(func(r): return GuildLeague.name_of(int(r)))))]
	if not results:
		return out
	var lg := league(t)
	if int(lg.leader) > 0:
		out += " สัปดาห์นี้%sนำ %d แต้ม" % [GuildLeague.name_of(int(lg.leader)), int(lg.points)]
	elif int(lg.rounds) == 0:
		out += " สัปดาห์นี้ยังไม่มีผลวอ"
	if int(lg.holder) > 0 and (out + " ปราสาทตอนนี้อยู่กับ " + GuildLeague.name_of(int(lg.holder))).length() <= MAX:
		out += " ปราสาทตอนนี้อยู่กับ " + GuildLeague.name_of(int(lg.holder))
	return out


static var _league := {}
static var _king := {}
static var _offers := {}


## Last season's Castle King (GuildLeague.champion_now), worked out once a week.
static func castle_king(t: float) -> int:
	var w := GuildLeague.week_of(t)
	if int(_king.get("week", -1)) != w:
		_king = {"week": w, "g": GuildLeague.champion_now(t)}
	return int(_king.g)


## The stalls selling item `id` of `kind` now (ChatTrade.offers), kept for a minute of
## world time per item (every stall's stock is read for it); a bought lot is gone at once.
static func offers(kind: String, id: String, t: float) -> Array:
	var key := "%s|%s|%d|%d" % [kind, id, int(t / 60.0), (Game.profile.get("flags", {}) as Dictionary).size() if Game.has_profile else 0]
	if not _offers.has(key):
		if _offers.size() > 64:
			_offers.clear()
		_offers[key] = ChatTrade.offers({"kind": kind, "ids": [id]}, t)
	return _offers[key]


## This week's league as its screen shows it at t: {leader, points, holder, rounds, table};
## worked out once a round (the table sums the week's rounds, which takes a while).
static func league(t: float) -> Dictionary:
	var w := GuildLeague.week_of(t)
	var key := "%d|%d" % [w, GuildLeague.last_ended(t)]
	if String(_league.get("key", "")) == key:
		return _league
	var real := GuildLeague.real_wars(w) if Game.has_profile else []
	var tab := GuildLeague.table(w, real, t)
	var rounds := 0
	for r in tab:
		rounds = maxi(rounds, int(r.wins) + int(r.losses))
	var lead := tab[0] if not tab.is_empty() and int(tab[0].points) > 0 else {}
	_league = {"key": key, "leader": int(lead.get("g", 0)), "points": int(lead.get("points", 0)), "holder": GuildLeague.holder(w, real, t), "rounds": rounds, "table": tab}
	return _league


## How guild g did this week (its row of the table), "" before it scored.
static func guild_standing(t: float, g: int) -> String:
	if g <= 0:
		return ""
	var tab: Array = league(t).table
	for r in tab:
		if int(r.g) == g:
			if int(r.points) <= 0 and int(r.wins) + int(r.losses) == 0:
				return ""
			return "%s สัปดาห์นี้อันดับ %d %d แต้ม ชนะ %d แพ้ %d" % [String(r.name), int(r.rank), int(r.points), int(r.wins), int(r.losses)]
	return ""


# --- Classes ------------------------------------------------------------------------------

static func class_info(id: StringName) -> String:
	var c := ClassData.get_class_data(id)
	if c.is_empty():
		return ""
	var desc := String(c.get("desc", ""))
	var dash := desc.find("—")
	if dash >= 0:
		desc = desc.substr(dash + 1).strip_edges()
	var cut := desc.find(" สกิล")
	if cut > 0:
		desc = desc.left(cut)
	return ("%s (%s) %s" % [c.name, c.get("title", ""), desc]).strip_edges().left(MAX)


# --- Stalls -------------------------------------------------------------------------------

## What keeper i has for sale now (up to `count` lots: name and price), "" with nothing.
static func stall(i: int, t: float, count := 2) -> String:
	var lots := StallStock.stock(i, t)
	if lots.is_empty():
		return ""
	var hot := lots.filter(func(e): return bool(e.get("hot", false)))
	var pick: Array = hot.slice(0, 1)
	for e in lots:
		if pick.size() >= count:
			break
		if not pick.has(e):
			pick.append(e)
	var parts: PackedStringArray = []
	for e in pick:
		var item: Dictionary = e.item
		var what := ItemData.name_of(item)
		if int(item.get("count", 1)) > 1:
			what += " ×%d" % int(item.count)
		parts.append("%s %s ทอง" % [what, thousands(int(e.price))])
	return "ในร้านมี " + " · ".join(parts) + (" กับอีก %d อย่าง" % (lots.size() - pick.size()) if lots.size() > pick.size() else "")


## The price of item `key` at keeper i's stall now, "" when it has none of it.
static func stall_price(i: int, key: String, t: float) -> String:
	var it: Dictionary = ChatLexicon.items.get(key, {})
	if it.is_empty():
		return ""
	for e in StallStock.stock(i, t):
		var item: Dictionary = e.item
		var iid := String(item.get("id", ""))
		if iid == String(it.id) or (String(it.kind) == "gem" and iid.begins_with(String(it.id) + "_")):
			var what := ItemData.name_of(item)
			if int(item.get("count", 1)) > 1:
				what += " ×%d" % int(item.count)
			return "%s ในร้านขาย %s ทอง" % [what, thousands(int(e.price))]
	return ""


# --- The hero's public sheet --------------------------------------------------------------

## What anyone sees of the hero (AiChat.request_body's hero): {level, stars, class, guild,
## gear: {slot: {name, plus}}, costume, god}.
static func hero_sheet() -> Dictionary:
	if not Game.has_profile:
		return {}
	var gear := {}
	var equip: Dictionary = Game.profile.get("equip", {})
	for slot in ["weapon", "armor", "helm", "boots", "wings"]:
		var item: Variant = equip.get(slot)
		if item is Dictionary and not (item as Dictionary).is_empty():
			gear[slot] = {"name": String(item.get("name", "")), "plus": int(item.get("plus", 0))}
	var cos := Game._worn_costume(Game.profile)
	return {"gear": gear, "costume": String(RewardShop.COSTUMES.get(cos, {}).get("name", "")) if cos != "" else ""}
