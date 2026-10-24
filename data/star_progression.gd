class_name StarProgression
extends RefCounted
## ★ regions, their gear tiers and milestone rewards. Star gear only drops
## (no forge); milestones use numeric flags supported by old/cloud saves.
const REGIONS: Array[StringName] = [&"dawn_forest", &"crystal_valley", &"sky_citadel", &"eclipse_realm"]
const TITLES := ["ป่าแสงอรุณ", "หุบเขาผลึกคราม", "นครลอยฟ้า", "อาณาจักรสุริยคราส"]
const TIERS := [50, 100, 150, 200]
const ENTRY := [1, 50, 100, 150]

static func is_region(id: StringName) -> bool:
	return REGIONS.has(id)

static func zones() -> Dictionary:
	var result := {}
	var skies := [Color("a3dce2"), Color("8db5d9"), Color("b7d6ed"), Color("3e385f")]
	for i in 4:
		var id: StringName = REGIONS[i]
		var layout := StarRegionArt.layout(id)
		var monsters := StarMonsters.ids_for(id)
		var camps: Array = []
		# Five farm camps of ten, one kind each like the older fields. The last
		# two also hold an elite now and then.
		var normals: Array = [monsters[0], monsters[1], monsters[2], monsters[3], monsters[7]]
		for k in 5:
			var ids: Array = [normals[k]]
			if k == 3: ids = [normals[k], normals[k], normals[k], monsters[4]]
			elif k == 4: ids = [normals[k], normals[k], normals[k], monsters[5]]
			camps.append({"name": String(StarMonsters.get_monster(normals[k]).name),"monsters":ids,"levels":[100 + i * 12,108 + i * 12],"pos":layout.camp_positions[k],"radius":9.0,"count":10})
		result[id] = {"name":TITLES[i],"scene":"field","theme":id,"star_region":true,"star":ENTRY[i],"gear_star":TIERS[i],
			"level":[100,100],"music":id,"sky":skies[i],"ground":Color("79a28b"),
			"fog":skies[i].lightened(0.15),"ambient":Color("c6d6f0"),"sun":Color("fff0ce"),"camps":camps,
			"boss":{"monster":monsters[6],"level":110+i*15,"respawn":110.0,"star":200 if i==3 else ENTRY[i]},
			"prev":&"void" if i==0 else REGIONS[i-1],"next":REGIONS[i+1] if i<3 else &"","ambience":&"water" if i==0 else &"wind"}
	return result

static func region_index(id: StringName) -> int:
	return REGIONS.find(id)

## One shared roll on a piece's stats. A legendary piece rolls 0.98-1.00 of its
## tier's value; the rare mythic one rolls 1.035-1.06, a clear step up that still
## stays under the weakest legendary piece of the next tier (the gap between two
## star tiers is at least 11%), so more stars always means better in every stat.
const ROLL_MIN := 0.98
const ROLL_MAX := 1.00
const MYTHIC_ROLL_MIN := 1.035
const MYTHIC_ROLL_MAX := 1.06
## Share of star pieces that come out mythic (red) instead of legendary (purple).
const MYTHIC_CHANCE := 0.08
const GEAR_RARITY := 3
const MYTHIC_RARITY := 4
## Bonus lines a ★ piece carries, spread evenly over hp, mp, crit, atk and def.
const BONUS_LINES := 3.0

static func _luck(piece: Dictionary) -> int:
	return absi(hash(JSON.stringify(piece.get("stats",{}))))

## The shared roll of a freshly generated piece, taken from its own random stats
## so that making a star piece draws no more random numbers than it always did.
static func roll_of(piece: Dictionary) -> float:
	return lerpf(ROLL_MIN,ROLL_MAX,float(_luck(piece) % 1000)/999.0)

static func is_mythic_roll(piece: Dictionary) -> bool:
	return float((_luck(piece) / 1000) % 1000)/1000.0 < MYTHIC_CHANCE

static func mythic_roll_of(piece: Dictionary) -> float:
	return lerpf(MYTHIC_ROLL_MIN,MYTHIC_ROLL_MAX,float(_luck(piece) % 1000)/999.0)

## The highest star count the older random gear reaches (Lv.100 + 20 stars).
const LEGACY_TOP_LEVEL := 120
## The stats that define a slot, the ones the ladder guarantees in full.
const DEFINING := {"weapon": ["atk"], "armor": ["def"], "helm": ["def"], "boots": ["def"], "ring": ["atk", "crit"], "amulet": ["hp", "mp"]}
## The weakest 50-star piece beats the best older piece by at least this much.
const LEGACY_MARGIN := 1.03
static var _boosts := {}

## Highest value an older random piece (Lv.1-120, any rarity, best roll, all four
## bonus lines on this one stat) can reach for [param key] in [param slot].
static func legacy_ceiling(slot: String, key: String) -> float:
	var best := 0.0
	for level in range(1, LEGACY_TOP_LEVEL + 1):
		var main := ItemData.main_stats(slot, level, 4, 1.08)
		best = maxf(best, float(main.get(key, 0)) + 4.0 * float(ItemData.bonus_line(key, level)))
	return best

