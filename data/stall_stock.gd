class_name StallStock
extends RefCounted
## What a stall keeper in the village sells and buys (WorldPlayers: the "afk" players and
## divine players taking a break, doing "stall"). They are players resting from the hunt
## who bring the good things they found, by their own level and stars (seller, lots_for):
## gear of the keeper's own level (star gear and wings from Lv.100, up to its stars) a
## grade or more above the merchant's (the NPC sells common and good pieces, a stall
## rare, legendary and, from a seasoned keeper, mythic ones; weapons mostly for the
## hero's class), the potions the merchant sells at the keeper's level a little under its
## price, and the forge jewels, mount materials and gems the keeper could have found (a
## newcomer's stall never holds chaos jewels, feathers or the set core). Each stall restocks every RESTOCK real seconds
## (each at its own offset); its stock in a window is seeded by the keeper's name and the
## window, so it is the same on every visit and every device. What the hero bought is gone
## from that stall until the next restock: Game.profile.flags["stall|<name>|<window>|<k>"]
## = 1, and the keys of older windows are dropped when a stall opens (open). A stall
## also buys from the hero's bag, paying SELL_BONUS times the merchant's price.
## The hero can haggle once per lot per window (haggle: a deterministic outcome of the
## keeper, the window, the lot and the hero's name; "haggle|<name>|<window>|<k>" = code),
## leave bag things (a chosen count of a stack) with a keeper to sell for more, paid out
## later ("consign|<due minute>|<n>" = gold; collect_consignments), and the keepers call out a lot of theirs in
## the world chat now and then (announcement).
##
## What a stall lays out is worth the trip: a keeper's spare finds come forged (plus_band:
## a newcomer's +1..+4, a veteran's +7..+12 and, from ★200, the odd +13..+15 showpiece),
## socketed with the gems their class builds on, legendary and mythic more often than not;
## a veteran sells the star tier it farms, the 100★ wings, the divine pieces and 200★
## jewellery from ★200 and, very rarely, a 250★ set piece; jewels and materials come in
## bulk, the sky isle's goods only from a ★300 keeper. Showpieces (is_hot: ของเด่น) are
## listed first and cost a premium. Prices follow the game's own (gear_price: the
## merchant's price, the forge jewels of the +, the gems), never under what the stall
## would pay back for the lot (RESALE_FLOOR).

## Real seconds between two restocks of a stall.
const RESTOCK := 7200.0
## A stall pays this much more than the merchant for what the hero sells.
const SELL_BONUS := 1.2
## Gear costs this many times the merchant's price for its rarity (rare, legendary, mythic).
const GEAR_MARKUP := {2: 1.3, 3: 1.55, 4: 1.8}
## Potions cost this share of the merchant's price.
const POTION_DISCOUNT := 0.85
## Forge jewels (the merchant has none) and gems cost this much over their base price.
const JEWEL_MARKUP := 1.15
## A stall gem by size (small .. legendary): a fused gem is worth well over three of the
## size below (the fusing gold and the failed tries); a special gem SPECIAL_GEM_MARKUP more.
const GEM_PRICE := [60, 240, 900, 4000, 16000]
const SPECIAL_GEM_MARKUP := 2.0
## The forge jewels of a piece's + cost this much over their average (enhance_value).
const ENHANCE_MARGIN := 1.15
## A divine piece (0.5% a kill in the lotus sanctum) costs this many times its grade's price.
const DIVINE_PREMIUM := 2.5
## A showpiece (is_hot) costs this much more.
const HOT_PREMIUM := 1.25
## Gear at this + or more is a showpiece (ของเด่น).
const HOT_PLUS := 13
## The rare goods that are showpieces too.
const HOT_GOODS: Array[String] = ["set_core", "dragon_fragment", "sky_dragon_egg"]
## A lot never costs less than this many times what a stall pays for it (and its gems)
## on consignment: bought here, haggled 20% off and consigned back, it still loses gold.
const RESALE_FLOOR := 1.6
## Chances of a stall piece being rare (2), legendary (3) or mythic (4) for a keeper of
## Lv.60-99 (rarity_odds: fewer good finds below, more from Lv.100).
const RARITY_ODDS := [[2, 0.3], [3, 0.52], [4, 0.18]]
## The order a stall lays its lots out in after the showpieces (_better).
const SHELF := {"equip": 0, "jewel": 1, "gem": 1, "potion": 2}
## A piece is for another class than the hero's this often.
const OTHER_CLASS := 0.25
## From Lv.100 (find): a gear lot is a 250★ set piece (from ★250), wings (not at an armour
## stall) or the divine piece of its slot (from ★200) at these shares; a star piece is of
## the tier below the seller's this often; a mythic star piece is the best of MYTHIC_TRIES.
const SET_SHARE := 0.008
const WING_SHARE := 0.13
const DIVINE_SHARE := 0.3
const LOWER_TIER := 0.2
const MYTHIC_TRIES := 10
## A set piece is sold at +0 .. +SET_PLUS_MAX.
const SET_PLUS_MAX := 7
## From Lv.100 a piece has a drilled socket this often (_socket).
const DRILL_SHARE := 0.35
## A gem (in a socket or a gem lot) is the seller's biggest size this often, else one under.
const TOP_GEM_SHARE := 0.55
## Materials a lot holds: [fewest, most for a ★300 keeper] (bulk_count).
const BULK := {"purple": [3, 40], "pink": [2, 30], "chaos": [2, 25], "feather": [1, 3], "drill": [1, 3],
	"wolf_fang": [1, 4], "stag_antler": [1, 4], "griffin_plume": [1, 3], "drake_scale": [1, 3],
	"lotus_scale": [1, 5], "dragon_scale": [1, 3], "set_core": [1, 1],
	"dragon_chest": [1, 3], "dragon_fragment": [1, 2], "sky_dragon_egg": [1, 1]}
