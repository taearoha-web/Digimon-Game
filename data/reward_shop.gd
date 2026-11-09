class_name RewardShop
extends RefCounted
## The reward exchange (ร้านแลกของรางวัล) and its two account currencies, kept in
## Game.profile[KEY]:
## - เหรียญลีก (League Coins, "lc"): paid once for every league round the hero fought
##   (GuildLeague.record_round / record_war -> round_coins: placement, captures, the
##   castle at the bell; `paid` remembers the rounds already paid so fighting the same
##   round again earns nothing twice), plus a placement bonus when the week closes
##   (week_closed, once a week, only for a hero who fought that week).
## - แต้มกิจกรรม (Event Points, "ep"): the world boss the hero helped bring down
##   (boss_defeated, once a day) and every kill during the event hours (the evening
##   EXP x2 and the festival, WorldEvents), KILL_EP a kill up to KILL_CAP a Thai day.
## The shop sells costumes (COSTUMES, tint + accessory on the hero visual, any class),
## walk trails (TRAILS, WalkTrail), name-plate colours (NAME_COLORS) and power stones
## (STONES: gems and forge jewels of ItemData, a weekly limit each). Cosmetics are
## account-wide unlocks (`own`), worn through `cos` / `trail` / `ncol` (the wardrobe);
## stones go to the bag. Nothing here can be sold or traded. The AI world players own
## cosmetics by their guild's league standing too (world_cosmetics).

const KEY := "rshop"
const COIN_NAME := "เหรียญลีก"
const POINT_NAME := "แต้มกิจกรรม"
const SHOP_NAME := "ร้านแลกของรางวัล"
const KEEPER := "ผู้ดูแลรางวัล"
const COIN_COLOR := Color("ffb81c")
const POINT_COLOR := Color("7ff0e0")
## Coins a round: by placement (1st..4th; an old two-guild war pays WIN_COINS / LOSS_COINS),
## per capture and for holding the castle at the bell.
const PLACE_COINS: Array[int] = [30, 20, 12, 8]
const WIN_COINS := 30
const LOSS_COINS := 10
const CAPTURE_COINS := 3
const HOLD_COINS := 10
## The week's placement bonus by the guild's final rank (1-4), once, for a hero who fought.
const WEEK_BONUS: Array[int] = [150, 100, 60, 30]
## Event points: the world boss (once a day), a kill in the event hours, the daily cap.
const BOSS_EP := 40
const KILL_EP := 1
const KILL_CAP := 60
const MAX_PAID := 32
const MAX_OWN := 64
const MAX_NUMBER := 1000000000000
const ID_MAX := 32
const INT_KEYS: Array[String] = ["lc", "ep", "week", "ev_day", "ev_pts", "boss_day", "bonus_week"]
const TEXT_KEYS: Array[String] = ["cos", "trail", "ncol"]
const TABS := [["costume", "คอสตูม"], ["trail", "เอฟเฟกต์ท่าเดิน"], ["ncol", "สีชื่อ"], ["stone", "หินเสริมพลัง"]]

