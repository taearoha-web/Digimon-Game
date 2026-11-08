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
## start with a head start (vet, none at present), newcomers log in for the first
## time some days after the opening (join; besides the ROSTER, 2-3 new players are made
## for every Thai day from the date alone: size, ensure_until), stall keepers stay in the
## village and everyone else plays hardcore, taking turns to rest. So levels,
## stars, whereabouts and who is online are the same for everyone at a given moment.
## A player with a play schedule spends its time online levelling: it hunts in the field
## that fits its level (WorldPresence shows it there, fighting the field's monsters for
## real) and only comes to the village for short errands (errand_at: a quest, the forge,
## new skills); with the divine set complete it spends its sessions on the endgame
## (endgame_plan) and enhances the set once it has climbed to ★300 (Game.PARAGON_MAX). Otherwise the village belongs to the stall keepers
## (the "afk" style, and divine players taking a break, endgame_plan's "stall"): resting
## players who sell the good things they found (StallStock).
## Below Lv.10 everyone is a Vagabond; the roster's class is the job taken at Lv.10.

## The world (re)opened here (unix seconds; 29 Oct 2026, 18:45 Thai time, the reopening
## after the grey-village fix): every world player starts again at Lv.1 as a Vagabond
## with no guild. Moving this resets them all (the party EXP kept on a device belongs to
## one opening and is dropped with it).
const START_UNIX := 1793274300
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
const GUILD_PICK_SEED := "guild4"
const GUILD_MIN := 20

