class_name WorldPlayers
extends RefCounted
## The other players of the world: fixed people with names, classes and guilds (each
## picks one of the four, pick_guild, and joins it on reaching Lv.100, like the hero must).
## Nobody runs them on a server. Each keeps a daily play schedule set by its play style
## (Thai time on the world's clock, which runs SPEED times faster than real time, so the
## busy evening comes several times a real day), and what it has reached is the EXP a
## real player earns in the real minutes it played: the auto-hunt rates
## tests/tools/pace_probe.gd measured in the real fields, times the player's own
## efficiency (deaths, trips to town, slower hands than the probe's). A roster entry may
## start with a head start (vet, none at present), a few log in for the first time some
## days after the opening (join), and from the day after the reopening 10-15 newcomers a
## day made from the date alone join them (up to NEWCOMER_MAX), stall keepers stay in the
## village and everyone else plays hardcore, taking turns to rest. So levels,
## stars, whereabouts and who is online are the same for everyone at a given moment.
## A player with a play schedule spends its time online levelling: it hunts in the field
## that fits its level (WorldPresence shows it there, fighting the field's monsters for
## real) and only comes to the village for short errands (errand_at: a quest, the forge,
## new skills); with the divine set complete it spends its sessions on the endgame
## (endgame_plan) and enhances the set once it has climbed to ★300 (JobData.GOD_STARS; the
## stars go on to ★500, Game.PARAGON_MAX, where each fights บททดสอบเทวาลัย itself and is
## Ascended only once it wins: ascended_at). Otherwise the village belongs to the stall keepers
## (the "afk" style, and divine players taking a break, endgame_plan's "stall"): resting
## players who sell the good things they found (StallStock).
## Everyone plays the roster's class from Lv.1 (no Vagabond start any more).

## The world (re)opened here (unix seconds; Sunday 22 Nov 2026, 06:00 Thai time, the
## owner's fresh start: every player's characters were deleted with it, Game.WORLD_EPOCH):
## every world player starts again at Lv.1 in its class with no guild, and the guild
## league, the maze war, the world bosses, world gear, stalls and chat all begin again
## from here. Moving this resets them all (the party EXP kept on a device belongs to one
## opening and is dropped with it). Before it the world is closed: nobody is online.
## Mirrored in hosting/worker/league.mjs, dungeon.mjs and hosting/accounts/server/accounts.js
## (WORLD_EPOCH); their tests read this line.
const START_UNIX := 1795309200
## Schedules run on Thai time.
const TZ := 7 * 3600
const DAY := 86400

## The world's four guilds. Everyone picks one (pick_guild) and is in it from Lv.100
## (Game.GUILD_LEVEL); the hero picks one at the guild registrar.
const ALPHA := 1
const NEVERDIE := 2
const TITAN := 3
const LNW := 4
const GUILDS: Array[int] = [ALPHA, NEVERDIE, TITAN, LNW]
const GUILD_NAMES := {ALPHA: "Alpha", NEVERDIE: "Neverdie", TITAN: "Titan", LNW: "3DLnw"}
const GUILD_COLORS := {ALPHA: Color("ffd24a"), NEVERDIE: Color("ff6f8e"), TITAN: Color("5ab4ff"), LNW: Color("8dff7a")}
## Seed of everyone's own guild choice (pick_guild): with it each guild draws at least
## GUILD_MIN of the roster's hardcore players (the ones who reach Lv.100 in days), so
## every guild fields a full guild-war side (GuildWarData.GUILD_SIDE). Changing it makes
## everyone choose again (guild_league4_test checks the counts).
const GUILD_PICK_SEED := "guild996168"
const GUILD_MIN := 20

## Which roster this is. The owner deleted every AI player before the reopening of 22 Nov
## 2026 and they all made new characters (new names, classes, genders, bodies, voices):
## the roster below. What a device kept about world players by name (the party EXP of
## BONUS_PATH) is dropped when it was written for another roster, so nobody of the old
## roster comes back. Change it whenever the roster is replaced.
const ROSTER_ID := "reborn_20261122b"

## The world players. "body": the chibi body (ChibiBodies index of its gender) each picked
## at random among all the characters of its gender; look() dresses it.
const ROSTER: Array[Dictionary] = [
	# Players with a play schedule (everyone plays hardcore; voice: the tone they talk in).
	{"name": "เวทมนตร์คนจน", "class": &"mage", "gender": 0, "body": 0, "style": "hardcore", "voice": "student"},
	{"name": "Tor_Warrior", "class": &"warrior", "gender": 0, "body": 1, "style": "hardcore", "voice": "student"},
	{"name": "Ohm_TH", "class": &"summoner", "gender": 0, "body": 0, "style": "hardcore", "voice": "regular"},
	{"name": "มวยวัดสายดุ", "class": &"muaythai", "gender": 0, "body": 1, "style": "hardcore", "voice": "student"},
	{"name": "คุณหนูปีศาจ", "class": &"summoner", "gender": 1, "body": 3, "style": "hardcore", "voice": "weekend"},
	{"name": "ArcaneOat", "class": &"mage", "gender": 0, "body": 1, "style": "hardcore", "voice": "night_owl"},
	{"name": "ผู้กองเหล็ก", "class": &"defender", "gender": 1, "body": 0, "style": "hardcore", "voice": "weekend"},
	{"name": "Jaa_Lance", "class": &"lancer", "gender": 1, "body": 2, "style": "hardcore", "voice": "daytime"},
	{"name": "Guitar_Bom", "class": &"bard", "gender": 0, "body": 0, "style": "hardcore", "voice": "regular"},
	{"name": "พ่อมดตาโต", "class": &"mage", "gender": 0, "body": 0, "style": "hardcore", "voice": "student"},
	{"name": "ต้นข้าวสายฟัน", "class": &"warrior", "gender": 0, "body": 0, "style": "hardcore", "voice": "early"},
	{"name": "Kong_Pob", "class": &"lancer", "gender": 0, "body": 1, "style": "hardcore", "voice": "regular"},
	{"name": "แม่ไม้มวยไทย", "class": &"muaythai", "gender": 1, "body": 0, "style": "hardcore", "voice": "weekend"},
	{"name": "Ploy_Mage", "class": &"mage", "gender": 1, "body": 2, "style": "hardcore", "voice": "regular"},
	{"name": "มีดสั้นใจเศร้า", "class": &"assassin", "gender": 1, "body": 0, "style": "hardcore", "voice": "early"},
	{"name": "Holy_Nam", "class": &"priest", "gender": 1, "body": 0, "style": "hardcore", "voice": "student"},
	{"name": "Lord_Krit", "class": &"darklord", "gender": 0, "body": 1, "style": "hardcore", "voice": "overseas"},
	{"name": "Mewnich", "class": &"mage", "gender": 1, "body": 3, "style": "hardcore", "voice": "weekend"},
	{"name": "Abyss_Ton", "class": &"darklord", "gender": 0, "body": 1, "style": "hardcore", "voice": "early"},
	{"name": "Petch_Summon", "class": &"summoner", "gender": 0, "body": 2, "style": "hardcore", "voice": "daytime"},
	{"name": "เงาไร้นาม", "class": &"assassin", "gender": 0, "body": 2, "style": "hardcore", "voice": "casual"},
	{"name": "เพื่อนผีน้อย", "class": &"summoner", "gender": 1, "body": 2, "style": "hardcore", "voice": "weekend"},
	{"name": "SwordBuddy", "class": &"warrior", "gender": 0, "body": 3, "style": "hardcore", "voice": "student"},
	{"name": "แทงค์หมีขาว", "class": &"defender", "gender": 0, "body": 0, "style": "hardcore", "voice": "daytime"},
	{"name": "Boonmee_Tank", "class": &"defender", "gender": 0, "body": 0, "style": "hardcore", "voice": "daytime"},
	{"name": "Thanwa", "class": &"lancer", "gender": 0, "body": 3, "style": "hardcore", "voice": "regular"},
	{"name": "หมอลำซิ่ง", "class": &"bard", "gender": 0, "body": 3, "style": "hardcore", "voice": "early"},
	{"name": "จอมมารขี้เซา", "class": &"darklord", "gender": 1, "body": 3, "style": "hardcore"},
	{"name": "Silent_Pond", "class": &"assassin", "gender": 1, "body": 3, "style": "hardcore", "voice": "night_owl"},
	{"name": "HawkeyeTH", "class": &"archer", "gender": 0, "body": 2, "style": "hardcore", "voice": "night_owl"},
	{"name": "หมอเต้ย", "class": &"priest", "gender": 0, "body": 0, "style": "hardcore", "voice": "night_owl"},
	{"name": "Lyra_Kim", "class": &"bard", "gender": 1, "body": 1, "style": "hardcore", "voice": "daytime"},
	{"name": "ฟ้าประทาน", "class": &"priest", "gender": 0, "body": 0, "style": "hardcore", "voice": "night_owl"},
	{"name": "Jirayu_88", "class": &"archer", "gender": 0, "body": 2, "style": "hardcore", "voice": "night_owl"},
	{"name": "SlyFox_TH", "class": &"assassin", "gender": 0, "body": 2, "style": "hardcore", "voice": "weekend"},
	{"name": "ดีดพิณไม่พัก", "class": &"bard", "gender": 1, "body": 3, "style": "hardcore", "voice": "daytime"},
	{"name": "SpearBoy_01", "class": &"lancer", "gender": 0, "body": 1, "style": "hardcore", "voice": "casual"},
	{"name": "SisterJune", "class": &"priest", "gender": 1, "body": 0, "style": "hardcore", "voice": "overseas"},
	{"name": "Nakmuay_Ek", "class": &"muaythai", "gender": 0, "body": 1, "style": "hardcore", "voice": "regular"},
	{"name": "ทวนเหล็กกล้า", "class": &"lancer", "gender": 0, "body": 2, "style": "hardcore", "voice": "night_owl"},
	{"name": "Fai_Dragoon", "class": &"lancer", "gender": 1, "body": 1, "style": "hardcore"},
	{"name": "TigerKnee", "class": &"muaythai", "gender": 0, "body": 0, "style": "hardcore", "voice": "overseas"},
	{"name": "หมัดหนักโคราช", "class": &"muaythai", "gender": 0, "body": 2, "style": "hardcore", "voice": "overseas"},
	{"name": "หอกเดียวดาย", "class": &"lancer", "gender": 0, "body": 0, "style": "hardcore", "voice": "weekend"},
	{"name": "Kage_Ninja", "class": &"assassin", "gender": 0, "body": 2, "style": "hardcore", "voice": "regular"},
	{"name": "Tum_Fighter", "class": &"muaythai", "gender": 1, "body": 2, "style": "hardcore", "voice": "overseas"},
	{"name": "แมวดำยามดึก", "class": &"assassin", "gender": 1, "body": 1, "style": "hardcore", "voice": "weekend"},
	{"name": "Venomz", "class": &"assassin", "gender": 0, "body": 2, "style": "hardcore", "voice": "regular"},
	{"name": "Kickboxer_Jo", "class": &"muaythai", "gender": 1, "body": 1, "style": "hardcore", "voice": "early"},
	{"name": "แม่พระน้อย", "class": &"priest", "gender": 1, "body": 2, "style": "hardcore", "voice": "daytime"},
	{"name": "FrostByte_7", "class": &"mage", "gender": 0, "body": 1, "style": "hardcore", "voice": "student"},
	{"name": "DarkPao", "class": &"darklord", "gender": 1, "body": 1, "style": "hardcore"},
	{"name": "Mordred_TH", "class": &"darklord", "gender": 0, "body": 1, "style": "hardcore"},
	{"name": "ภูตเงาจันทร์", "class": &"summoner", "gender": 1, "body": 3, "style": "hardcore", "voice": "casual"},
	{"name": "NongBank99", "class": &"warrior", "gender": 0, "body": 1, "style": "hardcore", "voice": "casual"},
	{"name": "PeachyBow", "class": &"archer", "gender": 1, "body": 1, "style": "hardcore", "voice": "night_owl"},
	{"name": "Kraisorn", "class": &"warrior", "gender": 0, "body": 3, "style": "hardcore", "voice": "casual"},
	{"name": "Hugsy_Bear", "class": &"priest", "gender": 0, "body": 2, "style": "hardcore", "voice": "daytime"},
	{"name": "ZooKeeperX", "class": &"summoner", "gender": 0, "body": 0, "style": "hardcore", "voice": "early"},
	{"name": "Nuna_Mon", "class": &"summoner", "gender": 1, "body": 0, "style": "hardcore", "voice": "regular"},
	{"name": "OmenKing", "class": &"darklord", "gender": 0, "body": 2, "style": "hardcore"},
	{"name": "นุ่นนิ่ม", "class": &"priest", "gender": 1, "body": 3, "style": "hardcore", "voice": "weekend"},
	{"name": "แบมแบม", "class": &"archer", "gender": 1, "body": 2, "style": "hardcore", "voice": "student"},
	{"name": "Pinn_Song", "class": &"bard", "gender": 1, "body": 1, "style": "hardcore"},
	{"name": "Tank_Kla", "class": &"defender", "gender": 0, "body": 2, "style": "hardcore", "voice": "casual"},
	{"name": "นักร้องเสียงทอง", "class": &"bard", "gender": 1, "body": 3, "style": "hardcore"},
	{"name": "MookBless", "class": &"priest", "gender": 1, "body": 2, "style": "hardcore", "voice": "night_owl"},
	{"name": "Pim_Shoot", "class": &"archer", "gender": 1, "body": 2, "style": "hardcore", "voice": "night_owl"},
	{"name": "StoneHeart", "class": &"defender", "gender": 1, "body": 0, "style": "hardcore", "voice": "early"},
	{"name": "ด่านหน้าตัวจริง", "class": &"defender", "gender": 0, "body": 1, "style": "hardcore", "voice": "overseas"},
	{"name": "Fahsai_TH", "class": &"archer", "gender": 1, "body": 0, "style": "hardcore", "voice": "daytime"},
	{"name": "อาร์ตจัง", "class": &"warrior", "gender": 1, "body": 1, "style": "hardcore", "voice": "early"},
	{"name": "Praew_Pray", "class": &"priest", "gender": 1, "body": 3, "style": "hardcore", "voice": "student"},
	{"name": "Nueng_Ghost", "class": &"assassin", "gender": 0, "body": 1, "style": "hardcore", "voice": "overseas"},
	{"name": "Tonnam_W", "class": &"warrior", "gender": 1, "body": 2, "style": "hardcore", "voice": "casual"},
	{"name": "เจ้าหอกม่วง", "class": &"lancer", "gender": 1, "body": 1, "style": "hardcore"},
	{"name": "ธนูใจร้าย", "class": &"archer", "gender": 0, "body": 3, "style": "hardcore", "voice": "casual"},
	{"name": "นายท่านยามค่ำ", "class": &"darklord", "gender": 0, "body": 0, "style": "hardcore", "voice": "overseas"},
	{"name": "น้องเกดยิงไว", "class": &"archer", "gender": 1, "body": 3, "style": "hardcore", "voice": "early"},
	{"name": "เจ้าพ่อดาบไม้", "class": &"warrior", "gender": 0, "body": 2, "style": "hardcore", "voice": "casual"},
	{"name": "ศอกกลับ", "class": &"muaythai", "gender": 0, "body": 0, "style": "hardcore", "voice": "regular"},
	{"name": "WallE_Nut", "class": &"defender", "gender": 0, "body": 0, "style": "hardcore", "voice": "overseas"},
	{"name": "น้ำแข็งใส", "class": &"mage", "gender": 1, "body": 3, "style": "hardcore"},
	{"name": "PikeRider", "class": &"lancer", "gender": 0, "body": 1, "style": "hardcore", "voice": "casual"},
	# Stall keepers: they stay in the village the whole session and sell what they find.
	{"name": "ร้านยาเจ๊ดา", "class": &"priest", "gender": 1, "body": 3, "style": "afk"},
	{"name": "PotionPim", "class": &"priest", "gender": 1, "body": 1, "style": "afk"},
	{"name": "Scroll_Hub", "class": &"mage", "gender": 0, "body": 3, "style": "afk"},
	{"name": "CrystalNook", "class": &"mage", "gender": 1, "body": 2, "style": "afk"},
	{"name": "ร้านเกราะเจ๊หมวย", "class": &"defender", "gender": 1, "body": 0, "style": "afk"},
	{"name": "IronShop_Toy", "class": &"defender", "gender": 0, "body": 3, "style": "afk"},
	{"name": "ร้านพิณลุงเปี๊ยก", "class": &"bard", "gender": 0, "body": 3, "style": "afk"},
	{"name": "ร้านดาบช่างโอ๊ต", "class": &"warrior", "gender": 0, "body": 3, "style": "afk"},
	{"name": "MagicCorner", "class": &"summoner", "gender": 1, "body": 0, "style": "afk"},
	{"name": "แผงลูกธนูพี่ต่าย", "class": &"archer", "gender": 1, "body": 1, "style": "afk"},
	{"name": "BlackMarket_Z", "class": &"darklord", "gender": 0, "body": 1, "style": "afk"},
	{"name": "ร้านสนับมือมือสอง", "class": &"muaythai", "gender": 0, "body": 1, "style": "afk"},
	# Newcomers: they log in for the first time some real days after the opening (join).
	{"name": "Ukulele_Ice", "class": &"bard", "gender": 0, "body": 0, "style": "hardcore", "voice": "weekend", "join": 6},
	{"name": "Golem_Daddy", "class": &"summoner", "gender": 0, "body": 1, "style": "hardcore", "voice": "daytime", "join": 11},
	{"name": "Jett_Dagger", "class": &"assassin", "gender": 0, "body": 3, "style": "hardcore", "join": 18},
	{"name": "Mellow_Fern", "class": &"bard", "gender": 1, "body": 1, "style": "hardcore", "voice": "student", "join": 30},
]