## Costumes: a cloth colour over the outfit, its sheen / glow and a head accessory
## (RewardShop.build_accessory). Prices in coins, some need points too.
const COSTUMES := {
	"sakura": {"name": "ชุดซากุระบาน", "cloth": Color("ff9ccb"), "sheen": 0.3, "glow": Color(0.25, 0.08, 0.14), "acc": "blossom", "lc": 300, "ep": 0},
	"midnight": {"name": "ชุดราตรีสีนิล", "cloth": Color("2a2b4a"), "sheen": 0.45, "glow": Color(0.08, 0.1, 0.3), "acc": "horns", "lc": 400, "ep": 0},
	"kitsune": {"name": "ชุดจิ้งจอกเก้าหาง", "cloth": Color("ff8a3a"), "sheen": 0.25, "glow": Color(0.3, 0.12, 0.0), "acc": "ears", "lc": 450, "ep": 60},
	"seafoam": {"name": "ชุดคลื่นทะเล", "cloth": Color("5ad0e6"), "sheen": 0.5, "glow": Color(0.05, 0.25, 0.3), "acc": "shell", "lc": 350, "ep": 80},
	"royal": {"name": "ชุดราชันทองคำ", "cloth": Color("ffd24a"), "sheen": 0.7, "glow": Color(0.35, 0.28, 0.05), "acc": "crown", "lc": 800, "ep": 150},
	"shadow": {"name": "ชุดเงาอสูร", "cloth": Color("4a1c5e"), "sheen": 0.4, "glow": Color(0.3, 0.05, 0.4), "acc": "horns", "lc": 600, "ep": 200},
	"celestial": {"name": "ชุดเทวดาแสงดาว", "cloth": Color("f2f0ff"), "sheen": 0.6, "glow": Color(0.3, 0.3, 0.45), "acc": "halo", "lc": 900, "ep": 300},
}
## Walk trails (WalkTrail): what follows the hero's steps.
const TRAILS := {
	"sparkle": {"name": "ประกายทอง", "color": Color("ffd86a"), "lc": 200, "ep": 40},
	"petal": {"name": "กลีบซากุระ", "color": Color("ff9ccb"), "lc": 250, "ep": 40},
	"flame": {"name": "เปลวเพลิง", "color": Color("ff6a3d"), "lc": 300, "ep": 120},
	"star": {"name": "ดวงดาวพราว", "color": Color("8fd0ff"), "lc": 350, "ep": 160},
	"frost": {"name": "เกล็ดน้ำแข็ง", "color": Color("bfe6ff"), "lc": 300, "ep": 100},
}
## Name-plate colours: the text colour and the outline that makes the gradient look.
const NAME_COLORS := {
	"rose": {"name": "ชมพูกุหลาบ", "color": Color("ff8fcf"), "edge": Color(0.35, 0.05, 0.2, 0.9), "lc": 150, "ep": 0},
	"sky": {"name": "ฟ้าใส", "color": Color("8fd0ff"), "edge": Color(0.05, 0.15, 0.4, 0.9), "lc": 150, "ep": 0},
	"mint": {"name": "เขียวมิ้นต์", "color": Color("8dff9a"), "edge": Color(0.02, 0.3, 0.15, 0.9), "lc": 150, "ep": 0},
	"sunset": {"name": "ไล่สีอาทิตย์อัสดง", "color": Color("ffb36a"), "edge": Color(0.5, 0.1, 0.35, 0.9), "lc": 250, "ep": 60},
	"aurora": {"name": "ไล่สีแสงเหนือ", "color": Color("9df2d2"), "edge": Color(0.3, 0.08, 0.5, 0.9), "lc": 300, "ep": 120},
	"royal_gold": {"name": "ทองราชัน", "color": Color("ffe27a"), "edge": Color(0.45, 0.2, 0.0, 0.9), "lc": 400, "ep": 200},
}
## Power stones: a supplement, not a shortcut (forge jewels drop in every field, gems from
## bosses): kind "jewel" (ItemData.jewel) or "gem" (ItemData.gem), `limit` a week each.
const STONES: Array[Dictionary] = [
	{"id": "purple5", "kind": "jewel", "item": "purple", "size": 0, "count": 5, "lc": 40, "ep": 0, "limit": 3},
	{"id": "pink3", "kind": "jewel", "item": "pink", "size": 0, "count": 3, "lc": 60, "ep": 0, "limit": 2},
	{"id": "chaos2", "kind": "jewel", "item": "chaos", "size": 0, "count": 2, "lc": 90, "ep": 30, "limit": 2},
	{"id": "ruby2", "kind": "gem", "item": "ruby", "size": 2, "count": 1, "lc": 0, "ep": 120, "limit": 1},
	{"id": "emerald2", "kind": "gem", "item": "emerald", "size": 2, "count": 1, "lc": 0, "ep": 120, "limit": 1},
	{"id": "amethyst2", "kind": "gem", "item": "amethyst", "size": 2, "count": 1, "lc": 0, "ep": 120, "limit": 1},
	{"id": "sapphire2", "kind": "gem", "item": "sapphire", "size": 2, "count": 1, "lc": 0, "ep": 120, "limit": 1},
	{"id": "topaz2", "kind": "gem", "item": "topaz", "size": 2, "count": 1, "lc": 0, "ep": 120, "limit": 1},
	{"id": "onyx1", "kind": "gem", "item": "onyx", "size": 1, "count": 1, "lc": 50, "ep": 150, "limit": 1},
	{"id": "drill1", "kind": "jewel", "item": "drill", "size": 0, "count": 1, "lc": 200, "ep": 100, "limit": 1},
]