## How much a slot's star stats are lifted so that even the weakest 50-star
## piece beats the best older piece in every defining stat. One factor per slot
## keeps each stat's proportions, and every tier gets it so the ladder up to
## 200 stars keeps its steps.
static func slot_boost(slot: String) -> float:
	if not _boosts.has(slot):
		var base := ItemData.tiered_stats(slot, 100 + TIERS[0], GEAR_RARITY, BONUS_LINES, ROLL_MIN)
		var boost := 1.0
		for key in DEFINING.get(slot, []):
			boost = maxf(boost, legacy_ceiling(slot, key) * LEGACY_MARGIN / maxf(float(base.get(key, 1)), 0.0001))
		_boosts[slot] = boost
	return float(_boosts[slot])

static func tier_stats(slot: String, stars: int, roll: float) -> Dictionary:
	return ItemData.tiered_stats(slot, 100 + stars, GEAR_RARITY, BONUS_LINES, roll * slot_boost(slot))

## The best a 200-star piece can roll in [param slot]: what the class set must clear.
static func top_stats(slot: String) -> Dictionary:
	return tier_stats(slot, TIERS[-1], MYTHIC_ROLL_MAX)

static func item(cls: StringName, stars: int, slot: String, rng: RandomNumberGenerator) -> Dictionary:
	if not TIERS.has(stars) or not ClassData.IDS.has(cls) or not ItemData.EQUIP_SLOTS.has(slot): return {}
	if slot=="wings": return StarWingData.item(String(cls),rng) if stars==100 else {}
	var result := ItemData.generate(100+stars,cls,rng,3,slot)
	# Tier decides the grade, not luck: every stat is the tier's fixed value
	# times one small roll, so a higher-star piece is better in every stat.
	var mythic := is_mythic_roll(result)
	result["stats"] = tier_stats(slot,stars,mythic_roll_of(result) if mythic else roll_of(result))
	if mythic:
		# Same tier, better grade: red colour, a third socket and a higher price.
		result["rarity"] = MYTHIC_RARITY
		result["sockets"] = ItemData.sockets_for(MYTHIC_RARITY)
		result["price"] = int(float(result.get("price",0)) * 1.2)
	result.merge({"star_tier":stars,"star_class":String(cls),"star_set":StarGearData.set_id(String(cls),stars),
		"level":100+stars,"name":StarGearData.item_name(slot,String(cls),stars),"class":String(cls)},true)
	result["set"] = StarGearData.set_id(String(cls),stars) if slot in ["weapon","armor","helm","boots"] else ""
	result["look"]=StarGearData.look_of(result)
	return result

## Each ★ milestone (50/100/150/200) grants 2 skill points once, by itself.
## Works on any profile dictionary, so loading an old save pays what it is owed.
static func grant_milestones(profile: Dictionary) -> int:
	if int(profile.get("level", 0)) < 100:
		return 0
	var stars := int(profile.get("paragon", {}).get("level", 0))
	if not profile.get("flags") is Dictionary:
		profile["flags"] = {}
	var granted := 0
	for tier in TIERS:
		var key := "star_reward_%d" % tier
		if stars >= tier and int(profile.flags.get(key, 0)) == 0:
			profile.flags[key] = 1
			profile["skill_points"] = int(profile.get("skill_points", 0)) + 2
			granted += 1
	return granted

## A random piece of this ★ tier's gear for the class (no wings).
static func random_item(cls: StringName, stars: int, rng: RandomNumberGenerator) -> Dictionary:
	return item(cls, stars, ItemData.SLOTS[rng.randi() % ItemData.SLOTS.size()], rng)

static func set_bonus_text(cls: String) -> String:
	return {"warrior":"4 ชิ้น: รับความเสียหายลด 10% และหลังรับการโจมตี สกิลถัดไปแรงขึ้น 20%",
		"archer":"4 ชิ้น: โจมตีเป้าหมายเดิม 5 ฮิต จะยิงแรงขึ้น 25% ในฮิตถัดไป",
		"lancer":"4 ชิ้น: สกิลหอกดาวฮิตที่ 3 เป็นต้นไปแรงขึ้น 15%",
		"mage":"4 ชิ้น: ใช้ MP ลด 12%",
		"priest":"4 ชิ้น: พลังฟื้นฟูเพิ่ม 20%",
		"summoner":"4 ชิ้น: อสูรอัญเชิญทำดาเมจเพิ่ม 15%",
		"defender":"4 ชิ้น: สกิลยั่วยุและสกิลทุบพื้นให้โล่ดูดซับ 5% ของ HP",
		"assassin":"4 ชิ้น: คริติคอลแรงขึ้น 25%"}.get(cls,"")

static func has_full_set(profile: Dictionary, cls: String) -> bool:
	var counts := {}
	for slot in ["weapon","armor","helm","boots"]:
		var piece: Variant=profile.get("equip",{}).get(slot)
		if not piece is Dictionary: continue
		if int(piece.get("star_tier",0))>0 and String(piece.get("star_class",""))==cls:
			var id:=String(piece.get("set",""))
			counts[id]=int(counts.get(id,0))+1
	return counts.values().has(4)
