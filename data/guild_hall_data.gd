class_name GuildHallData
extends RefCounted
## The guild halls (โถงกิลด์): one zone a guild (id_of: "guild_hall_<guild>"), the same
## hall in each guild's colours, entered from the guild screen ("เข้าโถงกิลด์") or the
## door in front of the village keep, and only by that guild's members (enter_problem).
## Inside (GuildHall builds it): the crest, a trophy wall of the league's real history
## (trophies: the weeks the guild was แชมป์ลีก, ราชันปราสาท or จักรพรรดิ, from GuildLeague's
## frozen records), the war roster (roster: the GUILD_SIDE strongest, by power), the steward
## พ่อบ้านกิลด์ (the hall's blessing, the next war and registration), the leader's notice
## (notice / set_notice: the hero writes it when it leads, else the AI leader's own
## deterministic line), a training dummy (TrainingDummy) and the rest area that grants
## the blessing. Guild mates (mates) idle and chat in the hall (HallMate).
## The blessing พรแห่งโถงกิลด์ (grant): +EXP% and +ATK% for BUFF_TIME after a rest, its
## tier the guild's placement in the current league table (1st the biggest), applied in
## Game.add_exp / Game.stats_now and shown as the HUD's event chip (chip_text). It is
## granted once per BUFF_TIME: while it runs the rest area says how long is left.
## profile.flags: FLAG_UNTIL (unix end), FLAG_TIER (1-4); profile.hall_notice: the
## hero's notice as leader (NOTICE_MAX characters).

const ID_PREFIX := "guild_hall_"
const TITLE := "โถงกิลด์"
const STEWARD := "พ่อบ้านกิลด์"
const MUSIC := &"dawn_forest"

const BUFF_NAME := "พรแห่งโถงกิลด์"
const BUFF_TIME := 30 * 60
const FLAG_UNTIL := "hall_until"
const FLAG_TIER := "hall_tier"
## By league placement (1st first): [EXP bonus, ATK bonus].
const TIERS: Array = [[0.20, 0.10], [0.15, 0.08], [0.10, 0.05], [0.05, 0.03]]

const NOTICE_KEY := "hall_notice"
const NOTICE_MAX := 160
const NOTICE_EMPTY := "ยังไม่มีประกาศ — หัวหน้ากิลด์เขียนได้ที่กระดานนี้"

## Guild mates shown in the hall at once, by quality (low, medium, high).
const MATES: Array[int] = [6, 8, 12]
const MATES_PRESSURE := 6


# --- Zones --------------------------------------------------------------------------

static func id_of(g: int) -> StringName:
	return StringName("%s%d" % [ID_PREFIX, g])


## The guild whose hall `id` is (0 for any other zone).
static func guild_of(id: StringName) -> int:
	var s := String(id)
	if not s.begins_with(ID_PREFIX):
		return 0
	var tail := s.substr(ID_PREFIX.length())
	if not tail.is_valid_int():
		return 0
	var g := int(tail)
	return g if WorldPlayers.GUILD_NAMES.has(g) else 0


static func is_hall(id: StringName) -> bool:
	return guild_of(id) > 0


## The zone record of guild g's hall (ZoneData.get_zone gives it; not in ZoneData.ZONES:
## never walked to, never a warp destination, never a save's resume zone).
static func zone(id: StringName) -> Dictionary:
	var g := guild_of(id)
	var color: Color = WorldPlayers.GUILD_COLORS.get(g, Color.WHITE)
	return {
		"name": "%s %s" % [TITLE, WorldPlayers.guild_name(g)], "scene": "hall", "safe": true, "hall": true, "guild": g,
		"level": [1, 100], "music": MUSIC, "theme": &"village", "tree_density": 0.0, "camps": [],
		"sky": Color("2b2438"), "ground": Color("8a6a4a"), "prev": &"town", "next": &"", "color": color,
	}