# --- The record -------------------------------------------------------------------

static func now() -> float:
	return WorldPresence.clock()


## The hero's record ({} without a profile), made when first needed.
static func data() -> Dictionary:
	if not Game.has_profile:
		return {}
	var d: Variant = Game.profile.get(KEY)
	if not d is Dictionary:
		d = {"lc": 0, "ep": 0, "own": [], "cos": "", "trail": "", "ncol": "", "buy": {}, "paid": {}}
		Game.profile[KEY] = d
	return d


static func coins() -> int:
	return int(data().get("lc", 0))


static func points() -> int:
	return int(data().get("ep", 0))


static func add_coins(amount: int) -> void:
	if amount <= 0 or not Game.has_profile:
		return
	var d := data()
	d["lc"] = mini(int(d.get("lc", 0)) + amount, MAX_NUMBER)
	Game.mark_dirty()


static func add_points(amount: int) -> void:
	if amount <= 0 or not Game.has_profile:
		return
	var d := data()
	d["ep"] = mini(int(d.get("ep", 0)) + amount, MAX_NUMBER)
	Game.mark_dirty()


# --- Earning ------------------------------------------------------------------------

## Coins for a round record (GuildLeague ROUND_KEYS / WAR_KEYS shape) as guild g fought it.
static func round_coins(e: Dictionary, g: int) -> int:
	if g <= 0:
		return 0
	if e.has("g1"):
		var gs: Array = []
		var ks: Array = []
		var cs: Array = []
		for i in 4:
			gs.append(int(e.get("g%d" % (i + 1), 0)))
			ks.append(int(e.get("k%d" % (i + 1), 0)))
			cs.append(int(e.get("c%d" % (i + 1), 0)))
		var i := gs.find(g)
		if i < 0:
			return 0
		var place := GuildLeague.placement({"g": gs, "k": ks, "c": cs, "held": int(e.get("held", 0)), "at": int(e.get("at", 0))}).find(g)
		return int(PLACE_COINS[clampi(place, 0, PLACE_COINS.size() - 1)]) + CAPTURE_COINS * maxi(0, int(cs[i])) + (HOLD_COINS if int(e.get("held", 0)) == g else 0)
	if int(e.get("a", 0)) != g and int(e.get("b", 0)) != g:
		return 0
	var ours := int(e.get("a", 0)) == g
	var out := WIN_COINS if int(e.get("win", 0)) == g else LOSS_COINS
	out += CAPTURE_COINS * int(e.get("ca" if ours else "cb", 0))
	out += HOLD_COINS if int(e.get("held", 0)) == g else 0
	return out


## The hero fought round `e` (its record) as guild g: pays its coins once per round start.
## Returns the coins paid (0 when that round was paid before).
static func round_fought(e: Dictionary, g: int) -> int:
	if not Game.has_profile or g <= 0:
		return 0
	var d := data()
	var key := str(int(e.get("at", 0)))
	var paid: Dictionary = d.get("paid", {})
	if paid.has(key):
		return 0
	var amount := round_coins(e, g)
	paid[key] = amount
	while paid.size() > MAX_PAID:
		var oldest := ""
		for k in paid:
			if oldest == "" or int(k) < int(oldest):
				oldest = String(k)
		paid.erase(oldest)
	d["paid"] = paid
	add_coins(amount)
	Game.mark_dirty()
	if amount > 0:
		Game.say("ได้%s +%d จากรอบลีกกิลด์" % [COIN_NAME, amount], &"success")
	return amount


