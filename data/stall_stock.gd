class_name StallStock
extends RefCounted
## What a stall keeper in the village sells and buys (WorldPlayers: the "afk" players and
## divine players taking a break, doing "stall"). They are players resting from the hunt
## who bring the good things they found: gear for the buyer (the hero's class and level)
## a grade or more above the merchant's (the NPC sells common and good pieces, a stall
## rare, legendary and now and then mythic ones), plus potions a little under the
## merchant's price, forge jewels and gems. Each stall restocks every RESTOCK real seconds
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
const GEM_PRICE := [60, 180, 540]
## Chances of a stall piece being rare (2), legendary (3) or mythic (4).
const RARITY_ODDS := [[2, 0.62], [3, 0.3], [4, 0.08]]
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
## Specialities and what a stall of each lays out: gear pieces, consumable lots.
const KINDS := {
	"mixed": {"gear": 4, "potions": 1, "jewels": 1},
	"weapon": {"gear": 5, "potions": 1, "jewels": 0},
	"armor": {"gear": 5, "potions": 0, "jewels": 1},
	"potion": {"gear": 2, "potions": 4, "jewels": 0},
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


static func _rarity(rng: RandomNumberGenerator) -> int:
	var r := rng.randf()
	for pair in RARITY_ODDS:
		r -= float(pair[1])
		if r <= 0.0:
			return int(pair[0])
	return 2


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


## Every lot stall keeper i lays out in the window of time t, sold or not, for the hero's
## class and level: [{item, price, k}], price for the whole lot.
static func full_stock(i: int, t: float = -1.0) -> Array[Dictionary]:
	t = _now(t)
	var w := window(i, t)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("stall|%s|%d" % [WorldPlayers.entry(i).name, w])
	var spec := specialty(i)
	var kind: Dictionary = KINDS[spec]
	var level := clampi(int(Game.profile.get("level", 1)), 1, Game.MAX_LEVEL)
	var cls := Game.class_id()
	var out: Array[Dictionary] = []
	for n in int(kind.gear):
		var slot: String = ItemData.SLOTS[rng.randi() % ItemData.SLOTS.size()]
		if spec == "weapon" and n < 3:
			slot = "weapon"
		elif spec == "armor":
			slot = ["armor", "helm", "boots", "ring", "amulet"][n % 5]
		var rarity := _rarity(rng)
		var item := ItemData.generate(maxi(1, level - rng.randi_range(0, 2)), cls, rng, rarity, slot)
		var price := int(round(float(ItemData.buy_price(item)) * float(GEAR_MARKUP[rarity])))
		out.append({"item": item, "price": price})
	var potions := _potions_for(level)
	for n in int(kind.potions):
		var id: String = potions[(n + rng.randi()) % potions.size()]
		var count: int = [10, 20, 30, 50][rng.randi() % 4]
		var item := ItemData.potion(id, count)
		out.append({"item": item, "price": maxi(1, int(round(float(ItemData.POTIONS[id].price) * POTION_DISCOUNT * count)))})
	for n in int(kind.jewels):
		var item := {}
		var price := 0
		if rng.randf() < 0.5:
			var jewels := ["purple", "purple", "pink"] + (["chaos"] if level >= Game.MAX_LEVEL else [])
			var id: String = jewels[rng.randi() % jewels.size()]
			var count := 1 + rng.randi() % 3
			item = ItemData.jewel(id, count)
			price = int(round(float(ItemData.JEWELS[id].price) * JEWEL_MARKUP * count))
		else:
			var gems: Array = ItemData.GEMS.keys()
			var size := mini(2, rng.randi() % 3 + (1 if level >= 60 else 0))
			var count := 1 + rng.randi() % 2
			item = ItemData.gem(String(gems[rng.randi() % gems.size()]), size, count)
			price = int(GEM_PRICE[size]) * count
		out.append({"item": item, "price": price})
	for k in out.size():
		out[k]["k"] = k
	return out


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


## The hero buys lot k of stall i: gold spent, the lot in the bag and gone from the stall.
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
		var stacks: bool = ItemData.is_stackable(item) and Game.profile.inv.any(func(x): return x.get("kind", "") == item.get("kind", "") and x.get("id") == item.id)
		if not stacks and Game.inventory_free() <= 0:
			Game.say("กระเป๋าเต็ม", &"warning")
			return false
		if item.get("kind", "") == "equip":
			item["uid"] = ItemData.make_uid()
		Game.profile.flags[_flag_key(i, window(i, t), k)] = 1
		Game.spend_gold(price)
		Game.add_item(item)
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
		Game.say("ของชิ้นนี้ฝากขายไม่ได้", &"warning")
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


## Stall keeper i calls out one of the lots it still has at time t for the world chat
## ("ร้านลุงหมี: มีดาบระดับหายาก Lv.27 ราคา 3,200 แวะดูได้"); "" with nothing left.
## The name of one lot of `kind` (equip / potion / jewel) stall i really has now, as a
## chat line says it ("ดาบนักล่า +0" is never claimed as +8), or "" when it has none.
static func lot_name(i: int, kind: String, pick: int, t: float = -1.0) -> String:
	if i < 0:
		return ""
	var lots := stock(i, _now(t)).filter(func(e): return String(e.item.get("kind", "")) == kind)
	if lots.is_empty():
		return ""
	var item: Dictionary = lots[absi(pick) % lots.size()].item
	var plus := int(item.get("plus", 0))
	return ItemData.name_of(item) + (" +%d" % plus if plus > 0 else "")


static func announcement(i: int, t: float = -1.0) -> String:
	t = _now(t)
	var lots := stock(i, t)
	if lots.is_empty():
		return ""
	var name := String(WorldPlayers.entry(i).name)
	var e: Dictionary = lots[absi(hash("announce|%s|%d" % [name, int(t / 600.0)])) % lots.size()]
	var item: Dictionary = e.item
	var what := ItemData.name_of(item)
	if String(item.get("kind", "")) == "equip":
		what = "%sระดับ%s %s" % [what, ItemData.RARITY_NAMES[clampi(int(item.get("rarity", 2)), 0, ItemData.RARITY_NAMES.size() - 1)], ItemData.level_text(int(item.level))]
	elif int(item.get("count", 1)) > 1:
		what = "%s ×%d" % [what, int(item.count)]
	var shop := name if name.begins_with("ร้าน") else "ร้าน" + name
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
