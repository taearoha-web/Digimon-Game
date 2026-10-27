class_name StarGearData
extends RefCounted
## Four authored endgame collections. star_tier stores the actual unlock star
## (50/100/150/200), independently of the legacy equipment tier 0..9.

const TIERS: Array[int] = [50, 100, 150, 200]
const CLASSES: Array[String] = ["warrior", "archer", "lancer", "mage", "priest", "summoner", "defender", "assassin", "darklord", "bard"]
const ARMOR_SLOTS: Array[String] = ["armor", "helm", "boots", "ring", "amulet"]
const WEAPON_KIND := {"warrior": "sword", "archer": "bow", "lancer": "spear", "mage": "staff", "priest": "wand", "summoner": "lantern", "defender": "greatshield", "assassin": "dagger", "darklord": "scepter", "bard": "lute"}
const THEME_NAMES := ["อรุณพฤกษา", "ผลึกคราม", "ราชันนภา", "สุริยคราส"]
const CLASS_NAMES := {"warrior": "ราชสีห์", "archer": "นักล่าจันทรา", "lancer": "มังกร", "mage": "จอมอาคม", "priest": "เซราฟ", "summoner": "ราชันภูต", "defender": "ป้อมปราการ", "assassin": "เงาราตรี", "darklord": "ราชันอีกา", "bard": "คีตกวี"}
const OUTFITS := {"warrior": "knight", "archer": "ranger", "lancer": "knight", "mage": "mage", "priest": "mage", "summoner": "rogue", "defender": "knight", "assassin": "rogue", "darklord": "knight", "bard": "ranger"}
const WEAPON_NAMES := {
	"sword": ["ดาบเขี้ยวสิงห์อรุณ", "ดาบผลึกเจ็ดประกาย", "ดาบราชันเวหา", "ดาบจักรพรรดิคราส"],
	"bow": ["ธนูกิ่งพฤกษา", "ธนูปีกผลึก", "ธนูพิณนภา", "ธนูจันทราคราส"],
	"spear": ["หอกยอดพฤกษา", "หอกผลึกตรีศูล", "หอกปีกวายุ", "หอกพิพากษาคราส"],
	"staff": ["คทาดอกไม้อรุณ", "คทาปริซึมคราม", "คทาวงโคจรดารา", "คทาประตูสุริยคราส"],
	"wand": ["คทาบุปผาศรัทธา", "คทากางเขนผลึก", "คทาปีกเสราฟ", "คทารุ่งอรุณนิรันดร์"],
	"lantern": ["โคมดอกบัววิญญาณ", "โคมกรงผลึก", "โคมวิหารนภา", "โคมราชันคราส"],
	"greatshield": ["โล่ปราการพฤกษา", "โล่ป้อมผลึกคราม", "โล่ปราการนภา", "โล่ป้อมสุริยคราส"],
	"dagger": ["มีดคู่หนามพฤกษา", "มีดคู่ผลึกคราม", "มีดคู่ปีกนภา", "มีดคู่เขี้ยวคราส"],
	"scepter": ["คทาราชันพฤกษา", "คทาราชันผลึกคราม", "คทาราชันนภา", "คทาจักรพรรดิคราส"],
	"lute": ["พิณพฤกษาอรุณ", "พิณผลึกคราม", "พิณราชันนภา", "พิณสุริยคราส"],
}
const SET_INTENT := {
	"warrior": "เกราะแนวหน้า เสริมการฟันหลังป้องกัน",
	"archer": "ความแม่นยำ เสริมการยิงเป้าหมายต่อเนื่อง",
	"lancer": "ทะลวงแนวรบ เสริมการแทงหลายเป้าหมาย",
	"mage": "ประสานธาตุ เสริมพลังเวทและมานา",
	"priest": "พิทักษ์และฟื้นฟู เสริมการช่วยเหลือฝ่ายเรา",
	"summoner": "พันธสัญญาภูต เสริมผู้ร่ายและอสูร",
	"defender": "กำแพงหน้าทัพ เสริมการคุมฝูงและป้องกันทีม",
	"assassin": "เงาสังหาร เสริมความเร็วและคริติคอลรุนแรง",
	"darklord": "ราชันผู้บัญชาการ เสริมพลังทีมและอีกาคู่ใจ",
	"bard": "บทเพลงหนุนทีม เสริมพลังเพลงและการกดดันศัตรู",
}


static func index(stars: int) -> int:
	return clampi(int(stars / 50) - 1, 0, 3)


