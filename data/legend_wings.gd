class_name LegendWings
extends RefCounted
## ปีกตำนานแห่งกิลด์ (Legendary Guild Wings): one pair a week, minted when a league season
## closes (after the Sunday 21:30 round is frozen) for the guild first in the table
## (GuildLeague.league_champion_of), stamped with the week id and the guild (legend_week,
## legend_guild). The guild's leader receives it (Game.guild_war_leader: the hero when it
## leads its own guild, else a world player, who then wears it for real: WorldGear shows
## it in its gear, so chat and the player card tell the truth). When the same guild is
## champion again the next week (a streak), the leader does not keep the new pair but hands
## it to a member: the hero as leader picks one in the guild screen (hand_choices /
## hand_to; itself only while it holds none of this streak); an AI leader gives it to the
## strongest member who holds none of this streak yet, the hero among the candidates by
## the same score, so the hero's chance is real and never forced.
##
## Receiving = worn at once (give_to_hero: the old wings go to the bag, else the storage)
## and the holder must wear it: it comes off only for another pair of these wings
## (Game.unequip / equip_from_bag, LOCK_TEXT). Stats: a mythic tier above the 100★ class
## wings — every stat above the best 100★ pair at +15 (STATS, fixed) — plus the aura
## (AURA: +10% to the wearer and its party within AURA_RANGE m: HeroStats.compute, Hero,
## Companion). Any class from Lv.1 (no class, no stars). Never sold (Game.sell_item,
## StallStock), traded (Trade.tradable) or consigned (PlayerStall); it can be deposited in
## the SharedStorage and withdrawn by any character of the account (no class lock).
##
## profile.legend_wings (valid_record / repair): {done: the last season worked out, hold:
## {"<week>": {g: guild, n: holder ("" the hero), s: streak length}}, hand: {"<week>": the
## member the hero as leader handed that week's pair to ("" itself)}}. The record decides
## who holds each week's pair for good, so a later change of leader never rewrites the past
## (ai_item reads it for the world players' gear). The server (accounts.js) checks every
## pair and refuses two pairs with one week id across an account.

const KEY := "legend_wings"
const NAME := "ปีกตำนานแห่งกิลด์"
const TAG := "ตำนาน"
const COLOR := Color("ffe08a")
const AURA := 0.10
const AURA_RANGE := 8.0
## The first season a pair is minted for (the seasons before were played without it).
const FROM_WEEK := GuildLeague.FINAL_FROM_WEEK
## Seasons caught up at most when the game was away (tick).
const MAX_BACK := 8
const MAX_WEEK := 100000
const MAX_RECORDS := 64
const KEEP_WEEKS := 60
const LEVEL := 1
const RARITY := 4
const SOCKETS := 3
## Every stat is the best 100★ pair's (StarWingData.INFO, the mythic roll) at +15
## (HeroStats.PLUS_BONUS, the crit grade) and a tenth more. Fixed, never rolled: the
## server checks the very same numbers (accounts.js LEGEND_STATS: keep them equal).
const STATS := {"atk": 1414, "matk": 1456, "hp": 5822, "def": 624, "mp": 2391, "crit": 0.2}
## The wing models a pair may show (assets/models/star_wings; the Dark Lord's cape is not
## a pair of wings), by week.
const MODELS: Array[String] = ["priest", "warrior", "mage", "archer", "lancer", "assassin", "defender", "summoner", "bard"]
const LOOK := "legend_wings"
const LOCK_TEXT := "ปีกตำนานแห่งกิลด์ถอดไม่ได้ — เปลี่ยนได้เฉพาะปีกตำนานแห่งกิลด์คู่อื่น"
const SELL_TEXT := "ปีกตำนานแห่งกิลด์ขายไม่ได้ (ฝากคลังรวมให้ตัวละครอื่นได้)"
const TRADE_TEXT := "ปีกตำนานแห่งกิลด์แลกเปลี่ยนไม่ได้"
const STALL_TEXT := "ปีกตำนานแห่งกิลด์ตั้งขายและฝากขายไม่ได้"
const ANNOUNCER := "ประกาศลีกกิลด์"