## Sessions as [start hour, hours] on weekdays and at weekends (Saturday, Sunday). Each day
## moves every start by up to ±jitter hours and stretches every length by 0.7-1.3; skip is
## the chance a day is missed. eff: how much of the probe's EXP rate the style earns
## (a player online is out hunting most of its session, so the hunting styles earn about
## a third of the probe's rate, hardcore the most and casual the least; a stall keeper
## sits in the village and earns little).
## Every player with a play schedule is hardcore now (the guild war fields each guild's
## best, and the world should never feel empty): two long sessions a day with a short
## break between and a long rest after, each player at hours of its own (phase: its whole
## day moved by up to that many hours; spread: evenly down the roster), so they take turns
## resting: at any hour about half to two thirds of them are on, the most from the Thai
## evening to midnight (about 70%), the fewest early in the morning and mid-afternoon
## (about 50%), never all. Marathon sessions are hunted at a steadier pace (pots, repairs, a
## chat, a stall visit), so eff is lower than a short session's while the total EXP a day
## stays a hardcore player's (★200 in about a week; world_players_test).
## The other styles stay defined for the way each player talks: an entry's "voice" (the
## style it used to play, its chat tone and words; ChatThreads.voice, ChatBrain.tone_of).
const STYLES := {
	"hardcore": {"weekday": [[6.0, 6.0], [13.5, 8.0]], "weekend": [[5.5, 6.5], [13.0, 8.5]], "jitter": 0.75, "stretch": [0.85, 1.15], "phase": 20.0, "spread": true, "skip": 0.03, "eff": 0.23, "label": "ขาโหด"},
	"regular": {"weekday": [[20.0, 3.0]], "weekend": [[14.0, 2.0], [20.0, 3.5]], "jitter": 1.0, "skip": 0.08, "eff": 0.33, "label": "เล่นประจำ"},
	"student": {"weekday": [[16.5, 1.5], [20.5, 2.0]], "weekend": [[10.0, 3.0], [19.0, 3.0]], "jitter": 0.8, "skip": 0.06, "eff": 0.32, "label": "นักเรียน"},
	"night_owl": {"weekday": [[22.0, 4.0]], "weekend": [[21.0, 5.5]], "jitter": 1.2, "skip": 0.08, "eff": 0.34, "label": "สายนอนดึก"},
	"weekend": {"weekday": [[21.0, 1.0]], "weekend": [[10.0, 4.0], [19.0, 4.0]], "jitter": 1.0, "skip": 0.35, "eff": 0.33, "label": "สายเสาร์อาทิตย์"},
	"casual": {"weekday": [[20.0, 1.5]], "weekend": [[15.0, 2.5]], "jitter": 1.5, "skip": 0.25, "eff": 0.27, "label": "เล่นชิลล์"},
	"daytime": {"weekday": [[9.0, 3.0], [13.0, 4.0]], "weekend": [[10.5, 3.0], [15.0, 3.0]], "jitter": 1.0, "skip": 0.1, "eff": 0.30, "label": "ว่างกลางวัน"},
	"early": {"weekday": [[6.0, 2.5], [12.0, 1.0]], "weekend": [[6.5, 3.5], [15.5, 2.0]], "jitter": 0.7, "skip": 0.08, "eff": 0.30, "label": "สายตื่นเช้า"},
	"overseas": {"weekday": [[1.5, 4.0], [7.5, 2.5]], "weekend": [[1.0, 5.0], [9.0, 3.0]], "jitter": 1.0, "skip": 0.1, "eff": 0.32, "label": "อยู่ต่างประเทศ"},
	# Stall keepers / AFK: online most of the day, always in the village (town), slow EXP.
	# A short break between sessions (spread down the roster so the breaks never bunch up)
	# and no whole day off, so the stalls are always kept.
	"afk": {"weekday": [[0.0, 7.8], [8.0, 7.8], [16.0, 7.8]], "weekend": [[0.0, 7.8], [8.0, 7.8], [16.0, 7.8]], "jitter": 0.3, "stretch": [0.96, 1.04], "phase": 8.0, "spread": true, "skip": 0.0, "eff": 0.03, "label": "ตั้งร้าน/AFK", "town": true},
}
## The world's clock runs SPEED times faster than real time: a day of the schedules
## (morning, afternoon, the busy evening, the night) passes every 24 / SPEED real hours,
## so the busy evening comes round several times a real day. Sessions are set out in
## world hours; what they earn is the real minutes played, so the pace of levelling stays
## that of a real player.
const SPEED := 3.0
## EXP per minute of auto-hunting (pace_probe, warrior/mage mean, 60 s each) at each
## level in its field, and at Lv.100 by stars in the star fields. From ★200 the rate is
## the ★200-300 hunting ground's (about 1.3x the eclipse realm's ★200 rate at ★200,
## rising to about 1.6x by ★300), so the steeper star curve (HeroStats.star_need, 4% more
## per star past ★200) still takes a real player's weeks.
const LEVEL_RATE := [[1, 900], [3, 1146], [10, 2465], [18, 5498], [26, 12453], [35, 14066], [46, 18823], [58, 21692], [70, 29115], [82, 26128], [94, 36727], [100, 36727]]
const STAR_RATE := [[0, 56160], [25, 26488], [75, 46653], [125, 38994], [175, 41755], [199, 41755], [200, 54282], [300, 66808]]
## Potions a world player carries out of the village.
const POTIONS := 20
const MP_POTIONS := 10
## The divine set drops in the lotus sanctum (DivineRegionData, ★200): a player starts
## finding it on reaching DIVINE_STARS and has the whole set after DIVINE_HOURS of play
## there, while it keeps climbing to ★300.
const DIVINE_STARS := 200
const DIVINE_HOURS := 20.0

static var _table: PackedFloat64Array = PackedFloat64Array()
static var _minutes_cache := {}


## Everyone in the world by now: the ROSTER, then the daily newcomers who joined up to
## today (Thai time; newcomers below), in the order they came, so an index never changes.
static func size() -> int:
	ensure_until(maxf(now(), WorldPresence.clock()))
	return _all.size()


static func now() -> float:
	return Time.get_unix_time_from_system()


static func entry(i: int) -> Dictionary:
	if _all.is_empty():
		_roster()
	return _all[i]


# --- Newcomers ----------------------------------------------------------------------

## Every Thai day from the opening on, NEWCOMERS (10 to 15, by the day) new players log in
## for the first time, each at a moment of that day of its own. They are made from the
## date alone (name, class, face, guild), so every device meets the same people at the
## same moment: they start at Lv.1 in their class on their day and play hardcore like
## everyone; on reaching Lv.100 they join the guild they picked (pick_guild). The classes go
## round in shuffled rounds of every class. After NEWCOMER_MAX of them nobody new comes,
## so the world stays light enough for a phone. Off from the reopening of 22 Nov 2026
## (the ROSTER's hundred players) until NEWCOMER_FROM_DAY: from 23 Nov 2026 (Thai day 1
## after the opening) 10 to 15 new players log in every day (the owner's order).
const NEWCOMERS := Vector2i(10, 15)
## The first day (from the opening's Thai day) with newcomers: 23 Nov 2026.
const NEWCOMER_FROM_DAY := 1
## At most this many newcomers in all (about 96 days of them at 12.5 a day), so a phone
## keeps up. tools/world_scale_bench.tscn timed the world's reads at 100 + 600 / 1100 /
## 1500 players on day 241: every pass over everyone (a state ~50 us, a progress read
## ~30 us, an online look-up ~2 us a player on a desktop, a phone several times that)
## grows with the count (at 1300 players the occasional whole-world reads, the registry,
## parties_at, IsleLuck.hunters_at, take about 30-50 ms on a desktop); the maze no longer
## does (MazeWar.warm works its slots, powers and the forging behind them out a 1.5 ms
## step a frame, its longest frame ~15 ms at 1600 players). Kept at 1200: every index
## stays far inside the keys that hold them (WorldGear's reads: index < 4096).
const NEWCOMER_MAX := 1200
## How a newcomer talks in the chats (a play style's voice: ChatThreads.voice, ChatBrain).
const NEWCOMER_VOICES: Array[String] = ["hardcore", "regular", "student", "night_owl", "casual", "daytime", "early"]
const _EN_HEAD: Array[String] = ["Storm", "Kira", "Neo", "Blaze", "Frost", "Pixel", "Nova", "Yuki", "Ace", "Rex",
	"Zen", "Kai", "Mika", "Tofu", "Bubble", "Ghost", "Iron", "Lucky", "Moon", "Star", "Sunny", "Wolf", "Fox", "Cyber",
	"Jade", "Ruby", "Onyx", "Echo", "Rogue", "Vex", "Pudding", "Milo", "Toto", "Benz", "Gun", "Bank", "Bow", "Ploy",
	"Fern", "Earth", "Beam", "Mew", "Nut", "Pond", "Tae", "Jay", "Sky", "Ice"]
const _EN_TAIL: Array[String] = ["", "_TH", "X", "Boy", "Girl", "Kung", "Z", "Blade", "Fang", "Heart", "Wing",
	"Shot", "Pro", "Rider", "Hunter", "Knight", "Cat", "Bear", "_Jr", "Max", "Neko", "Senpai"]
const _TH_HEAD: Array[String] = ["น้อง", "พี่", "จอม", "เจ้า", "ขุน", "อัศวิน", "นักล่า", "จ้าว", "หมอ", "ซามูไร", "เด็ก", "ลุง", "ป้า", "สาว", "หนุ่ม", "แม่ทัพ"]
const _TH_TAIL: Array[String] = ["ข้าวปั้น", "มะลิ", "เสือ", "เมฆ", "ฟ้า", "ดาว", "ไผ่", "ต้นกล้า", "มะปราง", "ทองคำ", "หมีพูห์",
	"แมวเหมียว", "ปลาทู", "ส้มตำ", "ลมพัด", "ไฟลุก", "สายฟ้า", "จันทร์", "กาแฟ", "ชานม", "ขนมครก", "มังกร", "หมาป่า", "ลูกชิ้น"]

static var _all: Array[Dictionary] = []
## Name -> index, for everyone made so far.
static var _index := {}
## The last day (from the opening's Thai day) whose newcomers are made, and how many so far.
static var _gen_day := -1
static var _gen_count := 0


static func _roster() -> void:
	if not _all.is_empty():
		return
	for e in ROSTER:
		var copy: Dictionary = e.duplicate()
		copy["guild"] = pick_guild(String(e.name))
		_index[String(e.name)] = _all.size()
		_all.append(copy)


## The guild a player picks, its own choice: one of the four, from its name alone (the
## same on every device). Players join it on reaching Lv.100.
static func pick_guild(player_name: String) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("guild_pick|%s|%s" % [GUILD_PICK_SEED, player_name])
	return GUILDS[rng.randi_range(0, GUILDS.size() - 1)]


## The opening's Thai day number.
static func _first_day() -> int:
	return int(floor((float(START_UNIX) + TZ) / DAY))


## Makes everyone who has joined by the end of the Thai day of real time t (tests look
## ahead with it; size() goes up to today). Never undone: the roster only grows.
static func ensure_until(t: float) -> void:
	if _all.is_empty():
		_roster()
	var last := int(floor((t + TZ) / DAY)) - _first_day()
	while _gen_day < last and _gen_count < NEWCOMER_MAX:
		_gen_day += 1
		if _gen_day >= NEWCOMER_FROM_DAY:
			_add_day(_gen_day)