## Season w closed (GuildLeague.tick): the placement bonus of the hero's guild, once a
## week, only when the hero fought a round of that season. Returns the coins paid.
static func week_closed(w: int) -> int:
	if not Game.has_profile or Game.guild() <= 0:
		return 0
	var d := data()
	if int(d.get("bonus_week", -1)) >= w:
		return 0
	d["bonus_week"] = w
	Game.mark_dirty()
	var real := GuildLeague.real_wars(w)
	var fought := false
	for e in real:
		if e is Dictionary and round_coins(e, Game.guild()) > 0:
			fought = true
	if not fought:
		return 0
	var rank := GuildLeague.rank_of(w, real, Game.guild())
	var amount := int(WEEK_BONUS[clampi(rank - 1, 0, WEEK_BONUS.size() - 1)])
	add_coins(amount)
	Game.say("โบนัสอันดับ %d ของสัปดาห์ที่แล้ว: %s +%d" % [rank, COIN_NAME, amount], &"success")
	return amount


## The hero helped bring the world boss down (Game.world_boss_defeated): BOSS_EP once a day.
static func boss_defeated(t := -1.0) -> int:
	if not Game.has_profile:
		return 0
	if t < 0.0:
		t = now()
	var d := data()
	var day := WorldEvents.day_of(t)
	if int(d.get("boss_day", -1)) == day:
		return 0
	d["boss_day"] = day
	add_points(BOSS_EP)
	Game.say("ได้%s +%d จากบอสโลก" % [POINT_NAME, BOSS_EP], &"success")
	return BOSS_EP


## Whether the event hours (EXP x2 evening or the festival) run at t.
static func event_hours(t: float) -> bool:
	return WorldEvents.evening_exp(t) or WorldEvents.festival_on(t)


## A kill at t (Game.report_kill): KILL_EP during the event hours, KILL_CAP a Thai day.
static func kill(t := -1.0) -> int:
	if not Game.has_profile:
		return 0
	if t < 0.0:
		t = now()
	if not event_hours(t):
		return 0
	var d := data()
	var day := WorldEvents.day_of(t)
	if int(d.get("ev_day", -1)) != day:
		d["ev_day"] = day
		d["ev_pts"] = 0
	var had := int(d.get("ev_pts", 0))
	if had >= KILL_CAP:
		return 0
	var amount := mini(KILL_EP, KILL_CAP - had)
	d["ev_pts"] = had + amount
	add_points(amount)
	if had + amount == KILL_CAP:
		Game.say("%sจากการล่าช่วงกิจกรรมครบ %d แต้มของวันนี้แล้ว" % [POINT_NAME, KILL_CAP], &"info")
	return amount


## Event points still to earn from kills today.
static func kill_left(t := -1.0) -> int:
	if not Game.has_profile:
		return 0
	if t < 0.0:
		t = now()
	var d := data()
	if int(d.get("ev_day", -1)) != WorldEvents.day_of(t):
		return KILL_CAP
	return maxi(0, KILL_CAP - int(d.get("ev_pts", 0)))


# --- The catalogue ------------------------------------------------------------------

## The catalogue of a tab: "costume", "trail", "ncol" or "stone".
static func catalog(tab: String) -> Dictionary:
	match tab:
		"costume": return COSTUMES
		"trail": return TRAILS
		"ncol": return NAME_COLORS
	return {}


## The tab a cosmetic id belongs to ("" for none).
static func tab_of(id: String) -> String:
	for tab in ["costume", "trail", "ncol"]:
		if catalog(tab).has(id):
			return tab
	return ""


static func entry(tab: String, id: String) -> Dictionary:
	if tab == "stone":
		return stone(id)
	return (catalog(tab) as Dictionary).get(id, {})