## The sky isle's goods (SkyIsleLoot): only a keeper of ISLE_STARS lays them out, a jewel
## lot ISLE_SHARE of the time, [id, share] (the chest most, the egg very rarely).
const ISLE_STARS := 300
const ISLE_SHARE := 0.08
const ISLE_GOODS := [["dragon_chest", 0.7], ["dragon_fragment", 0.25], ["sky_dragon_egg", 0.05]]
const FLAG := "stall|"
const HAGGLE_FLAG := "haggle|"
const CONSIGN_FLAG := "consign|"
## Haggling: result codes kept in the flags, and the odds (percent) of each.
const HAGGLE_ACCEPTED := 1
const HAGGLE_REFUSED := 2
const HAGGLE_COUNTER := 3
const HAGGLE_ACCEPT_ODDS := 45
const HAGGLE_REFUSE_ODDS := 40
## A stall sells what the hero leaves with it for this much of the merchant's price, paid
## CONSIGN_MINUTES real minutes later; at most CONSIGN_MAX lots out at once.
const CONSIGN_BONUS := 1.5
const CONSIGN_MINUTES := 30
const CONSIGN_MAX := 8
const HAGGLE_ACCEPT_LINES := ["ก็ได้ ลดให้ %d%% แต่บอกต่อด้วยนะ", "เอ้า ลด %d%% ให้เป็นพิเศษเลย", "ตกลง ลดให้ %d%% เพราะคุณน่ารัก"]
const HAGGLE_REFUSE_LINES := ["ขอโทษนะ ราคานี้ต่อไม่ได้แล้วจริง ๆ", "ของดีขนาดนี้ ราคาเต็มเท่านั้นนะ", "ลดไม่ไหวแล้ว หามาเหนื่อยมาก"]
const HAGGLE_COUNTER_LINES := ["เต็มที่ได้แค่ %d%% นะ เอาไหม", "ลด %d%% พอได้ แต่มากกว่านี้ไม่ไหว"]
## Specialities and what a stall of each lays out: gear pieces, consumable lots (six lots
## a stall, the same as ever).
const KINDS := {
	"mixed": {"gear": 4, "potions": 0, "jewels": 2},
	"weapon": {"gear": 5, "potions": 0, "jewels": 1},
	"armor": {"gear": 5, "potions": 0, "jewels": 1},
	"potion": {"gear": 2, "potions": 3, "jewels": 1},
	"jewel": {"gear": 2, "potions": 0, "jewels": 4},
}
const KIND_NAMES := {"mixed": "ของดีสารพัด", "weapon": "อาวุธ", "armor": "เกราะและเครื่องประดับ", "potion": "ยา", "jewel": "เพชรและอัญมณี"}
## Words in a keeper's name that tell what it sells.
const KEYWORDS := [
	["potion", ["ยา", "potion", "ป้า", "แม่ค้า"]],
	["armor", ["เกราะ", "เครื่องเงิน", "shield", "ลุงหมี", "iron"]],
	["weapon", ["พิณ", "lute", "trade", "ดาบ", "หอก"]],
	["jewel", ["scroll", "crystal", "เวท", "magic", "market"]],
]

static var _by_name := {}
static var _sellers := {}
static var _lots := {}


## The stall's restock window at real time t (each stall keeps its own offset).
static func window(i: int, t: float) -> int:
	var offset := float(hash("restock|%s" % WorldPlayers.entry(i).name) % 1000) / 1000.0 * RESTOCK
	return int(floor((t + offset) / RESTOCK))


## Real time the stall restocks next after t.
static func restock_at(i: int, t: float) -> float:
	var offset := float(hash("restock|%s" % WorldPlayers.entry(i).name) % 1000) / 1000.0 * RESTOCK
	return float(window(i, t) + 1) * RESTOCK - offset


## What stall keeper i specialises in: a word in its name, otherwise its name's hash.
static func specialty(i: int) -> String:
	var name := String(WorldPlayers.entry(i).name).to_lower()
	for pair in KEYWORDS:
		for word in pair[1]:
			if name.contains(String(word)):
				return String(pair[0])
	var kinds := ["mixed", "mixed", "weapon", "armor", "potion", "jewel"]
	return kinds[hash("stall_kind|%s" % name) % kinds.size()]


static func _flag_key(i: int, w: int, k: int) -> String:
	return "%s%s|%d|%d" % [FLAG, WorldPlayers.entry(i).name, w, k]


static func _haggle_key(i: int, w: int, k: int) -> String:
	return "%s%s|%d|%d" % [HAGGLE_FLAG, WorldPlayers.entry(i).name, w, k]


static func _now(t: float) -> float:
	return WorldPresence.clock() if t < 0.0 else t


## The potions the merchant sells at the hero's level (the same steps as ShopScreen).
static func _potions_for(level: int) -> Array[String]:
	var out: Array[String] = ["hp_s", "mp_s"]
	if level >= 7:
		out = ["hp_m", "mp_m"]
	if level >= 16:
		out = ["hp_l", "mp_l"]
	if level >= 40:
		out = ["hp_xl", "mp_xl"]
	if level >= 70:
		out = ["hp_war", "hp_xxl", "mp_xxl"]
	if level >= 100:
		out.append("hp_god")
	return out


