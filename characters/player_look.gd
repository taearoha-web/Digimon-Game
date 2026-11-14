class_name PlayerLook
extends RefCounted
## One character's appearance as a plain dictionary, the same shape for the hero, a world
## player (FieldPlayer) and a real player seen online (RemotePlayer): what the class,
## its job step, the face and hair, every worn piece (with its plus, gems and set, so the
## enhancement glow, wings, cape and set pieces come out the same) and the wing pose are.
##   {"class": "mage", "adv": 2, "face": {gender, hair, ...}, "equip": {slot: item},
##    "wing_mode": 0, "level": 41, "stars": 0, "cos": "", "trail": "", "ncol": ""}
## cos / trail / ncol are the reward shop's costume, walk trail and name colour worn
## (RewardShop ids, "" for none): they travel with the look so the others see them.
## of_hero builds it from the hero's profile (Game.hero_look), of_member from a world
## player's sheet (what FieldPlayer wears), dress puts it on a HeroVisual the way a
## Companion / FieldPlayer is dressed (HeroVisual.setup with the class, the gear and the
## face), and clean checks one that came over the network (Online) before anything
## builds from it: unknown classes, broken items and out-of-range values never reach
## the character code.

## Item fields left out on the wire: the look never reads them and they are most of an
## item's bytes (a frame is at most 8 KB).
const WIRE_DROP: Array[String] = ["stats", "price"]
## Item fields that must be numbers when present (Game._repair_item turns them to ints).
const NUMBER_KEYS: Array[String] = ["count", "rarity", "level", "price", "plus", "sockets", "star_tier"]
## Item fields that must be text when present.
const TEXT_KEYS: Array[String] = ["kind", "slot", "uid", "name", "class", "set", "base", "boss", "wing", "star_class", "collection", "set_gear"]


## The hero's look from a profile dictionary (Game.profile).
static func of_profile(p: Dictionary) -> Dictionary:
	var flags: Variant = p.get("flags", {})
	var paragon: Variant = p.get("paragon", {})
	return {
		"class": String(p.get("class", ClassData.START)),
		"adv": int(p.get("adv", 0)),
		"face": (p.get("look", {}) as Dictionary).duplicate() if p.get("look") is Dictionary else {},
		"equip": wire_equip(p.get("equip", {}) if p.get("equip") is Dictionary else {}),
		"wing_mode": clampi(int((flags as Dictionary).get("wing_mode", 0)) if flags is Dictionary else 0, HeroVisual.WING_STAND, HeroVisual.WING_FOLD),
		"level": int(p.get("level", 1)),
		"stars": int((paragon as Dictionary).get("level", 0)) if paragon is Dictionary else 0,
		"cos": _worn(p, "costume"),
		"trail": _worn(p, "trail"),
		"ncol": _worn(p, "ncol"),
	}


## The reward-shop cosmetic of `tab` profile `p` wears ("" for none or when not owned;
## the costume: the one in its costume slot).
static func _worn(p: Dictionary, tab: String) -> String:
	# The costume is the item in the costume slot (any hero's, moved through the storage).
	if tab == "costume":
		return RewardShop.worn_of(p)
	var d: Variant = p.get(RewardShop.KEY, {})
	if not d is Dictionary:
		return ""
	var key := "cos" if tab == "costume" else tab
	var id := str((d as Dictionary).get(key, ""))
	var own: Variant = (d as Dictionary).get("own", [])
	return id if id != "" and own is Array and (own as Array).has(id) and RewardShop.catalog(tab).has(id) else ""


## A world player's look (the one FieldPlayer wears): sheet `m` (WorldPlayers.member)
## of roster player `index`.
static func of_member(m: Dictionary, index: int) -> Dictionary:
	var level := int(m.get("level", 1))
	var stars := Game.party_stars(m)
	var worn := RewardShop.world_cosmetics(index)
	return {
		"class": String(m.get("class", ClassData.START)),
		"adv": JobData.adv_for(level, stars),
		"face": WorldPlayers.look(index) if index >= 0 and index < WorldPlayers.size() else {"gender": int(m.get("gender", 0))},
		"equip": wire_equip(WorldPlayers.equip(m)),
		"wing_mode": HeroVisual.WING_STAND,
		"level": level,
		"stars": stars,
		"cos": String(worn.cos),
		"trail": String(worn.trail),
		"ncol": String(worn.ncol),
	}


