class_name GuildQuestData
extends RefCounted
## Guild daily quests (ภารกิจกิลด์รายวัน) and the guild points shop (ร้านแต้มกิลด์).
## Each Thai day (WorldEvents.day_of on WorldPresence.clock()) a guild gets SLOTS quests
## drawn from POOL by its guild and the day alone, so they are the same on every device.
## A quest's progress is the hero's own work today (Game counts it in profile.flags) plus
## the share of the guild mates: the guild's world players at Lv.100 count by the minutes
## they have played today (WorldPlayers.played_minutes, so the bar moves while they are
## online and stands still while they sleep), at most MATE_CAP of the target so the hero
## always has a part to do. A finished quest is claimed once for guild points and gold;
## the points buy forge jewels and potions here (Game.guild_shop_buy).

const SLOTS := 3
## The guild mates' share stops at this fraction of a target (the hero does the rest).
const MATE_CAP := 0.7

## kind: what the hero does (Game.guild_quest_progress); name takes the target;
## targets: one is drawn a day; mate_rate: what one mate adds per real minute played.
const POOL: Array[Dictionary] = [
	{"kind": "kills", "name": "ล่ามอนสเตอร์ %d ตัว", "targets": [300, 400, 500], "points": 10, "gold": 15000, "mate_rate": 1.2},
	{"kind": "boss", "name": "ล่าบอสสนาม %d ตัว", "targets": [3, 4, 5], "points": 12, "gold": 20000, "mate_rate": 0.012},
	{"kind": "enhance", "name": "ตีบวกสำเร็จ %d ครั้ง", "targets": [2, 3], "points": 10, "gold": 15000, "mate_rate": 0.008},
	{"kind": "war", "name": "ชนะสงครามกิลด์ %d ครั้ง", "targets": [1], "points": 15, "gold": 30000, "mate_rate": 0.0},
	{"kind": "jewels", "name": "เก็บเพชร %d เม็ด", "targets": [10, 15], "points": 10, "gold": 15000, "mate_rate": 0.03},
]

## A day of quests pays about 30-37 points: a chaos jewel takes 1-2 days, a feather 5.
const SHOP: Array[Dictionary] = [
	{"id": "chaos", "kind": "jewel", "item": "chaos", "count": 1, "price": 45},
	{"id": "feather", "kind": "jewel", "item": "feather", "count": 1, "price": 170},
	{"id": "drill", "kind": "jewel", "item": "drill", "count": 1, "price": 100},
	{"id": "pink5", "kind": "jewel", "item": "pink", "count": 5, "price": 50},
	{"id": "hp_god10", "kind": "potion", "item": "hp_god", "count": 10, "price": 30},
]

const POINTS_FLAG := "gpoints"
const DAY_FLAG := "gq_day"

static var _mate_cache := {}


static func template(kind: String) -> Dictionary:
	for t in POOL:
		if String(t.kind) == kind:
			return t
	return {}


## Today's quests of `guild` on Thai day `day`: [{slot, kind, name, target, points, gold}].
## The war quest is left out while the other guild has nobody to fight (`war_ok`).
static func quests_for(guild: int, day: int, war_ok := true) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if guild <= 0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("guild_quest|%d|%d" % [guild, day])
	var pool: Array[Dictionary] = []
	for t in POOL:
		if String(t.kind) != "war" or war_ok:
			pool.append(t)
	# A seeded Fisher-Yates shuffle (Array.shuffle uses the global generator).
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	for slot in mini(SLOTS, pool.size()):
		var t: Dictionary = pool[slot]
		var targets: Array = t.targets
		var target := int(targets[rng.randi_range(0, targets.size() - 1)])
		out.append({"slot": slot, "kind": String(t.kind), "name": String(t.name) % target, "target": target,
			"points": int(t.points), "gold": int(t.gold)})
	return out


## Real unix time of the Thai midnight that starts day `day`.
static func day_start(day: int) -> float:
	return float(day) * float(WorldEvents.DAY) - float(WorldPlayers.TZ)


## The guild's world players at Lv.100 at t, and how many of them are online.
static func mates(guild: int, t: float) -> Dictionary:
	var list: Array[int] = []
	var online := 0
	for i in WorldPlayers.members(guild):
		var s := WorldPlayers.state(i, t)
		if int(s.level) >= Game.GUILD_LEVEL:
			list.append(i)
			online += 1 if bool(s.online) else 0
	return {"members": list, "online": online}


## Real minutes the guild's members have played since today's Thai midnight up to t
## (kept a minute at a time: the same for everyone at that minute).
static func mate_minutes(guild: int, t: float) -> Dictionary:
	var key := "%d|%d" % [guild, int(t / 60.0)]
	if _mate_cache.has(key):
		return _mate_cache[key]
	if _mate_cache.size() > 64:
		_mate_cache.clear()
	var info := mates(guild, t)
	var start := day_start(WorldEvents.day_of(t))
	var minutes := 0.0
	for i in info.members:
		minutes += maxf(0.0, WorldPlayers.played_minutes(i, t) - WorldPlayers.played_minutes(i, start))
	var out := {"minutes": minutes, "online": int(info.online), "members": (info.members as Array).size()}
	_mate_cache[key] = out
	return out


## The guild mates' part of a quest at t (capped at MATE_CAP of the target).
static func mate_share(guild: int, quest: Dictionary, t: float) -> int:
	var rate := float(template(String(quest.kind)).get("mate_rate", 0.0))
	if rate <= 0.0:
		return 0
	var raw := int(floor(float(mate_minutes(guild, t).minutes) * rate))
	return mini(raw, int(floor(float(quest.target) * MATE_CAP)))


static func shop_entry(id: String) -> Dictionary:
	for e in SHOP:
		if String(e.id) == id:
			return e
	return {}


static func shop_item(e: Dictionary) -> Dictionary:
	if String(e.kind) == "potion":
		return ItemData.potion(String(e.item), int(e.count))
	return ItemData.jewel(String(e.item), int(e.count))


static func shop_name(e: Dictionary) -> String:
	var item := shop_item(e)
	var n := ItemData.name_of(item)
	return n + (" x%d" % int(e.count) if int(e.count) > 1 else "")