## Why the hero may not go into hall `id` now ("" when it may): only that guild's members.
static func enter_problem(id: StringName) -> String:
	var g := guild_of(id)
	if g <= 0:
		return "ไม่มีโถงกิลด์นี้"
	if not Game.has_profile:
		return "ยังไม่มีตัวละคร"
	var mine := Game.guild()
	if mine <= 0:
		return "โถงกิลด์เปิดให้เฉพาะสมาชิกกิลด์ — เข้ากิลด์ที่นายทะเบียนกิลด์ (เลเวล %d) ก่อน" % Game.GUILD_LEVEL
	if mine != g:
		return "โถงนี้เป็นของกิลด์ %s — เข้าได้เฉพาะสมาชิกกิลด์ %s เท่านั้น" % [WorldPlayers.guild_name(g), WorldPlayers.guild_name(g)]
	return ""


## The hall the hero may enter now (its own guild's), "" outside a guild.
static func hero_hall() -> StringName:
	var g := Game.guild()
	return id_of(g) if g > 0 else &""


static func now() -> float:
	return WorldPresence.clock()


# --- The blessing (พรแห่งโถงกิลด์) ------------------------------------------------

## Guild g's placement in the current league table (1 best, 4 last).
static func placement(g: int, t := -1.0) -> int:
	if t < 0.0:
		t = now()
	var w := GuildLeague.week_of(t)
	var rank := GuildLeague.rank_of(w, GuildLeague.real_wars(w) if Game.has_profile else [], g)
	return clampi(rank, 1, TIERS.size()) if rank > 0 else TIERS.size()


static func tier_bonus(tier: int) -> Array:
	return TIERS[clampi(tier, 1, TIERS.size()) - 1]


## Seconds the blessing still runs (0 when none).
static func left(t := -1.0) -> float:
	if not Game.has_profile:
		return 0.0
	if t < 0.0:
		t = now()
	return maxf(0.0, float(Game.profile.get("flags", {}).get(FLAG_UNTIL, 0)) - t)


static func active(t := -1.0) -> bool:
	return left(t) > 0.0


## The running blessing's tier (1-4), 0 when none runs.
static func tier(t := -1.0) -> int:
	if not active(t):
		return 0
	return clampi(int(Game.profile.get("flags", {}).get(FLAG_TIER, TIERS.size())), 1, TIERS.size())


static func exp_bonus(t := -1.0) -> float:
	var k := tier(t)
	return float(tier_bonus(k)[0]) if k > 0 else 0.0


static func atk_bonus(t := -1.0) -> float:
	var k := tier(t)
	return float(tier_bonus(k)[1]) if k > 0 else 0.0


## The EXP multiplier of the running blessing (Game.add_exp).
static func exp_mult(t := -1.0) -> float:
	return 1.0 + exp_bonus(t)


## Rests in the hall: the blessing of the guild's current placement for BUFF_TIME. "ok",
## or why not (outside a guild, or one still running: once per BUFF_TIME).
static func grant(t := -1.0) -> String:
	if t < 0.0:
		t = now()
	var g := Game.guild()
	if not Game.has_profile or g <= 0:
		return "ต้องเป็นสมาชิกกิลด์ก่อน"
	var remain := left(t)
	if remain > 0.0:
		return "ยังมี%sอยู่ (เหลือ %d นาที) — รับใหม่ได้เมื่อหมดเวลา" % [BUFF_NAME, maxi(1, int(ceil(remain / 60.0)))]
	var k := placement(g, t)
	Game.profile["flags"][FLAG_UNTIL] = int(round(t)) + BUFF_TIME
	Game.profile["flags"][FLAG_TIER] = k
	Game.mark_dirty()
	return "ok"


static func tier_text(k: int) -> String:
	var b := tier_bonus(k)
	return "ระดับ %d (อันดับลีก %d): EXP +%d%% โจมตี +%d%%" % [k, k, int(round(float(b[0]) * 100.0)), int(round(float(b[1]) * 100.0))]