## The keeper's own progress at the start of its restock window, which its stock is cut
## to for the whole window: {level, stars} (cached per keeper and window).
static func seller(i: int, t: float = -1.0) -> Dictionary:
	t = _now(t)
	var key := "%s|%d" % [WorldPlayers.entry(i).name, window(i, t)]
	if _sellers.has(key):
		return _sellers[key]
	if _sellers.size() > 256:
		_sellers.clear()
	var s := WorldPlayers.state(i, restock_at(i, t) - RESTOCK)
	var out := {"level": int(s.level), "stars": int(s.stars) if int(s.level) >= Game.MAX_LEVEL else 0}
	_sellers[key] = out
	return out


## How far a seller of `level` and `stars` has come: its level, plus its stars from Lv.100.
static func progress(level: int, stars: int) -> int:
	return level + (stars if level >= Game.MAX_LEVEL else 0)


## The highest gear level a seller of `level` and `stars` may lay out: its own level, and
## from Lv.100 the star gear it could find (100 + its stars up to the ★200 tier: the
## divine pieces are Lv.300), from ★250 the set pieces (Lv.350, SetGearData.LEVEL).
static func gear_cap(level: int, stars: int) -> int:
	if level < Game.MAX_LEVEL:
		return maxi(1, level)
	if stars >= SetGearData.STARS:
		return SetGearData.LEVEL
	return Game.MAX_LEVEL + clampi(stars, 0, ItemData.MAX_GEAR_STAR)


## Chances of a gear lot's grade by the seller's progress (a newcomer finds no mythic piece).
static func rarity_odds(level: int, stars: int) -> Array:
	var p := progress(level, stars)
	if p < 25:
		return [[2, 0.55], [3, 0.45]]
	if p < 60:
		return [[2, 0.4], [3, 0.5], [4, 0.1]]
	if p < Game.MAX_LEVEL:
		return RARITY_ODDS
	return [[2, 0.1], [3, 0.6], [4, 0.3]]


## The forge jewels and mount materials a seller of `level` and `stars` has found by now
## (ids, the common ones more than once): purple from the start, pink from Lv.20, the
## mount materials as their mounts come within reach, chaos and drills at Lv.100, the
## ancient dragon's scales from ★20 (the mechanics dungeon, DungeonData.MIN_STARS),
## feathers from ★50, the drake's scale from ★100 and the set core and the Lotus Scale
## from ★200 (both drop only in the two ★200-300 fields, EndgameFields). The sky isle's
## goods are not here: only a ★300 keeper has them, rarely (ISLE_GOODS).
static func jewels_for(level: int, stars: int) -> Array[String]:
	var out: Array[String] = ["purple", "purple", "purple"]
	if level >= 20:
		out.append_array(["pink", "pink"])
	if level >= 35:
		out.append("wolf_fang")
	if level >= 60:
		out.append("stag_antler")
	if level >= Game.MAX_LEVEL:
		out.append_array(["chaos", "chaos", "chaos", "drill", "griffin_plume"])
		if stars >= DungeonData.MIN_STARS:
			out.append(DungeonData.SCALE)
		if stars >= ItemData.FEATHER_STARS:
			out.append_array(["feather", "feather"])
		if stars >= 100:
			out.append("drake_scale")
		if stars >= DrownedAbyssData.ENTRY_STAR:
			out.append("set_core")
			out.append_array([EndgameFields.SCALE, EndgameFields.SCALE])
	return out


## The largest gem a seller of `level` and `stars` lays out (0 small .. 4 legendary).
static func gem_cap(level: int, stars: int) -> int:
	var p := progress(level, stars)
	if p < 20:
		return 0
	if p < 50:
		return 1
	if p < Game.MAX_LEVEL:
		return 2
	if p < Game.MAX_LEVEL + 150:
		return 3
	return ItemData.GEM_MAX_SIZE


## Every lot stall keeper i lays out in the window of time t, sold or not: what the keeper
## itself found by its own level and stars (seller), weapons mostly for the hero's class:
## [{item, price, k}], price for the whole lot.
static func full_stock(i: int, t: float = -1.0) -> Array[Dictionary]:
	t = _now(t)
	var who := seller(i, t)
	var lots := lots_for("%s|%d" % [WorldPlayers.entry(i).name, window(i, t)], specialty(i), int(who.level), int(who.stars), Game.class_id())
	# Finds for sale are its spare pieces, never what it wears itself (WorldGear).
	var worn := {}
	for piece in WorldGear.equip_at_work(i, WorldPlayers.work_at(i, t)).values():
		worn["%s|%s|%d" % [piece.get("slot", ""), piece.get("name", ""), int(piece.get("level", 0))]] = true
	var out: Array[Dictionary] = []
	for lot in lots:
		var item: Dictionary = lot.item
		if not worn.has("%s|%s|%d" % [item.get("slot", ""), item.get("name", ""), int(item.get("level", 0))]):
			out.append(lot)
	return out


## The lots of a stall of `spec` kept by a seller of `level` and `stars`, seeded by `key`
## (the keeper and the window), for a hero of class `cls`, the best first (hot lots, then
## the dearest; k keeps each lot's own number): gear of the seller's own reach (find: its
## level, a few levels under it at most; from ★50 the star tiers, the 100★ wings, the
## divine pieces from ★200 and now and then a 250★ set piece), graded by rarity_odds,
## forged to the + of its progress (plus_band) and socketed with the gems its class builds
## on (_socket); the potions the merchant sells at the seller's level; the jewels it could
## have found, in bulk (jewels_for, bulk_count; the sky isle's goods only from a ★300
## keeper, ISLE_SHARE) and its gems (gem_cap). A low-level seller never has high-tier
## goods; nothing that may not change hands (sellable) is ever laid out.
static func lots_for(key: String, spec: String, level: int, stars: int, cls: StringName) -> Array[Dictionary]:
	# The chat and the stall screen ask often: a window's lots are made once (copies out).
	var memo := "%s|%s|%d|%d|%s" % [key, spec, level, stars, cls]
	if not _lots.has(memo):
		if _lots.size() > 96:
			_lots.clear()
		_lots[memo] = _make_lots(key, spec, level, stars, cls)
	var out: Array[Dictionary] = []
	for lot in _lots[memo]:
		out.append((lot as Dictionary).duplicate(true))
	return out