static func stone(id: String) -> Dictionary:
	for e in STONES:
		if String(e.id) == id:
			return e
	return {}


static func stone_item(e: Dictionary) -> Dictionary:
	if String(e.kind) == "gem":
		return ItemData.gem(String(e.item), int(e.size), int(e.count))
	return ItemData.jewel(String(e.item), int(e.count))


static func name_of(tab: String, id: String) -> String:
	var e := entry(tab, id)
	if e.is_empty():
		return id
	if tab == "stone":
		return "%s ×%d" % [ItemData.name_of(stone_item(e)), int(e.count)]
	return String(e.name)


## "300 เหรียญลีก + 60 แต้มกิจกรรม" of an entry.
static func price_text(e: Dictionary) -> String:
	var parts: PackedStringArray = []
	if int(e.get("lc", 0)) > 0:
		parts.append("%d %s" % [int(e.lc), COIN_NAME])
	if int(e.get("ep", 0)) > 0:
		parts.append("%d %s" % [int(e.ep), POINT_NAME])
	return " + ".join(parts) if not parts.is_empty() else "ฟรี"


# --- Owning and wearing ------------------------------------------------------------

static func owns(id: String) -> bool:
	return Game.has_profile and (data().get("own", []) as Array).has(id)


## The id worn of a cosmetic tab ("" for none); the costume only while it is still owned.
static func active(tab: String) -> String:
	if not Game.has_profile:
		return ""
	var key := "cos" if tab == "costume" else tab
	var id := String(data().get(key, ""))
	return id if id != "" and owns(id) and catalog(tab).has(id) else ""


## Wears `id` of its tab ("" takes it off). "ok" or a reason.
static func wear(tab: String, id: String) -> String:
	if not Game.has_profile:
		return "ยังไม่มีตัวละคร"
	var key := "cos" if tab == "costume" else tab
	if id != "" and not catalog(tab).has(id):
		return "ไม่มีของชิ้นนี้"
	if id != "" and not owns(id):
		return "ยังไม่ได้แลกของชิ้นนี้"
	var d := data()
	if String(d.get(key, "")) == id:
		return "ok"
	d[key] = id
	Game.mark_dirty()
	Game.cosmetics_changed.emit()
	return "ok"


## How many of stone `id` the hero bought this week.
static func bought(id: String, t := -1.0) -> int:
	var d := data()
	if d.is_empty() or int(d.get("week", -1)) != GuildLeague.week_of(now() if t < 0.0 else t):
		return 0
	return int((d.get("buy", {}) as Dictionary).get(id, 0))


## Why `id` of `tab` cannot be bought now ("" when it can).
static func problem(tab: String, id: String, t := -1.0) -> String:
	var e := entry(tab, id)
	if e.is_empty():
		return "ไม่มีสินค้านี้"
	if tab != "stone" and owns(id):
		return "มีแล้ว"
	if tab == "stone" and bought(id, t) >= int(e.limit):
		return "แลกครบ %d ครั้งของสัปดาห์นี้แล้ว" % int(e.limit)
	if tab == "stone" and Game.inventory_free() <= 0 and Game.storage().size() >= Game.STORAGE_SIZE:
		return "กระเป๋าและคลังเต็ม"
	if coins() < int(e.get("lc", 0)):
		return "%sไม่พอ" % COIN_NAME
	if points() < int(e.get("ep", 0)):
		return "%sไม่พอ" % POINT_NAME
	return ""