## The world players' pairs (ai_item), by the record they were read from.
static var _ai_items := {}
static var _ai_sig := ""


# --- The item -------------------------------------------------------------------------

static func is_item(item: Variant) -> bool:
	return item is Dictionary and int((item as Dictionary).get("legend_week", 0)) > 0 and String((item as Dictionary).get("slot", "")) == "wings"


static func model_of(w: int) -> String:
	return MODELS[posmod(w, MODELS.size())]


## Season w's pair for guild g.
static func item(w: int, g: int) -> Dictionary:
	return {"kind": "equip", "uid": ItemData.make_uid(), "slot": "wings", "base": "wings", "wing": model_of(w),
		"plus": 0, "sockets": SOCKETS, "gems": [], "set": "", "name": "%s %s" % [NAME, GuildLeague.name_of(g)],
		"rarity": RARITY, "level": LEVEL, "class": "", "stats": STATS.duplicate(), "price": 0,
		"legend_week": w, "legend_guild": g, "look": LOOK}


## "ปีกตำนานแห่งกิลด์ Alpha · สัปดาห์ที่ 2967" for tooltips.
static func title_of(item: Dictionary) -> String:
	return "%s %s · ฤดูกาลที่ %d" % [NAME, GuildLeague.name_of(int(item.get("legend_guild", 0))), int(item.get("legend_week", 0))]


## Tooltip lines (ItemData.detail_lines).
static func detail_lines(item: Dictionary) -> Array[String]:
	return [
		"ปีกระดับ%s · รางวัลกิลด์แชมป์ลีกฤดูกาลที่ %d (กิลด์ %s)" % [TAG, int(item.get("legend_week", 0)), GuildLeague.name_of(int(item.get("legend_guild", 0)))],
		"ออร่าตำนาน: ทุกค่าสถานะ +%d%% ให้ผู้ใส่และปาร์ตี้ในระยะ %d ม." % [int(round(AURA * 100.0)), int(AURA_RANGE)],
		"ใส่ได้ทุกอาชีพตั้งแต่เลเวล 1 · ใส่แล้วถอดไม่ได้ (เปลี่ยนได้เฉพาะปีกตำนานคู่อื่น)",
		"ขาย แลกเปลี่ยน ตั้งแผงไม่ได้ · ฝากคลังรวมให้ตัวละครอื่นในบัญชีได้",
	]


## A pair is well formed: the fixed fields and stats of item().
static func valid_item(item: Dictionary) -> bool:
	if not Game._valid_integer(item.get("legend_week"), FROM_WEEK, MAX_WEEK) or not Game._valid_integer(item.get("legend_guild"), 1, 4):
		return false
	if not WorldPlayers.GUILD_NAMES.has(int(item.legend_guild)):
		return false
	if item.get("kind") != "equip" or item.get("slot") != "wings" or item.get("base") != "wings" or not MODELS.has(String(item.get("wing", ""))):
		return false
	if int(item.get("level", 0)) != LEVEL or int(item.get("rarity", 0)) != RARITY or String(item.get("class", "")) != "":
		return false
	for key in ["star_tier", "set_gear", "collection"]:
		if item.has(key):
			return false
	var stats: Variant = item.get("stats")
	if not stats is Dictionary or (stats as Dictionary).size() != STATS.size():
		return false
	for key in STATS:
		if not stats.has(key) or not (stats[key] is int or stats[key] is float):
			return false
		if key == "crit":
			if absf(float(stats[key]) - float(STATS[key])) > 0.0001:
				return false
		elif int(stats[key]) != int(STATS[key]):
			return false
	return true


## True when the hero wears a pair.
static func worn(profile: Dictionary) -> bool:
	return is_item((profile.get("equip", {}) as Dictionary).get("wings"))


