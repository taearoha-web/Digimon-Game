class_name HeavenMonsters
extends RefCounted
## The bestiary of ดินแดนเทวาลัย (HeavenRealmData): the guardians of the celestial
## temple above the clouds, from ★300 toward ★500. Existing CC0 Quaternius rigs
## (Ultimate Monsters, Animated Monster Pack) and the summoner's Wind King, re-dressed
## with new names, sizes and a white-gold / jade palette ("tint"), and a golden halo
## of light pearls (DeepMonsterArt's dressing in the "aura" colour; the elites wear its
## crown of spikes, the boss the Wind King's own summon aura).
##
## Ordinary monsters fight with MobAttack moves, the boss with BossAttack's: เสาแสงทอง
## (sun_pillars) and อัสนีสวรรค์ถล่ม (heavens_fall), taking turns from the start.
## Their health is TOUGH_HP times the design and the ordinary monsters' attack NORMAL_ATK
## times (as on เกาะลอยฟ้าเทพมังกร); MonsterData.ZONE_TUNING / LATE_HP add the field's
## own rows (HeavenRealmData.TUNING / LATE_HP).

const TOUGH_HP := 10.0
const NORMAL_ATK := 2.0

const MONSTERS := {
	# The lantern deva and the cloud hermit are sculpted in code ("folk": HeavenFolk,
	# HeavenFolkVisual); "model" is only their fallback rig.
	&"heaven_lantern": {"name": "เทวดาน้อยถือโคม", "folk": "deva", "model": "remaster/flying/Hywirl", "height": 2.2, "hover": 0.6, "hp": 2.1, "atk": 2.4, "def": 1.4, "speed": 3.0, "aggro": true, "attack": "ranged",
		"color": Color("ffe9a0"), "tint": Color(1.35, 1.2, 0.85), "aura": Color("ffe28a"), "behavior": "volley", "exp": 2.5, "gold": 3.2},
	# The young garuda and the kinnari are sculpted in code ("bird": HeavenBird,
	# HeavenBirdVisual); "model" is only their fallback rig.
	&"heaven_hound": {"name": "ครุฑน้อยเทวาลัย", "bird": "garuda", "model": "remaster/star/Wolf", "height": 2.6, "hp": 2.6, "atk": 2.4, "def": 1.8, "speed": 3.8, "aggro": true, "attack": "melee",
		"color": Color("ffb04a"), "tint": Color(1.45, 1.3, 1.0), "aura": Color("ffd77a"), "behavior": "pounce", "exp": 2.55, "gold": 3.3},
	&"golden_hamsa": {"name": "กินรี", "bird": "kinnari", "model": "remaster/flying/Pigeon", "height": 2.5, "hover": 0.7, "hp": 2.0, "atk": 2.6, "def": 1.3, "speed": 3.2, "aggro": true, "attack": "ranged",
		"color": Color("ffd25a"), "tint": Color(1.5, 1.2, 0.6), "aura": Color("ffcf5a"), "behavior": "beam", "exp": 2.5, "gold": 3.2},
	# The gate giants and the golden naga are sculpted in code ("yaksha": HeavenYaksha,
	# HeavenYakshaVisual; "naga": HeavenNaga, HeavenNagaVisual) and dress themselves (no
	# "aura" halo); "model" is only their fallback rig.
	&"jade_yaksha": {"name": "ยักษ์ทวารบาลหยก", "yaksha": "jade", "model": "remaster/big/Tribal", "height": 2.9, "hp": 2.8, "atk": 2.5, "def": 2.0, "speed": 2.9, "aggro": true, "attack": "melee",
		"color": Color("7ff0c4"), "behavior": "cleave", "exp": 2.6, "gold": 3.4},
	&"cloud_hermit": {"name": "พระฤๅษีนั่งเมฆ", "folk": "hermit", "model": "remaster/blob/Wizard", "height": 2.2, "hover": 0.4, "hp": 2.1, "atk": 2.7, "def": 1.3, "speed": 2.8, "aggro": true, "attack": "ranged",
		"color": Color("ffd66a"), "tint": Color(1.2, 1.2, 1.35), "aura": Color("ffe6a0"), "behavior": "mortar", "exp": 2.55, "gold": 3.3},
	&"heaven_gatekeeper": {"name": "ท้าวยักษ์เฝ้าทวารสวรรค์", "yaksha": "king", "model": "remaster/big/BlueDemon", "height": 3.9, "hp": 6.6, "atk": 3.2, "def": 2.7, "speed": 3.0, "aggro": true, "attack": "melee", "elite": true,
		"color": Color("ffd25a"), "behavior": "spin", "exp": 4.0, "gold": 4.8},
	&"celestial_naga": {"name": "พญานาคทองเทวาลัย", "naga": "gold", "model": "remaster/flying/Dragon_Evolved", "height": 4.1, "hover": 0.6, "hp": 7.0, "atk": 3.1, "def": 2.8, "speed": 3.2, "aggro": true, "attack": "ranged", "elite": true,
		"color": Color("ffd766"), "behavior": "mortar", "exp": 4.1, "gold": 4.8},
	# The field boss: the Wind King of the summoner's god skill grown to a giant in white
	# gold, his staff calling pillars of sunlight and the thunder of heaven (Skill2).
	&"heaven_monkey_king": {"name": "พญาวานรวายุ ผู้ท้าเทวาลัย", "model": "summon/WindKing", "height": 6.2, "hp": 46.0, "atk": 3.9, "def": 3.2, "speed": 3.1, "aggro": true, "attack": "melee", "boss": true,
		"color": Color("ffe08a"), "tint": Color(1.25, 1.15, 0.9), "aura": Color("ffe08a"), "legend": "wind_king",
		"behavior": "sun_pillars", "behavior2": "heavens_fall", "alternate": true, "exp": 5.4, "gold": 8.0},
}
const NORMALS: Array[StringName] = [&"heaven_lantern", &"heaven_hound", &"golden_hamsa", &"jade_yaksha", &"cloud_hermit"]
const ELITES: Array[StringName] = [&"heaven_gatekeeper", &"celestial_naga"]
const BOSS: StringName = &"heaven_monkey_king"


static func has_monster(id: StringName) -> bool:
	return MONSTERS.has(id)


static func monster(id: StringName) -> Dictionary:
	var m: Dictionary = MONSTERS.get(id, {}).duplicate(true)
	if not m.is_empty():
		m.hp = float(m.hp) * TOUGH_HP
		if NORMALS.has(id):
			m.atk = float(m.atk) * NORMAL_ATK
	return m