static func _make_lots(key: String, spec: String, level: int, stars: int, cls: StringName) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("stall|%s" % key)
	var kind: Dictionary = KINDS.get(spec, KINDS.mixed)
	level = clampi(level, 1, Game.MAX_LEVEL)
	stars = clampi(stars, 0, Game.PARAGON_MAX) if level >= Game.MAX_LEVEL else 0
	var odds := rarity_odds(level, stars)
	var band := plus_band(level, stars)
	var out: Array[Dictionary] = []
	for n in int(kind.gear):
		var slot: String = ItemData.SLOTS[rng.randi() % ItemData.SLOTS.size()]
		if spec == "weapon" and n < 3:
			slot = "weapon"
		elif spec == "armor":
			slot = ["armor", "helm", "boots", "ring", "amulet"][n % 5]
		var rarity := _rarity_by(rng, odds)
		# Gear mostly for the hero's class, now and then another class's find.
		var for_class: StringName = cls if ClassData.IDS.has(cls) else ClassData.IDS[rng.randi() % ClassData.IDS.size()]
		if rng.randf() < OTHER_CLASS:
			for_class = ClassData.IDS[rng.randi() % ClassData.IDS.size()]
		var item := find(rng, level, stars, slot, rarity, for_class, spec)
		# A 250★ set piece leaves the forge at +0 and is sold near it; the rest at the band.
		item["plus"] = rng.randi_range(0, SET_PLUS_MAX) if SetGearData.is_item(item) else roll_plus(rng, band)
		# Rings and amulets cannot be forged (EnhanceFx.can_enhance): they are sold at +0.
		if not EnhanceFx.can_enhance(item):
			item["plus"] = 0
		_socket(item, rng, level, stars, cls)
		out.append({"item": item, "price": gear_price(item)})
	var potions := _potions_for(level)
	for n in int(kind.potions):
		var id: String = potions[(n + rng.randi()) % potions.size()]
		var count: int = [10, 20, 30, 50][rng.randi() % 4]
		var item := ItemData.potion(id, count)
		out.append({"item": item, "price": maxi(1, int(round(float(ItemData.POTIONS[id].price) * POTION_DISCOUNT * count)))})
	var jewels := jewels_for(level, stars)
	var biggest := gem_cap(level, stars)
	for n in int(kind.jewels):
		var item := {}
		if stars >= ISLE_STARS and rng.randf() < ISLE_SHARE:
			var r := rng.randf()
			var id := "dragon_chest"
			for pair in ISLE_GOODS:
				r -= float(pair[1])
				if r < 0.0:
					id = String(pair[0])
					break
			item = ItemData.jewel(id, bulk_count(id, level, stars, rng))
		elif rng.randf() < 0.6:
			var id: String = jewels[rng.randi() % jewels.size()]
			item = ItemData.jewel(id, bulk_count(id, level, stars, rng))
		else:
			# Mostly the gems the hero's class builds on (WorldGear.gem_plan).
			var plan := WorldGear.gem_plan(String(cls) if ClassData.IDS.has(cls) else "warrior")
			var wanted := [String(plan.main), String(plan.main), String(plan.body), String(plan.special)]
			var gem_id: String = String(wanted[rng.randi() % wanted.size()]) if rng.randf() < 0.65 else String(ItemData.GEMS.keys()[rng.randi() % ItemData.GEMS.size()])
			var size := clampi(biggest - (0 if rng.randf() < TOP_GEM_SHARE else 1), 0, biggest)
			item = ItemData.gem(gem_id, size, 1 + rng.randi() % (3 if size < ItemData.GEM_MAX_SIZE else 2))
		out.append({"item": item, "price": goods_price(item)})
	var kept: Array[Dictionary] = []
	for k in out.size():
		out[k]["k"] = k
		out[k]["hot"] = is_hot(out[k].item)
		if sellable(out[k].item):
			kept.append(out[k])
	kept.sort_custom(_better)
	return kept


## Best lot first: a hot lot, then gear before jewels and gems before potions, then the
## dearer one, then the earlier one.
static func _better(a: Dictionary, b: Dictionary) -> bool:
	if bool(a.hot) != bool(b.hot):
		return bool(a.hot)
	var ra := int(SHELF.get(String(a.item.get("kind", "")), SHELF.size()))
	var rb := int(SHELF.get(String(b.item.get("kind", "")), SHELF.size()))
	if ra != rb:
		return ra < rb
	if int(a.price) != int(b.price):
		return int(a.price) > int(b.price)
	return int(a.k) < int(b.k)


