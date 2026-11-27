class_name AscensionData
extends RefCounted
## บททดสอบเทวาลัย: the ★500 job change (เปลี่ยนอาชีพขั้นที่ 6, JobData.ASCEND_ADV). The
## celestial sage in the village (ROLE, beside the Job Master) gives it to a God at ★500
## (JobData.ASCEND_STARS) and walks the hero through three steps:
##   1 hunt   defeat HUNT_COUNT elite monsters of ดินแดนเทวาลัย (HeavenMonsters.ELITES, its
##            boss counts BOSS_WORTH); without that bestiary, any monster of the highest
##            star fields (hunt_zones) counts;
##   2 tokens collect TOKEN_COUNT ตราเทวาลัย, dropped by those same monsters (TOKEN_CHANCE,
##            a boss BOSS_TOKENS);
##   3 trial  enter the solo stage ลานบททดสอบเทวาลัย (STAGE_ID, AscendTrial) and defeat
##            the guardian (BOSS_ID) before it grows enraged (ENRAGE_SECONDS).
## Winning promotes the hero (promote): adv 6, its grand title (JobData.ascend_step), the
## two Ascension skills (AscendSkillData), ASCEND_SKILL_POINTS and the celebration. Falling
## in the trial is the game's ordinary death; the sage lets the hero try again any time.
## AI world players are held to the same rule: ★500 alone is no Ascension. Each walks the
## steps at its own pace and then fights the guardian itself, a try about every session of
## its play, won or lost by what it really has then against MONSTERS' guardian (its HP,
## blows, FLOOR_SHARE, the enrage) on a seeded roll (WorldPlayers.ascended_at, the same on
## every device): the strong pass in a few tries, the weak keep failing, some never pass.
## Only a pass makes it Ascended (JobData.adv_for's ascended); the Announcer tells it.
##
## State lives in Game.profile.flags (integers only): STEP_FLAG (0 not taken, 1..3 the
## step, DONE once promoted), KILLS_FLAG, TOKENS_FLAG and TRIES_FLAG (trial attempts).

const TITLE := "บททดสอบเทวาลัย"
const ROLE := "celestial_sage"
const SAGE := "เทวฤๅษีอนันตคุณ"
const SAGE_TITLE := "บททดสอบเทวาลัย · เปลี่ยนอาชีพขั้นที่ 6"
const STAGE_ID: StringName = &"celestial_trial"
const STAGE_TITLE := "ลานบททดสอบเทวาลัย"
const HEAVEN_ID: StringName = &"heaven_realm"
const HEAVEN_NAME := "ดินแดนเทวาลัย"
const TOKEN_NAME := "ตราเทวาลัย"
const STEP_FLAG := "asc_step"
const KILLS_FLAG := "asc_kills"
const TOKENS_FLAG := "asc_tokens"
const TRIES_FLAG := "asc_tries"
const HUNT := 1
const TOKENS := 2
const TRIAL := 3
const DONE := 4
const HUNT_COUNT := 30
const BOSS_WORTH := 5
const TOKEN_COUNT := 12
const TOKEN_CHANCE := 0.35
const BOSS_TOKENS := 3
## The promotion's purse on top of the step itself.
const REWARD_GOLD := 5000000
## The trial guardian: a class-agnostic god of the halls, fought alone.
const BOSS_ID: StringName = &"trial_guardian"
const BOSS_NAME := "อนันตเทวะ ผู้พิทักษ์เทวาลัย"
## Past this the guardian is enraged: its blows and moves grow far stronger and faster.
const ENRAGE_SECONDS := 300.0
const ENRAGE_ATK := 2.5
## The guardian tests the hero, however well geared: a blow at its own base strength takes
## at least FLOOR_SHARE of the hero's max HP before the hero's guard and shields (a move
## of k times its strength k times that; enraged, ENRAGE_ATK times). The owner found a
## +15 ★500 hero took about 1% a blow; at 15% it hit 40k a blow in a row (too much): 6%.
## FLOOR_META on the guardian holds its base attack.
const FLOOR_SHARE := 0.06
## ... and the floor never grows past FLOOR_MAX_SCALE times that (15%): the story moves
## already hit a share of max HP of their own (StoryBoss.HIT_FRACTION, 35%), and their raw
## blow, many times the guardian's attack, once made the floor over 100% (300k+ on the
## owner's hero).
const FLOOR_MAX_SCALE := 2.5
const FLOOR_META := &"hp_floor_atk"
const STEPS := [
	{"name": "ล่าผู้พิทักษ์แห่งเทวาลัย", "desc": "ปราบมอนสเตอร์ชั้นยอดในดินแดนเทวาลัย %d ตัว (บอสนับ %d)"},
	{"name": "ตราแห่งเทวาลัย", "desc": "เก็บตราเทวาลัย %d ชิ้นจากมอนสเตอร์ในดินแดนเทวาลัย"},
	{"name": "ลานบททดสอบเทวาลัย", "desc": "เข้าลานบททดสอบเพียงลำพัง แล้วปราบอนันตเทวะ ผู้พิทักษ์เทวาลัย ก่อนมันคลั่ง (%d วินาที)"},
]
## The guardian: tuned as the top star field's boss (home_of), about 1.25x the health of
## the heaven realm's boss and a softer blow (ascension_test's probe: a ★500 Star500 set
## with its points spent takes about a fifth of its HP a blow, a third from the heaven
## boss), so the fight is long rather than a one-shot, with the field bosses'
## light moves (BossAttack sun_pillars / solar_wedge) and the story bosses' telegraphed
## nova / lance / rain / veil (StoryBoss, AscendTrial); ten times the design health like
## the endgame fields (EndgameFields.TOUGH_HP).
const MONSTERS := {
	&"trial_guardian": {"name": BOSS_NAME, "model": "remaster/big/Demon_void_emperor", "height": 7.8, "hp": 53.0, "atk": 2.8, "def": 3.4, "speed": 3.0,
		"aggro": true, "attack": "melee", "boss": true, "tint": Color(2.1, 1.75, 0.95), "color": Color("ffd86a"),
		"behavior": "sun_pillars", "behavior2": "solar_wedge", "exp": 6.0, "gold": 10.0},
}
## The adds the guardian's veil calls: the fallen host of the sky city.
const ADDS: Array[StringName] = [&"fallen_angel"]


