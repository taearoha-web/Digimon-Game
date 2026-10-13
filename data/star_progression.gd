class_name StarProgression
extends RefCounted
## Persistent rewards use numeric flags, already supported by old/cloud saves.
const REGIONS: Array[StringName] = [&"dawn_forest", &"crystal_valley", &"sky_citadel", &"eclipse_realm"]
const TITLES := ["ป่าแสงอรุณ", "หุบเขาผลึกคราม", "นครลอยฟ้า", "อาณาจักรสุริยคราส"]
const MATERIALS := ["เกสรแสงอรุณ", "ผลึกคราม", "โลหะเมฆา", "เศษสุริยคราส"]
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

static func material_count(stars: int, core := false) -> int:
	return int(Game.profile.get("flags",{}).get("star_%s_%d" % ["core" if core else "mat",stars],0))

static func award_material(stars: int, count: int, core := false) -> void:
	var key := "star_%s_%d" % ["core" if core else "mat", stars]
	Game.profile.flags[key] = material_count(stars,core) + maxi(count,0)
	Game.mark_dirty()

static func item(cls: StringName, stars: int, slot: String, rng: RandomNumberGenerator) -> Dictionary:
	if not TIERS.has(stars) or not ClassData.IDS.has(cls) or not ItemData.EQUIP_SLOTS.has(slot): return {}
	if slot=="wings": return StarWingData.item(String(cls),rng) if stars==100 else {}
	var result := ItemData.generate(100+stars,cls,rng,3,slot)
	result.merge({"star_tier":stars,"star_class":String(cls),"star_set":StarGearData.set_id(String(cls),stars),
		"level":100+stars,"name":StarGearData.item_name(slot,String(cls),stars),"class":String(cls)},true)
	result["set"] = StarGearData.set_id(String(cls),stars) if slot in ["weapon","armor","helm","boots"] else ""
	result["look"]=StarGearData.look_of(result)
	return result

static func cost(stars: int, slot: String) -> Dictionary:
	if slot=="wings": return {}
	return {"material":50 if slot=="weapon" else 35,
		"core":2 if slot=="weapon" else 1,"gold":10000+stars*400}

static func craft_problem(stars: int, slot: String) -> String:
	if slot=="wings": return "ปีก 100 ดาวดรอปจากมอนสเตอร์ใน 4 ดินแดนใหม่เท่านั้น"
	if not TIERS.has(stars) or not ItemData.EQUIP_SLOTS.has(slot): return "สูตรไม่ถูกต้อง"
	if int(Game.profile.level)<100 or int(Game.paragon().level)<stars: return "ต้องเลเวล 100 และดาว %d" % stars
	if Game.inventory_free()<=0: return "กระเป๋าเต็ม"
	var price := cost(stars,slot)
	if material_count(stars)<int(price.material) or material_count(stars,true)<int(price.core): return "วัตถุดิบหรือแก่นบอสไม่พอ"
	if int(Game.profile.gold)<int(price.gold): return "เหรียญไม่พอ"
	return ""

static func craft(stars: int, slot: String) -> bool:
	var problem := craft_problem(stars,slot)
	if not problem.is_empty():
		Game.say(problem,&"warning")
		return false
	var result := item(Game.class_id(),stars,slot,Game.rng)
	if result.is_empty(): return false
	var price := cost(stars,slot)
	# All preconditions precede mutation; no signal or await interrupts deduction.
	Game.profile.flags["star_mat_%d" % stars]=material_count(stars)-int(price.material)
	Game.profile.flags["star_core_%d" % stars]=material_count(stars,true)-int(price.core)
	Game.profile.gold-=int(price.gold)
	Game.profile.inv.append(result)
	Game.mark_dirty()
	Game.gold_changed.emit(Game.profile.gold)
	Game.inventory_changed.emit()
	Game.say("สร้าง %s สำเร็จ" % result.name,&"success")
	Game.save()
	return true

static func claim(stars: int) -> bool:
	var key := "star_reward_%d" % stars
	if not TIERS.has(stars) or int(Game.profile.level)<100 or int(Game.paragon().level)<stars or int(Game.profile.flags.get(key,0))!=0: return false
	Game.profile.flags[key]=1
	Game.profile.skill_points+=2
	award_material(stars,25)
	Game.profile_changed.emit()
	Game.save()
	return true

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