## One piece of gear a seller of `level` and `stars` found in `slot` for `for_class`:
## below Lv.100 a piece of its level; from Lv.100 the best it can reach: now and then a
## 250★ set piece (from ★250, SET_SHARE), wings (the 100★ wings from ★100), the class's
## divine piece (from ★200, its four slots, DIVINE_SHARE) or a piece of the star tier it
## farms (from ★50, now and then the tier below), otherwise the older Lv.100+ gear. The
## class-locked endgame pieces are the best of a few rolls (_best): a seller keeps its
## good rolls for the stall.
static func find(rng: RandomNumberGenerator, level: int, stars: int, slot: String, rarity: int, for_class: StringName, spec: String) -> Dictionary:
	var item := {}
	if level >= Game.MAX_LEVEL:
		var roll := rng.randf()
		var cls := String(for_class)
		if stars >= SetGearData.STARS and roll < SET_SHARE:
			item = SetGearData.item(cls, slot)
		elif spec != "armor" and roll < SET_SHARE + WING_SHARE:
			if stars >= StarWingData.REQUIRED_STARS:
				item = _best(func(): return StarWingData.item(cls, rng, 4 if rarity >= 4 else 3), 2)
			else:
				item = ItemData.wings(rng, cls, rarity)
		elif stars >= DivineGearData.STARS and DivineGearData.SLOTS.has(slot) and roll < SET_SHARE + WING_SHARE + DIVINE_SHARE:
			item = _best(func(): return DivineGearData.item(for_class, slot, rng), 3)
		elif stars >= int(StarProgression.TIERS[0]):
			var tiers: Array = StarProgression.TIERS.filter(func(x): return stars >= int(x))
			var tier := int(tiers[-1])
			if tiers.size() > 1 and rng.randf() < LOWER_TIER:
				tier = int(tiers[-2])
			item = _best(func(): return StarProgression.item(for_class, tier, slot, rng), MYTHIC_TRIES if rarity >= 4 else 2)
	if item.is_empty():
		var top := gear_cap(level, stars)
		if level >= Game.MAX_LEVEL:
			top = Game.MAX_LEVEL + clampi(stars - rng.randi_range(0, 8), 0, mini(stars, 20))
		var lv := maxi(1, top - rng.randi_range(0, 3 if level < Game.MAX_LEVEL else 0))
		item = ItemData.generate(lv, for_class, rng, rarity, slot)
	return item


## The best of `tries` pieces made by `make` (the higher grade, then the higher stats).
static func _best(make: Callable, tries: int) -> Dictionary:
	var best: Dictionary = make.call()
	for n in tries - 1:
		var other: Dictionary = make.call()
		if other.is_empty():
			break
		if _worth(other) > _worth(best):
			best = other
	return best


static func _worth(item: Dictionary) -> float:
	var sum := 0.0
	for key in item.get("stats", {}):
		sum += float(item.stats[key]) * (1000.0 if key == "crit" else 1.0)
	return float(item.get("rarity", 0)) * 1e9 + sum


## The + a seller of `level` and `stars` forges its finds to: {lo, hi, show}: a piece is
## +lo..+hi (the higher steps rarer) or, rarely, one of the showpieces in show ([[plus,
## chance]]): a newcomer's few purple-jewel steps, a veteran's +7..+12 and, from ★200,
## the odd +13..+15. Below Lv.100 no piece reaches +10 (that takes chaos jewels).
static func plus_band(level: int, stars: int) -> Dictionary:
	var p := progress(level, stars)
	if p < 25:
		return {"lo": 1, "hi": 4, "show": [[6, 0.05]]}
	if p < 60:
		return {"lo": 3, "hi": 6, "show": [[7, 0.08], [8, 0.03]]}
	if level < Game.MAX_LEVEL:
		return {"lo": 4, "hi": 8, "show": [[9, 0.08]]}
	if stars < 100:
		return {"lo": 6, "hi": 10, "show": [[11, 0.06], [12, 0.02]]}
	if stars < DivineGearData.STARS:
		return {"lo": 7, "hi": 11, "show": [[12, 0.07], [13, 0.025]]}
	if stars < ISLE_STARS:
		return {"lo": 7, "hi": 12, "show": [[13, 0.04], [14, 0.015], [15, 0.005]]}
	return {"lo": 8, "hi": 12, "show": [[13, 0.05], [14, 0.02], [15, 0.008]]}


## One + from `band` (plus_band): a showpiece by its chance, otherwise lo..hi, the
## higher steps rarer.
static func roll_plus(rng: RandomNumberGenerator, band: Dictionary) -> int:
	var r := rng.randf()
	for pair in band.show:
		r -= float(pair[1])
		if r < 0.0:
			return int(pair[0])
	var span := int(band.hi) - int(band.lo) + 1
	return int(band.lo) + mini(span - 1, int(pow(rng.randf(), 1.3) * float(span)))


## A seller fills the sockets of its find with the gems the piece's class builds on
## (WorldGear.gem_for_slot; a ring takes the class's special gem first), of the sizes it
## has (gem_cap); from Lv.100 it may have drilled one more (a fourth only at +15). Some
## pieces, a newcomer's most, come with empty sockets.
static func _socket(item: Dictionary, rng: RandomNumberGenerator, level: int, stars: int, cls: StringName) -> void:
	var sockets := int(item.get("sockets", 0))
	if level >= Game.MAX_LEVEL and rng.randf() < DRILL_SHARE:
		sockets += 1
	sockets = clampi(sockets, 0, ItemData.max_sockets(item))
	item["sockets"] = sockets
	item["gems"] = []
	var fill := 0.45 if level < Game.MAX_LEVEL else (0.8 if stars < DivineGearData.STARS else 0.92)
	if sockets <= 0 or rng.randf() >= fill:
		return
	var owner := ItemData.gear_class(item)
	if not ClassData.IDS.has(StringName(owner)):
		owner = String(cls) if ClassData.IDS.has(cls) else "warrior"
	var slot := String(item.get("slot", "weapon"))
	var main := WorldGear.gem_for_slot(owner, "weapon" if slot == "wings" else slot)
	var biggest := gem_cap(level, stars)
	for n in sockets:
		var kind := main
		if slot == "ring" and n == 0:
			kind = String(WorldGear.gem_plan(owner).special)
		var size := clampi(biggest - (0 if rng.randf() < TOP_GEM_SHARE else 1), 0, biggest)
		(item.gems as Array).append("%s_%d" % [kind, size])