## The week ids of every pair this account holds (the hero's bag, worn gear and old
## storage, the shared storage, the other characters' saves): one pair a week an account.
static func account_weeks() -> Dictionary:
	var weeks := {}
	var lists: Array = []
	if Game.has_profile:
		lists.append(Game.profile.get("inv", []))
		lists.append(Game.profile.get("storage", []))
		lists.append((Game.profile.get("equip", {}) as Dictionary).values())
	lists.append(SharedStorage.items())
	for i in range(1, Game.SLOT_COUNT + 1):
		if Game.has_profile and i == Game.slot:
			continue
		var raw := Game._read_slot(i)
		if raw.is_empty():
			continue
		lists.append(raw.get("inv", []))
		lists.append(raw.get("storage", []))
		lists.append((raw.get("equip", {}) as Dictionary).values())
	for list in lists:
		for piece in list:
			if is_item(piece):
				weeks[int(piece.legend_week)] = true
	return weeks


# --- The hero's record -------------------------------------------------------------

static func record() -> Dictionary:
	if not Game.has_profile:
		return {}
	var d: Variant = Game.profile.get(KEY)
	if not d is Dictionary:
		d = {"done": -1, "hold": {}, "hand": {}}
		Game.profile[KEY] = d
	return d


## Who holds season w's pair as recorded: {g, n ("" the hero), s} or {}.
static func hold_of(w: int) -> Dictionary:
	var d := record()
	var h: Variant = (d.get("hold", {}) as Dictionary).get(str(w)) if not d.is_empty() else null
	return h if h is Dictionary else {}


## The latest season a pair was recorded for (0 when none).
static func latest_week() -> int:
	var best := 0
	for key in record().get("hold", {}):
		best = maxi(best, int(String(key)))
	return best


## The holder's name as shown: the hero's own name for "".
static func holder_label(h: Dictionary) -> String:
	var n := String(h.get("n", ""))
	if n == "":
		return "%s (คุณ)" % String(Game.profile.get("name", "")) if Game.has_profile else "คุณ"
	return n


## "ปีกตำนานสัปดาห์นี้: กิลด์ X → Y" for the latest season closed ("" before any).
static func line_now() -> String:
	var w := latest_week()
	if w <= 0:
		return "ปีกตำนานสัปดาห์นี้: ยังไม่มี (มอบให้หัวหน้ากิลด์แชมป์ลีกเมื่อฤดูกาลจบ)"
	var h := hold_of(w)
	var streak := int(h.get("s", 1))
	return "ปีกตำนานสัปดาห์นี้: กิลด์ %s → %s%s" % [GuildLeague.name_of(int(h.g)), holder_label(h), " · แชมป์ติดต่อกัน %d สัปดาห์" % streak if streak > 1 else ""]


## The holders of the latest streak, newest first: [{w, g, n, s}].
static func streak_holders() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var w := latest_week()
	if w <= 0:
		return out
	var g := int(hold_of(w).g)
	while true:
		var h := hold_of(w)
		if h.is_empty() or int(h.g) != g:
			break
		out.append({"w": w, "g": g, "n": String(h.n), "s": int(h.s)})
		w -= 1
	return out


# --- Season close: who gets the pair ------------------------------------------------