## The HUD event chip's line while the blessing runs ("" otherwise).
static func chip_text(t := -1.0) -> String:
	if t < 0.0:
		t = now()
	var remain := left(t)
	if remain <= 0.0:
		return ""
	var b := tier_bonus(tier(t))
	return "✦ %s ระดับ %d EXP +%d%% โจมตี +%d%% เหลือ %d นาที" % [BUFF_NAME, tier(t), int(round(float(b[0]) * 100.0)), int(round(float(b[1]) * 100.0)), maxi(1, int(ceil(remain / 60.0)))]


# --- The trophy wall --------------------------------------------------------------------

## The first league season (the world's opening week).
static func first_week() -> int:
	return GuildLeague.week_of(float(WorldPlayers.START_UNIX))


## The seasons over by t in which guild g held each title, oldest first: {"league": [weeks],
## "castle": [weeks], "emperor": [weeks]} (GuildLeague's records: the same on every device).
static func trophies(g: int, t := -1.0) -> Dictionary:
	if t < 0.0:
		t = now()
	var out := {"league": [], "castle": [], "emperor": []}
	var last := GuildLeague.week_of(t) - 1
	for w in range(first_week(), last + 1):
		var real := GuildLeague.real_wars(w) if Game.has_profile else []
		if GuildLeague.league_champion_of(w, real) == g:
			(out.league as Array).append(w)
		if GuildLeague.champion_of(w, real) == g:
			(out.castle as Array).append(w)
		if GuildLeague.emperor_of(w, real) == g:
			(out.emperor as Array).append(w)
	return out


## "สัปดาห์ที่ 3" style name of season w, counted from the opening.
static func week_name(w: int) -> String:
	return "สัปดาห์ที่ %d" % (w - first_week() + 1)


## The trophy wall's lines: one per title with its count and the latest weeks.
static func trophy_lines(g: int, t := -1.0) -> PackedStringArray:
	var tr := trophies(g, t)
	var out := PackedStringArray()
	for spec in [["league", GuildLeague.LEAGUE_TITLE], ["castle", GuildLeague.CASTLE_TITLE], ["emperor", GuildLeague.EMPEROR_TITLE]]:
		var weeks: Array = tr[spec[0]]
		var line := "%s: %d สัปดาห์" % [spec[1], weeks.size()]
		if not weeks.is_empty():
			var names := PackedStringArray()
			for w in weeks.slice(maxi(0, weeks.size() - 4)):
				names.append(week_name(int(w)))
			line += " (%s)" % ", ".join(names)
		out.append(line)
	if (tr.league as Array).is_empty() and (tr.castle as Array).is_empty():
		out.append("ยังไม่มีถ้วยรางวัล — ชนะลีกสัปดาห์นี้แล้วมาวางที่นี่!")
	return out


# --- The war roster ------------------------------------------------------------------

## Guild g's war side at t (GuildWarData.side_ids: its GUILD_SIDE strongest, the hero when
## it ranks among them), strongest power first: [{name, tag, power, hero}].
static func roster(g: int, t := -1.0) -> Array[Dictionary]:
	if t < 0.0:
		t = now()
	var rows: Array[Dictionary] = []
	var hero_point := GuildWarData.hero_rank_point() if Game.guild() == g else -1.0
	var side := GuildWarData.side_ids(g, t, hero_point)
	for i in side.ids:
		var f := WorldPlayers.fighter(i, t)
		rows.append({"name": String(f.member.name), "tag": String(f.tag), "power": float(f.power), "hero": false})
	if bool(side.hero):
		var stars := int(Game.paragon().level)
		rows.append({"name": String(Game.profile.get("name", "คุณ")), "tag": "Lv.%d%s" % [int(Game.profile.level), " ★%d" % stars if stars > 0 else ""],
			"power": GuildWarData.hero_power(), "hero": true})
	rows.sort_custom(func(a, b): return float(a.power) > float(b.power) or (float(a.power) == float(b.power) and String(a.name) < String(b.name)))
	return rows