## Buys `id` of `tab`: a cosmetic becomes an account unlock (and is worn when nothing of
## its kind is), a stone goes to the bag. "ok" or a reason.
static func buy(tab: String, id: String, t := -1.0) -> String:
	var why := problem(tab, id, t)
	if why != "":
		return why
	var e := entry(tab, id)
	var d := data()
	d["lc"] = int(d.get("lc", 0)) - int(e.get("lc", 0))
	d["ep"] = int(d.get("ep", 0)) - int(e.get("ep", 0))
	if tab == "stone":
		Game.give_or_store(stone_item(e))
		var w := GuildLeague.week_of(now() if t < 0.0 else t)
		if int(d.get("week", -1)) != w:
			d["week"] = w
			d["buy"] = {}
		var buys: Dictionary = d.get("buy", {})
		buys[id] = int(buys.get(id, 0)) + 1
		d["buy"] = buys
	else:
		var own: Array = d.get("own", [])
		if not own.has(id):
			own.append(id)
		d["own"] = own
		var key := "cos" if tab == "costume" else tab
		if String(d.get(key, "")) == "":
			d[key] = id
			Game.cosmetics_changed.emit()
	Game.mark_dirty()
	Game.save()
	return "ok"


# --- The world players --------------------------------------------------------------

## What AI world player i owns and wears ({cos, trail, ncol}, "" for none): nothing
## below Lv.100 (no guild, no league coins yet); the better its guild's league standing
## last season, the more of its members wear the shop's things, fixed by the name so it
## is the same on every device all week.
static func world_cosmetics(i: int, t := -1.0) -> Dictionary:
	var out := {"cos": "", "trail": "", "ncol": ""}
	if i < 0 or i >= WorldPlayers.size():
		return out
	if t < 0.0:
		t = now()
	var level := WorldPlayers.level_at(i, t)
	var g := WorldPlayers.guild_at(i, level)
	if g <= 0:
		return out
	var w := GuildLeague.week_of(t) - 1
	var rank := GuildLeague.rank_of(w, GuildLeague.real_wars(w) if Game.has_profile else [], g)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("rshop|%s|%d" % [String(WorldPlayers.entry(i).name), w])
	# Odds by rank (1st..4th) of wearing a costume, a trail and a name colour.
	var odds: Array = [[0.7, 0.5, 0.6], [0.5, 0.3, 0.45], [0.3, 0.15, 0.3], [0.15, 0.05, 0.15]][clampi(rank - 1, 0, 3)]
	var costumes := COSTUMES.keys()
	var trails := TRAILS.keys()
	var colors := NAME_COLORS.keys()
	if rng.randf() < float(odds[0]):
		out["cos"] = String(costumes[rng.randi() % costumes.size()])
	if rng.randf() < float(odds[1]):
		out["trail"] = String(trails[rng.randi() % trails.size()])
	if rng.randf() < float(odds[2]):
		out["ncol"] = String(colors[rng.randi() % colors.size()])
	return out


# --- Looks -------------------------------------------------------------------------

## The name-plate colours of `id`: {color, edge} or {} for none.
static func name_color(id: String) -> Dictionary:
	return NAME_COLORS.get(id, {})


