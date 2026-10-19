class_name DivineRegionData
extends RefCounted
## A fifth, post-story destination. The four star milestones and wing drop
## regions remain unchanged; this sanctuary is an equipment hunt at 200 stars.
const ID: StringName = &"lotus_sanctum"
const TITLE := "วิหารบัวดารา"
## Quaternius CC0 models (Ultimate Monsters), tinted for the sanctuary.
## Health is ten times the original design, like the star regions from 50 stars.
const TOUGH_HP := 10.0
const MONSTERS := {
	&"lotus_sprite": {"name":"ภูตบัวประกายดาว", "model":"flying/Ghost", "height":1.8, "hover":0.9, "hp":1.7, "atk":1.9, "def":1.15, "speed":2.7, "aggro":true, "attack":"ranged", "color":Color("f8c6eb"), "tint":Color(1.25,0.95,1.15), "behavior":"lotus_bolt", "exp":1.3, "gold":1.5},
	&"jade_qilin": {"name":"มังกรหยกเทวะ", "model":"cute/YellowDragon", "height":2.4, "hp":2.4, "atk":1.8, "def":1.5, "speed":3.0, "aggro":true, "attack":"melee", "color":Color("89e9c5"), "tint":Color(0.75,1.2,0.95), "behavior":"jade_charge", "exp":1.5, "gold":1.7},
	&"lotus_frog": {"name":"กบทองบัวทิพย์", "model":"big/Frog", "height":1.8, "hp":2.0, "atk":1.7, "def":1.35, "speed":2.6, "aggro":true, "attack":"melee", "color":Color("ffd98a"), "tint":Color(1.15,1.05,0.8), "behavior":"jade_charge", "exp":1.35, "gold":1.5},
	&"jade_monk": {"name":"นักพรตวานรหยก", "model":"big/Monkroose", "height":2.2, "hp":2.2, "atk":1.85, "def":1.45, "speed":2.8, "aggro":true, "attack":"melee", "color":Color("8fe3c0"), "tint":Color(0.8,1.15,0.95), "behavior":"jade_charge", "exp":1.45, "gold":1.6},
	&"gold_bee": {"name":"ผึ้งเกสรทองคำ", "model":"flying/Armabee_Evolved", "height":1.7, "hover":1.1, "hp":1.6, "atk":2.0, "def":1.1, "speed":3.0, "aggro":true, "attack":"ranged", "color":Color("ffd98a"), "tint":Color(1.25,1.1,0.8), "behavior":"lotus_bolt", "exp":1.35, "gold":1.6},
	&"temple_guardian": {"name":"โกเลมพิทักษ์วิหาร", "model":"flying/Goleling_Evolved", "height":3.0, "hover":0.4, "hp":5.0, "atk":2.3, "def":2.0, "speed":2.4, "aggro":true, "attack":"melee", "elite":true, "color":Color("ffdc91"), "tint":Color(1.3,1.15,0.8), "behavior":"divine_slam", "exp":2.4, "gold":2.8},
	&"lotus_seraph": {"name":"ออเรเลีย ราชันปีกบัวดารา", "model":"flying/Alpaking_Evolved", "height":5.0, "hover":0.6, "hp":29.0, "atk":3.15, "def":2.4, "speed":2.6, "aggro":true, "attack":"ranged", "boss":true, "color":Color("ffe3b3"), "tint":Color(1.3,1.2,1.05), "behavior":"lotus_judgment", "exp":3.0, "gold":4.0},
}

static func has_monster(id: StringName) -> bool:
	return MONSTERS.has(id)

static func monster(id: StringName) -> Dictionary:
	var m: Dictionary = MONSTERS.get(id, {}).duplicate(true)
	if not m.is_empty():
		m.hp = float(m.hp) * TOUGH_HP
	return m

static func zone() -> Dictionary:
	# Five farm camps of ten, one kind each like the older fields; the last two
	# also hold a temple golem now and then.
	var positions: Array = DivineRegionArt.layout().camp_positions
	var normals := [&"lotus_sprite", &"jade_qilin", &"lotus_frog", &"jade_monk", &"gold_bee"]
	var names := ["สวนบัวเรืองแสง", "ลานมังกรหยก", "สระกบทองบัวทิพย์", "ศาลานักพรตหยก", "อุทยานเกสรทอง"]
	var camps: Array = []
	for i in 5:
		var ids: Array = [normals[i]]
		if i >= 3: ids = [normals[i], normals[i], normals[i], &"temple_guardian"]
		camps.append({"name":names[i], "monsters":ids, "levels":[158,166], "pos":positions[i], "radius":9.0, "count":10})
	return {"name":TITLE, "scene":"field", "theme":ID, "divine_region":true, "star":200, "gear_star":200,
		"level":[100,100], "music":ID, "ambience":&"water", "sky":Color("746995"), "fog":Color("c3a8c4"),
		"ambient":Color("d9d7e9"), "sun":Color("ffefd9"), "ground":Color("aab7b7"), "camps":camps,
		"boss":{"monster":&"lotus_seraph", "level":175, "respawn":120.0, "star":200}, "prev":&"eclipse_realm", "next":&""}