static func has_monster(id: StringName) -> bool:
	return MONSTERS.has(id)


static func monster(id: StringName) -> Dictionary:
	var m: Dictionary = MONSTERS.get(id, {}).duplicate(true)
	if not m.is_empty():
		m.hp = float(m.hp) * EndgameFields.TOUGH_HP
	return m


## The field whose tuning the guardian fights with: the heaven realm when it is tuned,
## else the ★300 sky isle.
static func home_of(_id: StringName) -> StringName:
	return HEAVEN_ID if MonsterData.ZONE_TUNING.has(HEAVEN_ID) else SkyIsleData.ID


## Where the hunt counts: ดินแดนเทวาลัย when the world has it, else the highest star fields.
static func hunt_zones() -> Array[StringName]:
	ZoneData.ensure()
	if ZoneData.ZONES.has(HEAVEN_ID):
		return [HEAVEN_ID]
	return [SkyIsleData.ID, DrownedAbyssData.ID]


## The heaven realm's bestiary (HeavenMonsters, read by path so this file stands without
## it): {all: {id: true}, elites: {id: true}, boss: id}; empty without it.
const HEAVEN_BESTIARY := "res://data/heaven_monsters.gd"
static var _heaven: Dictionary = {}
static func heaven() -> Dictionary:
	if not _heaven.is_empty():
		return _heaven
	_heaven = {"all": {}, "elites": {}, "boss": &""}
	if ResourceLoader.exists(HEAVEN_BESTIARY):
		var script := load(HEAVEN_BESTIARY) as GDScript
		var table: Dictionary = script.get_script_constant_map() if script else {}
		if table.get("MONSTERS") is Dictionary:
			for id in table.MONSTERS:
				_heaven.all[StringName(id)] = true
		for id in table.get("ELITES", []):
			_heaven.elites[StringName(id)] = true
		_heaven.boss = StringName(table.get("BOSS", &""))
	return _heaven


static func heaven_monsters() -> Dictionary:
	return heaven().all


## Whether the hunt asks for the heaven realm's elites (its bestiary exists).
static func elite_hunt() -> bool:
	return not (heaven().elites as Dictionary).is_empty()


static func hunt_place() -> String:
	ZoneData.ensure()
	if ZoneData.ZONES.has(HEAVEN_ID):
		return String(ZoneData.ZONES[HEAVEN_ID].get("name", HEAVEN_NAME))
	return "%s / %s" % [String(ZoneData.get_zone(SkyIsleData.ID).get("name", "")), String(ZoneData.get_zone(DrownedAbyssData.ID).get("name", ""))]