static func power_text(p: float) -> String:
	if p >= 1000000.0:
		return "%.1fM" % (p / 1000000.0)
	if p >= 10000.0:
		return "%.0fK" % (p / 1000.0)
	return "%d" % int(round(p))


# --- The steward -------------------------------------------------------------------------

## The steward's word on the next war: its time, the countdown, the hero's registration
## and whether it makes the line-up.
static func war_text(t := -1.0) -> String:
	if t < 0.0:
		t = now()
	var live := GuildLeague.live_slot(t)
	var next := GuildLeague.next_slot(t)
	var g := Game.guild()
	var out := ""
	if live >= 0:
		out = "สงครามกิลด์รอบ %s กำลังรบอยู่ตอนนี้! " % GuildLeague.clock_text(live)
	out += "รอบถัดไป %s (อีก %s) — %s" % [GuildLeague.clock_text(next), GuildLeague.until_text(next, t), GuildLeague.owner_text(next)]
	if g > 0:
		var place := GuildLeague.hero_place(next)
		out += " · อันดับของเจ้าในกิลด์ #%d %s" % [place, "ติดตัวจริง %d คน" % GuildWarData.GUILD_SIDE if place > 0 and place <= GuildWarData.GUILD_SIDE else "(ยังไม่ติดตัวจริง %d คน ชมได้)" % GuildWarData.GUILD_SIDE]
		out += " · %s" % ("สมัครรอบนี้แล้ว ✓" if GuildLeague.registered(next) else "ยังไม่ได้สมัครรอบนี้")
	return out


## The steward's word on the blessing: the guild's placement now and what the rest gives.
static func buff_text(g: int, t := -1.0) -> String:
	if t < 0.0:
		t = now()
	var k := placement(g, t)
	var line := "%s: นั่งพักที่ลานพักของโถง แล้วรับพร %d นาที — ระดับพรตามอันดับลีกของกิลด์ตอนนี้ (อันดับ 1 แรงสุด) ตอนนี้กิลด์ %s อยู่อันดับ %d: %s" % [
		BUFF_NAME, BUFF_TIME / 60, WorldPlayers.guild_name(g), k, tier_text(k)]
	var remain := left(t)
	if remain > 0.0:
		line += " · พรของเจ้ายังอยู่อีก %d นาที" % maxi(1, int(ceil(remain / 60.0)))
	return line


# --- The notice --------------------------------------------------------------------------

## The hero leads guild g (it may write the notice).
static func hero_writes(g: int, t := -1.0) -> bool:
	return Game.has_profile and Game.hero_leads_guild(g, t)


## The guild's notice on the hall's board: {text, by (the leader's name), mine (the hero
## wrote it or may)}. The hero's own when it leads (NOTICE_EMPTY before it wrote one), else
## the AI leader's deterministic line of the week (ai_notice).
static func notice(g: int, t := -1.0) -> Dictionary:
	if t < 0.0:
		t = now()
	if hero_writes(g, t):
		var text := String(Game.profile.get(NOTICE_KEY, "")).strip_edges()
		return {"text": text if text != "" else NOTICE_EMPTY, "by": String(Game.profile.get("name", "")), "mine": true, "empty": text == ""}
	var leader := Game.guild_leader_name(g, t) if Game.has_profile else WorldPlayers.guild_leader(g, t)
	if leader == "":
		leader = WorldPlayers.guild_leader(g, t)
	return {"text": ai_notice(g, leader, t), "by": leader if leader != "" else "หัวหน้ากิลด์", "mine": false, "empty": false}


