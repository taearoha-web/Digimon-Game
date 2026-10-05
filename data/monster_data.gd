class_name MonsterData
extends RefCounted
## Monster templates (Quaternius models). Stats scale with level in [method stats_for].
##
##   model  path under assets/models/monsters
##   height target model height in metres
##   hp / atk / def  multipliers on the level curve
##   speed  walk speed (m/s); chase speed is faster
##   aggro  true = attacks on sight, false = fights back when hit
##   attack "melee" or "ranged"; color = projectile/ring colour
##   boss   boss monsters are bigger, tougher and hit harder

const MONSTERS := {
	&"pink_slime": {"name": "สไลม์ชมพู", "model": "blob/PinkBlob", "height": 1.0, "hp": 0.8, "atk": 0.8, "def": 0.8, "speed": 1.8, "aggro": false, "attack": "melee"},
	&"green_slime": {"name": "สไลม์เขียว", "model": "blob/GreenBlob", "height": 1.1, "hp": 1.0, "atk": 0.9, "def": 0.9, "speed": 1.9, "aggro": false, "attack": "melee"},
	&"wild_chicken": {"name": "ไก่ป่าจอมเกรี้ยวกราด", "model": "blob/Chicken", "height": 1.0, "hp": 0.9, "atk": 1.0, "def": 0.8, "speed": 2.6, "aggro": true, "attack": "melee"},
	&"yellow_frog": {"name": "กบพิษสีเหลือง", "model": "big/Frog", "height": 1.2, "hp": 1.1, "atk": 1.0, "def": 1.0, "speed": 2.2, "aggro": false, "attack": "melee"},
	&"cactus_hat": {"name": "กระบองเพชรหมวกใหญ่", "model": "blob/Cactoro", "height": 1.3, "hp": 1.2, "atk": 1.1, "def": 1.2, "speed": 1.8, "aggro": true, "attack": "ranged", "color": Color("6fe36b")},
	&"mush_baby": {"name": "เห็ดน้อยจอมซน", "model": "blob/Mushnub", "height": 1.2, "hp": 1.0, "atk": 1.0, "def": 1.0, "speed": 1.9, "aggro": false, "attack": "melee"},
	&"mush_king": {"name": "ราชาเห็ดยักษ์", "model": "big/MushroomKing", "height": 2.9, "hp": 9.0, "atk": 1.7, "def": 1.6, "speed": 2.0, "aggro": true, "attack": "melee", "boss": true},
	&"forest_orc": {"name": "ออร์คป่า", "model": "big/Orc", "height": 1.8, "hp": 1.3, "atk": 1.2, "def": 1.2, "speed": 2.3, "aggro": true, "attack": "melee"},
	&"skull_orc": {"name": "ออร์คกะโหลก", "model": "big/Orc_Skull", "height": 1.9, "hp": 1.5, "atk": 1.3, "def": 1.3, "speed": 2.3, "aggro": true, "attack": "melee"},
	&"shadow_ninja": {"name": "นินจาเงา", "model": "big/Ninja", "height": 1.7, "hp": 1.0, "atk": 1.5, "def": 1.0, "speed": 3.2, "aggro": true, "attack": "melee"},
	&"poison_bee": {"name": "ผึ้งพิษ", "model": "flying/Armabee", "height": 1.0, "hp": 0.9, "atk": 1.1, "def": 0.9, "speed": 2.8, "aggro": true, "attack": "ranged", "hover": 1.2, "color": Color("c9e84a")},
	&"ghost": {"name": "ผีเงาม่วง", "model": "flying/Ghost", "height": 1.5, "hp": 1.1, "atk": 1.3, "def": 0.9, "speed": 2.4, "aggro": true, "attack": "ranged", "hover": 1.0, "color": Color("b08aff")},
	&"fire_dragon": {"name": "มังกรเพลิงผู้พิทักษ์", "model": "flying/Dragon_Evolved", "height": 3.2, "hp": 11.0, "atk": 1.9, "def": 1.7, "speed": 2.6, "aggro": true, "attack": "ranged", "boss": true, "hover": 0.8, "color": Color("ff6a2a")},
}


static func get_monster(id: StringName) -> Dictionary:
	return MONSTERS.get(id, MONSTERS[&"pink_slime"])


## Level curve shared by every monster; the template multiplies it.
static func stats_for(id: StringName, level: int) -> Dictionary:
	var m := get_monster(id)
	var boss := bool(m.get("boss", false))
	return {
		"hp": int(round((38.0 + level * level * 3.0 + level * 26.0) * float(m.hp))),
		"atk": int(round((5.0 + level * 3.1) * float(m.atk))),
		"def": int(round((1.0 + level * 1.5) * float(m.def))),
		"exp": int(round((10.0 + level * 9.0) * (8.0 if boss else 1.0))),
		"gold": int(round((3.0 + level * 3.0) * (10.0 if boss else 1.0))),
	}