const ROSTER: Array[Dictionary] = [
	{"name": "Kaito", "class": &"warrior", "gender": 0, "style": "hardcore", "voice": "daytime"},
	{"name": "Shadow_Fang", "class": &"assassin", "gender": 0, "style": "hardcore"},
	{"name": "น้องแพรวา", "class": &"priest", "gender": 1, "style": "hardcore", "voice": "daytime"},
	{"name": "LanceKung", "class": &"lancer", "gender": 0, "style": "hardcore", "voice": "daytime"},
	{"name": "SkyArrow", "class": &"archer", "gender": 0, "style": "hardcore", "voice": "early"},
	{"name": "Mintty", "class": &"mage", "gender": 1, "style": "hardcore", "voice": "early"},
	{"name": "Rinrada", "class": &"summoner", "gender": 1, "style": "hardcore", "voice": "overseas"},
	{"name": "ป้อมปราการ", "class": &"defender", "gender": 0, "style": "hardcore", "voice": "regular"},
	{"name": "เมจิกหมูกรอบ", "class": &"mage", "gender": 0, "style": "hardcore", "voice": "overseas"},
	{"name": "ข้าวเหนียวมะม่วง", "class": &"archer", "gender": 1, "style": "hardcore", "voice": "overseas"},
	{"name": "Zerox", "class": &"warrior", "gender": 0, "style": "hardcore"},
	{"name": "BlackLotus", "class": &"assassin", "gender": 1, "style": "hardcore"},
	{"name": "TonkatsuX", "class": &"defender", "gender": 0, "style": "hardcore", "voice": "daytime"},
	{"name": "นักล่าตะวัน", "class": &"archer", "gender": 0, "style": "hardcore", "voice": "regular"},
	{"name": "Fiora", "class": &"lancer", "gender": 1, "style": "hardcore"},
	{"name": "Yoyo", "class": &"priest", "gender": 1, "style": "hardcore", "voice": "student"},
	{"name": "แม่หมอมิว", "class": &"priest", "gender": 1, "style": "hardcore", "voice": "night_owl"},
	{"name": "PhantomZ", "class": &"summoner", "gender": 0, "style": "hardcore", "voice": "night_owl"},
	{"name": "ไฟร์บอลเด้ง", "class": &"mage", "gender": 0, "style": "hardcore", "voice": "student"},
	{"name": "Raijin", "class": &"warrior", "gender": 0, "style": "hardcore", "voice": "casual"},
	{"name": "Ryuu", "class": &"warrior", "gender": 0, "style": "hardcore", "voice": "student"},
	{"name": "ขุนศึกหน้าหวาน", "class": &"warrior", "gender": 1, "style": "hardcore", "voice": "weekend"},
	{"name": "ปีศาจสีเงิน", "class": &"assassin", "gender": 0, "style": "hardcore", "voice": "regular"},
	{"name": "Gekko", "class": &"assassin", "gender": 0, "style": "hardcore", "voice": "night_owl"},
	{"name": "Momo", "class": &"priest", "gender": 1, "style": "hardcore", "voice": "casual"},
	{"name": "นางฟ้าตาหวาน", "class": &"priest", "gender": 1, "style": "hardcore", "voice": "regular"},
	{"name": "หอกทะลวงฟ้า", "class": &"lancer", "gender": 0, "style": "hardcore"},
	{"name": "Valkyrie", "class": &"lancer", "gender": 1, "style": "hardcore", "voice": "regular"},
	{"name": "NightHawk", "class": &"archer", "gender": 0, "style": "hardcore", "voice": "night_owl"},
	{"name": "ไอซ์ซี่", "class": &"archer", "gender": 1, "style": "hardcore", "voice": "casual"},
	{"name": "พ่อมดน้อยฟ้าใส", "class": &"mage", "gender": 0, "style": "hardcore", "voice": "student"},
	{"name": "Luna_Mew", "class": &"summoner", "gender": 1, "style": "hardcore", "voice": "weekend"},
	{"name": "หมอผีหมูเด้ง", "class": &"summoner", "gender": 0, "style": "hardcore", "voice": "student"},
	{"name": "BearTank", "class": &"defender", "gender": 0, "style": "hardcore", "voice": "student"},
	{"name": "ShieldMaiden", "class": &"defender", "gender": 1, "style": "hardcore"},
	{"name": "Ragnar", "class": &"warrior", "gender": 0, "style": "hardcore"},
	{"name": "เสือดาวดำ", "class": &"warrior", "gender": 0, "style": "hardcore", "voice": "regular"},
	{"name": "Kurogane", "class": &"assassin", "gender": 0, "style": "hardcore", "voice": "student"},
	{"name": "จิ้งจอกเงา", "class": &"assassin", "gender": 1, "style": "hardcore", "voice": "night_owl"},
	{"name": "Seraphine", "class": &"priest", "gender": 1, "style": "hardcore", "voice": "regular"},
	{"name": "หอกพยัคฆ์", "class": &"lancer", "gender": 0, "style": "hardcore", "voice": "regular"},
	{"name": "Akane", "class": &"lancer", "gender": 1, "style": "hardcore", "voice": "weekend"},
	{"name": "ArrowRain", "class": &"archer", "gender": 0, "style": "hardcore"},
	{"name": "ลูกศรสีชมพู", "class": &"archer", "gender": 1, "style": "hardcore", "voice": "student"},
	{"name": "บะหมี่เวทมนตร์", "class": &"mage", "gender": 0, "style": "hardcore", "voice": "casual"},
	{"name": "Nebula", "class": &"mage", "gender": 1, "style": "hardcore", "voice": "regular"},
	{"name": "อสูรน้อยหลับยาก", "class": &"summoner", "gender": 1, "style": "hardcore", "voice": "night_owl"},
	{"name": "Wyvern", "class": &"summoner", "gender": 0, "style": "hardcore", "voice": "casual"},
	{"name": "IronWall", "class": &"defender", "gender": 0, "style": "hardcore", "voice": "weekend"},
	{"name": "โล่ทองคำ", "class": &"defender", "gender": 0, "style": "hardcore", "voice": "casual"},
	# Dark Lords (scepter and raven), added with the class.
	{"name": "DarkKaiser", "class": &"darklord", "gender": 0, "style": "hardcore"},
	{"name": "ราชันอีกา", "class": &"darklord", "gender": 0, "style": "hardcore", "voice": "regular"},
	{"name": "LordRaven", "class": &"darklord", "gender": 1, "style": "hardcore", "voice": "night_owl"},
	{"name": "จักรพรรดิมืด", "class": &"darklord", "gender": 0, "style": "hardcore", "voice": "weekend"},
	# Bards (lute and songs), added with the class.
	{"name": "Melodia", "class": &"bard", "gender": 1, "style": "hardcore"},
	{"name": "เสียงพิณราตรี", "class": &"bard", "gender": 1, "style": "hardcore", "voice": "night_owl"},
	{"name": "SongBird", "class": &"bard", "gender": 0, "style": "hardcore", "voice": "student"},
	{"name": "นักพิณพเนจร", "class": &"bard", "gender": 0, "style": "hardcore", "voice": "regular"},
	# More players of every style (a roster entry may carry "vet": a head start, see head_work).
	{"name": "MaxPower", "class": &"warrior", "gender": 0, "style": "hardcore", "voice": "daytime"},
	{"name": "Hikari", "class": &"priest", "gender": 1, "style": "hardcore", "voice": "early"},
	{"name": "หมูกระทะ", "class": &"mage", "gender": 0, "style": "hardcore", "voice": "overseas"},
	# Stall keepers: they stay in the village the whole session and sell what they find.
	{"name": "ร้านป้าแดง", "class": &"priest", "gender": 1, "style": "afk"},
	{"name": "Shop_Nana", "class": &"mage", "gender": 1, "style": "afk"},
	{"name": "ร้านเครื่องเงิน", "class": &"defender", "gender": 0, "style": "afk"},
	{"name": "ตลาดนัดเวท", "class": &"summoner", "gender": 1, "style": "afk"},
	{"name": "LuteSeller", "class": &"bard", "gender": 1, "style": "afk"},
	{"name": "แม่ค้าออนไลน์", "class": &"priest", "gender": 1, "style": "afk"},
	{"name": "PotionKing", "class": &"mage", "gender": 0, "style": "afk"},
	{"name": "ร้านลุงหมี", "class": &"defender", "gender": 0, "style": "afk"},
	{"name": "ร้านพิณเสียงใส", "class": &"bard", "gender": 1, "style": "afk"},
	{"name": "ScrollShop", "class": &"mage", "gender": 0, "style": "afk"},
	{"name": "ร้านเกราะพี่โต", "class": &"warrior", "gender": 0, "style": "afk"},
	{"name": "ร้านยาแม่มด", "class": &"mage", "gender": 1, "style": "afk"},
	# Once stall keepers and AFK players, now out levelling with a play schedule like the rest.
	{"name": "TradeMaster", "class": &"warrior", "gender": 0, "style": "hardcore", "voice": "regular"},
	{"name": "ขายของถูก", "class": &"archer", "gender": 0, "style": "hardcore", "voice": "casual"},
	{"name": "AFK_Taro", "class": &"lancer", "gender": 0, "style": "hardcore", "voice": "overseas"},
	{"name": "นอนรอบอส", "class": &"assassin", "gender": 0, "style": "hardcore"},
	{"name": "DarkMarket", "class": &"darklord", "gender": 0, "style": "hardcore", "voice": "early"},
	{"name": "ZzzSleepy", "class": &"warrior", "gender": 0, "style": "hardcore", "voice": "night_owl"},
	{"name": "Afk_Mochi", "class": &"priest", "gender": 1, "style": "hardcore", "voice": "casual"},
	{"name": "CrystalMart", "class": &"darklord", "gender": 1, "style": "hardcore", "voice": "daytime"},
	# Fresh players who play in the daytime, in the early morning or from abroad.
	{"name": "Mango", "class": &"archer", "gender": 1, "style": "hardcore", "voice": "daytime"},
	{"name": "ข้าวผัดกะเพรา", "class": &"warrior", "gender": 0, "style": "hardcore", "voice": "early"},
	{"name": "Sakura_TH", "class": &"priest", "gender": 1, "style": "hardcore", "voice": "overseas"},
	{"name": "Rocky", "class": &"defender", "gender": 0, "style": "hardcore", "voice": "daytime"},
	{"name": "นินจาน้อย", "class": &"assassin", "gender": 0, "style": "hardcore", "voice": "overseas"},
	{"name": "Aqua", "class": &"mage", "gender": 1, "style": "hardcore", "voice": "early"},
	{"name": "Leo_Lancer", "class": &"lancer", "gender": 0, "style": "hardcore", "voice": "daytime"},
	{"name": "ภูติจิ๋ว", "class": &"summoner", "gender": 1, "style": "hardcore", "voice": "overseas"},
	{"name": "Minnie", "class": &"bard", "gender": 1, "style": "hardcore", "voice": "daytime"},
	{"name": "Draco", "class": &"darklord", "gender": 0, "style": "hardcore", "voice": "early"},
	{"name": "ชาไข่มุก", "class": &"archer", "gender": 1, "style": "hardcore", "voice": "daytime"},
	{"name": "Coffee_Break", "class": &"archer", "gender": 1, "style": "hardcore", "voice": "daytime"},
	{"name": "Freelancer_Ken", "class": &"lancer", "gender": 0, "style": "hardcore", "voice": "daytime"},
	{"name": "NightNurse", "class": &"priest", "gender": 1, "style": "hardcore", "voice": "daytime"},
	# Newcomers (join: real days after the opening) and second characters of old hands.
	{"name": "Kaito_Bard", "class": &"bard", "gender": 0, "style": "hardcore", "join": 6},
	{"name": "Lily_New", "class": &"summoner", "gender": 1, "style": "hardcore", "voice": "early", "join": 11},
	{"name": "Rookie_Ace", "class": &"assassin", "gender": 0, "style": "hardcore", "voice": "night_owl", "join": 18},
	{"name": "TuneUp", "class": &"bard", "gender": 0, "style": "hardcore", "voice": "regular", "join": 30},
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
	# A short break between sessions (each at its own time), so the stalls are always kept.
	"afk": {"weekday": [[0.0, 7.8], [8.0, 7.8], [16.0, 7.8]], "weekend": [[0.0, 7.8], [8.0, 7.8], [16.0, 7.8]], "jitter": 0.3, "stretch": [0.96, 1.04], "phase": 8.0, "skip": 0.02, "eff": 0.03, "label": "ตั้งร้าน/AFK", "town": true},
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

## Every Thai day from the opening on, NEWCOMERS (2 or 3, by the day) new players log in
## for the first time, each at a moment of that day of its own. They are made from the
## date alone (name, class, face, guild), so every device meets the same people at the
## same moment: they start at Lv.1 as Vagabonds on their day and play hardcore like
## everyone; on reaching Lv.100 they join the guild they picked (pick_guild). The classes go
## round in shuffled rounds of every class. After NEWCOMER_MAX of them (about four months)
## nobody new comes, so the world stays light enough for a phone.
const NEWCOMERS := Vector2i(2, 3)
const NEWCOMER_MAX := 300
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
		_add_day(_gen_day)


## Forgets every newcomer and everything kept per player (tests: the world worked out
## again from nothing, as another device would).
static func reset_roster() -> void:
	_all.clear()
	_index.clear()
	_gen_day = -1
	_gen_count = 0
	for cache in [_at, _cum, _minutes_cache, _sessions, _eff, _hw_share, _hw_cache, _name_hash]:
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


static func sessions_on(i: int, day: int) -> Array:
	var key := day * 4096 + i
	var hit: Variant = _sessions.get(key)
	if hit != null:
		return hit
	var out := _make_sessions(i, day)
	if _sessions.size() > 12000:
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
		if float(d) * DAY - TZ - 7200.0 >= origin:
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
	var key := int(t / 60.0) * 4096 + i
	if _minutes_cache.has(key):
		return _minutes_cache[key]
	if _minutes_cache.size() > 6000:
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
	_minutes_cache[key] = total
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


## Errands: like a real player, a scheduled player pops back to the village now and then
## for a few real minutes (ERRAND_MIN-ERRAND_MAX), at most once in every ERRAND_EVERY real
## minutes of a session, at its own moment: to hand in a quest at the elder ("quest"),
## to enhance at the blacksmith ("enhance") or to learn skills at the skill master
## ("skill"; always when a skill of its class unlocked since the stretch began).
const ERRAND_EVERY := 70.0
const ERRAND_CHANCE := 0.35
const ERRAND_MIN := 2.5
const ERRAND_MAX := 4.0
const ERRAND_KINDS: Array[String] = ["quest", "enhance", "skill"]
static var _unlock_levels := {}


## The errand player i is on at real time t of the session (real start s0, end s1):
## {kind, from, until} (real unix seconds), or {} while it hunts.
static func errand_at(i: int, s0: float, s1: float, t: float) -> Dictionary:
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
		kind = "quest" if pick < 0.5 else ("enhance" if pick < 0.88 else "skill")
	else:
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
	return progress_for(own_minutes(i, t), efficiency(i), bonus_work(i) + head_work(i) + halloween_work(i, t) + party_work(i, t))


## Player i's work at real time t: the probe minutes progress_for reads (its own minutes
## times its efficiency, plus its party EXP, head start and potions). It only grows, and
## everything it has (its level, stars, the gear it forged: WorldGear) follows it.
static func work_at(i: int, t: float) -> float:
	return own_minutes(i, t) * efficiency(i) + maxf(0.0, bonus_work(i) + head_work(i) + halloween_work(i, t) + party_work(i, t))


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
	var cache_key: Variant = int(t / 10.0) * 4096 + i
	if paused.has(key) or hw_skipped.has(key):
		cache_key = "%d|%d|%s|%s" % [i, int(t / 10.0), str(paused.get(key, -1.0)), str(hw_skipped.get(key, 0.0))]
	if _hw_cache.has(cache_key):
		return float(_hw_cache[cache_key])
	var from := played_minutes(i, start)
	var last := played_minutes(i, float(WorldEvents.HALLOWEEN_END))
	var upto := minf(float(paused[key]) if paused.has(key) else played_minutes(i, t), last)
	var played := maxf(0.0, upto - from - float(hw_skipped.get(key, 0.0)))
	var work := played * efficiency(i) * halloween_share(i) * HALLOWEEN_EXTRA
	if _hw_cache.size() > 512:
		_hw_cache.clear()
	_hw_cache[cache_key] = work
	return work


static var _hw_cache := {}
## Event minutes (schedule minutes inside the Halloween window) each player spent in the
## hero's party, by name: they earn the party's EXP there, not their own potions'.
static var hw_skipped := {}


## Whether a skill of player i's class unlocks between real times a and b.
static func _unlocks_between(i: int, a: float, b: float) -> bool:
	var before := level_at(i, a)
	var after := level_at(i, b)
	if after <= before:
		return false
	var cls := StringName(entry(i)["class"]) if after >= ClassData.LINE_LEVEL else ClassData.START
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


## Probe minutes from Lv.1 to step k: steps 0..99 are Lv.1..100, steps 99..399 are ★0..300
## (Game.PARAGON_MAX).
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
## point (Lv.1-100 = 1-100, ★1-300 = 101-400, past 400 = tenths of DIVINE_HOURS played
## since ★300: 410 has played DIVINE_HOURS there, 420 twice as long).
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
	bonus[key] = float(bonus.get(key, 0.0)) + amount / maxf(1.0, rate(level, stars))
	_bonus_dirty = true


## Writes the party EXP when it changed (Game.save calls this).
static func store() -> void:
	if not _bonus_dirty or not persist:
		return
	var file := FileAccess.open(BONUS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"start": START_UNIX, "bonus": bonus, "skipped": skipped, "paused": paused, "hw_skipped": hw_skipped, "saved": now()}))
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
	# Party EXP from an earlier opening of the world is forgotten.
	if int(parsed.get("start", 0)) != START_UNIX:
		_bonus_dirty = true
		return
	for key in parsed.bonus:
		var value: Variant = parsed.bonus[key]
		if (value is float or value is int) and float(value) >= 0.0 and float(value) < 1e9:
			bonus[String(key)] = float(value)
	var tables := {"skipped": skipped, "paused": paused, "hw_skipped": hw_skipped}
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
	_hw_cache.clear()
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
		if town_time(i, float(s[0]), float(s[1]), t):
			place = "town"
			doing = "stall"
		else:
			var plan := endgame_plan(i, float(s[0]), int(p.level), int(p.stars), bool(p.divine))
			place = String(plan.place)
			doing = String(plan.doing)
			if doing != "stall":
				errand = errand_at(i, float(s[0]), float(s[1]), t)
				if not errand.is_empty():
					place = "town"
					doing = "errand"
	var out := e.duplicate()
	out.merge(p)
	out["index"] = i
	# Everyone starts as a Vagabond and takes the roster's class (its "job") at Lv.10,
	# like a player at the Job Master.
	out["job"] = String(e["class"])
	out["class"] = String(e["class"]) if int(p.level) >= ClassData.LINE_LEVEL else String(ClassData.START)
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
## the divine set too; once it is at ★300 (Game.PARAGON_MAX) with the divine set complete
## each session is one of the endgame's: the lotus sanctum's
## boss hunts ("boss"), helping friends in a star field ("help") or a break from it,
## keeping a stall in the village with what it found ("stall").
static func endgame_plan(i: int, s0: float, level: int, stars: int, divine: bool) -> Dictionary:
	var home := hunting_zone(level, stars, divine)
	if not divine or stars < Game.PARAGON_MAX:
		return {"place": home, "doing": "hunt"}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("plan|%s|%d" % [entry(i).name, int(s0 / 60.0)])
	var roll := rng.randf()
	if roll < 0.45:
		return {"place": home, "doing": "boss"}
	if roll < 0.75:
		return {"place": StarProgression.REGIONS[rng.randi() % StarProgression.REGIONS.size()], "doing": "help"}
	return {"place": &"town", "doing": "stall"}


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