## Writes the hero's notice (the leader of its guild only). "ok" or why not.
static func set_notice(text: String, t := -1.0) -> String:
	if not Game.has_profile:
		return "ยังไม่มีตัวละคร"
	var g := Game.guild()
	if g <= 0 or not hero_writes(g, t):
		return "เฉพาะหัวหน้ากิลด์เท่านั้นที่เขียนประกาศได้"
	var clean := text.strip_edges().replace("\n", " ")
	if clean.length() > NOTICE_MAX:
		return "ประกาศยาวเกินไป (ไม่เกิน %d ตัวอักษร)" % NOTICE_MAX
	Game.profile[NOTICE_KEY] = clean
	Game.mark_dirty()
	return "ok"


const AI_NOTICES: Array[String] = [
	"พี่น้อง %s ทุกคน รอบ %s วันนี้ขอให้ทุกคนที่ติดตัวจริงมาพร้อมกัน ยาเต็มกระเป๋า เราจะเอาปราสาทมาให้ได้!",
	"ประกาศจากหัวหน้า: ตอนนี้ %s อยู่อันดับ %d ของลีก ใครว่างช่วยกันทำภารกิจกิลด์รายวันด้วย แต้มกิลด์แลกของดีได้",
	"%s ปราสาทตอนนี้%s — รอบ %s เราจะไปเอาคืน ใครยังไม่ครบ 200 ดาวไปเก็บต่อก่อน แล้วมารวมพลที่โถง",
	"ขอบคุณทุกคนที่ลงสนามสัปดาห์นี้ %s จะต้องเป็น%s ให้ได้ อย่าลืมมารับพรแห่งโถงก่อนออกล่าทุกครั้ง",
	"ใครเจอมือใหม่เข้า %s ช่วยพาเก็บดาวหน่อย ปาร์ตี้ 3 คนแบ่ง EXP กันคุ้มกว่า ส่วนตัวจริงสงคราม ซ้อมกับหุ่นในโถงได้ตลอด",
	"นัดรวมพล: รอบ %s เวลาไทย เจอกันหน้าผู้บัญชาการสงครามกิลด์ก่อนปิดรับสมัคร 5 นาที %s สู้ ๆ!",
	"หัวหน้าฝากไว้: อันดับลีกตอนนี้ %d พรแห่งโถงยังให้ EXP ดีอยู่ ใครกำลังปั้นดาวมานั่งพักก่อนออกไปล่าทุกครั้ง",
	"%s ไม่ทิ้งกัน ใครโดนรุมในสนามให้ถอยมาที่ป้อมของเรา ผู้พิทักษ์ยืนหน้า นักบวชตามหลัง แล้วค่อยบุกยึดแท่นด้วยกัน",
]


## The AI leader's notice for guild g this season: the same on every device (from the
## guild, the season and the leader's name), filled with the week's real facts.
static func ai_notice(g: int, leader: String, t := -1.0) -> String:
	if t < 0.0:
		t = now()
	var w := GuildLeague.week_of(t)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("hall_notice|%d|%d|%s" % [g, w, leader])
	var line: String = AI_NOTICES[rng.randi() % AI_NOTICES.size()]
	var next := GuildLeague.next_slot(t)
	var holder := GuildLeague.holder(w, GuildLeague.real_wars(w) if Game.has_profile else [])
	var name := WorldPlayers.guild_name(g)
	var castle := "เป็นของกิลด์ %s" % WorldPlayers.guild_name(holder) if holder > 0 and holder != g else ("เป็นของเราแล้ว" if holder == g else "ยังว่าง")
	var rank := placement(g, t)
	var fills: Array = []
	match AI_NOTICES.find(line):
		0: fills = [name, GuildLeague.clock_text(next)]
		1: fills = [name, rank]
		2: fills = [name, castle, GuildLeague.clock_text(next)]
		3: fills = [name, GuildLeague.LEAGUE_TITLE if rank > 1 else GuildLeague.EMPEROR_TITLE]
		4: fills = [name]
		5: fills = [GuildLeague.clock_text(next), name]
		6: fills = [rank]
		7: fills = [name]
	var text := line % fills
	return "%s — %s" % [text, leader] if leader != "" else text