# --- State -----------------------------------------------------------------------------

static func _flags() -> Dictionary:
	if not Game.profile.has("flags") or not Game.profile.flags is Dictionary:
		Game.profile["flags"] = {}
	return Game.profile.flags


static func step() -> int:
	if Game.has_profile and JobData.is_ascended(Game.adv()):
		return DONE
	return int(_flags().get(STEP_FLAG, 0))


static func kills() -> int:
	return int(_flags().get(KILLS_FLAG, 0))


static func tokens() -> int:
	return int(_flags().get(TOKENS_FLAG, 0))


static func tries() -> int:
	return int(_flags().get(TRIES_FLAG, 0))


## Why the trial cannot be taken yet ("" when it can): a God at Lv.100 with ★500.
static func start_problem() -> String:
	if not Game.has_profile or Game.class_id() == ClassData.LEGACY:
		return "ยังไม่มีอาชีพ"
	if JobData.is_ascended(Game.adv()):
		return "ผ่านบททดสอบเทวาลัยแล้ว"
	if Game.adv() < JobData.GOD_ADV:
		return "ต้องเปลี่ยนอาชีพขั้นเทพเจ้าก่อน (%s)" % JobData.god_name(Game.class_id())
	if int(Game.paragon().level) < JobData.ASCEND_STARS:
		return "ต้องดาว %d (ตอนนี้ดาว %d)" % [JobData.ASCEND_STARS, int(Game.paragon().level)]
	return ""


## Takes the trial from the sage. False when refused or already taken.
static func start() -> bool:
	if start_problem() != "" or step() != 0:
		return false
	var flags := _flags()
	flags[STEP_FLAG] = HUNT
	flags[KILLS_FLAG] = 0
	flags[TOKENS_FLAG] = 0
	Game.say("รับ%s! ขั้นที่ 1: %s" % [TITLE, objective_text()], &"quest")
	Game.quest_changed.emit()
	Game.mark_dirty()
	return true


## The current step's objective for the tracker and the sage.
static func objective_text() -> String:
	match step():
		HUNT: return "ปราบ%sที่%s %d/%d" % ["มอนสเตอร์ชั้นยอด" if elite_hunt() else "มอนสเตอร์", hunt_place(), mini(kills(), HUNT_COUNT), HUNT_COUNT]
		TOKENS: return "เก็บ%s %d/%d จากมอนสเตอร์ที่%s" % [TOKEN_NAME, mini(tokens(), TOKEN_COUNT), TOKEN_COUNT, hunt_place()]
		TRIAL: return "เข้า%s (คุยกับ%s) ปราบ%s" % [STAGE_TITLE, SAGE, BOSS_NAME]
		DONE: return "ผ่าน%sแล้ว" % TITLE
	return ""


## The HUD tracker line ("" when the trial is not under way).
static func tracker_line() -> String:
	var s := step()
	if s <= 0 or s >= DONE:
		return ""
	return "%s (%d/3): %s" % [TITLE, s, objective_text()]


## How much a kill moves the hunt (0: it does not count): the heaven realm's elites 1 and
## its boss BOSS_WORTH; without that bestiary any monster of the hunt zones (a boss BOSS_WORTH).
static func hunt_worth(monster_id: StringName, is_boss := false) -> int:
	if elite_hunt():
		if monster_id == StringName(heaven().boss):
			return BOSS_WORTH
		return 1 if (heaven().elites as Dictionary).has(monster_id) else 0
	if not Game.current_zone in hunt_zones():
		return 0
	return BOSS_WORTH if is_boss else 1


## Whether a kill can drop a token: any monster of the heaven realm (or the hunt zones).
static func _counts(monster_id: StringName) -> bool:
	return Game.current_zone in hunt_zones() or heaven_monsters().has(monster_id)


