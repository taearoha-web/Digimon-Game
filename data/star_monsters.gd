class_name StarMonsters
extends RefCounted
## Star-region bestiary. Dawn forest uses CC0 Quaternius cartoon enemies
## (Ultimate Platformer Pack, Animated Monster Pack); later regions use the
## licensed animals/skeletons listed in assets/vendor/star_monsters/.
## Lists are ordered: four normal enemies, two elites, one regional boss, then
## a fifth normal enemy for the fifth farm camp.
## Source provenance and closed SHA-256 roster: assets/vendor/star_monsters/.

const REGIONS := {
	&"dawn_forest": [&"dawn_fox", &"dawn_deer", &"dawn_stag", &"dawn_alpaca", &"dawn_thornhart", &"dawn_spirit_fox", &"dawn_ancient_stag", &"dawn_bunny"],
	&"crystal_valley": [&"crystal_husky", &"crystal_wolf", &"crystal_bull", &"crystal_alpaca", &"crystal_fang", &"crystal_behemoth", &"crystal_horn_king", &"crystal_yeti"],
	&"sky_citadel": [&"sky_pegasus", &"sky_cloud_alpaca", &"sky_warden", &"sky_oracle", &"sky_storm_pegasus", &"sky_high_warden", &"sky_celestial_king", &"sky_wind_spirit"],
	&"eclipse_realm": [&"eclipse_minion", &"eclipse_rogue", &"eclipse_mage", &"eclipse_warrior", &"eclipse_reaper", &"eclipse_dreadknight", &"eclipse_sovereign", &"eclipse_wraith"],
}
const MONSTERS := {
	&"dawn_fox": {"name":"ปูกลีบอรุณ", "model":"dawn/Crab", "height":1.5, "hp":1.1, "atk":1.05, "def":0.9, "speed":3.1, "aggro":true, "attack":"melee", "region":"dawn_forest", "min_star":1, "decor_head":"Head3", "decor":"petals", "color":Color("ff9ab4"), "behavior":"pounce"},
	&"dawn_deer": {"name":"ภูตเขาใบไม้", "model":"dawn/Enemy", "height":1.7, "hp":1.2, "atk":1.0, "def":1.05, "speed":2.7, "aggro":false, "attack":"melee", "region":"dawn_forest", "min_star":1, "decor_head":"Head3", "decor":"leaves", "color":Color("9be070"), "behavior":"headbutt"},
	&"dawn_stag": {"name":"ค้างคาวรุ่งอรุณ", "model":"dawn/Bat", "height":2.1, "hover":1.0, "hp":1.45, "atk":1.2, "def":1.1, "speed":2.6, "aggro":true, "attack":"melee", "region":"dawn_forest", "min_star":5, "decor_lift":0.6, "decor":"leaves", "color":Color("ffb08a"), "behavior":"charge"},
	&"dawn_alpaca": {"name":"ผึ้งเกสรอรุณ", "model":"dawn/Bee", "height":1.6, "hover":1.1, "hp":1.25, "atk":1.15, "def":1.0, "speed":2.3, "aggro":false, "attack":"ranged", "region":"dawn_forest", "min_star":5, "decor_head":"Head3", "decor":"flower", "color":Color("ffd860"), "behavior":"pollen"},
	&"dawn_thornhart": {"name":"กะโหลกหนามพฤกษา", "model":"dawn/Skull", "height":2.6, "hp":3.2, "atk":1.6, "def":1.5, "speed":2.8, "aggro":true, "attack":"melee", "region":"dawn_forest", "min_star":20, "elite":true, "decor_head":"Head3", "decor_torso":"Body", "decor":"thorn", "color":Color("b8f060"), "behavior":"charge"},
	&"dawn_spirit_fox": {"name":"สไลม์วิญญาณอรุณ", "model":"dawn/Slime", "height":2.2, "hp":2.7, "atk":1.8, "def":1.25, "speed":3.4, "aggro":true, "attack":"ranged", "region":"dawn_forest", "min_star":25, "elite":true, "decor_lift":0.9, "decor_torso":"Body", "decor":"spirit", "color":Color("ffb040"), "behavior":"pollen"},
	&"dawn_ancient_stag": {"name":"อรุณศิลา ราชันมังกรพฤกษา", "model":"boss/ForestDragonKing", "height":4.8, "hp":17.0, "atk":2.3, "def":1.8, "speed":2.8, "aggro":true, "attack":"melee", "region":"dawn_forest", "min_star":40, "boss":true, "color":Color("e1c77c"), "behavior":"root_ring", "special2":"stone_thorns"},
	&"crystal_husky": {"name":"ฮัสกี้ผลึกหิมะ", "model":"star/Husky", "height":1.9, "hp":1.2, "atk":1.2, "def":1.0, "speed":3.2, "aggro":true, "attack":"melee", "region":"crystal_valley", "min_star":50, "color":Color("a9eaff"), "behavior":"pounce"},
	&"crystal_wolf": {"name":"หมาป่าเขี้ยวคราม", "model":"star/Wolf", "height":2.1, "hp":1.3, "atk":1.4, "def":1.05, "speed":3.4, "aggro":true, "attack":"melee", "region":"crystal_valley", "min_star":50, "color":Color("8dc5ff"), "behavior":"pounce"},
	&"crystal_bull": {"name":"กระทิงเกราะผลึก", "model":"star/Bull", "height":2.7, "hp":1.9, "atk":1.3, "def":1.6, "speed":2.2, "aggro":true, "attack":"melee", "region":"crystal_valley", "min_star":55, "color":Color("b6b4ff"), "behavior":"charge"},
	&"crystal_alpaca": {"name":"อัลปาก้าหมอกแก้ว", "model":"remaster/star/Alpaca_crystal_alpaca", "height":2.1, "hp":1.25, "atk":1.45, "def":1.1, "speed":2.4, "aggro":true, "attack":"ranged", "region":"crystal_valley", "min_star":55, "color":Color("c6f6ff"), "behavior":"ice_bolt"},
	&"crystal_fang": {"name":"จ่าฝูงเขี้ยวเพชร", "model":"remaster/star/Wolf_crystal_fang", "height":2.9, "hp":3.1, "atk":1.9, "def":1.4, "speed":3.5, "aggro":true, "attack":"melee", "region":"crystal_valley", "min_star":70, "elite":true, "color":Color("83ddff"), "behavior":"pounce"},
	&"crystal_behemoth": {"name":"เบฮีมอธเขาผลึก", "model":"remaster/star/Bull_crystal_behemoth", "height":3.5, "hp":4.0, "atk":1.8, "def":1.8, "speed":2.4, "aggro":true, "attack":"melee", "region":"crystal_valley", "min_star":75, "elite":true, "color":Color("af9bff"), "behavior":"charge"},
	&"crystal_horn_king": {"name":"ไครโอฮอร์น ราชันผลึกคราม", "model":"boss/CrystalHornKing", "height":7.0, "hp":19.0, "atk":2.5, "def":2.1, "speed":2.4, "aggro":true, "attack":"melee", "region":"crystal_valley", "min_star":90, "boss":true, "decor":"crystal_king", "color":Color("9deaff"), "behavior":"crystal_fault", "special2":"frost_crown"},
	&"sky_pegasus": {"name":"เพกาซัสปีกอรุณ", "model":"remaster/star/Horse_White_sky_pegasus", "height":2.6, "hp":1.3, "atk":1.25, "def":1.1, "speed":3.1, "aggro":true, "attack":"melee", "region":"sky_citadel", "min_star":100, "decor":"baked", "color":Color("ffdf91"), "behavior":"charge"},
	&"sky_cloud_alpaca": {"name":"แกะปุยเมฆ", "model":"remaster/blob/Dog_sky_cloud_alpaca", "height":1.7, "hp":1.3, "atk":1.5, "def":1.0, "speed":2.5, "aggro":true, "attack":"ranged", "region":"sky_citadel", "min_star":100, "decor":"baked", "color":Color("d7edff"), "behavior":"wind_bolt", "hover":0.5},
	&"sky_warden": {"name":"ผู้พิทักษ์วิหารฟ้า", "model":"remaster/star/Skeleton_Warrior_sky_warden", "height":2.2, "hp":1.8, "atk":1.35, "def":1.5, "speed":2.6, "aggro":true, "attack":"melee", "region":"sky_citadel", "min_star":105, "decor":"baked", "weapon":"sword_3", "color":Color("ffe1a0"), "behavior":"cleave"},
	&"sky_oracle": {"name":"ผู้พยากรณ์แห่งเมฆา", "model":"remaster/star/Skeleton_Mage_sky_oracle", "height":2.1, "hp":1.25, "atk":1.65, "def":1.0, "speed":2.4, "aggro":true, "attack":"ranged", "region":"sky_citadel", "min_star":105, "decor":"baked", "weapon":"staff_7", "color":Color("a9d9ff"), "behavior":"wind_bolt"},
	&"sky_storm_pegasus": {"name":"เพกาซัสพายุทอง", "model":"remaster/star/Horse_White_sky_storm_pegasus", "height":3.4, "hp":3.4, "atk":1.9, "def":1.45, "speed":3.4, "aggro":true, "attack":"melee", "region":"sky_citadel", "min_star":120, "elite":true, "decor":"baked", "color":Color("ffd16e"), "behavior":"charge"},
	&"sky_high_warden": {"name":"แม่ทัพปีกสุริยัน", "model":"remaster/star/Skeleton_Warrior_sky_high_warden", "height":2.8, "hp":3.7, "atk":2.0, "def":1.75, "speed":2.8, "aggro":true, "attack":"melee", "region":"sky_citadel", "min_star":125, "elite":true, "decor":"baked", "weapon":"sword_7", "color":Color("ffe9a9"), "behavior":"cleave"},
	&"sky_celestial_king": {"name":"เอเธอเรียน ราชันปีกสวรรค์", "model":"boss/SunWingKing", "height":5.6, "hp":21.0, "atk":2.6, "def":1.9, "speed":3.1, "aggro":true, "attack":"ranged", "region":"sky_citadel", "min_star":140, "boss":true, "decor":"sky_king", "color":Color("ffe8a3"), "behavior":"sun_lances", "special2":"radiant_wings"},
	&"eclipse_minion": {"name":"ทหารกระดูกคราส", "model":"remaster/star/Skeleton_Minion_eclipse_minion", "height":1.8, "hp":1.35, "atk":1.35, "def":1.2, "speed":2.7, "aggro":true, "attack":"melee", "region":"eclipse_realm", "min_star":150, "decor":"baked", "weapon":"sword_1", "color":Color("c599ff"), "behavior":"cleave"},
	&"eclipse_rogue": {"name":"เงามีดราตรี", "model":"remaster/star/Skeleton_Rogue_eclipse_rogue", "height":1.9, "hp":1.2, "atk":1.7, "def":1.0, "speed":3.5, "aggro":true, "attack":"melee", "region":"eclipse_realm", "min_star":150, "decor":"baked", "weapon":"dagger_6", "offhand":"dagger_6", "color":Color("dc9cef"), "behavior":"pounce"},
	&"eclipse_mage": {"name":"จอมเวทจันทร์ดับ", "model":"remaster/star/Skeleton_Mage_eclipse_mage", "height":2.1, "hp":1.2, "atk":1.8, "def":1.05, "speed":2.5, "aggro":true, "attack":"ranged", "region":"eclipse_realm", "min_star":155, "decor":"baked", "weapon":"staff_6", "color":Color("a789ed"), "behavior":"void_bolt"},
	&"eclipse_warrior": {"name":"อัศวินเกราะราตรี", "model":"remaster/star/Skeleton_Warrior_eclipse_warrior", "height":2.3, "hp":2.0, "atk":1.5, "def":1.7, "speed":2.6, "aggro":true, "attack":"melee", "region":"eclipse_realm", "min_star":155, "decor":"baked", "weapon":"sword_6", "color":Color("bfa5df"), "behavior":"cleave"},
	&"eclipse_reaper": {"name":"ผู้เก็บเกี่ยวแสงดาว", "model":"remaster/star/Skeleton_Mage_eclipse_reaper", "height":2.8, "hp":3.2, "atk":2.2, "def":1.4, "speed":2.7, "aggro":true, "attack":"ranged", "region":"eclipse_realm", "min_star":170, "elite":true, "decor":"baked", "color":Color("d59dff"), "behavior":"void_bolt"},
	&"eclipse_dreadknight": {"name":"ขุนพลเกราะคราส", "model":"remaster/star/Skeleton_Warrior_eclipse_dreadknight", "height":3.1, "hp":4.3, "atk":2.0, "def":1.9, "speed":2.7, "aggro":true, "attack":"melee", "region":"eclipse_realm", "min_star":175, "elite":true, "decor":"baked", "weapon":"sword_9", "color":Color("ae91d9"), "behavior":"cleave"},
	&"eclipse_sovereign": {"name":"น็อกซ์ออเรล ราชันสุริยคราส", "model":"boss/EclipseKnightKing", "height":5.2, "hp":25.0, "atk":2.9, "def":2.2, "speed":2.8, "aggro":true, "attack":"melee", "region":"eclipse_realm", "min_star":200, "boss":true, "final_boss":true, "decor":"eclipse_king", "color":Color("eac28a"), "behavior":"eclipse_crown", "special2":"eclipse_cleave"},
	&"dawn_bunny": {"name":"กระต่ายหมัดอรุณ", "model":"dawn/Bunny", "height":1.8, "hp":1.3, "atk":1.15, "def":1.05, "speed":3.0, "aggro":true, "attack":"melee", "region":"dawn_forest", "min_star":10, "decor_lift":1.6, "decor":"leaves", "color":Color("8fd4ff"), "behavior":"pounce"},
	&"crystal_yeti": {"name":"เยติผลึกน้ำแข็ง", "model":"remaster/big/Yeti_crystal_yeti", "height":2.5, "hp":1.5, "atk":1.35, "def":1.4, "speed":2.4, "aggro":true, "attack":"melee", "region":"crystal_valley", "min_star":60, "decor":"crystal", "color":Color("9fe3ff"), "tint":Color(0.8,1.0,1.25), "behavior":"cleave"},
	&"sky_wind_spirit": {"name":"ภูตวายุนภา", "model":"remaster/flying/Hywirl_sky_wind_spirit", "height":1.9, "hover":1.0, "hp":1.2, "atk":1.6, "def":1.0, "speed":2.9, "aggro":true, "attack":"ranged", "region":"sky_citadel", "min_star":110, "decor":"sky_guard", "color":Color("bfe6ff"), "tint":Color(1.1,1.08,1.2), "behavior":"wind_bolt"},
	&"eclipse_wraith": {"name":"วิญญาณกะโหลกคราส", "model":"remaster/flying/Ghost_Skull_eclipse_wraith", "height":2.0, "hover":1.0, "hp":1.25, "atk":1.75, "def":1.0, "speed":2.8, "aggro":true, "attack":"ranged", "region":"eclipse_realm", "min_star":160, "decor":"eclipse_sigil", "color":Color("c58aff"), "tint":Color(0.85,0.7,1.15), "behavior":"void_bolt"},
}

## Every star region monster has ten times the health it was designed with.
const TOUGH_REGIONS := [&"dawn_forest", &"crystal_valley", &"sky_citadel", &"eclipse_realm"]
const TOUGH_HP := 10.0

static func ids_for(zone_id: StringName) -> Array:
	return REGIONS.get(zone_id, []).duplicate()

static func has(id: StringName) -> bool:
	return MONSTERS.has(id)

static func get_monster(id: StringName) -> Dictionary:
	var m: Dictionary = MONSTERS.get(id, {}).duplicate(true)
	if StringName(m.get("region", "")) in TOUGH_REGIONS:
		m.hp = float(m.hp) * TOUGH_HP
	return m