# --- The mates in the hall ----------------------------------------------------------------

## How many guild mates the hall shows now (quality and memory pressure).
static func mates_limit() -> int:
	if GameSettings.safe_picture or not GameSettings.show_world_players:
		return 0
	var n := int(MATES[clampi(GameSettings.quality, 0, 2)])
	if MemoryGuard.pressure > 0:
		n = mini(n, MATES_PRESSURE)
	return n


## The guild mates idling in guild g's hall at t: its members (Lv.100), the ones online
## at the top of the hour first, in an order that turns with the hour, at most `count`
## (the same hall for the whole hour on every device).
static func mates(g: int, t := -1.0, count := -1) -> Array[int]:
	if t < 0.0:
		t = now()
	if count < 0:
		count = mates_limit()
	var hour := floorf(t / 3600.0) * 3600.0
	var members := WorldPlayers.members_at(g, hour)
	if members.is_empty() or count <= 0:
		return []
	var turn := int(hour / 3600.0) % members.size()
	var online: Array[int] = []
	var rest: Array[int] = []
	for k in members.size():
		var i: int = members[(k + turn) % members.size()]
		if WorldPlayers.session_at(i, hour).is_empty():
			rest.append(i)
		else:
			online.append(i)
	var out: Array[int] = online
	out.append_array(rest)
	out.resize(mini(out.size(), count))
	return out


const CHATTER: Array[String] = [
	"มารับพรแห่งโถงก่อนออกล่าดีกว่า EXP เพิ่มตั้ง %d%%",
	"รอบ %s นี้ใครติดตัวจริงบ้าง ไปพร้อมกันนะ",
	"ปราสาท%s — รอบหน้าเราต้องยึดให้ได้",
	"ซ้อมกับหุ่นแล้วได้ DPS เท่าไหร่กันบ้าง 555",
	"หัวหน้า %s ประกาศไว้ที่กระดาน ไปอ่านกันหน่อย",
	"%s อันดับ %d ของลีก ยังไหวอยู่ สู้ ๆ",
	"ใครยังไม่ครบ 200 ดาว เดี๋ยวพาไปสำนักบัวเก็บต่อ",
	"โถงเราสวยสุดในสี่กิลด์เลยว่าไหม",
	"อย่าลืมภารกิจกิลด์รายวันนะ แต้มใกล้แลกชุดได้แล้ว",
	"นั่งพักแป๊บ เดี๋ยวออกไปล่าต่อ",
]


## What guild mate i says in the hall at t (the same on every device, by the minute).
static func chatter(i: int, g: int, t := -1.0) -> String:
	if t < 0.0:
		t = now()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("hall_chat|%d|%d|%d" % [i, g, int(t / 60.0)])
	var k := rng.randi() % CHATTER.size()
	var w := GuildLeague.week_of(t)
	var holder := GuildLeague.holder(w, GuildLeague.real_wars(w) if Game.has_profile else [])
	var castle := "เป็นของ %s" % WorldPlayers.guild_name(holder) if holder > 0 and holder != g else ("เป็นของเราอยู่" if holder == g else "ยังว่าง")
	var leader := Game.guild_leader_name(g, t) if Game.has_profile else WorldPlayers.guild_leader(g, t)
	if leader == "":
		leader = String(Game.profile.get("name", "")) if Game.has_profile and Game.guild() == g else WorldPlayers.guild_leader(g, t)
	var rank := placement(g, t)
	match k:
		0: return CHATTER[k] % int(round(float(tier_bonus(rank)[0]) * 100.0))
		1: return CHATTER[k] % GuildLeague.clock_text(GuildLeague.next_slot(t))
		2: return CHATTER[k] % castle
		4: return CHATTER[k] % leader
		5: return CHATTER[k] % [WorldPlayers.guild_name(g), rank]
	return CHATTER[k]