## Game.report_kill: the hunt and the tokens count kills in the heaven realm.
static func on_kill(monster_id: StringName, is_boss := false, rng: RandomNumberGenerator = null) -> void:
	if not Game.has_profile or monster_id == BOSS_ID:
		return
	var s := step()
	if s != HUNT and s != TOKENS:
		return
	var flags := _flags()
	if s == HUNT:
		var worth := hunt_worth(monster_id, is_boss)
		if worth <= 0:
			return
		flags[KILLS_FLAG] = mini(kills() + worth, HUNT_COUNT)
		if kills() >= HUNT_COUNT:
			flags[STEP_FLAG] = TOKENS
			Game.say("%s ขั้นที่ 1 สำเร็จ! ขั้นที่ 2: %s" % [TITLE, objective_text()], &"quest")
		Game.quest_changed.emit()
		return
	if not _counts(monster_id):
		return
	var roll := rng.randf() if rng != null else randf()
	var found := BOSS_TOKENS if is_boss else (1 if roll < TOKEN_CHANCE else 0)
	if found <= 0:
		return
	flags[TOKENS_FLAG] = mini(tokens() + found, TOKEN_COUNT)
	Game.say("ได้%s! (%d/%d)" % [TOKEN_NAME, tokens(), TOKEN_COUNT], &"success")
	if tokens() >= TOKEN_COUNT:
		flags[STEP_FLAG] = TRIAL
		Game.say("%s ขั้นที่ 2 สำเร็จ! กลับไปหา%s เพื่อเข้า%s" % [TITLE, SAGE, STAGE_TITLE], &"quest")
	Game.quest_changed.emit()


## Why the hero cannot enter the trial stage now ("" when it can).
static func trial_problem() -> String:
	var problem := start_problem()
	if problem != "":
		return problem
	if step() < TRIAL:
		return "ต้องทำขั้นที่ %d ให้เสร็จก่อน" % maxi(1, step())
	return ""


## The trial stage's zone (a solo stage: no camps; its guardian comes from AscendTrial).
static func stage_zone() -> Dictionary:
	return {"name": STAGE_TITLE, "scene": "field", "level": [100, 100], "star": JobData.ASCEND_STARS, "music": SkyIsleData.ID, "theme": &"sky",
		"ambience": &"hum", "tree_density": 0.0, "camps": [], "ascend_trial": true, "divine_region": true,
		"sky": Color("2a2a5a"), "ground": Color("d8cfa8"), "fog": Color("b8a8e8"), "ambient": Color(1.0, 0.95, 0.85), "sun": Color(1.0, 0.92, 0.7),
		"path_color": Color("f0e0a0"), "seed": 61, "prev": &"town", "next": &"",
		"sky_palette": [Color("1a1640"), Color("5a4a9a"), Color("ffd8a0")], "sun_size": 1.4, "moon": false}


## The trial was won: the hero ascends (adv 6), with the step's skill points, a refill,
## the purse and the two Ascension skills on the bar. False when it cannot be granted.
static func promote() -> bool:
	if trial_problem() != "":
		return false
	var flags := _flags()
	flags[STEP_FLAG] = DONE
	Game.profile["adv"] = JobData.ASCEND_ADV
	Game.profile["skill_points"] = int(Game.profile.get("skill_points", 0)) + JobData.ASCEND_SKILL_POINTS
	Game.profile["gold"] = int(Game.profile.get("gold", 0)) + REWARD_GOLD
	Game.fill_loadout()
	_put_on_bar()
	var stats := Game.stats_now()
	Game.profile["hp"] = stats.max_hp
	Game.profile["mp"] = stats.max_mp
	Game.gold_changed.emit(Game.profile.gold)
	Game.profile_changed.emit()
	Game.quest_changed.emit()
	Game.mark_dirty()
	Game.say("เปลี่ยนอาชีพขั้นที่ 6! \"%s\" — %s ปลดล็อกสกิล %s" % [Game.class_data().name, Game.class_data().title, " และ ".join(AscendSkillData.pool(Game.class_id()).map(func(s): return String(s.name)))], &"success")
	return true


## The two Ascension skills take the bar's last two slots when they are not on it yet.
static func _put_on_bar() -> void:
	var bar: Array = Game.profile.get("loadout", [])
	var ids: Array = AscendSkillData.IDS.get(Game.class_id(), [])
	for k in ids.size():
		if bar.has(ids[k]) or bar.is_empty():
			continue
		var slot := bar.find("")
		if slot < 0:
			slot = bar.size() - ids.size() + k
		bar[slot] = ids[k]
	Game.profile["loadout"] = bar


## A trial attempt began (AscendTrial).
static func note_try() -> void:
	_flags()[TRIES_FLAG] = tries() + 1


## The sage's quest marker: the trial can be taken, or its stage entered.
static func marker() -> bool:
	if not Game.has_profile:
		return false
	return (step() == 0 and start_problem() == "") or step() == TRIAL