## The worn pieces without the fields the look never reads.
static func wire_equip(equip: Dictionary) -> Dictionary:
	var out := {}
	for slot in equip:
		var item: Variant = equip[slot]
		if item is Dictionary:
			var slim := (item as Dictionary).duplicate(true)
			for key in WIRE_DROP:
				slim.erase(key)
			out[String(slot)] = slim
	return out


## Puts `look` (already clean) on `visual`: the same HeroVisual.setup a Companion and a
## FieldPlayer go through, then the wing pose.
static func dress(visual: HeroVisual, look: Dictionary) -> void:
	visual.costume = str(look.get("cos", ""))
	visual.setup(StringName(look.get("class", ClassData.START)), "", true, look.get("equip", {}), look.get("face", {}))
	var mode := int(look.get("wing_mode", HeroVisual.WING_STAND))
	if mode != HeroVisual.WING_STAND and visual.has_wings():
		visual.set_wing_mode(mode, true)


## Equipment only (the body stays): a new piece or a new plus.
static func redress(visual: HeroVisual, look: Dictionary) -> void:
	visual.costume = str(look.get("cos", ""))
	visual.set_equipment(look.get("equip", {}))


## A look that came from somewhere else, made safe: a known class, the job step, the face
## through FaceKit.repair, and only the pieces that pass the save game's own item check
## (Game._valid_item) in the slot they claim. Anything else becomes the default.
static func clean(raw: Variant) -> Dictionary:
	var src: Dictionary = raw if raw is Dictionary else {}
	var cls := StringName(str(src.get("class", ClassData.START)))
	if not ClassData.CLASSES.has(cls):
		cls = ClassData.START
	var face_in: Dictionary = {}
	var face_raw: Variant = src.get("face", {})
	if face_raw is Dictionary:
		for key in face_raw:
			var v: Variant = face_raw[key]
			if (v is int or v is float) and is_finite(float(v)):
				face_in[str(key)] = int(v)
	var equip := {}
	var equip_raw: Variant = src.get("equip", {})
	if equip_raw is Dictionary:
		for slot in equip_raw:
			var item := clean_item(equip_raw[slot])
			if not item.is_empty() and String(item.get("slot", "")) == str(slot):
				equip[str(slot)] = item
	return {
		"class": String(cls),
		"adv": clampi(_int(src.get("adv", 0)), 0, JobData.MAX_ADV),
		"face": FaceKit.repair(face_in),
		"equip": equip,
		"wing_mode": clampi(_int(src.get("wing_mode", 0)), HeroVisual.WING_STAND, HeroVisual.WING_FOLD),
		"level": clampi(_int(src.get("level", 1)), 1, Game.MAX_LEVEL),
		"stars": clampi(_int(src.get("stars", 0)), 0, Game.PARAGON_MAX),
		"cos": _cosmetic(src.get("cos", ""), "costume"),
		"trail": _cosmetic(src.get("trail", ""), "trail"),
		"ncol": _cosmetic(src.get("ncol", ""), "ncol"),
	}


## A reward-shop id from the wire: one of the catalogue's or "".
static func _cosmetic(v: Variant, tab: String) -> String:
	return str(v) if (v is String or v is StringName) and RewardShop.catalog(tab).has(str(v)) else ""


## One worn piece from the network, or {} when it is not a valid piece of gear.
static func clean_item(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var item := (raw as Dictionary).duplicate(true)
	for key in WIRE_DROP:
		item.erase(key)
	for key in NUMBER_KEYS:
		if item.has(key):
			var v: Variant = item[key]
			if not (v is int or v is float) or not is_finite(float(v)):
				return {}
	for key in TEXT_KEYS:
		if item.has(key) and not (item[key] is String or item[key] is StringName):
			return {}
	if item.has("gems") and not item.gems is Array:
		return {}
	if item.get("kind") != "equip":
		return {}
	Game._repair_item(item)
	return item if Game._valid_item(item) else {}


## A short key that changes whenever the look does (cheap to compare).
static func signature(look: Dictionary) -> String:
	return str(hash(JSON.stringify(look)))


static func _int(v: Variant) -> int:
	return int(v) if (v is int or v is float) and is_finite(float(v)) else 0
