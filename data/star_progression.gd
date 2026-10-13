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
			"level":[100,100],"music":&"forest" if i in [0,3] else &"field","sky":skies[i],"ground":Color("79a28b"),
			"fog":skies[i].lightened(0.15),"ambient":Color("c6d6f0"),"sun":Color("fff0ce"),"camps":camps,
			"boss":{"monster":monsters[6],"level":110+i*15,"respawn":110.0,"star":200 if i==3 else ENTRY[i]},
			"prev":&"void" if i==0 else REGIONS[i-1],"next":REGIONS[i+1] if i<3 else &"","ambience":&"water" if i==0 else &"wind"}
	return result

static func region_index(id: StringName) -> int:
	return REGIONS.find(id)

static func item(cls: StringName, stars: int, slot: String, rng: RandomNumberGenerator) -> Dictionary:
	if not TIERS.has(stars) or not ClassData.IDS.has(cls) or not ItemData.EQUIP_SLOTS.has(slot): return {}
	if slot=="wings": return StarWingData.item(String(cls),rng) if stars==100 else {}
	var result := ItemData.generate(100+stars,cls,rng,3,slot)
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
		"summoner":"4 ชิ้น: อสูรอัญเชิญทำดาเมจเพิ่ม 15%"}.get(cls,"")

static func has_full_set(profile: Dictionary, cls: String) -> bool:
	var counts := {}
	for slot in ["weapon","armor","helm","boots"]:
		var piece: Variant=profile.get("equip",{}).get(slot)
		if not piece is Dictionary: continue
		if int(piece.get("star_tier",0))>0 and String(piece.get("star_class",""))==cls:
			var id:=String(piece.get("set",""))
			counts[id]=int(counts.get(id,0))+1
	return counts.values().has(4)