static func is_star(item: Variant) -> bool:
	return item is Dictionary and int(item.get("star_tier", 0)) in TIERS


static func item_tier(item: Dictionary) -> int:
	return int(item.get("star_tier", 0)) if is_star(item) else 0


static func item_class(item: Dictionary, fallback := "warrior") -> String:
	var cls := String(item.get("star_class", item.get("class", fallback)))
	return cls if cls in CLASSES else fallback


static func set_id(class_id: String, stars: int) -> String:
	return "star_%s_%d" % [class_id, TIERS[index(stars)]]


static func set_label(class_id: String, stars: int) -> String:
	return "ชุด%s%s" % [CLASS_NAMES.get(class_id, CLASS_NAMES.warrior), THEME_NAMES[index(stars)]]


static func weapon_name(kind: String, stars: int) -> String:
	return String(WEAPON_NAMES.get(kind, WEAPON_NAMES.sword)[index(stars)])


static func item_name(slot: String, class_id: String, stars: int) -> String:
	if slot == "weapon":
		return weapon_name(WEAPON_KIND.get(class_id, "sword"), stars)
	if slot == "wings":
		return StarWingData.item_name(class_id)
	var prefix := {"armor": "เกราะ", "helm": "มงกุฎ", "boots": "รองเท้า", "ring": "แหวน", "amulet": "สร้อย"}
	return "%s%s%s" % [prefix.get(slot, "เครื่องประดับ"), CLASS_NAMES.get(class_id, CLASS_NAMES.warrior), THEME_NAMES[index(stars)]]


static func look_of(item: Dictionary) -> String:
	if DivineGearData.is_item(item): return DivineGearData.look_of(item)
	var stars := item_tier(item)
	if stars == 0:
		return ""
	var slot := String(item.get("slot", "weapon"))
	if slot == "weapon":
		return "star_%s_%d" % [String(item.get("base", WEAPON_KIND[item_class(item)])), stars]
	if slot == "wings":
		return StarWingData.look(item_class(item))
	return "star_%s_%s_%d" % [slot, item_class(item), stars]


static func kind_from_look(look: String) -> String:
	var parts := look.split("_")
	if (look.begins_with("star_") or look.begins_with("divine_")) and parts.size() >= 3:
		return parts[1]
	return look.rsplit("_", true, 1)[0]


static func stars_from_look(look: String) -> int:
	return int(look.rsplit("_", true, 1)[-1])


static func palette(stars: int, class_id := "warrior") -> Dictionary:
	var palettes := [
		{"metal": Color("ebba64"), "edge": Color("fff2c8"), "cloth": Color("286658"), "gem": Color("9affe0"), "dark": Color("234339")},
		{"metal": Color("b1d6f4"), "edge": Color("efffff"), "cloth": Color("335085"), "gem": Color("65e5ff"), "dark": Color("263555")},
		{"metal": Color("efc478"), "edge": Color("fff8e6"), "cloth": Color("426da4"), "gem": Color("91e6ff"), "dark": Color("283959")},
		{"metal": Color("d8a454"), "edge": Color("ffedbe"), "cloth": Color("382749"), "gem": Color("e4a1ff"), "dark": Color("221f35")},
	]
	var p: Dictionary = palettes[index(stars)].duplicate()
	var accents := {"warrior": Color("d06b49"), "archer": Color("49886d"), "lancer": Color("386781"), "mage": Color("7253a4"), "priest": Color("e3d3a3"), "summoner": Color("487887"), "defender": Color("4a6f9a"), "assassin": Color("5a3a8a"), "darklord": Color("8a2232"), "bard": Color("a8306a")}
	p["cloth"] = (p.cloth as Color).lerp(accents.get(class_id, accents.warrior), 0.42)
	return p


static func catalogue() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for stars in TIERS:
		for cls in CLASSES:
			for slot in ["weapon", "armor", "helm", "boots", "ring", "amulet"]:
				var item := {"kind": "equip", "slot": slot, "class": cls, "star_class": cls, "star_tier": stars, "star_set": set_id(cls, stars), "name": item_name(slot, cls, stars)}
				item["base"] = WEAPON_KIND[cls] if slot == "weapon" else slot
				item["look"] = look_of(item)
				out.append(item)
	for cls in CLASSES:
		out.append({"kind":"equip","slot":"wings","base":"wings","class":cls,"star_class":cls,"star_tier":100,"name":StarWingData.item_name(cls),"look":StarWingData.look(cls)})
	return out