## Gold the forge jewels for +`plus` are worth on average (ItemData.enhance_cost at the
## jewels' prices over ItemData.enhance_chance, step by step from +0).
static func enhance_value(plus: int) -> int:
	var total := 0.0
	for step in clampi(plus, 0, ItemData.MAX_PLUS):
		var cost := ItemData.enhance_cost({"plus": step})
		var gold := 0.0
		for id in cost:
			gold += float(ItemData.JEWELS[id].price) * int(cost[id])
		total += gold / ItemData.enhance_chance(step)
	return int(round(total))


## A gem's price on a stall (one gem): GEM_PRICE by size, a special gem dearer.
static func gem_price(gem_id: String) -> int:
	var info := ItemData.gem_info({"id": gem_id})
	return int(round(float(GEM_PRICE[int(info.size)]) * (SPECIAL_GEM_MARKUP if bool(info.special) else 1.0)))


## What a gear lot costs: the merchant's price times the grade's markup (a divine piece
## DIVINE_PREMIUM more), the forge jewels of its + (enhance_value) with ENHANCE_MARGIN,
## the gems in it (gem_price), HOT_PREMIUM on a showpiece; never under RESALE_FLOOR times
## what a stall pays for it and its gems on consignment, so buying here to consign it
## back (haggled or not) never pays.
static func gear_price(item: Dictionary) -> int:
	var grade := clampi(int(item.get("rarity", 2)), 2, 4)
	var worth := float(ItemData.buy_price(item)) * float(GEAR_MARKUP[grade])
	if DivineGearData.is_item(item):
		worth *= DIVINE_PREMIUM
	worth += float(enhance_value(int(item.get("plus", 0)))) * ENHANCE_MARGIN
	var resale := float(consign_price(item))
	for gem_id in item.get("gems", []):
		var bits := String(gem_id).split("_")
		worth += float(gem_price(String(gem_id)))
		resale += float(consign_price(ItemData.gem(bits[0], int(bits[1]))))
	if is_hot(item):
		worth *= HOT_PREMIUM
	return int(round(maxf(worth, resale * RESALE_FLOOR)))


## What a jewel or gem lot costs: JEWEL_MARKUP over the jewels' price, gem_price a gem;
## never under RESALE_FLOOR times its consignment value.
static func goods_price(item: Dictionary) -> int:
	var count := int(item.get("count", 1))
	var worth := 0.0
	if String(item.get("kind", "")) == "gem":
		worth = float(gem_price(String(item.id))) * count
	else:
		worth = float(ItemData.JEWELS[item.id].price) * JEWEL_MARKUP * count
	if is_hot(item):
		worth *= HOT_PREMIUM
	return int(round(maxf(worth, float(consign_price(item) * count) * RESALE_FLOOR)))


## How many of material `id` a seller of `level` and `stars` lays out in one lot: BULK's
## range, its top growing with the seller's progress (a newcomer a handful, a ★300 keeper
## dozens of jewels).
static func bulk_count(id: String, level: int, stars: int, rng: RandomNumberGenerator) -> int:
	var span: Array = BULK.get(id, [1, 1])
	var reach := clampf(float(progress(level, stars)) / float(Game.MAX_LEVEL + Game.PARAGON_MAX), 0.15, 1.0)
	var hi := int(span[0]) + int(round(float(int(span[1]) - int(span[0])) * reach))
	return rng.randi_range(int(span[0]), maxi(int(span[0]), hi))


## A showpiece (ของเด่น): gear at +HOT_PLUS or more, a 250★ set piece, or one of the rare
## goods in HOT_GOODS (the set core, the Dragon God costume's fragment, the sky dragon's egg).
static func is_hot(item: Dictionary) -> bool:
	match String(item.get("kind", "")):
		"equip":
			return int(item.get("plus", 0)) >= HOT_PLUS or SetGearData.is_item(item)
		"jewel":
			return HOT_GOODS.has(String(item.get("id", "")))
	return false


## Whether a stall may lay out `item`: never the Dragon God's weapon or wings, a costume,
## the Legendary Guild Wings or anything else that may not be traded or saved.
static func sellable(item: Dictionary) -> bool:
	if DragonGearData.is_item(item) or ItemData.is_costume(item) or LegendWings.is_item(item):
		return false
	return OnlineTrade.tradable(item) and Game._valid_item(item)


static func _rarity_by(rng: RandomNumberGenerator, odds: Array) -> int:
	var r := rng.randf()
	for pair in odds:
		r -= float(pair[1])
		if r <= 0.0:
			return int(pair[0])
	return int(odds[0][0])


## What stall keeper i still has for sale at time t (the lots the hero bought are gone
## until the next restock): [{item, price, k}].
static func stock(i: int, t: float = -1.0) -> Array[Dictionary]:
	t = _now(t)
	var w := window(i, t)
	var flags: Dictionary = Game.profile.get("flags", {})
	var out: Array[Dictionary] = []
	for e in full_stock(i, t):
		if int(flags.get(_flag_key(i, w, int(e.k)), 0)) != 0:
			continue
		var off := discount(i, int(e.k), t)
		if off > 0:
			e["base"] = int(e.price)
			e["price"] = maxi(1, int(round(float(e.price) * float(100 - off) / 100.0)))
		out.append(e)
	return out


## What haggling over lot k of stall i in the window of time t comes to, the same on every
## try (a hash of the keeper, the window, the lot and the hero's name): {code, percent}.
static func haggle_outcome(i: int, k: int, t: float = -1.0) -> Dictionary:
	t = _now(t)
	var h := absi(hash("haggle|%s|%d|%d|%s" % [WorldPlayers.entry(i).name, window(i, t), k, String(Game.profile.get("name", ""))]))
	var roll := h % 100
	var spin := h / 100
	if roll < HAGGLE_ACCEPT_ODDS:
		return {"code": HAGGLE_ACCEPTED, "percent": 10 + spin % 11}
	if roll < HAGGLE_ACCEPT_ODDS + HAGGLE_REFUSE_ODDS:
		return {"code": HAGGLE_REFUSED, "percent": 0}
	return {"code": HAGGLE_COUNTER, "percent": 4 + spin % 4}