## Members of guild g at time t with the hero as one of them (in its guild): [{name
## ("" the hero), class, level, stars, score}], strongest first (level, then stars: the
## same measure WorldPlayers.guild_leader uses).
static func members(g: int, t: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in WorldPlayers.members_at(g, t):
		var p := WorldPlayers.progress_at(i, t)
		out.append({"name": String(WorldPlayers.entry(i).name), "class": StringName(WorldPlayers.entry(i)["class"]), "level": int(p.level), "stars": int(p.stars), "score": int(p.level) * 1000 + int(p.stars)})
	if Game.has_profile and Game.guild() == g:
		var stars := int(Game.paragon().level)
		out.append({"name": "", "class": Game.class_id(), "level": int(Game.profile.level), "stars": stars, "score": int(Game.profile.level) * 1000 + stars})
	out.sort_custom(func(a, b): return int(a.score) > int(b.score) if int(a.score) != int(b.score) else String(a.name) < String(b.name))
	return out


## Who held a pair of the streak season w continues (the seasons before w of the same
## guild): names, "" the hero.
static func streak_names(w: int, g: int) -> Array[String]:
	var out: Array[String] = []
	var k := w - 1
	while true:
		var h := hold_of(k)
		if h.is_empty() or int(h.g) != g:
			break
		out.append(String(h.n))
		k -= 1
	return out


## Whom the hero as leader may hand season w's pair to: the champion's members (world
## players) who hold none of this streak, and the hero itself only while it holds none.
## [{name, class, level, stars, score, me}].
static func hand_choices(w: int) -> Array[Dictionary]:
	var p := pending(w)
	if p.is_empty():
		return []
	var g := int(p.g)
	var taken := streak_names(w, g)
	var out: Array[Dictionary] = []
	for m in members(g, GuildLeague.week_end(w)):
		if taken.has(String(m.name)):
			continue
		var row := m.duplicate()
		row["me"] = String(m.name) == ""
		out.append(row)
	return out


## The hero as leader hands season w's pair to `who` (a member's name, "" itself).
## "ok" or the reason.
static func hand_to(w: int, who: String) -> String:
	var choices := hand_choices(w)
	if choices.is_empty():
		return "ไม่มีปีกตำนานรอมอบ"
	var ok := false
	for c in choices:
		ok = ok or String(c.name) == who
	if not ok:
		return "มอบให้ตัวเองได้เมื่อยังไม่มีปีกตำนานของแชมป์ชุดนี้" if who == "" else "สมาชิกคนนี้รับไม่ได้"
	var d := record()
	var hand: Dictionary = d.get("hand", {})
	hand[str(w)] = who
	d["hand"] = hand
	Game.mark_dirty()
	tick()
	return "ok"


## A season whose pair waits for the hero as leader to hand it on: {w, g, s} or {}.
static func pending(w := -1) -> Dictionary:
	var d := record()
	if d.is_empty():
		return {}
	var next := int(d.get("done", -1)) + 1
	if w >= 0 and w != next:
		return {}
	var r := _resolve(next, GuildLeague.now())
	return {"w": next, "g": int(r.g), "s": int(r.s)} if bool(r.get("pending", false)) else {}


## Works out season w's holder (not yet recorded): {g, n, s} ({g: 0} for no champion,
## {pending: true, g, s} while the hero as leader has not handed it on).
static func _resolve(w: int, t: float) -> Dictionary:
	if w < FROM_WEEK or GuildLeague.week_end(w) > t:
		return {"g": 0}
	var champ := GuildLeague.league_champion_of(w, GuildLeague.real_wars(w))
	if champ <= 0:
		return {"g": 0}
	var close := GuildLeague.week_end(w)
	var prev := hold_of(w - 1)
	var streak := int(prev.get("s", 0)) + 1 if not prev.is_empty() and int(prev.g) == champ else 1
	var leader := Game.guild_war_leader(champ, close)
	if streak == 1:
		return {"g": champ, "n": leader, "s": 1, "by": leader}
	var taken := streak_names(w, champ)
	if leader == "":
		# The hero leads: it picks (hand_to), itself only while it holds none of the streak.
		var hand: Variant = (record().get("hand", {}) as Dictionary).get(str(w))
		if hand is String:
			var pick := String(hand)
			if not taken.has(pick) and (pick == "" or Game.is_guild_member(champ, pick, close)):
				return {"g": champ, "n": pick, "s": streak, "by": ""}
		return {"pending": true, "g": champ, "s": streak}
	# An AI leader: the strongest member without a pair of this streak, the hero counted.
	for m in members(champ, close):
		var n := String(m.name)
		if n == leader or taken.has(n):
			continue
		return {"g": champ, "n": n, "s": streak, "by": leader}
	return {"g": champ, "n": leader, "s": streak, "by": leader}


## Mints the pairs of every season closed since the last one worked out (at most
## MAX_BACK back, from FROM_WEEK): records the holder, gives the hero its pair (toast,
## world chat and the popup: Game.legend_wings_awarded) and announces the week's holder.
## Stops at a season the hero as leader has yet to hand on. Game._process calls it;
## true when a season was recorded now.
static func tick(t := -1.0) -> bool:
	if not Game.has_profile:
		return false
	if t < 0.0:
		t = GuildLeague.now()
	var d := record()
	var last_closed := GuildLeague.week_of(t) - 1
	var w := maxi(maxi(FROM_WEEK, int(d.get("done", -1)) + 1), last_closed - MAX_BACK + 1)
	var any := false
	while w <= last_closed:
		var r := _resolve(w, t)
		if bool(r.get("pending", false)):
			break
		var hold: Dictionary = d.get("hold", {})
		if int(r.g) > 0:
			hold[str(w)] = {"g": int(r.g), "n": String(r.n), "s": int(r.s)}
			_announce(w, hold[str(w)])
			if String(r.n) == "":
				_award_hero(w, int(r.g), int(r.s), String(r.get("by", "")))
		d["hold"] = hold
		d["done"] = w
		any = true
		w += 1
	if any:
		_prune(d)
		Game.mark_dirty()
	return any


static func _announce(w: int, h: Dictionary) -> void:
	var line := "ปีกตำนานฤดูกาลที่ %d: กิลด์ %s → %s%s" % [w, GuildLeague.name_of(int(h.g)), holder_label(h), " (แชมป์ติดต่อกัน %d สัปดาห์ หัวหน้ามอบให้สมาชิก)" % int(h.s) if int(h.s) > 1 else " (หัวหน้ากิลด์)"]
	Game.say(line, &"quest")
	Game.post_chat("world", ANNOUNCER, line, COLOR)


## The hero receives season w's pair (once an account: another character's pair of that
## week leaves this one out) and wears it at once.
static func _award_hero(w: int, g: int, streak: int, by := "") -> void:
	if account_weeks().has(w):
		Game.say("ปีกตำนานฤดูกาลที่ %d อยู่กับตัวละครอื่นในบัญชีนี้แล้ว" % w, &"warning")
		return
	var pair := item(w, g)
	give_to_hero(pair)
	var why := "หัวหน้ากิลด์ %s (%s) มอบปีกตำนานให้คุณ (แชมป์ลีกติดต่อกัน %d สัปดาห์)" % [GuildLeague.name_of(g), by, streak] if streak > 1 else "กิลด์ %s เป็นแชมป์ลีก คุณในฐานะหัวหน้ากิลด์ได้รับปีกตำนาน" % GuildLeague.name_of(g)
	var text := "%s\n%s\nใส่ให้แล้วทันที — %s" % [why, title_of(pair), LOCK_TEXT]
	Game.say("ได้รับ %s! ใส่ให้แล้ว" % NAME, &"success")
	Game.legend_wings_awarded.emit(pair, text)


## Puts a pair on the hero at once: the worn wings go to the bag, else the shared
## storage (a pair never goes missing: when both are full the old pair stays in the bag
## past its size until something is taken out).
static func give_to_hero(pair: Dictionary) -> void:
	var equip: Dictionary = Game.profile["equip"]
	var old: Variant = equip.get("wings")
	equip["wings"] = pair
	if old is Dictionary:
		var where := "กระเป๋า"
		if not Game.add_item(old):
			if SharedStorage.put(old):
				SharedStorage.store()
				where = "คลังรวม (กระเป๋าเต็ม)"
			else:
				Game.profile["inv"].append(old)
		Game.say("%s ถูกถอดไปไว้ที่%s" % [ItemData.name_of(old), where], &"info")
	Game.flag_max("got_mythic", 1)
	Game.clamp_vitals()
	Game.inventory_changed.emit()
	Game.profile_changed.emit()
	Game.mark_dirty()
	Game.title_changed.emit(Achievements.title_of(Game.profile))


## Old seasons drop off the record (the world players' pairs of the last KEEP_WEEKS stay).
static func _prune(d: Dictionary) -> void:
	var hold: Dictionary = d.get("hold", {})
	var hand: Dictionary = d.get("hand", {})
	var floor_week := int(d.get("done", 0)) - KEEP_WEEKS
	for key in hold.keys():
		if int(String(key)) < floor_week:
			hold.erase(key)
	for key in hand.keys():
		if int(String(key)) < floor_week:
			hand.erase(key)


# --- The world players' pairs (WorldGear) ----------------------------------------------

## The pair world player i holds (its latest), {} for none. Read from the record, so
## the player's gear, chat and card agree with the week's announcement.
static func ai_item(i: int) -> Dictionary:
	if not Game.has_profile or i < 0 or i >= WorldPlayers.size():
		return {}
	var hold: Dictionary = record().get("hold", {})
	var sig := "%d|%d" % [Game.slot, hold.hash()]
	if sig != _ai_sig:
		_ai_sig = sig
		_ai_items = {}
		var weeks: Array = hold.keys()
		weeks.sort_custom(func(a, b): return int(String(a)) < int(String(b)))
		for key in weeks:
			var h: Dictionary = hold[key]
			var n := String(h.get("n", ""))
			if n != "":
				var pair := item(int(String(key)), int(h.g))
				pair["uid"] = "legend-%s" % String(key)
				_ai_items[n] = pair
	var found: Variant = _ai_items.get(String(WorldPlayers.entry(i).name))
	return found if found is Dictionary else {}


## True when world player i holds a pair (the name plate tag).
static func ai_holds(i: int) -> bool:
	return not ai_item(i).is_empty()


# --- The save ------------------------------------------------------------------------

static func _week_key(k: Variant) -> bool:
	return k is String and String(k).is_valid_int() and int(String(k)) >= 0 and int(String(k)) <= MAX_WEEK


## profile.legend_wings is well formed.
static func valid_record(v: Variant) -> bool:
	if not v is Dictionary or (v as Dictionary).size() > 3:
		return false
	for k in v:
		if not k is String:
			return false
		match String(k):
			"done":
				if not Game._valid_integer(v[k], -1, MAX_WEEK):
					return false
			"hold":
				if not v[k] is Dictionary or (v[k] as Dictionary).size() > MAX_RECORDS:
					return false
				for key in v[k]:
					var h: Variant = v[k][key]
					if not _week_key(key) or not h is Dictionary or (h as Dictionary).size() != 3:
						return false
					if not Game._valid_integer(h.get("g"), 1, 4) or not h.get("n", 0) is String or String(h.n).length() > Game.GUILD_LEADER_NAME_MAX or not Game._valid_integer(h.get("s"), 1, MAX_WEEK):
						return false
			"hand":
				if not v[k] is Dictionary or (v[k] as Dictionary).size() > MAX_RECORDS:
					return false
				for key in v[k]:
					if not _week_key(key) or not v[k][key] is String or String(v[k][key]).length() > Game.GUILD_LEADER_NAME_MAX:
						return false
			_:
				return false
	return true


## Numbers back to ints (JSON reads them as floats); a broken record is dropped.
static func repair(profile: Dictionary) -> void:
	if not profile.has(KEY):
		return
	if not valid_record(profile[KEY]):
		profile.erase(KEY)
		return
	var d: Dictionary = profile[KEY]
	if d.has("done"):
		d["done"] = int(d.done)
	for key in d.get("hold", {}):
		var h: Dictionary = d.hold[key]
		h["g"] = int(h.g)
		h["s"] = int(h.s)