## A code-built head accessory of costume `id` on `root` (a node on the head bone whose
## axes are the chibi model's). CC0 shapes only.
static func build_accessory(root: Node3D, id: String) -> void:
	var c: Dictionary = COSTUMES.get(id, {})
	if c.is_empty():
		return
	var cloth: Color = c.cloth
	match String(c.acc):
		"blossom":
			var at := Vector3(-0.16, 0.18, -0.03)
			for k in 5:
				var a := k * TAU / 5.0
				GearKit._p(root, MeshKit.sphere_low(), cloth.lerp(Color.WHITE, 0.3), at + Vector3(0.0, sin(a) * 0.035, cos(a) * 0.035), Vector3(0.02, 0.05, 0.05))
			GearKit._p(root, MeshKit.sphere_low(), Color("ffd24a"), at + Vector3(-0.012, 0, 0), Vector3.ONE * 0.03, Vector3.ZERO, 0.4)
		"horns":
			for side in [-1.0, 1.0]:
				GearKit._p(root, MeshKit.cone(), cloth.lerp(Color.BLACK, 0.3), Vector3(side * 0.11, 0.24, 0.0), Vector3(0.05, 0.12, 0.05), Vector3(0, 0, side * -25.0), 0.15)
		"ears":
			for side in [-1.0, 1.0]:
				GearKit._p(root, MeshKit.cone(), cloth, Vector3(side * 0.12, 0.26, -0.02), Vector3(0.07, 0.14, 0.05), Vector3(0, 0, side * -12.0))
				GearKit._p(root, MeshKit.cone(), Color("fff1e0"), Vector3(side * 0.12, 0.25, 0.0), Vector3(0.035, 0.09, 0.03), Vector3(0, 0, side * -12.0))
		"shell":
			GearKit._p(root, MeshKit.hemisphere(), cloth.lerp(Color.WHITE, 0.2), Vector3(0.15, 0.17, -0.02), Vector3(0.07, 0.06, 0.07), Vector3(0, 0, -60.0), 0.2)
			GearKit._p(root, MeshKit.sphere_low(), Color("f2f0ff"), Vector3(0.15, 0.2, -0.02), Vector3.ONE * 0.025, Vector3.ZERO, 0.5)
		"crown":
			GearKit._p(root, MeshKit.torus(), cloth, Vector3(0, 0.25, 0), Vector3(0.14, 0.14, 0.14), Vector3(90, 0, 0), 0.5)
			for k in 5:
				var a := k * TAU / 5.0
				GearKit._p(root, MeshKit.cone(), cloth, Vector3(sin(a) * 0.13, 0.3, cos(a) * 0.13), Vector3(0.03, 0.06, 0.03), Vector3.ZERO, 0.5)
			GearKit._p(root, MeshKit.sphere_low(), Color("ff4a5e"), Vector3(0, 0.33, 0.13), Vector3.ONE * 0.025, Vector3.ZERO, 0.8)
		"halo":
			var ring := GearKit._p(root, MeshKit.torus(), Color("ffe9a0"), Vector3(0, 0.36, 0), Vector3(0.12, 0.12, 0.12), Vector3(90, 0, 0), 1.0)
			ring.scale = Vector3(0.12, 0.12, 0.04)


# --- Save safety (Game._valid_profile / _repair, accounts.js validRewardShop) ---------

static func _int_ok(v: Variant, lo := 0.0, hi := float(MAX_NUMBER)) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) == floor(float(v)) and float(v) >= lo and float(v) <= hi


static func _text_ok(v: Variant) -> bool:
	return v is String and (v as String).length() <= ID_MAX


## A save's profile.rshop is well formed.
static func valid(v: Variant) -> bool:
	if not v is Dictionary or (v as Dictionary).size() > 16:
		return false
	for k in v:
		if not k is String:
			return false
		var key := String(k)
		if key in INT_KEYS:
			if not _int_ok(v[k], -1.0):
				return false
		elif key in TEXT_KEYS:
			if not _text_ok(v[k]):
				return false
		elif key == "own":
			if not v[k] is Array or (v[k] as Array).size() > MAX_OWN:
				return false
			for id in v[k]:
				if not _text_ok(id):
					return false
		elif key == "buy" or key == "paid":
			if not v[k] is Dictionary or (v[k] as Dictionary).size() > MAX_PAID:
				return false
			for id in v[k]:
				if not _text_ok(id) or not _int_ok(v[k][id], 0.0, 1000.0 if key == "buy" else float(MAX_NUMBER)):
					return false
		else:
			return false
	return true


## Numbers back to ints (JSON reads them as floats); unknown ids dropped; a broken record goes.
static func repair(profile: Dictionary) -> void:
	if not profile.has(KEY):
		return
	if not valid(profile[KEY]):
		profile.erase(KEY)
		return
	var d: Dictionary = profile[KEY]
	for key in INT_KEYS:
		if d.has(key):
			d[key] = int(d[key])
	for key in ["buy", "paid"]:
		var m: Dictionary = d.get(key, {})
		for id in m:
			m[id] = int(m[id])
	var own: Array = []
	for id in d.get("own", []):
		if tab_of(String(id)) != "" and not own.has(String(id)):
			own.append(String(id))
	d["own"] = own
	for key in TEXT_KEYS:
		var id := String(d.get(key, ""))
		if id != "" and not own.has(id):
			d[key] = ""