## Player i's face and hair, always the same.
static func look(i: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("look|%s" % entry(i).name)
	var l := FaceKit.random_look(rng)
	var gender := int(entry(i).gender)
	if int(l.gender) != gender:
		l["gender"] = gender
		l["hair"] = rng.randi() % FaceKit.option_count("hair", gender)
		ChibiLook.apply_style(l, int(l["hair"]) % ChibiLook.count("style"))
	return l


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
## gear it found and its job (the God step at Lv.100 ★300: JobData.adv_for), plus every stat point spent like a player does (60% main
## stat, 40% vitality), its star points and the skill points it earned spent at the
## Skill Master (skill_ranks). All of it follows what its own play reached.
static func profile(m: Dictionary) -> Dictionary:
	var level := int(m.level)
	var stars := Game.party_stars(m)
	var p := {"class": m["class"], "level": level, "attrs": {}, "equip": equip(m), "adv": JobData.adv_for(level, stars),
		"paragon": {"level": stars, "alloc": Game.party_star_alloc(stars)}}
	var points := Game.STAT_POINTS_PER_LEVEL * (level - 1)
	var main := String(JobData.resolve(StringName(m["class"]), int(p.adv)).main)
	var attrs := {"str": 0, "int": 0, "dex": 0, "vit": 0}
	attrs[main] = int(points * 0.6)
	attrs["vit"] = int(attrs["vit"]) + int(points * 0.4)
	p["attrs"] = attrs
	p["skills"] = skill_ranks(StringName(m["class"]), level, stars)
	# Its mount (mount_of): the stats count like the hero's (HeroStats.mount_bonus).
	var ride := mount_of(m)
	p["mounts"] = {String(ride.id): int(ride.level)} if not ride.is_empty() else {}
	p["mount"] = String(ride.get("id", ""))
	return p


## Skill points a player has earned by `level` and `stars`, the way the hero earns them
## (Game): one to start and one each level, the job advancements' (JobData.TIER_SKILL_POINTS)
## and two at each star tier (StarProgression.grant_milestones).
static func skill_points(level: int, stars: int) -> int:
	var points := level
	for k in JobData.adv_for_level(level):
		points += int(JobData.TIER_SKILL_POINTS[k])
	if level >= Game.MAX_LEVEL:
		for tier in StarProgression.TIERS:
			points += 2 if stars >= int(tier) else 0
	return points


## The ranks a player of class `cls` has bought at the Skill Master by `level` and
## `stars`: every skill it has unlocked starts at rank 1, and the points it earned
## (skill_points) go one at a time to the lowest-ranked skill (the longest-known first),
## like a player keeping its whole bar up, up to SkillRank.MAX; points it has no use
## for yet wait for the next skill.
static func skill_ranks(cls: StringName, level: int, stars: int) -> Dictionary:
	var unlocked: Array = []
	for skill in ClassData.pool(cls):
		if int(skill.level) <= level:
			unlocked.append(skill)
	unlocked.sort_custom(func(a, b): return int(a.level) < int(b.level))
	var ranks := {}
	for skill in unlocked:
		ranks[String(skill.id)] = 1
	var points := skill_points(level, stars)
	for rank in range(1, SkillRank.MAX):
		for skill in unlocked:
			if points <= 0:
				return ranks
			ranks[String(skill.id)] = rank + 1
			points -= 1
	return ranks


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
## level done, then 100 + stars (to 400 at ★300, Game.PARAGON_MAX).
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


## Display line: "Lv.57" or "Lv.100 ★120".
## Whether player state (or member) s has taken the God promotion: Lv.100 and ★300
## (JobData.adv_for), like the hero's เทพเจ้าแห่ง<อาชีพ>.
static func is_god(s: Dictionary) -> bool:
	return JobData.is_god(JobData.adv_for(int(s.get("level", 1)), int(s.get("stars", 0))))


## Its God title ("เทพเจ้าแห่งนักรบ"), "" before the promotion.
static func god_title(s: Dictionary) -> String:
	return JobData.god_name(StringName(s.get("class", "warrior"))) if is_god(s) else ""


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
