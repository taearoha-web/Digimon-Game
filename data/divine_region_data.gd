class_name DivineRegionData
extends RefCounted
## A fifth, post-story destination. The four star milestones and wing drop
## regions remain unchanged; this sanctuary is an equipment hunt at 200 stars.
const ID: StringName = &"lotus_sanctum"
const TITLE := "วิหารบัวดารา"
const MONSTERS := {
	&"lotus_sprite": {"name":"ภูตบัวประกายดาว", "model":"divine/LotusSprite", "height":1.7, "hover":0.35, "hp":1.7, "atk":1.9, "def":1.15, "speed":2.7, "aggro":true, "attack":"ranged", "color":Color("f8c6eb"), "behavior":"lotus_bolt", "exp":1.3, "gold":1.5},
	&"jade_qilin": {"name":"กิเลนหยกเทวะ", "model":"divine/JadeQilin", "height":2.6, "hp":2.4, "atk":1.8, "def":1.5, "speed":3.0, "aggro":true, "attack":"melee", "color":Color("89e9c5"), "behavior":"jade_charge", "exp":1.5, "gold":1.7},
	&"temple_guardian": {"name":"เทวรูปพิทักษ์วิหาร", "model":"divine/TempleGuardian", "height":3.0, "hp":5.0, "atk":2.3, "def":2.0, "speed":2.4, "aggro":true, "attack":"melee", "elite":true, "color":Color("ffdc91"), "behavior":"divine_slam", "exp":2.4, "gold":2.8},
	&"lotus_seraph": {"name":"ออเรเลีย เทพพิทักษ์บัวดารา", "model":"divine/LotusSeraph", "height":5.0, "hover":0.45, "hp":29.0, "atk":3.15, "def":2.4, "speed":2.6, "aggro":true, "attack":"ranged", "boss":true, "color":Color("ffe3b3"), "behavior":"lotus_judgment", "exp":3.0, "gold":4.0},
}

static func has_monster(id: StringName) -> bool:
	return MONSTERS.has(id)

static func monster(id: StringName) -> Dictionary:
	return MONSTERS.get(id, {}).duplicate(true)

static func zone() -> Dictionary:
	var positions := [Vector2(-23,20), Vector2(24,18), Vector2(-23,-10), Vector2(25,-9)]
	var encounters := [[&"lotus_sprite"], [&"jade_qilin"], [&"lotus_sprite", &"temple_guardian"], [&"jade_qilin", &"temple_guardian"]]
	var names := ["สวนบัวเรืองแสง", "ลานกิเลนหยก", "ศาลาพิทักษ์ตะวัน", "อุทยานเทวรูป"]
	var camps: Array = []
	for i in 4:
		camps.append({"name":names[i], "monsters":encounters[i], "levels":[158,166], "pos":positions[i], "radius":7.0, "count":4})
	return {"name":TITLE, "scene":"field", "theme":ID, "divine_region":true, "star":200, "gear_star":200,
		"level":[100,100], "music":&"title", "ambience":&"water", "sky":Color("746995"), "fog":Color("c3a8c4"),
		"ambient":Color("d9d7e9"), "sun":Color("ffefd9"), "ground":Color("aab7b7"), "camps":camps,
		"boss":{"monster":&"lotus_seraph", "level":175, "respawn":120.0, "star":200}, "prev":&"eclipse_realm", "next":&""}