## The haggle code kept for lot k of stall i in this window (0: not haggled yet).
static func haggled(i: int, k: int, t: float = -1.0) -> int:
	t = _now(t)
	return int(Game.profile.get("flags", {}).get(_haggle_key(i, window(i, t), k), 0))


## The percent off lot k of stall i the hero haggled (0 without a haggle or when refused).
static func discount(i: int, k: int, t: float = -1.0) -> int:
	t = _now(t)
	return int(haggle_outcome(i, k, t).percent) if haggled(i, k, t) in [HAGGLE_ACCEPTED, HAGGLE_COUNTER] else 0


## Whether the hero may still haggle over lot k of stall i (once a lot a window).
static func can_haggle(i: int, k: int, t: float = -1.0) -> bool:
	t = _now(t)
	return haggled(i, k, t) == 0 and stock(i, t).any(func(e): return int(e.k) == k)


## The hero haggles over lot k of stall i: the keeper answers in the world chat and the
## stock shows the new price; {code, percent, text}, empty when it cannot (already haggled
## in this window, or no such lot).
static func haggle(i: int, k: int, t: float = -1.0) -> Dictionary:
	t = _now(t)
	if not can_haggle(i, k, t):
		return {}
	var out := haggle_outcome(i, k, t)
	var lines: Array = HAGGLE_REFUSE_LINES
	if int(out.code) == HAGGLE_ACCEPTED:
		lines = HAGGLE_ACCEPT_LINES
	elif int(out.code) == HAGGLE_COUNTER:
		lines = HAGGLE_COUNTER_LINES
	var text := String(lines[absi(hash("haggle_line|%s|%d" % [WorldPlayers.entry(i).name, k])) % lines.size()])
	if text.contains("%d"):
		text = text % int(out.percent)
	out["text"] = text
	Game.profile.flags[_haggle_key(i, window(i, t), k)] = int(out.code)
	Game.mark_dirty()
	Game.world_chat.emit(String(WorldPlayers.entry(i).name), text, Color("8ff0ff"))
	return out


## The hero buys lot k of stall i: gold spent, the lot in the bag (in the shared storage
## when the bag is full, Game.give_or_store) and gone from the stall. Nothing is spent
## when neither has room.
static func buy(i: int, k: int, t: float = -1.0) -> bool:
	t = _now(t)
	for e in stock(i, t):
		if int(e.k) != k:
			continue
		var item: Dictionary = (e.item as Dictionary).duplicate(true)
		var price := int(e.price)
		if int(Game.profile.gold) < price:
			Game.say("เหรียญไม่พอ", &"warning")
			return false
		if item.get("kind", "") == "equip":
			item["uid"] = ItemData.make_uid()
		if not Game.give_or_store(item):
			return false
		Game.profile.flags[_flag_key(i, window(i, t), k)] = 1
		Game.spend_gold(price)
		Game.mark_dirty()
		return true
	return false


## What a stall pays for one of `item` (stackables) or the item: more than the merchant.
static func sell_price(item: Dictionary) -> int:
	var unit := ItemData.unit_sell_price(item)
	return int(ceil(float(unit) * SELL_BONUS - 0.001)) if unit > 0 else 0


## The hero sells `count` of bag slot `index` to a stall.
static func sell(index: int, count := 1) -> bool:
	if index < 0 or index >= Game.profile.inv.size():
		return false
	var item: Dictionary = Game.profile.inv[index]
	if LegendWings.is_item(item):
		Game.say(LegendWings.SELL_TEXT, &"warning")
		return false
	if ItemData.is_costume(item) or sell_price(item) <= 0:
		Game.say(Game.COSTUME_SELL_TEXT if ItemData.is_costume(item) else "ของชิ้นนี้ขายไม่ได้", &"warning")
		return false
	var qty := clampi(count, 1, int(item.get("count", 1))) if ItemData.is_stackable(item) else 1
	Game.add_gold(sell_price(item) * qty)
	Game.remove_item_at(index, qty)
	return true


## What a stall pays later for one of `item` left with it to sell: more than selling now.
static func consign_price(item: Dictionary) -> int:
	var unit := ItemData.unit_sell_price(item)
	return int(ceil(float(unit) * CONSIGN_BONUS - 0.001)) if unit > 0 else 0


## The lots left with the keepers and not yet paid: [{due (real seconds), gold, key}],
## the soonest first.
static func consignments() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in Game.profile.get("flags", {}):
		var text := String(key)
		if not text.begins_with(CONSIGN_FLAG):
			continue
		var bits := text.split("|")
		if bits.size() == 3 and bits[1].is_valid_int():
			out.append({"due": float(int(bits[1])) * 60.0, "gold": int(Game.profile.flags[key]), "key": text})
	out.sort_custom(func(a, b): return float(a.due) < float(b.due))
	return out