## Forgets every newcomer and everything kept per player (tests: the world worked out
## again from nothing, as another device would).
static func reset_roster() -> void:
	_all.clear()
	_index.clear()
	_gen_day = -1
	_gen_count = 0
	for cache in [_at, _cum, _minutes_cache, _sessions, _eff, _hw_share, _hw_cache, _name_hash, _trial]:
		(cache as Dictionary).clear()
	WorldGear.clear()
	WorldParties.clear_cache()
	_roster()


## Whether player i is one of the daily newcomers (made, not in ROSTER).
static func is_newcomer(i: int) -> bool:
	return bool(entry(i).get("newcomer", false))


## The newcomers of day k after the opening's Thai day, in the order they log in.
static func _add_day(k: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("newcomers|%d|%d" % [START_UNIX, k])
	var count := rng.randi_range(NEWCOMERS.x, NEWCOMERS.y)
	var midnight := float(_first_day() + k) * DAY - TZ
	var lo := maxf(midnight + 1800.0, float(START_UNIX) + 600.0)
	var hi := midnight + DAY - 1800.0
	var times: Array[float] = []
	for j in count:
		times.append(rng.randf_range(lo, hi))
	times.sort()
	for at in times:
		if _gen_count >= NEWCOMER_MAX:
			return
		var e := _newcomer(_gen_count, rng, at)
		e["day"] = k
		_index[String(e.name)] = _all.size()
		_all.append(e)
		_gen_count += 1


## Newcomer number n (from 0), logging in at real time `at`.
static func _newcomer(n: int, rng: RandomNumberGenerator, at: float) -> Dictionary:
	# Classes in shuffled rounds of every class, so they spread evenly.
	var bag: Array[StringName] = ClassData.IDS.duplicate()
	var shuffle := RandomNumberGenerator.new()
	shuffle.seed = hash("newcomer_bag|%d" % (n / bag.size()))
	for k in range(bag.size() - 1, 0, -1):
		var j := shuffle.randi_range(0, k)
		var tmp := bag[k]
		bag[k] = bag[j]
		bag[j] = tmp
	var gender := rng.randi() % 2
	var voice: String = NEWCOMER_VOICES[rng.randi() % NEWCOMER_VOICES.size()]
	var name := _new_name(rng)
	return {"name": name, "class": bag[n % bag.size()], "guild": pick_guild(name),
		"gender": gender, "style": "hardcore", "voice": voice, "join": (at - float(START_UNIX)) / DAY, "newcomer": true}


## A player's name nobody has yet: Thai or English style, a number added if it keeps
## coming out taken.
static func _new_name(rng: RandomNumberGenerator) -> String:
	for attempt in 40:
		var name := ""
		if rng.randf() < 0.4:
			name = _TH_HEAD[rng.randi() % _TH_HEAD.size()] + _TH_TAIL[rng.randi() % _TH_TAIL.size()]
		else:
			name = _EN_HEAD[rng.randi() % _EN_HEAD.size()] + _EN_TAIL[rng.randi() % _EN_TAIL.size()]
		if attempt >= 6:
			name += str(rng.randi_range(2, 99))
		if not _index.has(name):
			return name
	return "Newbie%d" % _all.size()


static func guild_name(guild: int) -> String:
	return String(GUILD_NAMES.get(guild, ""))


## Everyone who joins `guild` once at Lv.100 (the roster's side, whatever their level now).
static func members(guild: int) -> Array[int]:
	var out: Array[int] = []
	for i in size():
		if int(entry(i).guild) == guild:
			out.append(i)
	return out


## The guild player i is in at `level`: its roster guild from Lv.100 (Game.GUILD_LEVEL), none before.
static func guild_at(i: int, level: int) -> int:
	return int(entry(i).guild) if level >= Game.GUILD_LEVEL else 0


## Who is in `guild` at time t: the members who have reached Lv.100.
## The guild's leader (หัวหน้ากิลด์) among the world players: its strongest member at
## `t` (level, then stars). The hero leads its own guild instead (GuildScreen).
static func guild_leader(guild: int, t: float) -> String:
	var best := ""
	var best_score := -1
	for i in members_at(guild, t):
		var p := progress_at(i, t)
		var score := int(p.level) * 1000 + int(p.stars)
		if score > best_score:
			best_score = score
			best = String(entry(i).name)
	return best


static func members_at(guild: int, t: float) -> Array[int]:
	var out: Array[int] = []
	for i in members(guild):
		if t >= joined_at(i) and level_at(i, t) >= Game.GUILD_LEVEL:
			out.append(i)
	return out


## The first world player of a class (for tools and tests), -1 if none.
static func first_of(cls: StringName) -> int:
	for i in size():
		if StringName(entry(i)["class"]) == cls:
			return i
	return -1


# --- Schedule -------------------------------------------------------------------

## World time (the schedules' clock) at real unix time t: SPEED times faster from the opening.
static func world_time(t: float) -> float:
	return t if t <= START_UNIX else float(START_UNIX) + (t - float(START_UNIX)) * SPEED


## Real unix time of world time w.
static func real_time(w: float) -> float:
	return w if w <= START_UNIX else float(START_UNIX) + (w - float(START_UNIX)) / SPEED


## Real unix time player i first logs in (newcomers join some days after the opening).
static func joined_at(i: int) -> float:
	return float(START_UNIX) + float(entry(i).get("join", 0)) * DAY


## Local day number (Thai time) of a world time.
static func day_of(w: float) -> int:
	return int(floor((w + TZ) / DAY))


## The sessions player i plays on local world day `day`: [[start, end], ...] in world seconds.
## Kept per player and day (asked for by every state read: whether online, the minutes
## played, when last seen); a few days' worth for the whole world.
static var _sessions := {}


## How many entries a per-player cache may hold before it starts again: `floor`, or `per`
## entries for everyone in the world when that is more (a pass over a world of thousands
## reads a few days, minutes and event windows of each player: a cache smaller than one
## pass would be emptied in every pass and never hit).
static func _cache_cap(floor_size: int, per: int) -> int:
	return maxi(floor_size, per * _all.size())


static func sessions_on(i: int, day: int) -> Array:
	var key := day * 65536 + i
	var hit: Variant = _sessions.get(key)
	if hit != null:
		return hit
	var out := _make_sessions(i, day)
	if _sessions.size() > _cache_cap(12000, 8):
		_sessions.clear()
	_sessions[key] = out
	return out


static func _make_sessions(i: int, day: int) -> Array:
	var style: Dictionary = STYLES[String(entry(i).style)]
	var rng := RandomNumberGenerator.new()
	rng.seed = day_seed(i, day)
	if rng.randf() < float(style.skip):
		return []
	# 1970-01-01 was a Thursday: weekday 0 = Monday.
	var weekday := (day + 3) % 7
	var plan: Array = style.weekend if weekday >= 5 else style.weekday
	var out := []
	var midnight := float(day) * DAY - TZ
	# Round-the-clock styles keep their own hours (so their breaks never fall together).
	# A spread style's players take their hours in turn down the roster (the golden ratio
	# spaces them evenly however many there are), so their rests never bunch up.
	if style.has("phase"):
		var share := fposmod(float(i) * 0.6180339887, 1.0) if style.get("spread", false) else float(hash("phase|%s" % entry(i).name) % 1000) / 1000.0
		midnight += share * float(style.phase) * 3600.0
	var last_end := -INF
	for slot in plan:
		var start := midnight + (float(slot[0]) + rng.randf_range(-1.0, 1.0) * float(style.jitter)) * 3600.0
		var stretch: Array = style.get("stretch", [0.7, 1.3])
		var length := float(slot[1]) * rng.randf_range(float(stretch[0]), float(stretch[1])) * 3600.0
		start = maxf(start, last_end + 900.0)
		out.append([start, start + length])
		last_end = start + length
	return out


static var _day_rng := RandomNumberGenerator.new()


## Sums player i's days into `cum` until it holds `upto` entries (days first-1 ..). A day
## that begins well after it joined counts whole: the lengths _make_sessions draws (the
## same seed and draws, worked out inline: a few hundred players times a few hundred days
## the first time the world is read).
static func _extend_cum(i: int, cum: PackedFloat64Array, upto: int, first: int, origin: float) -> void:
	var style: Dictionary = STYLES[String(entry(i).style)]
	var skip := float(style.skip)
	var stretch: Array = style.get("stretch", [0.7, 1.3])
	var lo := float(stretch[0])
	var hi := float(stretch[1])
	var lengths := []
	for plan in [style.weekday, style.weekend]:
		var list := PackedFloat64Array()
		for slot in plan:
			list.append(float(slot[1]) * 60.0)
		lengths.append(list)
	day_seed(i, first)
	var nh := int(_name_hash[i])
	var rng := _day_rng
	var total := cum[cum.size() - 1]
	while cum.size() < upto:
		var d := first + cum.size() - 1
		var begins := float(d) * DAY - TZ
		if begins + 3.0 * DAY <= origin:
			# Every session of a day this long before the player joined is over by then
			# (none runs two days past its midnight): nothing to count, nothing to draw.
			cum.append(total)
			continue
		if begins - 7200.0 >= origin:
			rng.seed = nh * 1000003 + d * 7919
			if rng.randf() >= skip:
				for length in (lengths[1] if (d + 3) % 7 >= 5 else lengths[0]) as PackedFloat64Array:
					rng.randf()
					total += length * rng.randf_range(lo, hi)
		else:
			total += _day_minutes(i, d, origin, INF)
		cum.append(total)


## The seed of player i's sessions on world day `day`: its name's and the day's.
static func day_seed(i: int, day: int) -> int:
	var nh: Variant = _name_hash.get(i)
	if nh == null:
		nh = hash("day|%s" % entry(i).name)
		_name_hash[i] = nh
	return int(nh) * 1000003 + day * 7919


static var _name_hash := {}


## World minutes of the sessions of world day `day` between world times lo and hi.
static func _day_minutes(i: int, day: int, lo: float, hi: float) -> float:
	var total := 0.0
	for sess in sessions_on(i, day):
		var a := maxf(float(sess[0]), lo)
		var b := minf(float(sess[1]), hi)
		if b > a:
			total += (b - a) / 60.0
	return total


## Per player: world minutes played in whole days, cumulated from the day before the opening.
static var _cum := {}


## Real minutes player i has played between joining the world and real time t.
static func played_minutes(i: int, t: float) -> float:
	var origin := world_time(joined_at(i))
	var w := world_time(t)
	if w <= origin:
		return 0.0
	# Kept per player and minute for the very moment read (another moment of the same
	# minute is worked out again, so the answer never depends on what was read first).
	var key := int(t / 60.0) * 65536 + i
	var hit: Variant = _minutes_cache.get(key)
	if hit != null and float(hit[0]) == t:
		return float(hit[1])
	if _minutes_cache.size() > _cache_cap(6000, 8):
		_minutes_cache.clear()
	# A session can run past midnight (never past the next one), so the two latest days
	# are cut at w and every earlier day counts whole.
	var first := day_of(float(START_UNIX)) - 1
	var today := day_of(w)
	var cum: PackedFloat64Array = _cum.get(i, PackedFloat64Array([0.0]))
	if cum.size() <= today - 1 - first:
		_extend_cum(i, cum, today - first, first, origin)
	_cum[i] = cum
	var total := cum[maxi(0, today - 1 - first)]
	for d in [today - 1, today]:
		if d >= first:
			total += _day_minutes(i, d, origin, w)
	total /= SPEED
	_minutes_cache[key] = [t, total]
	return total


## The session player i is in at real time t as [start, end] in real unix seconds, or [] offline.
static func session_at(i: int, t: float) -> Array:
	if t < START_UNIX or t < joined_at(i):
		return []
	# The answer holds from one session's start or end to the next (within a world day):
	# kept per player with the stretch of real time it holds for, so the many reads of a
	# moment (and of the moments after it) cost a look-up.
	var c: Variant = _at.get(i)
	if c != null and t >= float(c[0]) and t < float(c[1]):
		return c[2]
	var w := world_time(t)
	var origin := world_time(joined_at(i))
	var today := day_of(w)
	var lo := float(today) * DAY - TZ
	var hi := lo + DAY
	var out := []
	for day in [today - 1, today]:
		for sess in sessions_on(i, day):
			var a := float(sess[0])
			var b := float(sess[1])
			if b <= origin:
				continue
			if w >= a and w < b:
				out = [real_time(maxf(a, origin)), real_time(b)]
				lo = maxf(lo, a)
				hi = minf(hi, b)
			elif b <= w:
				lo = maxf(lo, b)
			elif a > w:
				hi = minf(hi, a)
	_at[i] = [real_time(lo), real_time(hi), out, -1.0]
	return out


## Per player: [from, until (real unix seconds), session_at's answer, last seen (-1 not
## worked out yet)].
static var _at := {}


## A stall keeper / AFK player: stays in the village the whole session.
static func in_town_style(i: int) -> bool:
	return bool(STYLES[String(entry(i).style)].get("town", false))


## Whether player i stays in the village at real time t of its session (real start s0,
## end s1): only a stall keeper does, the whole session. A player with a play schedule
## spends its time online levelling, but for the short errands below.
static func town_time(i: int, _s0: float, _s1: float, _t: float) -> bool:
	return in_town_style(i)


## Errands: like a real player, a player pops back to the village now and then for a few
## real minutes (ERRAND_MIN-ERRAND_MAX). Its enhancing is done there and only there (the
## owner's rule): about every ERRAND_EVERY real minutes of its play it goes to the
## blacksmith ("enhance") with the jewels it gathered while hunting, on the forge trips
## WorldGear works out (WorldGear.forge_window: the + only rises during them), a stall
## keeper too (it leaves its stall for them). Besides, a scheduled player now and then hands
## in a quest at the elder ("quest") or learns skills at the skill master ("skill"; always
## when a skill of its class unlocked since the stretch began), at most once in every
## ERRAND_EVERY real minutes of a session, never over a forge trip.
const ERRAND_EVERY := 70.0
const ERRAND_CHANCE := 0.35
const ERRAND_MIN := 2.5
const ERRAND_MAX := 4.0
const ERRAND_KINDS: Array[String] = ["quest", "enhance", "skill"]
static var _unlock_levels := {}


## The errand player i is on at real time t of the session (real start s0, end s1):
## {kind, from, until} (real unix seconds), or {} while it hunts.
static func errand_at(i: int, s0: float, s1: float, t: float) -> Dictionary:
	var forge := forge_errand(i, s0, s1, t)
	if not forge.is_empty():
		return forge
	return _side_errand(i, s0, s1, t)


## The forge trip (WorldGear.forge_window) player i is on at real time t of its session
## (real start s0, end s1): {kind "enhance", from, until, trip}, or {}. It runs from when its
## work reaches the trip's start to when it reaches its end (within the session: one cut
## off by logging out goes on as the next session starts).
static func forge_errand(i: int, s0: float, s1: float, t: float) -> Dictionary:
	if t < s0 or t >= s1:
		return {}
	var w := work_at(i, t)
	var trip := WorldGear.forge_trip_at(i, w)
	if int(trip[0]) < 0:
		return {}
	# Kept per player for the trip and the session (and the party EXP / pauses it was
	# worked out with), so the many reads of a trip cost a look-up.
	var key := String(entry(i).name)
	var sig := PackedFloat64Array([float(trip[0]), s0, float(bonus.get(key, 0.0)), float(paused.get(key, -1.0)), float(skipped.get(key, 0.0))])
	var hit: Variant = _forge_runs.get(i)
	if hit != null and hit[0] == sig:
		return {"kind": "enhance", "from": float(hit[1]), "until": float(hit[2]), "trip": int(trip[0])}
	var start := float(trip[1])
	var end := float(trip[2])
	var from := s0 if work_at(i, s0) >= start - WorldGear.FORGE_EPS else _when_work(i, start, s0, t)
	var until := s1 if work_at(i, s1 - 1.0) < end else _when_work(i, end, t, s1)
	if _forge_runs.size() > _cache_cap(512, 1):
		_forge_runs.clear()
	_forge_runs[i] = [sig, from, until]
	return {"kind": "enhance", "from": from, "until": until, "trip": int(trip[0])}


## Per player: [the trip and session signature, from, until] of its latest forge trip.
static var _forge_runs := {}


## The real time in [lo, hi] at which player i's work reaches w (to the second; its work
## only grows while it plays).
static func _when_work(i: int, w: float, lo: float, hi: float) -> float:
	if work_at(i, lo) >= w - WorldGear.FORGE_EPS:
		return lo
	for step in 24:
		if hi - lo < 1.0:
			break
		var mid := (lo + hi) * 0.5
		if work_at(i, mid) >= w - WorldGear.FORGE_EPS:
			hi = mid
		else:
			lo = mid
	return hi


## Whether player i is on a forge trip at real time t (online, at the blacksmith).
static func on_forge_trip(i: int, t: float) -> bool:
	var s := session_at(i, t)
	return not s.is_empty() and int(WorldGear.forge_trip_at(i, work_at(i, t))[0]) >= 0


## A quest or skill errand of a scheduled player (never over a forge trip).
static func _side_errand(i: int, s0: float, s1: float, t: float) -> Dictionary:
	if in_town_style(i) or t < s0 or t >= s1:
		return {}
	var slot := int((t - s0) / 60.0 / ERRAND_EVERY)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("errand|%s|%d|%d" % [entry(i).name, int(s0 / 60.0), slot])
	var length := rng.randf_range(ERRAND_MIN, ERRAND_MAX)
	var from := s0 + (float(slot) * ERRAND_EVERY + rng.randf_range(4.0, ERRAND_EVERY - length - 4.0)) * 60.0
	var until := from + length * 60.0
	if t < from or t >= until or until > s1 - 120.0:
		return {}
	var roll := rng.randf()
	var pick := rng.randf()
	var kind := ""
	if _unlocks_between(i, s0 + float(slot) * ERRAND_EVERY * 60.0, from):
		kind = "skill"
	elif roll < ERRAND_CHANCE:
		kind = "quest" if pick < 0.65 else "skill"
	else:
		return {}
	# Never over a forge trip, nor right next to one (its work from 8 minutes before the
	# errand's start to 8 minutes after its end).
	var wa := work_at(i, from - 480.0)
	var wb := work_at(i, until + 480.0)
	for k in range(WorldGear.forge_cell_of(i, wa), WorldGear.forge_cell_of(i, wb) + 1):
		var win := WorldGear.forge_window(i, k)
		if float(win[0]) <= wb and float(win[1]) > wa:
			return {}
	# One hunting with a party of world players stays with it (no errand meanwhile).
	if not WorldParties.party_of(i, t).is_empty():
		return {}
	return {"kind": kind, "from": from, "until": until}


## The level player i has reached at real time t.
static func level_at(i: int, t: float) -> int:
	return int(progress_at(i, t).level)


## How far player i has come at real time t, as one number for picking the best (the
## guild war's line-up): Lv.1-100, then the stars, the part of the next step done, the
## divine set gathered (up to 1) and its enhancing after (up to 1 at +10). It only goes up.
static func rank_point(i: int, t: float) -> float:
	var p := progress_at(i, t)
	var stars := int(p.stars)
	var frac := float(p.frac) * 0.99 if stars < Game.PARAGON_MAX else 0.0
	return float(int(p.level) + stars) + frac + float(p.divine_frac) + minf(float(p.after) / (DIVINE_PLUS_HOURS * 10.0), 1.0)


## Player i's progress at real time t (progress_for: level, stars, frac, divine, ...),
## without the rest of state() (where it is, its party): for picking the strongest.
static func progress_at(i: int, t: float) -> Dictionary:
	return progress_for(own_minutes(i, t), efficiency(i), bonus_work(i) + head_work(i) + halloween_work(i, t) + festival3_work(i, t) + party_work(i, t))


## Player i's work at real time t: the probe minutes progress_for reads (its own minutes
## times its efficiency, plus its party EXP, head start and potions). It only grows, and
## everything it has (its level, stars, the gear it forged: WorldGear) follows it.
static func work_at(i: int, t: float) -> float:
	return own_minutes(i, t) * efficiency(i) + maxf(0.0, bonus_work(i) + head_work(i) + halloween_work(i, t) + festival3_work(i, t) + party_work(i, t))


## The work behind a member sheet (level, stars, frac, divine_frac, after): what
## progress_for turned into it, read back.
static func work_of(m: Dictionary, i: int) -> float:
	var steps := _steps()
	var eff := efficiency(i)
	var base := steps[mini(Game.MAX_LEVEL - 1 + DIVINE_STARS, steps.size() - 1)]
	var divine_need := DIVINE_HOURS * 60.0 * eff
	var after := float(m.get("after", 0.0))
	var divine_frac := float(m.get("divine_frac", 0.0))
	var level := int(m.get("level", 1))
	var stars := int(m.get("stars", 0)) if level >= Game.MAX_LEVEL else 0
	if level >= Game.MAX_LEVEL and stars >= DIVINE_STARS:
		if after > 0.0:
			return base + divine_need + after * 60.0 * eff
		if divine_frac > 0.0:
			return maxf(base + divine_frac * divine_need, _sheet_work(steps, level, stars, float(m.get("frac", 0.0))))
	return _sheet_work(steps, level, stars, float(m.get("frac", 0.0)))


static func _sheet_work(steps: PackedFloat64Array, level: int, stars: int, frac: float) -> float:
	var k := clampi(level - 1 + (stars if level >= Game.MAX_LEVEL else 0), 0, steps.size() - 1)
	if k >= steps.size() - 1:
		return steps[k]
	return steps[k] + clampf(frac, 0.0, 0.999) * (steps[k + 1] - steps[k])


## Probe minutes partying with other world players (WorldParties) has added to player i by
## real time t: EXP_BONUS more on the share of its own play it spends in parties.
static func party_work(i: int, t: float) -> float:
	return own_minutes(i, t) * efficiency(i) * WorldParties.taste(i) * WorldParties.EXP_BONUS


# --- Halloween ----------------------------------------------------------------------

## World players find Halloween potions too (WorldEvents.HALLOWEEN_*) and drink them
## while they hunt: each hour of the event a player online is under one with its own
## chance (HALLOWEEN_SHARE_MIN..MAX, by name), at x2 or x3 for that hour. What the
## potions add is HALLOWEEN_EXTRA (the mean of x2 and x3, less the base) of its own
## progress for that share of the event minutes it played.
const HALLOWEEN_SHARE_MIN := 0.25
const HALLOWEEN_SHARE_MAX := 0.5
const HALLOWEEN_EXTRA := 1.5


static func halloween_share(i: int) -> float:
	var hit: Variant = _hw_share.get(i)
	if hit != null:
		return hit
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("hw_share|%s" % entry(i).name)
	var share := rng.randf_range(HALLOWEEN_SHARE_MIN, HALLOWEEN_SHARE_MAX)
	_hw_share[i] = share
	return share


## The potion multiplier player i is under at real time t (1: none, or not online).
static func halloween_mult(i: int, t: float) -> int:
	if not WorldEvents.halloween_on(t) or session_at(i, t).is_empty():
		return 1
	var hour := int(floor(t / 3600.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("hw|%s|%d" % [entry(i).name, hour])
	if rng.randf() >= halloween_share(i):
		return 1
	return 2 if rng.randf() < 0.5 else 3


## Probe minutes the potions have added to player i by real time t: its schedule's
## minutes inside the event, frozen while it is in the hero's party (where the party's
## EXP counts, Game.share_party_exp) and less the event minutes it spent in parties.
static func halloween_work(i: int, t: float) -> float:
	var start := float(WorldEvents.HALLOWEEN_START)
	if t <= start:
		return 0.0
	_load_bonus()
	var key := String(entry(i).name)
	# Asked for by every level read: kept per player for the same 10 s of the clock.
	var cache_key: Variant = int(t / 10.0) * 65536 + i
	if paused.has(key) or hw_skipped.has(key):
		cache_key = "%d|%d|%s|%s" % [i, int(t / 10.0), str(paused.get(key, -1.0)), str(hw_skipped.get(key, 0.0))]
	var hw_hit: Variant = _hw_cache.get(cache_key)
	if hw_hit != null and float(hw_hit[0]) == t:
		return float(hw_hit[1])
	var from := played_minutes(i, start)
	var last := played_minutes(i, float(WorldEvents.HALLOWEEN_END))
	var upto := minf(float(paused[key]) if paused.has(key) else played_minutes(i, t), last)
	var played := maxf(0.0, upto - from - float(hw_skipped.get(key, 0.0)))
	var work := played * efficiency(i) * halloween_share(i) * HALLOWEEN_EXTRA
	if _hw_cache.size() > _cache_cap(512, 2):
		_hw_cache.clear()
	_hw_cache[cache_key] = [t, work]
	return work


static var _hw_cache := {}
## Event minutes (schedule minutes inside the Halloween window) each player spent in the
## hero's party, by name: they earn the party's EXP there, not their own potions'.
static var hw_skipped := {}


# --- The third festival (EXP x3) --------------------------------------------------------

## World players play the festival too (WorldEvents.FESTIVAL3_*, EXP x3 for everyone):
## every minute of their schedule inside it earns them FESTIVAL3_EXP times their normal
## progress (their own and their parties' share, party_work), so it adds (FESTIVAL3_EXP - 1)
## times that for the festival minutes played; frozen while in the hero's party (where the
## party's EXP counts, itself x3) and less the festival minutes spent there (f3_skipped).
## Read off the clock and the roster alone, so the same on every device. The forge jewels'
## x3 follows from the work (WorldGear.festival_kill_share).
static func festival3_work(i: int, t: float) -> float:
	var start := float(WorldEvents.FESTIVAL3_START)
	if t <= start or not WorldEvents.festival_enabled:
		return 0.0
	_load_bonus()
	var key := String(entry(i).name)
	# Asked for by every level read: kept per player for the same 10 s of the clock.
	var cache_key: Variant = int(t / 10.0) * 65536 + i
	if paused.has(key) or f3_skipped.has(key):
		cache_key = "%d|%d|%s|%s" % [i, int(t / 10.0), str(paused.get(key, -1.0)), str(f3_skipped.get(key, 0.0))]
	var hit: Variant = _f3_cache.get(cache_key)
	if hit != null and float(hit[0]) == t:
		return float(hit[1])
	var played := festival3_minutes(i, t)
	var work := played * efficiency(i) * (1.0 + WorldParties.taste(i) * WorldParties.EXP_BONUS) * (WorldEvents.FESTIVAL3_EXP - 1.0)
	if _f3_cache.size() > _cache_cap(512, 2):
		_f3_cache.clear()
	_f3_cache[cache_key] = [t, work]
	return work


## The schedule minutes player i has played inside the third festival by real time t
## that count for its own progress (not those in the hero's party).
static func festival3_minutes(i: int, t: float) -> float:
	var start := float(WorldEvents.FESTIVAL3_START)
	if t <= start or not WorldEvents.festival_enabled:
		return 0.0
	_load_bonus()
	var key := String(entry(i).name)
	var from := played_minutes(i, start)
	var last := played_minutes(i, float(WorldEvents.FESTIVAL3_END))
	var upto := minf(float(paused[key]) if paused.has(key) else played_minutes(i, t), last)
	return maxf(0.0, upto - from - float(f3_skipped.get(key, 0.0)))


static var _f3_cache := {}
## Festival minutes (schedule minutes inside the third festival) each player spent in the
## hero's party, by name.
static var f3_skipped := {}


## Whether a skill of player i's class unlocks between real times a and b.
static func _unlocks_between(i: int, a: float, b: float) -> bool:
	var before := level_at(i, a)
	var after := level_at(i, b)
	if after <= before:
		return false
	var cls := StringName(entry(i)["class"])
	if not _unlock_levels.has(cls):
		var levels := {}
		for skill in ClassData.pool(cls):
			levels[int(skill.level)] = true
		_unlock_levels[cls] = levels
	for lv in range(before + 1, after + 1):
		if (_unlock_levels[cls] as Dictionary).has(lv):
			return true
	return false


# --- Progress -------------------------------------------------------------------

## Probe EXP per minute at a level (and at Lv.100, at a star count).
static func rate(level: int, stars: int) -> float:
	if level >= Game.MAX_LEVEL:
		return _lerp_table(STAR_RATE, stars)
	return _lerp_table(LEVEL_RATE, level)


static func _lerp_table(table: Array, x: int) -> float:
	for k in range(1, table.size()):
		if x <= int(table[k][0]):
			var a: Array = table[k - 1]
			var b: Array = table[k]
			var f := clampf(float(x - int(a[0])) / float(maxi(1, int(b[0]) - int(a[0]))), 0.0, 1.0)
			# Rates grow by factors, so they are blended in log space.
			return exp(lerpf(log(float(a[1])), log(float(b[1])), f))
	return float(table[-1][1])


## Probe minutes from Lv.1 to step k: steps 0..99 are Lv.1..100, steps 99..599 are ★0..500
## (Game.PARAGON_MAX; past ★300 HeroStats.star_need asks 1.5x, at STAR_RATE's ★300 pace).
static func _steps() -> PackedFloat64Array:
	if not _table.is_empty():
		return _table
	var table := PackedFloat64Array()
	var total := 0.0
	table.append(0.0)
	for level in range(1, Game.MAX_LEVEL):
		total += float(HeroStats.exp_to_next(level)) / rate(level, 0)
		table.append(total)
	for star in Game.PARAGON_MAX:
		total += float(HeroStats.star_need(star)) / rate(Game.MAX_LEVEL, star)
		table.append(total)
	_table = table
	return table


## How much of the probe's rate player i earns: its style's efficiency and its own hands.
static func efficiency(i: int) -> float:
	var hit: Variant = _eff.get(i)
	if hit != null:
		return hit
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("eff|%s" % entry(i).name)
	var eff := float(STYLES[String(entry(i).style)].eff) * rng.randf_range(0.88, 1.12)
	_eff[i] = eff
	return eff


## Per player (fixed by name and style): its efficiency and Halloween share.
static var _eff := {}
static var _hw_share := {}


## {level, stars, frac (0..1 to the next step), minutes (played), divine (bool),
## divine_frac (0..1 of the divine set's hours)} for `minutes` of play at efficiency
## `eff`, plus `extra` probe minutes earned in the hero's party (bonus_work).
static func progress_for(minutes: float, eff: float, extra := 0.0) -> Dictionary:
	var steps := _steps()
	var work := minutes * eff + maxf(0.0, extra)
	var k := steps.bsearch(work, false) - 1
	k = clampi(k, 0, steps.size() - 1)
	var frac := 0.0
	if k < steps.size() - 1:
		frac = clampf((work - steps[k]) / maxf(0.001, steps[k + 1] - steps[k]), 0.0, 0.999)
	var level := mini(k + 1, Game.MAX_LEVEL)
	var stars := clampi(k - (Game.MAX_LEVEL - 1), 0, Game.PARAGON_MAX)
	# The divine set is gathered from ★200 (DIVINE_STARS) while the stars go on to ★300.
	var divine_need := DIVINE_HOURS * 60.0 * eff
	var post := work - steps[mini(Game.MAX_LEVEL - 1 + DIVINE_STARS, steps.size() - 1)]
	var divine_frac := clampf(post / maxf(0.001, divine_need), 0.0, 1.0) if stars >= DIVINE_STARS else 0.0
	# Hours of play since the divine set was complete (enhancing it, see equip).
	var after := maxf(0.0, post - divine_need) / maxf(0.001, 60.0 * eff) if divine_frac >= 1.0 else 0.0
	return {"level": level, "stars": stars, "frac": frac, "minutes": minutes, "divine": divine_frac >= 1.0, "divine_frac": divine_frac, "after": after}


## A veteran's head start in probe minutes: where it stood when the world reopened, as a
## point (Lv.1-100 = 1-100, ★1-500 = 101-600, past 600 = tenths of DIVINE_HOURS played
## since ★500: 610 has played DIVINE_HOURS there, 620 twice as long).
static func head_work(i: int) -> float:
	var point := int(entry(i).get("vet", 0))
	if point <= 1:
		return 0.0
	var steps := _steps()
	var work := steps[clampi(point - 1, 0, steps.size() - 1)]
	var top := Game.MAX_LEVEL + Game.PARAGON_MAX
	if point > top:
		work += float(point - top) / 10.0 * DIVINE_HOURS * 60.0 * efficiency(i)
	return work


# --- Party EXP ----------------------------------------------------------------------

## What world players earned in the hero's party is kept with the world on this
## device, not with a character: a new character meets them as they were.
const BONUS_PATH := "user://toon_tale_world.json"
## Kept on disk except in headless runs (tests keep it in memory, so runs stay alike).
static var persist := DisplayServer.get_name() != "headless"
## Probe minutes of progress each player (by name) earned in parties.
static var bonus := {}
## Real minutes of each player's schedule (by name) spent in the hero's party, and the
## schedule minutes of those in it now (own_minutes).
static var skipped := {}
static var paused := {}
## Party EXP (probe minutes, by name) held back until its forge trip is done (add_exp).
static var held := {}
static var _bonus_loaded := false
static var _bonus_dirty := false


static func bonus_work(i: int) -> float:
	_load_bonus()
	return float(bonus.get(String(entry(i).name), 0.0))


## Real minutes of player i's own play that count for its progress: its schedule's
## minutes less the time it spent in the hero's party (where only the party's shared EXP
## counts, add_exp), frozen while it is in the party now.
static func own_minutes(i: int, t: float) -> float:
	_load_bonus()
	var key := String(entry(i).name)
	var minutes := float(paused[key]) if paused.has(key) else played_minutes(i, t)
	return maxf(0.0, minutes - float(skipped.get(key, 0.0)))


## Player i joins the hero's party at real time t: its own schedule stops counting.
static func pause_schedule(i: int, t: float) -> void:
	_load_bonus()
	var key := String(entry(i).name)
	if not paused.has(key):
		paused[key] = played_minutes(i, t)
		_bonus_dirty = true


## Player i leaves the hero's party at real time t: the minutes it was away from its
## schedule are skipped, so it carries on from the level the party left it at.
static func resume_schedule(i: int, t: float) -> void:
	_load_bonus()
	var key := String(entry(i).name)
	if not paused.has(key):
		return
	var now_m := played_minutes(i, t)
	skipped[key] = float(skipped.get(key, 0.0)) + maxf(0.0, now_m - float(paused[key]))
	var hw_from := maxf(float(paused[key]), played_minutes(i, float(WorldEvents.HALLOWEEN_START)))
	var hw_to := minf(now_m, played_minutes(i, float(WorldEvents.HALLOWEEN_END)))
	if hw_to > hw_from:
		hw_skipped[key] = float(hw_skipped.get(key, 0.0)) + hw_to - hw_from
	var f3_from := maxf(float(paused[key]), played_minutes(i, float(WorldEvents.FESTIVAL3_START)))
	var f3_to := minf(now_m, played_minutes(i, float(WorldEvents.FESTIVAL3_END)))
	if f3_to > f3_from:
		f3_skipped[key] = float(f3_skipped.get(key, 0.0)) + f3_to - f3_from
	paused.erase(key)
	_bonus_dirty = true


## Every paused schedule resumes at real time t (the party is let go, or the game left
## with a party: resumed at the time the world file was written).
static func resume_all(t: float) -> void:
	_load_bonus()
	for key in paused.keys():
		var i := index_of(String(key))
		if i >= 0:
			resume_schedule(i, t)
		else:
			paused.erase(key)


static func index_of(player_name: String) -> int:
	if not _index.has(player_name):
		size()
	return int(_index.get(player_name, -1))


## Player i earns `amount` EXP at its level and stars (its share of a party kill).
static func add_exp(i: int, amount: float, level: int, stars: int) -> void:
	if amount <= 0.0 or i < 0 or i >= size():
		return
	_load_bonus()
	var key := String(entry(i).name)
	# Its forging is done at the blacksmith (WorldGear.forge_window): the EXP carries it up
	# to its next forge trip's start and the rest is held until the trip is behind it (the
	# hero's party lets it go there: Game.party_refresh), so no + of the trip comes early.
	var gain := amount / maxf(1.0, rate(level, stars)) + float(held.get(key, 0.0))
	var w := work_at(i, WorldPresence.clock())
	var room := maxf(0.0, WorldGear.forge_hold(i, w) - w)
	var take := minf(gain, room)
	bonus[key] = float(bonus.get(key, 0.0)) + take
	if gain - take > 0.0:
		held[key] = gain - take
	else:
		held.erase(key)
	_bonus_dirty = true


## Probe minutes of party EXP player i has waiting for its forge trip (add_exp).
static func held_work(i: int) -> float:
	return float(held.get(String(entry(i).name), 0.0))


## Writes the party EXP when it changed (Game.save calls this).
static func store() -> void:
	if not _bonus_dirty or not persist:
		return
	var file := FileAccess.open(BONUS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"start": START_UNIX, "roster": ROSTER_ID, "bonus": bonus, "skipped": skipped, "paused": paused, "hw_skipped": hw_skipped, "f3_skipped": f3_skipped, "held": held, "saved": now()}))
		_bonus_dirty = false


static func _load_bonus() -> void:
	if _bonus_loaded:
		return
	_bonus_loaded = true
	if not persist or not FileAccess.file_exists(BONUS_PATH):
		return
	var file := FileAccess.open(BONUS_PATH, FileAccess.READ)
	if file == null or file.get_length() > 65536:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.get("bonus") is Dictionary:
		return
	# Party EXP from an earlier opening of the world, or of an earlier roster, is forgotten.
	if int(parsed.get("start", 0)) != START_UNIX or String(parsed.get("roster", "")) != ROSTER_ID:
		_bonus_dirty = true
		return
	for key in parsed.bonus:
		var value: Variant = parsed.bonus[key]
		if (value is float or value is int) and float(value) >= 0.0 and float(value) < 1e9:
			bonus[String(key)] = float(value)
	var tables := {"skipped": skipped, "paused": paused, "hw_skipped": hw_skipped, "f3_skipped": f3_skipped, "held": held}
	for field in tables:
		var table: Variant = parsed.get(field, {})
		if not table is Dictionary:
			continue
		for key in table:
			var value: Variant = table[key]
			if (value is float or value is int) and float(value) >= 0.0 and float(value) < 1e9:
				(tables[field] as Dictionary)[String(key)] = float(value)
	# A party does not outlive the game: those who were in it resume from when the file
	# was written.
	var saved: Variant = parsed.get("saved", 0.0)
	if not paused.is_empty() and (saved is float or saved is int):
		resume_all(float(saved))


## Forgets every party EXP (tests).
static func clear_bonus() -> void:
	bonus.clear()
	skipped.clear()
	paused.clear()
	hw_skipped.clear()
	held.clear()
	_forge_runs.clear()
	_hw_cache.clear()
	f3_skipped.clear()
	_f3_cache.clear()
	_bonus_loaded = true
	_bonus_dirty = true


## Everything about player i at time t: the roster entry plus level, stars, online,
## place (the zone id it stands in, "" offline), doing ("hunt", "boss", "help", "stall",
## or "errand" with the errand's kind in "errand" and its end in "errand_until"), its
## guild now (0 below Lv.100; the roster's side is in "joins") and the gear grade it wears.
static func state(i: int, t: float = -1.0) -> Dictionary:
	if t < 0.0:
		t = now()
	var e: Dictionary = entry(i)
	var p := progress_at(i, t)
	var s := session_at(i, t)
	var place := ""
	var doing := ""
	var errand := {}
	var party := {}
	if not s.is_empty():
		# A forge trip (WorldGear.forge_window) takes it to the blacksmith from anywhere: a
		# field, the maze or its stall.
		errand = forge_errand(i, float(s[0]), float(s[1]), t)
		if not errand.is_empty():
			place = "town"
			doing = "errand"
		elif town_time(i, float(s[0]), float(s[1]), t):
			place = "town"
			doing = "stall"
		else:
			var plan := endgame_plan(i, float(s[0]), int(p.level), int(p.stars), bool(p.divine))
			place = String(plan.place)
			doing = String(plan.doing)
			# เขาวงกตหนึ่งในใต้หล้า: an interested player's maze blocks of the session (MazeWar).
			if MazeWar.ai_on() and MazeWar.in_maze(i, t):
				place = String(MazeWar.ID)
				doing = "maze"
			if doing != "stall" and doing != "maze":
				errand = _side_errand(i, float(s[0]), float(s[1]), t)
				if not errand.is_empty():
					place = "town"
					doing = "errand"
	var out := e.duplicate()
	out.merge(p)
	out["index"] = i
	# Everyone plays the roster's class (its "job") from Lv.1, like a new player.
	out["job"] = String(e["class"])
	out["class"] = String(e["class"])
	out["joins"] = int(e.guild)
	out["guild"] = guild_at(i, int(p.level))
	out["online"] = not s.is_empty()
	out["place"] = place
	out["doing"] = doing
	out["errand"] = String(errand.get("kind", ""))
	out["errand_until"] = float(errand.get("until", 0.0))
	out["grade"] = grade_of(int(p.level), int(p.stars), bool(p.divine))
	out["last_seen"] = _last_seen(i, t) if s.is_empty() else t
	out["pumpkin"] = halloween_mult(i, t) > 1
	# A party of world players (WorldParties): its people hunt its field together.
	if doing in ["hunt", "boss"]:
		party = WorldParties.party_of(i, t)
	out["party_id"] = String(party.get("id", ""))
	out["party_leader"] = int(party.get("leader", -1))
	out["party_members"] = (party.get("members", []) as Array).duplicate()
	if not party.is_empty():
		out["place"] = String(party.zone)
	return out


## When player i last logged off before real time t (0 if never).
static func _last_seen(i: int, t: float) -> float:
	var c: Variant = _at.get(i)
	if c != null and t >= float(c[0]) and t < float(c[1]) and float(c[3]) >= 0.0:
		return float(c[3])
	var seen := _find_last_seen(i, t)
	if c != null and t >= float(c[0]) and t < float(c[1]):
		c[3] = seen
	return seen


static func _find_last_seen(i: int, t: float) -> float:
	var w := world_time(t)
	var origin := world_time(joined_at(i))
	var day := day_of(w)
	for back in 8:
		var list := sessions_on(i, day - back)
		for k in range(list.size() - 1, -1, -1):
			var end := float(list[k][1])
			if end <= w and end > maxf(float(START_UNIX), origin):
				return real_time(end)
	return 0.0


## What a player with a play schedule does in the session that started at real time s0:
## {place, doing}. On the way up it hunts the field that fits it ("hunt"), to ★300 with
## the divine set too; once it is at ★300 (JobData.GOD_STARS) with the divine set complete
## each session is one of the endgame's: the lotus sanctum's
## boss hunts ("boss"), helping friends in a star field ("help") or a break from it,
## keeping a stall in the village with what it found ("stall").
static func endgame_plan(i: int, s0: float, level: int, stars: int, divine: bool) -> Dictionary:
	var home := session_zone(i, s0, level, stars)
	# The endgame opens at ★300 (JobData.GOD_STARS); the stars climb on to ★500 meanwhile
	# (progress_for follows the play, not the session's plan).
	if not divine or stars < JobData.GOD_STARS:
		return {"place": home, "doing": "hunt"}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("plan|%s|%d" % [entry(i).name, int(s0 / 60.0)])
	var roll := rng.randf()
	if roll < 0.45:
		return {"place": home, "doing": "boss"}
	if roll < 0.75:
		return {"place": StarProgression.REGIONS[rng.randi() % StarProgression.REGIONS.size()], "doing": "help"}
	return {"place": &"town", "doing": "stall"}


## The field player i hunts in during the session that started at real time s0: the
## field that fits it (hunting_zone); from ★200 the drowned abyss or the lotus sanctum,
## the two endgame maps with the same drops and monster band, a session each by turns of
## its own (WorldGear's drops are the same in either).
const ISLE_SHARE := 60
## Of the ★300+ sessions not on the isle, the share that hunts in ดินแดนเทวาลัย.
const HEAVEN_SHARE := 70


static func session_zone(i: int, s0: float, level: int, stars: int) -> StringName:
	var home := hunting_zone(level, stars)
	# At ★300 most sessions go to เกาะลอยฟ้าเทพมังกร (ISLE_SHARE of them, a roll of its own
	# so the turns between the two older maps stay as they were).
	if home == DrownedAbyssData.ID and stars >= SkyIsleData.ENTRY_STAR and WorldEvents.roll("isle|%s|%d" % [entry(i).name, int(s0 / 60.0)]) % 100 < ISLE_SHARE:
		return SkyIsleData.ID
	# The rest of the ★300+ sessions mostly go to ดินแดนเทวาลัย (HEAVEN_SHARE of them, a roll
	# of its own), the hunt toward ★500.
	if home == DrownedAbyssData.ID and stars >= HeavenRealmData.ENTRY_STAR and WorldEvents.roll("heaven|%s|%d" % [entry(i).name, int(s0 / 60.0)]) % 100 < HEAVEN_SHARE:
		return HeavenRealmData.ID
	if home == DrownedAbyssData.ID and hash("map|%s|%d" % [entry(i).name, int(s0 / 60.0)]) % 2 == 1:
		return DivineRegionData.ID
	return home


## The field a player hunts in: the one whose levels fit, then the star fields by stars,
## and from ★200 (DIVINE_STARS) on the ★200-300 hunting ground, the drowned abyss
## (DrownedAbyssData; STAR_RATE's ★200-300 rates are its EXP).
static func hunting_zone(level: int, stars: int, _divine := false) -> StringName:
	if level >= Game.MAX_LEVEL:
		if stars >= DIVINE_STARS:
			return DrownedAbyssData.ID
		var at: StringName = &"void"
		for k in StarProgression.REGIONS.size():
			if stars >= int(StarProgression.ENTRY[k]):
				at = StarProgression.REGIONS[k]
		return at
	ZoneData.ensure()
	for id in ZoneData.ZONES:
		var z: Dictionary = ZoneData.ZONES[id]
		if String(z.get("scene", "")) != "field" or z.get("pvp", false) or z.get("arena", false) or z.get("tower", false) or z.has("star"):
			continue
		var band: Array = z.get("level", [0, 0])
		if level >= int(band[0]) and level <= int(band[1]) and id != &"void":
			return id
	return &"meadow"


## Guild-war gear grade (GuildWarData.GRADES): the star set reached, the divine set once
## it is complete; below ★50 the plain 50-star set (war rules dress everyone).
static func grade_of(_level: int, stars: int, divine: bool) -> int:
	if divine:
		return GuildWarData.DIVINE
	var grade := 50
	for g in [100, 150, 200]:
		if stars >= g:
			grade = g
	return grade


# --- Looks and fighters ---------------------------------------------------------------

## Player i's look, always the same: its own chibi body of its gender (the roster entry's
## "body", ChibiBodies: the original or one of the other characters, picked at random for
## each player when the roster was made; anyone without one, from its name) in one of
## the ready-made colourings (ChibiLook style). Read from the roster alone, so it takes
## no draw from a guild war's or a maze's seeded rng.
static func look(i: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("look|%s" % entry(i).name)
	var l := FaceKit.random_look(rng)
	var gender := int(entry(i).gender)
	if int(l.gender) != gender:
		l["gender"] = gender
		ChibiLook.apply_style(l, (rng.randi() % FaceKit.option_count("hair", gender)) % ChibiLook.count("style"))
	var body := int(entry(i).body) if entry(i).has("body") else rng.randi() % ChibiBodies.count(gender)
	return {"gender": gender, "body": FaceKit.hero_look({"gender": gender, "body": body}).body, "style": clampi(int(l.get("style", 0)), 0, ChibiLook.count("style") - 1)}


## A party-member dictionary for the field (Companion reads class, name, level, stars;
## the gear it found follows frac and divine_frac too; "pet" is its pet, pet_of).
static func member(i: int, t: float = -1.0) -> Dictionary:
	var s := state(i, t)
	return {"class": String(s["class"]), "name": String(s.name), "level": int(s.level), "stars": int(s.stars), "exp": 0,
		"frac": float(s.frac), "divine_frac": float(s.divine_frac), "after": float(s.get("after", 0.0)),
		"stance": "aggressive", "trait": "brave", "gender": int(s.gender), "potions": POTIONS, "mp_potions": MP_POTIONS,
		"pet": pet_of(i)}


## Player i's pet (PetData): every world player has one, picked from its name, so it is
## the same pet on every device and from the day it joined.
static func pet_of(i: int) -> String:
	return PetData.of_player(String(entry(i).name))


## Brings a member sheet up to state s; true when it found something new to wear.
static func sync_member(m: Dictionary, s: Dictionary) -> bool:
	var before := gear_signature(m)
	var was := String(m["class"])
	m["class"] = String(s["class"])
	m["level"] = int(s.level)
	m["stars"] = int(s.stars)
	m["frac"] = float(s.frac)
	m["divine_frac"] = float(s.divine_frac)
	m["after"] = float(s.get("after", 0.0))
	return was != String(m["class"]) or gear_signature(m) != before


## The character sheet of a world player at its level and stars (for HeroStats): the
## gear it found and its job (the God step at Lv.100 ★300, the Ascension once it has passed
## the trial: ascended_sheet), plus every stat point spent like a player does (60% main
## stat, 40% vitality), its star points and the skill points it earned spent at the
## Skill Master (skill_ranks). All of it follows what its own play reached.
static func profile(m: Dictionary) -> Dictionary:
	return _profile(m, ascended_sheet(m))


static func _profile(m: Dictionary, ascended: bool) -> Dictionary:
	var level := int(m.level)
	var stars := Game.party_stars(m)
	var p := {"class": m["class"], "level": level, "attrs": {}, "equip": equip(m), "adv": JobData.adv_for(level, stars, ascended),
		"paragon": {"level": stars, "alloc": Game.party_star_alloc(stars), "special": Game.party_special_alloc(stars, m["class"])}}
	var points := Game.STAT_POINTS_PER_LEVEL * (level - 1)
	var main := String(JobData.resolve(StringName(m["class"]), int(p.adv)).main)
	var attrs := {"str": 0, "int": 0, "dex": 0, "vit": 0}
	attrs[main] = int(points * 0.6)
	attrs["vit"] = int(attrs["vit"]) + int(points * 0.4)
	p["attrs"] = attrs
	p["skills"] = skill_ranks(StringName(m["class"]), level, stars, ascended)
	# Its mount (mount_of): the stats count like the hero's (HeroStats.mount_bonus).
	var ride := mount_of(m)
	p["mounts"] = {String(ride.id): int(ride.level)} if not ride.is_empty() else {}
	p["mount"] = String(ride.get("id", ""))
	return p


## Skill points a player has earned by `level` and `stars`, the way the hero earns them
## (Game): one to start and one each level, the job advancements' (JobData.TIER_SKILL_POINTS)
## and two at each star tier (StarProgression.grant_milestones), and the Ascension's once
## it has passed the trial ([param ascended], ascended_at).
static func skill_points(level: int, stars: int, ascended := false) -> int:
	var points := level
	for k in JobData.adv_for_level(level):
		points += int(JobData.TIER_SKILL_POINTS[k])
	if level >= Game.MAX_LEVEL:
		for tier in StarProgression.TIERS:
			points += 2 if stars >= int(tier) else 0
	if JobData.is_ascended(JobData.adv_for(level, stars, ascended)):
		points += JobData.ASCEND_SKILL_POINTS
	return points


## The ranks a player of class `cls` has bought at the Skill Master by `level` and
## `stars`: every skill it has unlocked starts at rank 1, and the points it earned
## (skill_points) go one at a time to the lowest-ranked skill (the longest-known first),
## like a player keeping its whole bar up, up to SkillRank.MAX; points it has no use
## for yet wait for the next skill. [param ascended]: it has passed the trial (ascended_at),
## which opens the two Ascension skills at ★500.
static func skill_ranks(cls: StringName, level: int, stars: int, ascended := false) -> Dictionary:
	var unlocked: Array = []
	# A class with skill lines: its lines (ranks are kept per line, ClassData.rank_id).
	for skill in ClassData.pool(cls):
		if int(skill.level) <= level and (not ClassData.has_lines(cls) or ClassData.is_line(cls, String(skill.id)) or skill.has("star")):
			# The Ascension's skills only once it has passed the trial (★500 and its own win
			# against the guardian, ascended_at).
			if bool(skill.get("ascend", false)) and not JobData.is_ascended(JobData.adv_for(level, stars, ascended)):
				continue
			unlocked.append(skill)
	unlocked.sort_custom(func(a, b): return int(a.level) < int(b.level))
	var ranks := {}
	for skill in unlocked:
		ranks[String(skill.id)] = 1
	var points := skill_points(level, stars, ascended)
	for rank in range(1, SkillRank.MAX):
		for skill in unlocked:
			if points <= 0:
				return ranks
			ranks[String(skill.id)] = rank + 1
			points -= 1
	return ranks


## Player i's skills at real time t for its card: {skills (how many it has unlocked),
## stars (the ranks it bought, skill_ranks), max}.
static func skill_summary(i: int, t: float) -> Dictionary:
	var p := progress_at(i, t)
	var level := int(p.level)
	var cls := StringName(String(entry(i)["class"]))
	var ranks := skill_ranks(cls, level, int(p.stars), ascended_at(i, t))
	var stars := 0
	for id in ranks:
		stars += int(ranks[id])
	return {"skills": ranks.size(), "stars": stars, "max": ranks.size() * SkillRank.MAX}


# --- The Ascension trial (บททดสอบเทวาลัย, AscensionData) ---------------------------------

## A world player at ★500 is not Ascended by its stars: like the hero it walks the trial's
## steps and must defeat the guardian (AscensionData.BOSS_ID) itself. Everything is read off
## its own work (work_at: its play, the same on every device), so the answer is the same
## everywhere and only ever goes from "not yet" to "passed":
## * ★500 is reached at star500_work(); the hunt and the tokens then take TRIAL_PREP_WORK
##   (the elites the two steps ask for at the endgame maps' elite kill rate, WorldGear),
##   so the first try comes about a day and a half of a hardcore player's play later;
## * then a try every TRIAL_EVERY_HOURS of its play (about a session) until it wins;
## * each try is fought with what it really has then: its God sheet at that work (the
##   gear WorldGear forged, its stat and skill points, adv 5) against the guardian's own
##   stats (MonsterData.stats_for, the trial's level): trial_odds estimates the seconds it
##   needs to bring the guardian down and the seconds it lasts (each blow at least
##   AscensionData.FLOOR_SHARE of its max HP, the blows it does not dodge or step out of,
##   its lifesteal; past ENRAGE_SECONDS the blows land ENRAGE_ATK times harder), and turns
##   the margin into a chance (trial_chance); a seeded roll of its name and the try's
##   number decides (_try_roll). Its hands (trial_hands, by name) and what it learns from
##   each failed try (TRIAL_LEARN) count; a chance below TRIAL_MIN_CHANCE is no chance.
## So the strong pass in a try or two, the weak keep failing until their gear grows, and
## some never pass. Kept per player (_trial): the tries looked at so far and the work of
## its win; a later read only looks at the tries since.
const TRIAL_PREP_WORK := (AscensionData.HUNT_COUNT + AscensionData.TOKEN_COUNT / AscensionData.TOKEN_CHANCE) / (WorldGear.KILLS_ENDGAME * WorldGear.ELITE_SHARE)
const TRIAL_EVERY_HOURS := 2.5
## The same guardian the hero fights (the owner's rule: one standard for everyone), a
## second: TRIAL_BLOWS swings (each at least AscensionData.FLOOR_SHARE of max HP), a
## volley of its field moves (BossAttack: TRIAL_VOLLEY_SHOTS shots at TRIAL_VOLLEY_MULT
## its attack, the floor scaled the same, capped at FLOOR_MAX_SCALE) every
## Mob.SLAM_INTERVAL, and a story move (StoryBoss: HIT_FRACTION of max HP) every
## StoryBoss.CYCLE at the trial's average haste (AscendTrial.PHASE_HASTE); the share of
## them a player of trial_hands 1 steps out of (its own dodge comes on top).
const TRIAL_BLOWS := 0.5
const TRIAL_VOLLEY_SHOTS := 2.0
const TRIAL_VOLLEY_MULT := 1.4
const TRIAL_EVADE := 0.7
const TRIAL_EVADE_MAX := 0.85
## Lifesteal makes good at most this share of the damage that lands.
const TRIAL_HEAL_MAX := 0.7
## Damage a second: the bar's TRIAL_SKILLS best single-target skills at their rank and
## the basic attack (like tools/balance.gd), TRIAL_UPTIME of the fight spent hitting.
const TRIAL_SKILLS := 4
const TRIAL_UPTIME := 0.6
## The margin (seconds it can fight / seconds it needs) turned into a chance: 50% at
## TRIAL_EVEN, rising and falling by the log of the margin over TRIAL_SPREAD. 1.0: an even
## chance when it lasts just as long as it needs (the same fight as the hero's, no thumb
## on the scale either way).
const TRIAL_EVEN := 1.0
const TRIAL_SPREAD := 0.5
const TRIAL_MIN_CHANCE := 0.04
const TRIAL_MAX_CHANCE := 0.92
## Hands: TRIAL_HANDS[0]..[1] by name; each failed try adds TRIAL_LEARN, up to TRIAL_LEARN_MAX.
const TRIAL_HANDS := Vector2(0.7, 1.15)
const TRIAL_LEARN := 0.012
const TRIAL_LEARN_MAX := 0.24
## The tries whose sheet is read (HeroStats, about a millisecond): past ★500 the gear
## grows slowly, so the tries between fight with the last one read, and a player who
## keeps failing costs a read at those tries, then one every TRIAL_SHEET_EVERY (its gear
## goes on growing, and a later try fights with it).
const TRIAL_SHEET_AT: Array[int] = [0, 10, 40, 160]
const TRIAL_SHEET_EVERY := 80
## Per player: {k: tries looked at, pass: its win's work (INF none yet), sheet / stats:
## the last sheet read, odds: its chance by hands for that sheet}.
static var _trial := {}
static var _guardian := {}


## The work at which every world player reaches ★500 (Game.PARAGON_MAX).
static func star500_work() -> float:
	var steps := _steps()
	return steps[mini(Game.MAX_LEVEL - 1 + JobData.ASCEND_STARS, steps.size() - 1)]


## The work of player i's try k (0 the first).
static func trial_work(i: int, k: int) -> float:
	return star500_work() + TRIAL_PREP_WORK + float(k) * TRIAL_EVERY_HOURS * 60.0 * efficiency(i)


## Player i's own hands in the trial (fixed by name).
static func trial_hands(i: int) -> float:
	return lerpf(TRIAL_HANDS.x, TRIAL_HANDS.y, float(hash("trial_hands|%s" % entry(i).name) % 10000) / 9999.0)


## The guardian as the trial stage fights it: {hp, atk, def}.
static func guardian() -> Dictionary:
	if _guardian.is_empty():
		_guardian = MonsterData.stats_for(AscensionData.BOSS_ID, AscendTrial.BOSS_LEVEL)
	return _guardian


## {kill (seconds to bring the guardian down), last (seconds it lasts), margin} of the
## God sheet `sheet` with its stats `st` against the guardian, at hands `hands`.
static func trial_odds(sheet: Dictionary, st: Dictionary, hands: float) -> Dictionary:
	var g := guardian()
	var cls := StringName(sheet["class"])
	var data := JobData.resolve(cls, int(sheet.adv))
	var crit := 1.0 + clampf(float(st.crit), 0.0, 1.0) * (HeroStats.CRIT_DAMAGE - 1.0 + float(st.get("crit_dmg", 0.0)))
	var attack: Dictionary = data.get("attack", {"mult": 1.0, "interval": 1.0})
	var per_atk := float(attack.get("mult", 1.0)) / (maxf(0.3, float(attack.get("interval", 1.0))) * 1.05)
	var ranks: Dictionary = sheet.get("skills", {})
	var level := int(sheet.level)
	var stars := int((sheet.get("paragon", {}) as Dictionary).get("level", 0))
	var rates: Array = []
	for skill in ClassData.pool(cls):
		if float(skill.get("mult", 0.0)) <= 0.0 or not ClassData.knows(skill, level, 1 + int(sheet.adv), stars):
			continue
		var rank := int(ranks.get(ClassData.rank_id(skill), ranks.get(String(skill.id), 1)))
		rates.append(float(skill.mult) * SkillRank.power(rank) / (float(skill.get("cd", 1.0)) * (1.0 - clampf(float(st.get("cdr", 0.0)), 0.0, 0.5)) + 0.9))
	rates.sort()
	rates.reverse()
	for k in mini(TRIAL_SKILLS, rates.size()):
		per_atk += float(rates[k]) * TRIAL_UPTIME
	var dps := HeroStats.mitigate(float(st.atk) * per_atk * crit, float(g.def) * (1.0 - clampf(float(st.get("pierce", 0.0)), 0.0, 0.9))) * hands
	var kill := float(g.hp) / maxf(1.0, dps)
	var max_hp := maxf(1.0, float(st.max_hp))
	var guard := 1.0 - clampf(float(st.get("guard", 0.0)), 0.0, 0.45)
	var swing := maxf(HeroStats.mitigate(float(g.atk), float(st.def)), AscensionData.FLOOR_SHARE * max_hp)
	var shot := maxf(HeroStats.mitigate(float(g.atk) * TRIAL_VOLLEY_MULT, float(st.def)), minf(TRIAL_VOLLEY_MULT, AscensionData.FLOOR_MAX_SCALE) * AscensionData.FLOOR_SHARE * max_hp)
	var haste := 0.0
	for h in AscendTrial.PHASE_HASTE:
		haste += float(h) / float(AscendTrial.PHASE_HASTE.size())
	var story_every := (StoryBoss.CYCLE.x + StoryBoss.CYCLE.y) * 0.5 * haste
	# The damage a second the guardian sends (blow = that, one blow a second).
	var blow := (TRIAL_BLOWS * swing + TRIAL_VOLLEY_SHOTS * shot / Mob.SLAM_INTERVAL + StoryBoss.HIT_FRACTION * max_hp / story_every) * guard
	var landed := (1.0 - clampf(float(st.get("dodge", 0.0)), 0.0, 0.5)) * (1.0 - clampf(TRIAL_EVADE * hands, 0.0, TRIAL_EVADE_MAX))
	# Lifesteal heals between the blows, but never more than TRIAL_HEAL_MAX of what lands
	# (a blow takes its share at once).
	var heal := float(st.get("lifesteal", 0.0)) * dps
	var lose := maxf(blow * landed - heal, blow * landed * (1.0 - TRIAL_HEAL_MAX))
	var lose_enraged := maxf(blow * AscensionData.ENRAGE_ATK * landed - heal, blow * AscensionData.ENRAGE_ATK * landed * (1.0 - TRIAL_HEAL_MAX))
	var last := max_hp / maxf(0.001, lose)
	if last > AscensionData.ENRAGE_SECONDS:
		last = AscensionData.ENRAGE_SECONDS + (max_hp - lose * AscensionData.ENRAGE_SECONDS) / maxf(0.001, lose_enraged)
	return {"kill": kill, "last": last, "margin": last / maxf(0.001, kill), "dps": dps}


## The chance a try with this margin (trial_odds) wins.
static func trial_chance(margin: float) -> float:
	var p := 1.0 / (1.0 + exp(-(log(maxf(margin, 0.0001)) - log(TRIAL_EVEN)) / TRIAL_SPREAD))
	return 0.0 if p < TRIAL_MIN_CHANCE else minf(p, TRIAL_MAX_CHANCE)


## Player i's God sheet and stats at work w (what it fights the guardian with: adv 5,
## no Ascension skills).
static func trial_sheet(i: int, w: float) -> Dictionary:
	var p := progress_for(0.0, efficiency(i), w)
	var e := entry(i)
	var m := {"class": String(e["class"]), "name": String(e.name), "level": int(p.level), "stars": int(p.stars),
		"frac": float(p.frac), "divine_frac": float(p.divine_frac), "after": float(p.after)}
	return _profile(m, false)


## The seeded roll of player i's try k (0..1): its name and the try's number alone.
static func _try_roll(i: int, k: int) -> float:
	return float(hash("trial|%s|%d" % [entry(i).name, k]) % 1000000) / 1000000.0


## Looks at player i's tries up to work w (each once): the work of its win, INF none yet.
static func _trial_pass(i: int, w: float) -> float:
	var c: Dictionary = _trial.get(i, {})
	if c.is_empty():
		c = {"k": 0, "pass": INF, "sheet": {}, "stats": {}, "odds": {}}
		_trial[i] = c
	if float(c.pass) < INF:
		return float(c.pass)
	while trial_work(i, int(c.k)) <= w:
		var k := int(c.k)
		var at := trial_work(i, k)
		if TRIAL_SHEET_AT.has(k) or (k > 160 and (k - 160) % TRIAL_SHEET_EVERY == 0) or (c.sheet as Dictionary).is_empty():
			c["sheet"] = trial_sheet(i, at)
			c["stats"] = HeroStats.compute(c.sheet)
			c["odds"] = {}
		# The odds change only with a new sheet read or what it has learnt (TRIAL_LEARN).
		var hands := trial_hands(i) + minf(float(k) * TRIAL_LEARN, TRIAL_LEARN_MAX)
		var odds: Dictionary = c.odds
		if not odds.has(hands):
			odds[hands] = trial_chance(float(trial_odds(c.sheet, c.stats, hands).margin))
		var chance := float(odds[hands])
		c["k"] = k + 1
		if _try_roll(i, k) < chance:
			c["pass"] = at
			c["sheet"] = {}
			c["stats"] = {}
			c["odds"] = {}
			return at
	return INF


## Whether player i has passed the trial by work w (its sheet's work, work_of / work_at).
static func ascended_at_work(i: int, w: float) -> bool:
	if i < 0 or w < trial_work(i, 0):
		return false
	return _trial_pass(i, w) <= w


## Whether player i has passed the trial by real time t (JobData.adv_for's Ascension step).
static func ascended_at(i: int, t: float) -> bool:
	if _all.is_empty():
		_roster()
	if i < 0 or i >= _all.size():
		return false
	return ascended_at_work(i, work_at(i, t))


## Whether member sheet m (a world player's, by name or "index") has passed the trial at
## the play its sheet shows (work_of); never below ★500, never for a sheet of nobody's.
static func ascended_sheet(m: Dictionary) -> bool:
	if int(m.get("level", 1)) < Game.MAX_LEVEL or int(m.get("stars", 0)) < JobData.ASCEND_STARS:
		return false
	var i := int(m.index) if m.has("index") and int(m.index) >= 0 and int(m.index) < _all.size() and String(entry(int(m.index)).name) == String(m.get("name", entry(int(m.index)).name)) else _sheet_index(m)
	if i < 0:
		return false
	return ascended_at_work(i, work_of(m, i))


## The tries player i has made by work w (its win included), for its card and chat.
static func trial_tries(i: int, w: float) -> int:
	if i < 0 or w < trial_work(i, 0):
		return 0
	var at := _trial_pass(i, w)
	if at <= w:
		return int(_trial[i].k)
	return int(floor((w - trial_work(i, 0)) / (TRIAL_EVERY_HOURS * 60.0 * efficiency(i)))) + 1


## The world players who passed the trial between real times t0 and t1 (tests; a pass
## over everyone: the Announcer uses take_ascended instead).
static func ascended_between(t0: float, t1: float) -> Array[int]:
	var out: Array[int] = []
	if t1 <= t0:
		return out
	var first := star500_work() + TRIAL_PREP_WORK
	for i in _all.size():
		if t1 < joined_at(i):
			continue
		var w1 := work_at(i, t1)
		if w1 < first or not ascended_at_work(i, w1):
			continue
		if not ascended_at_work(i, work_at(i, t0)):
			out.append(i)
	return out


## The world players found to have passed the trial since the last call (the Announcer's
## "ผ่านบททดสอบเทวาลัย" line, once a WATCH_EVERY seconds): WATCH_SLICE players a call,
## round the world in turn, each compared with what it was the last time it was looked at,
## so a pass is told within a few minutes and a call costs a few work reads (a player whose
## forging WorldGear has not worked out that far yet waits for a later round). Nothing is
## told for a player seen for the first time, or across a gap longer than WATCH_GAP (a
## game back from the background does not replay what it missed).
const WATCH_SLICE := 40
const WATCH_GAP := 1800.0
static var _watch := {}
static var _watch_next := 0


static func take_ascended(t: float) -> Array[int]:
	var out: Array[int] = []
	var n := _all.size()
	if n == 0:
		return out
	var first := star500_work() + TRIAL_PREP_WORK
	for _k in mini(WATCH_SLICE, n):
		var i := _watch_next % n
		_watch_next = (_watch_next + 1) % n
		if t < joined_at(i):
			continue
		var w := work_at(i, t)
		# A try not looked at yet whose forging is not worked out (WorldGear.warm does it a
		# little each frame) waits for a later round: the watch never forces a simulation.
		if w >= first and not _trial_known(i, w) and not WorldGear.is_warm(i, w):
			continue
		var now_passed := w >= first and ascended_at_work(i, w)
		var was: Variant = _watch.get(i)
		_watch[i] = [t, now_passed]
		if now_passed and was != null and not bool(was[1]) and t - float(was[0]) <= WATCH_GAP:
			out.append(i)
	return out


## Whether player i's tries up to work w are all looked at already (a read is a look-up).
static func _trial_known(i: int, w: float) -> bool:
	var c: Dictionary = _trial.get(i, {})
	return not c.is_empty() and (float(c.pass) <= w or trial_work(i, int(c.k)) > w)


## Forgets what take_ascended has seen (tests, Announcer.reset).
static func reset_watch() -> void:
	_watch.clear()
	_watch_next = 0


# --- Mounts (MountData) --------------------------------------------------------------

## The share of players who ever take up mounts (the rest never craft one).
const MOUNT_SHARE := 0.6
## The level a mount-keeping player crafts its first mount (its own, in this range).
const MOUNT_FROM := Vector2i(35, 70)
## Progress (levels since the first mount + stars) a player needs, beyond its own
## extra, before it trades up to the stag, the griffin and the drake.
const MOUNT_TIERS := {"glow_stag": [30.0, 30.0], "griffin": [90.0, 60.0], "fire_drake": [170.0, 90.0]}
## Of the players who get that far, the share that ever lands the drake's 10% craft.
const DRAKE_SHARE := 0.25
## Progress per mount level (Lv.1 at the craft, up to MountData.MAX_LEVEL).
const MOUNT_LEVEL_EVERY := 14.0
## How much each play style likes to ride (MOUNT_TASTE_JITTER scales it per player).
const STYLE_RIDE := {"hardcore": 0.75, "regular": 0.55, "student": 0.6, "night_owl": 0.5, "weekend": 0.45,
	"casual": 0.35, "daytime": 0.45, "early": 0.4, "overseas": 0.5, "afk": 0.2}
## The share of mount owners who never bother riding, and who rarely do.
const NEVER_RIDE := 0.15
const RARELY_RIDE := 0.25


## The mount a world player (member sheet: name, level, stars) has at its progress: {id,
## level} or {} with none. Seeded by its name, so the same on every device: some players
## never craft one; the rest craft the wolf at a level of their own (MOUNT_FROM) and trade
## up as they progress, levelling the newest one.
static func mount_of(m: Dictionary) -> Dictionary:
	var i := _sheet_index(m)
	if i >= 0:
		return WorldGear.mount_at_work(i, work_of(m, i))
	return _drawn_mount(m)


## The world player a member sheet belongs to (by name; -1 for none, e.g. a stand-in).
static func _sheet_index(m: Dictionary) -> int:
	var name := String(m.get("name", ""))
	if name == "":
		return -1
	if not _index.has(name):
		if _all.is_empty():
			_roster()
		if not _index.has(name):
			return -1
	return int(_index[name])


## The mount a sheet that is no world player's would have, drawn from its name alone.
static func _drawn_mount(m: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("mount|%s" % String(m.get("name", "")))
	if rng.randf() >= MOUNT_SHARE:
		return {}
	var from := rng.randi_range(MOUNT_FROM.x, MOUNT_FROM.y)
	var level := int(m.get("level", 1))
	if level < from:
		return {}
	var point := float(level - from) + float(m.get("stars", 0))
	var id := "thunder_wolf"
	var since := 0.0
	var drake := rng.randf() < DRAKE_SHARE
	for tier in ["glow_stag", "griffin", "fire_drake"]:
		var need := float(MOUNT_TIERS[tier][0]) + rng.randf() * float(MOUNT_TIERS[tier][1])
		if point >= need and (tier != "fire_drake" or drake):
			id = tier
			since = need
	return {"id": id, "level": clampi(1 + int((point - since) / MOUNT_LEVEL_EVERY), 1, MountData.MAX_LEVEL)}


## How much player i likes to ride its mount (0 = never, up to about 0.95 = nearly
## always), always the same: its play style's taste (STYLE_RIDE) and its own whim; some
## never ride, some rarely.
static func ride_taste(i: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("ride|%s" % entry(i).name)
	var pick := rng.randf()
	if pick < NEVER_RIDE:
		return 0.0
	var base := float(STYLE_RIDE.get(String(entry(i).style), 0.5))
	if pick < NEVER_RIDE + RARELY_RIDE:
		return clampf(base * rng.randf_range(0.15, 0.4), 0.05, 0.3)
	return clampf(base * rng.randf_range(0.9, 1.5), 0.2, 0.95)


# --- What they wear: what they found -----------------------------------------------

## A world player wears what it has picked up, slot by slot, like a player: every level
## band (10 levels) its monsters drop one piece per slot somewhere in the band, or none
## at all (MISS: it keeps the older piece through that band); a find has its own rarity
## and is enhanced a step at a time after it is found (common pieces less). The best piece
## found so far is worn, so a rare older piece can stay on over a plain newer one. Past
## Lv.100 the star fields drop the star tiers' pieces, worn some stars after the tier opens;
## a Lv.100 boss drops the class wings, the star wings come after ★100; in the lotus
## sanctum the divine pieces turn up one by one until the set is complete. All of it is
## seeded by the player's name: the same finds on every device at the same moment.
const FIND_LEVELS := 8.0
const FIND_STARS := 22.0
const MISS := 0.22
const STAR_MISS := 0.12
## Rarity of a find, common .. mythic (players keep the better drops).
const FIND_RARITY := [0.16, 0.36, 0.32, 0.13, 0.03]
## A find comes from the monster at +0 and is taken to the forge like the hero's gear
## (ItemData.JEWELS): +1 to +6 come one each PLUS_EVERY levels of play (purple jewels,
## never failing), +7 to +9 take three times as long each (pink jewels at 50%), and +10
## as long as all three of those (three purple and two pink at 50%). Star pieces go the
## same way by stars (STAR_PLUS_EVERY), the divine set by hours (DIVINE_PLUS_HOURS).
## Like the hero, a player never finds a piece already enhanced: every find is +0 and
## goes up only at the forge, once it has gathered the jewels (ENHANCE_WAIT of play
## first), and the jewels are shared by every slot, so a grade takes a few levels.
const PLUS_EVERY := 4.0
const STAR_PLUS_EVERY := 6.0
const ENHANCE_WAIT := 1.5


## The forge grade reached after `progress` (levels or stars) of play with one step
## every `step`.
static func plus_after(progress: float, step: float) -> int:
	var steps := (progress - ENHANCE_WAIT) / maxf(0.001, step)
	if steps < 6.0:
		return int(maxf(steps, 0.0))
	if steps < 15.0:
		return 6 + int((steps - 6.0) / 3.0)
	return 9 if steps < 24.0 else 10
## Stars after the wing level the class wings drop, and after ★100 the star wings.
const WING_STARS := 35.0
const STAR_WING_STARS := 40.0

static var _gear := {}
static var _gear_sig := {}


## Where a member sheet is on the way, as one number: Lv.1-100 with the part of the
## level done, then 100 + stars (to 600 at ★500, Game.PARAGON_MAX).
static func point_of(m: Dictionary) -> float:
	var level := int(m.level)
	var frac := clampf(float(m.get("frac", 0.0)), 0.0, 0.999)
	if level < Game.MAX_LEVEL:
		return float(level) + frac
	var stars := clampi(int(m.get("stars", 0)), 0, Game.PARAGON_MAX)
	return float(Game.MAX_LEVEL + stars) + (frac if stars < Game.PARAGON_MAX else 0.0)


static func _find_rng(name: String, slot: String, what: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("find|%s|%s|%s" % [name, slot, what])
	return rng


static func _roll_find_rarity(rng: RandomNumberGenerator) -> int:
	var r := rng.randf()
	for k in FIND_RARITY.size():
		r -= float(FIND_RARITY[k])
		if r <= 0.0:
			return k
	return 0


## The piece kept for one slot at point p: {} when nothing was found yet, otherwise
## {"key", "kind" (level / star / divine), "level", "rarity", "plus", "tier", "at"}.
static func _best_find(name: String, slot: String, p: float, divine_frac: float) -> Dictionary:
	var best := {}
	var best_score := -1.0
	for band in 10:
		var start := float(band * 10 + 1)
		if p < start:
			break
		var rng := _find_rng(name, slot, "b%d" % band)
		var at := start + rng.randf() * FIND_LEVELS
		var rarity := _roll_find_rarity(rng)
		var missed := rng.randf() < MISS
		if band == 0 and slot == "weapon":
			# Everyone sets out with the beginner's weapon.
			at = 1.0
			rarity = 0
			missed = false
		if missed or p < at:
			continue
		var level := clampi(int(at), int(start), int(start) + 9)
		var plus := plus_after(p - at, PLUS_EVERY)
		var score := ItemData.gear_power(level) * ItemData.rarity_mult(rarity, 0.2) * (1.0 + 0.06 * plus)
		if score > best_score:
			best_score = score
			best = {"key": "b%d" % band, "kind": "level", "level": level, "rarity": rarity, "plus": plus, "at": at}
	for tier in StarProgression.TIERS:
		var start := float(Game.MAX_LEVEL + int(tier))
		if p < start:
			break
		var rng := _find_rng(name, slot, "s%d" % tier)
		var at := start + rng.randf() * FIND_STARS
		if rng.randf() < STAR_MISS or p < at:
			continue
		var score := ItemData.gear_power(Game.MAX_LEVEL + int(tier)) * ItemData.rarity_mult(3, 0.2)
		if score > best_score:
			best_score = score
			best = {"key": "s%d" % tier, "kind": "star", "tier": int(tier), "at": at, "plus": plus_after(p - at, STAR_PLUS_EVERY)}
	if divine_frac > 0.0 and slot in DivineGearData.SLOTS:
		var rng := _find_rng(name, slot, "divine")
		if divine_frac >= rng.randf_range(0.12, 1.0):
			best = {"key": "divine", "kind": "divine", "at": float(Game.MAX_LEVEL + DIVINE_STARS)}
	return best


## The pair of wings found by point p ({} for none yet).
static func _wing_find(name: String, p: float) -> Dictionary:
	var start := float(ItemData.WING_DROP_LEVEL)
	if p < start:
		return {}
	var star_rng := _find_rng(name, "wings", "star")
	var star_at := float(Game.MAX_LEVEL + StarWingData.REQUIRED_STARS) + star_rng.randf() * STAR_WING_STARS
	if p >= star_at:
		return {"key": "star_wings", "at": star_at}
	var rng := _find_rng(name, "wings", "class")
	var at := start + rng.randf() * WING_STARS
	return {"key": "wings", "at": at} if p >= at else {}


static func _gear_key(m: Dictionary) -> String:
	return "%s|%s|%d|%d|%d" % [m.name, m["class"], int(point_of(m) * 4.0), int(float(m.get("divine_frac", 0.0)) * 8.0), divine_plus(m)]


## Which pieces member sheet m wears, as one string (changes when it puts on a new find
## or enhances one).
static func gear_signature(m: Dictionary) -> String:
	var i := _sheet_index(m)
	if i >= 0:
		return WorldGear.signature_at_work(i, work_of(m, i))
	var key := _gear_key(m)
	if not _gear_sig.has(key):
		equip(m)
	return String(_gear_sig.get(key, ""))


## What member sheet m wears now: its best find per slot (see above).
static func equip(m: Dictionary) -> Dictionary:
	var i := _sheet_index(m)
	if i >= 0:
		return WorldGear.equip_at_work(i, work_of(m, i))
	return drawn_equip(m)


## What a sheet that is no world player's wears: its best find per slot, drawn by point.
static func drawn_equip(m: Dictionary) -> Dictionary:
	var key := _gear_key(m)
	if _gear.has(key):
		return _gear[key]
	var name := String(m.name)
	var cls := StringName(m["class"])
	var p := point_of(m)
	var divine_frac := float(m.get("divine_frac", 0.0))
	var gear := {}
	var sig: PackedStringArray = []
	for slot in ItemData.SLOTS:
		var find := _best_find(name, slot, p, divine_frac)
		if find.is_empty():
			continue
		var rng := _find_rng(name, slot, "%s|item" % find.key)
		var item := {}
		match String(find.kind):
			"divine":
				item = DivineGearData.item(cls, slot, rng)
				if EnhanceFx.can_enhance(item):
					item["plus"] = divine_plus(m)
			"star":
				item = StarProgression.item(cls, int(find.tier), slot, rng)
				if EnhanceFx.can_enhance(item):
					item["plus"] = int(find.plus)
			_:
				item = ItemData.generate(int(find.level), cls, rng, int(find.rarity), slot)
				if find.key == "b0" and slot == "weapon":
					item["name"] = "%s ของมือใหม่" % ItemData.NAMES[item.base][0]
				if EnhanceFx.can_enhance(item):
					item["plus"] = int(find.plus)
		if item.is_empty():
			continue
		gear[slot] = item
		sig.append("%s:%s+%d" % [slot, find.key, int(item.get("plus", 0))])
	var wings := _wing_find(name, p)
	if not wings.is_empty():
		var rng := _find_rng(name, "wings", "%s|item" % wings.key)
		gear["wings"] = StarWingData.item(String(cls), rng, 3) if wings.key == "star_wings" else ItemData.wings(rng, String(cls), 2 + rng.randi() % 2)
		sig.append(String(wings.key))
	if _gear.size() > 400:
		_gear.clear()
		_gear_sig.clear()
	_gear[key] = gear
	_gear_sig[key] = ",".join(sig)
	return gear


## The endgame: after the divine set is complete a player enhances it a grade every
## DIVINE_PLUS_HOURS hours of play, up to +10.
const DIVINE_PLUS_HOURS := 3.0


static func divine_plus(m: Dictionary) -> int:
	var i := _sheet_index(m)
	if i >= 0:
		return int(WorldGear.divine_plus_of(WorldGear.state_at_work(i, work_of(m, i))))
	return clampi(int(float(m.get("after", 0.0)) / DIVINE_PLUS_HOURS), 0, 10)


## The newest piece in `after` that `before` did not have (for "picked up" notes), or {}.
static func new_piece(before: Dictionary, after: Dictionary) -> Dictionary:
	for slot in after:
		var was: Variant = before.get(slot)
		var now_item: Dictionary = after[slot]
		if not was is Dictionary or String(was.get("name", "")) != String(now_item.get("name", "")) or int(was.get("plus", 0)) != int(now_item.get("plus", 0)):
			return now_item
	return {}


## How a player likes its wings (weights for stand / fly / fold), always the same.
static func wing_taste(i: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("wings|%s" % entry(i).name)
	return [rng.randf_range(0.2, 1.0), rng.randf_range(0.1, 1.4), rng.randf_range(0.05, 0.9)]


## Player i as a guild-war fighter at time t, as it really is then: its level, stars,
## stat points, skill ranks and the gear it found (WorldPlayers.profile), its own name and face.
static func fighter(i: int, t: float, _rng: RandomNumberGenerator = null) -> Dictionary:
	var s := state(i, t)
	var m := member(i, t)
	var sheet := profile(m)
	return {
		"member": {"class": String(s["class"]), "name": String(s.name), "level": int(s.level)},
		"profile": sheet,
		"mults": {"hp": 1.0, "atk": 1.0, "def": 1.0},
		"difficulty": GuildWarData.SKILL,
		"look": look(i),
		"grade": int(s.grade),
		"tag": level_text(s),
		"power": GuildWarData.power_of(HeroStats.compute(sheet)),
		"world": i,
		"online": bool(s.online),
	}


## Whether player state (or member) s has taken the God promotion: Lv.100 and ★300
## (JobData.adv_for), like the hero's เทพเจ้าแห่ง<อาชีพ>.
static func is_god(s: Dictionary) -> bool:
	return JobData.is_god(JobData.adv_for(int(s.get("level", 1)), int(s.get("stars", 0))))


## Its God title ("เทพเจ้าแห่งนักรบ"), "" before the promotion; its Ascension's name once it
## has passed the trial at ★500 (ascended_of: "ascended" or "adv" when s carries one,
## else the world player s names, at the play its sheet shows).
static func god_title(s: Dictionary) -> String:
	if ascended_of(s):
		return String(JobData.ascend_step(StringName(s.get("class", "warrior"))).name)
	return JobData.god_name(StringName(s.get("class", "warrior"))) if is_god(s) else ""


## Whether state, member sheet or plate s is Ascended: its "ascended" when it says, its
## "adv" (a real player's own step) when it carries one, else its world player's trial
## at the play its sheet shows (ascended_sheet). Below ★500 never.
static func ascended_of(s: Dictionary) -> bool:
	if int(s.get("level", 1)) < Game.MAX_LEVEL or int(s.get("stars", 0)) < JobData.ASCEND_STARS:
		return false
	if s.has("ascended"):
		return bool(s.ascended)
	if s.has("adv"):
		return JobData.is_ascended(int(s.adv))
	return ascended_sheet(s)


## Display line: "Lv.57" or "Lv.100 ★120".

static func level_text(s: Dictionary) -> String:
	return "Lv.%d%s" % [int(s.level), " ★%d" % int(s.stars) if int(s.stars) > 0 else ""]


const ERRAND_TEXT := {"quest": " · ส่งเควส", "enhance": " · ตีบวก", "skill": " · เรียนสกิล"}


## Where a player is, for the guild roster.
static func where_text(s: Dictionary, t: float = -1.0) -> String:
	if t < 0.0:
		t = now()
	if t < START_UNIX:
		return "รอเปิดโลก"
	if bool(s.online):
		var place := StringName(s.place)
		var where: String = ZoneData.get_zone(place).name if place != &"town" else "หมู่บ้าน"
		match String(s.get("doing", "")):
			"stall":
				return "ออนไลน์ · ตั้งร้านใน%s" % where
			"errand":
				return "ออนไลน์ · แวะ%s%s" % [where, ERRAND_TEXT.get(String(s.get("errand", "")), "")]
			"boss":
				return "ออนไลน์ · ล่าบอสที่ %s" % where
			"help":
				return "ออนไลน์ · พาเพื่อนเก็บดาวที่ %s" % where
			"maze":
				return "ออนไลน์ · ล่าหัวใน%s" % where
		return "ออนไลน์ · %s" % where
	var seen := float(s.get("last_seen", 0.0))
	if seen <= 0.0:
		return "ยังไม่เคยเข้าเกม" if t >= joined_at(int(s.get("index", 0))) else "ผู้เล่นใหม่ เข้าเกมเร็ว ๆ นี้"
	var ago := int((t - seen) / 60.0)
	if ago < 60:
		return "ออฟไลน์ · %d นาทีก่อน" % maxi(1, ago)
	if ago < 60 * 24:
		return "ออฟไลน์ · %d ชม.ก่อน" % (ago / 60)
	return "ออฟไลน์ · %d วันก่อน" % (ago / (60 * 24))