## The hero leaves `count` of bag slot `index` (0: the whole stack; always the piece
## itself for gear) with a stall to sell: gone from the bag now, the rest of the stack
## staying, its gold (CONSIGN_BONUS times the merchant's price per unit) paid
## CONSIGN_MINUTES later.
static func consign(index: int, count := 0, t: float = -1.0) -> bool:
	t = _now(t)
	if index < 0 or index >= Game.profile.inv.size():
		return false
	if consignments().size() >= CONSIGN_MAX:
		Game.say("ฝากขายได้ไม่เกิน %d ชิ้น" % CONSIGN_MAX, &"warning")
		return false
	var item: Dictionary = Game.profile.inv[index]
	var stack := int(item.get("count", 1)) if ItemData.is_stackable(item) else 1
	var qty := stack if count <= 0 else clampi(count, 1, stack)
	var gold := consign_price(item) * qty
	if gold <= 0:
		Game.say(LegendWings.STALL_TEXT if LegendWings.is_item(item) else "ของชิ้นนี้ฝากขายไม่ได้", &"warning")
		return false
	var due := int(ceil(t / 60.0)) + CONSIGN_MINUTES
	var n := 0
	while Game.profile.flags.has("%s%d|%d" % [CONSIGN_FLAG, due, n]):
		n += 1
	Game.profile.flags["%s%d|%d" % [CONSIGN_FLAG, due, n]] = gold
	Game.remove_item_at(index, qty)
	Game.mark_dirty()
	Game.say("ฝากขายแล้ว รับ %d เหรียญในอีก %d นาที" % [gold, CONSIGN_MINUTES])
	return true


## Pays the hero every consignment due by time t (and drops malformed keys): the gold paid.
static func collect_consignments(t: float = -1.0) -> int:
	t = _now(t)
	var flags: Dictionary = Game.profile.get("flags", {})
	var total := 0
	var drop: Array[String] = []
	for key in flags:
		var text := String(key)
		if not text.begins_with(CONSIGN_FLAG):
			continue
		var bits := text.split("|")
		if bits.size() != 3 or not bits[1].is_valid_int():
			drop.append(text)
		elif float(int(bits[1])) * 60.0 <= t:
			total += maxi(0, int(flags[key]))
			drop.append(text)
	for key in drop:
		flags.erase(key)
	if total > 0:
		Game.add_gold(total)
		Game.say("ได้เงินจากของฝากขาย %d เหรียญ" % total)
	elif not drop.is_empty():
		Game.mark_dirty()
	return total


static func _thousands(n: int) -> String:
	var text := str(n)
	var out := ""
	while text.length() > 3:
		out = "," + text.right(3) + out
		text = text.left(text.length() - 3)
	return text + out


## The name of one lot of `kind` (equip / potion / jewel) stall i really has now, as a
## chat line says it ("ดาบนักล่า +0" is never claimed as +8), or "" when it has none.
static func lot_name(i: int, kind: String, pick: int, t: float = -1.0) -> String:
	if i < 0:
		return ""
	var lots := stock(i, _now(t)).filter(func(e): return String(e.item.get("kind", "")) == kind)
	if lots.is_empty():
		return ""
	# ItemData.name_of already leads with the + ("+12 ดาบ..."), as the stall shows it.
	return ItemData.name_of(lots[absi(pick) % lots.size()].item)


## Stall keeper i calls out one of the lots it still has at time t for the world chat
## ("ร้านลุงหมี: มี+8 ดาบระดับหายาก Lv.27 ราคา 3,200 แวะดูได้"); "" with nothing left.
## A showpiece it has (is_hot) is called out half the time, as "ของเด่น".
static func announcement(i: int, t: float = -1.0) -> String:
	t = _now(t)
	var lots := stock(i, t)
	if lots.is_empty():
		return ""
	var name := String(WorldPlayers.entry(i).name)
	var roll := absi(hash("announce|%s|%d" % [name, int(t / 600.0)]))
	var hot := lots.filter(func(x): return bool(x.get("hot", false)))
	var e: Dictionary = hot[roll % hot.size()] if not hot.is_empty() and roll % 2 == 0 else lots[roll % lots.size()]
	var item: Dictionary = e.item
	var what := ItemData.name_of(item)
	if String(item.get("kind", "")) == "equip":
		what = "%sระดับ%s %s" % [what, ItemData.RARITY_NAMES[clampi(int(item.get("rarity", 2)), 0, ItemData.RARITY_NAMES.size() - 1)], ItemData.level_text(int(item.level))]
	elif int(item.get("count", 1)) > 1:
		what = "%s ×%d" % [what, int(item.count)]
	var shop := name if name.begins_with("ร้าน") else "ร้าน" + name
	if bool(e.get("hot", false)):
		return "%s: มีของเด่น %s ราคา %s แวะดูได้" % [shop, what, _thousands(int(e.price))]
	return "%s: มี%s ราคา %s แวะดูได้" % [shop, what, _thousands(int(e.price))]


## A stall opens to the hero at time t: the bought-lot and haggle keys of windows gone by
## (of every stall) are dropped, so the flags never grow, and the consignments due are paid.
static func open(_i: int, t: float = -1.0) -> void:
	t = _now(t)
	if _by_name.is_empty():
		for n in WorldPlayers.size():
			_by_name[String(WorldPlayers.entry(n).name)] = n
	var flags: Dictionary = Game.profile.get("flags", {})
	var drop: Array[String] = []
	for key in flags:
		var text := String(key)
		if not (text.begins_with(FLAG) or text.begins_with(HAGGLE_FLAG)):
			continue
		var bits := text.split("|")
		var who := int(_by_name.get(bits[1], -1)) if bits.size() == 4 else -1
		if who < 0 or int(bits[2]) != window(who, t):
			drop.append(text)
	for key in drop:
		flags.erase(key)
	if not drop.is_empty():
		Game.mark_dirty()
	collect_consignments(t)


## The keys of bought lots kept in the flags now (tests).
static func bought_keys() -> Array[String]:
	var out: Array[String] = []
	for key in Game.profile.get("flags", {}):
		if String(key).begins_with(FLAG):
			out.append(String(key))
	return out
