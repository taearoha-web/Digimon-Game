class_name AscendSkillData
extends RefCounted
## The two skills of the Ascension (JobData.ASCEND_ADV, "เปลี่ยนอาชีพขั้นที่ 6"): per class an
## ultimate above its ★300 god skill and a grand buff. Both are star skills (StarSkillSequence
## plays them) at ★500 (JobData.ASCEND_STARS) marked "ascend": ClassData.skill_tier puts
## them at JobData.ASCEND_TIER, so only a hero who passed the trial (AscensionData) casts
## them; AI world players cast them too once they have won the trial themselves
## (WorldPlayers.ascended_at, JobData.adv_for's ascended), never by ★500 alone.
##
## The ultimate is built on the class's god skill (same gesture, animation and shape,
## GOD_BEATS waves and finale) with ULT_POWER its TOTAL multiplier, more MP and a long
## cooldown; its art (combat/god_art/<id>.gd) plays the class's god art under the
## Ascension's own heavens (AscendSkillArt). The buff is a star buff (shape "self", never a
## god-tier attack: StarSkillData.is_god) under the party-buff rule (BuffBook.reaches_party:
## the Priest's and the Bard's reach the party), in the own-buff slots (the Defender keeps 3).

const STAR := 500
## The ultimate's TOTAL multiplier over its class's god skill (tuned as the god one).
const ULT_POWER := 1.45
const ULT_MP := 420
const ULT_CD := 90.0
const BUFF_MP := 320
const BUFF_CD := 120.0
const BUFF_SECS := 60.0
## The ultimates' art: each class's god skill (combat/god_art) under the Ascension's sky.
const GOD_OF := {
	&"warrior": "divine_edict", &"archer": "sunfall_volley", &"lancer": "heavenrend_spear", &"mage": "astral_apocalypse",
	&"priest": "seraphic_judgment", &"summoner": "celestial_dragon_emperor", &"defender": "pantheon_bastion",
	&"assassin": "death_gods_eclipse", &"darklord": "abyssal_throne", &"bard": "divine_symphony", &"muaythai": "three_realms_fist",
}
## [ultimate, buff] per class.
const IDS := {
	&"warrior": ["emperor_heavensword", "sovereign_awakening"],
	&"archer": ["starfall_emperor_arrow", "zenith_hawkeye"],
	&"lancer": ["dragon_emperor_lance", "celestial_phalanx"],
	&"mage": ["cosmos_genesis", "arcane_singularity"],
	&"priest": ["eternal_dawn_judgment", "halo_of_eternity"],
	&"summoner": ["primordial_beast_court", "covenant_of_beasts"],
	&"defender": ["eternal_bastion_fall", "aegis_of_eternity"],
	&"assassin": ["timeless_night_execution", "veil_of_eternity"],
	&"darklord": ["heaven_hell_sovereign", "crown_of_dual_realms"],
	&"bard": ["universe_hymn", "aria_of_eternity"],
	&"muaythai": ["heavenly_master_fist", "sacred_ring_vow"],
}
const NAMES := {
	&"warrior": ["ดาบจักรพรรดิสวรรค์", "ราชันดาบตื่นรู้"],
	&"archer": ["ศรจักรพรรดิดาราถล่ม", "เนตรเหยี่ยวสุดขอบฟ้า"],
	&"lancer": ["หอกจักรพรรดิมังกรสวรรค์", "กระบวนทัพเทวาลัย"],
	&"mage": ["ปฐมกาลแห่งจักรวาล", "เอกภาวะแห่งเวท"],
	&"priest": ["อรุณนิรันดร์พิพากษา", "รัศมีแห่งนิรันดร์"],
	&"summoner": ["ราชสำนักอสูรปฐมกาล", "พันธสัญญาสรรพสัตว์"],
	&"defender": ["ปราการนิรันดร์ถล่มฟ้า", "อีจิสแห่งนิรันดร์"],
	&"assassin": ["ประหารราตรีไร้กาล", "ม่านเงานิรันดร์"],
	&"darklord": ["จักรพรรดิสวรรค์และอเวจี", "มงกุฎสองภพ"],
	&"bard": ["บทเพลงสวดแห่งจักรวาล", "อาเรียนิรันดร์"],
	&"muaythai": ["หมัดบรมครูเทวะ", "สัจจะวงประเจียดเทวา"],
}
const DESCS := {
	&"warrior": ["สกิลเทวาลัย • ฟ้าแยกเป็นประตูเทวาลัย ห่าดาบจักรพรรดิฟันพื้นที่ 4 ระลอก ปิดด้วยดาบสวรรค์ยักษ์ปักกลางสนาม มึน 2 วิ เกราะแตก 30% นาน 10 วิ",
		"สกิลเทวาลัย • ปลุกวิญญาณจักรพรรดิดาบ โจมตี +60% คริ +15% ลดความเสียหาย 15% นาน 1 นาที (เฉพาะตัว)"],
	&"archer": ["สกิลเทวาลัย • ดาวจักรพรรดิลุกโชนเหนือสนาม ห่าศรดารา 4 ระลอก ปิดด้วยศรดาวตกยักษ์ ศัตรูช้าลง 5 วิ เกราะแตก 25% นาน 8 วิ",
		"สกิลเทวาลัย • เนตรเหยี่ยวเห็นสุดขอบฟ้า โจมตี +50% คริ +20% วิ่งเร็ว +30% หลบ +15% นาน 1 นาที (เฉพาะตัว)"],
	&"lancer": ["สกิลเทวาลัย • หอกมังกรสวรรค์ผุดรอบตัว 4 ระลอก ปิดด้วยหอกจักรพรรดิยักษ์ทะลวงลงจากเทวาลัย มึน 1.5 วิ เกราะแตก 30% นาน 10 วิ",
		"สกิลเทวาลัย • ตั้งกระบวนทัพแห่งเทวาลัย โจมตี +50% ป้องกัน +50% ลดความเสียหาย 25% นาน 1 นาที (เฉพาะตัว)"],
	&"mage": ["สกิลเทวาลัย • จักรวาลถือกำเนิดใหม่เหนือสนาม ดาวตกและวงแหวนเวท 4 ระลอก ปิดด้วยบิ๊กแบงปฐมกาล มึน 2 วิ ศัตรูช้าลง 5 วิ",
		"สกิลเทวาลัย • รวมพลังเวททั้งจักรวาลเป็นจุดเดียว โจมตี +70% คริ +12% นาน 1 นาที (เฉพาะตัว)"],
	&"priest": ["สกิลเทวาลัย • รุ่งอรุณนิรันดร์สาดลงจากเทวาลัย เสาแสง 5 ระลอกทำดาเมจหมู่ ฟื้น HP ทีม 10% ทุกระลอก (รวม 50%) มึน 1.5 วิ",
		"สกิลเทวาลัย • รัศมีนิรันดร์โอบทีม โล่ดูดซับ 30% ของ HP สูงสุด ป้องกัน +40% ลดความเสียหาย 20% นาน 1 นาที (ทั้งทีม)"],
	&"summoner": ["สกิลเทวาลัย • ราชสำนักอสูรปฐมกาลเสด็จลงโฉบวนสนาม 4 ระลอก ปิดด้วยมังกรจักรพรรดิพุ่งลงกลางวง มึน 2 วิ เกราะแตก 25% นาน 8 วิ",
		"สกิลเทวาลัย • พันธสัญญากับสรรพสัตว์สามภพ ผู้ร่ายและอสูรของตัวเองโจมตี +60% ป้องกัน +50% นาน 1 นาที"],
	&"defender": ["สกิลเทวาลัย • ปราการนิรันดร์ถล่มลงจากฟ้า โล่เทวะกระแทก 5 ระลอก มึน 2.5 วิ ศัตรูหันมาโจมตีคุณ 5 วิ",
		"สกิลเทวาลัย • ฟื้น HP 30% ป้องกัน +150% ลดความเสียหาย 40% โล่ดูดซับ 40% ของ HP สะท้อนความเสียหาย 40% นาน 1 นาที (เฉพาะตัว)"],
	&"assassin": ["สกิลเทวาลัย • ราตรีไร้กาลกลืนสนาม คมเงาไขว้ฟัน 4 ระลอก ปิดด้วยจันทร์ประหาร เลือดไหล 8 วิ เกราะแตก 25% นาน 8 วิ",
		"สกิลเทวาลัย • ม่านเงานิรันดร์ คริ +30% โจมตี +50% หลบ +20% นาน 1 นาที (เฉพาะตัว)"],
	&"darklord": ["สกิลเทวาลัย • บัลลังก์สวรรค์และอเวจีผุดคู่กัน สายฟ้าและเพลิงมืด 4 ระลอก ปิดด้วยมงกุฎสองภพถล่มสนาม มึน 2 วิ ศัตรูติดไฟ 6 วิ",
		"สกิลเทวาลัย • สวมมงกุฎสองภพ โจมตี +55% ป้องกัน +40% คริ +12% ตีแล้วฟื้นเลือด 6% ของดาเมจ นาน 1 นาที (เฉพาะตัว)"],
	&"bard": ["สกิลเทวาลัย • ไม่ใช่เพลง วงดุริยางค์จักรวาลบรรเลงบทสวด คลื่นเสียง 5 ระลอก มึน 2 วิ ศัตรูอ่อนแรง 25% นาน 10 วิ",
		"สกิลเทวาลัย • ไม่ใช่เพลง ใช้คู่กับเพลงได้ ทีมในระยะโจมตี +50% ป้องกัน +40% คริ +12% ลดดาเมจ 10% นาน 1 นาที"],
	&"muaythai": ["สกิลเทวาลัย • บรมครูเทวะลงมาไหว้ครูกลางเทวาลัย แล้วพุ่งเข้าใส่เป้าหมายพร้อมบรมครู ปล่อยหมัดเทวะหมัดเดียวระเบิดวงใหญ่ (หนักแต่ช้า) มึน 2 วิ ศัตรูติดไฟ 6 วิ ใช้คอมโบทั้งหมดเพิ่มพลัง",
		"สกิลเทวาลัย • ATK +100% คริ +25% วิ่งเร็ว +20% ลดความเสียหาย 22% ตีแล้วฟื้นเลือด 10% ของดาเมจ นาน 1 นาที (เฉพาะตัว)"],
}
## Each ultimate's own effects (on top of its god skill's shape).
const ULT_FX := {
	&"warrior": {"stun": 2.0, "shred": [0.3, 10.0]},
	&"archer": {"slow": 5.0, "shred": [0.25, 8.0]},
	&"lancer": {"stun": 1.5, "shred": [0.3, 10.0]},
	&"mage": {"stun": 2.0, "slow": 5.0},
	&"priest": {"stun": 1.5},
	&"summoner": {"stun": 2.0, "shred": [0.25, 8.0]},
	&"defender": {"stun": 2.5, "taunt": 5.0},
	&"assassin": {"burn": [0.5, 8.0], "shred": [0.25, 8.0]},
	&"darklord": {"stun": 2.0, "burn": [0.45, 6.0]},
	&"bard": {"stun": 2.0, "weaken": [0.25, 10.0]},
	&"muaythai": {"stun": 2.0, "burn": [0.5, 6.0], "combo_power": 0.025},
}
## Ultimates that land as ONE blow at the end instead of their god skill's four waves and
## finale (GOD_BEATS): the whole multiplier (the waves' and the finale's shares together,
## so the same total) on a single finale beat after a longer wind-up. id -> what changes:
## shape / hit_delay as data; "dash": the hero dashes up to that many metres to the aimed
## point just before the blow (StarSkillSequence: walls stop it, never through a body).
const FINISHERS := {
	"heavenly_master_fist": {"shape": "blast", "hit_delay": 2.0, "dash": 8.0},
}
## The finisher's single beat (seconds after the release).
const FINISHER_BEATS := [0.0]
## The dash ends this long before the blow, and takes this long.
const DASH_LEAD := 0.08
const DASH_TIME := 0.34
## Each buff (60 s): self_only keeps a stance on its caster.
const BUFFS := {
	&"warrior": {"atk": 0.6, "crit": 0.15, "guard": 0.15},
	&"archer": {"atk": 0.5, "crit": 0.2, "speed": 0.3, "dodge": 0.15},
	&"lancer": {"atk": 0.5, "def": 0.5, "guard": 0.25},
	&"mage": {"atk": 0.7, "crit": 0.12},
	&"priest": {"shield": 0.3, "def": 0.4, "guard": 0.2},
	&"summoner": {"atk": 0.6, "def": 0.5},
	&"defender": {"def": 1.5, "guard": 0.4, "shield": 0.4, "reflect": 0.4},
	&"assassin": {"crit": 0.3, "atk": 0.5, "dodge": 0.2},
	&"darklord": {"atk": 0.55, "def": 0.4, "crit": 0.12, "hit_heal": 0.06},
	&"bard": {"atk": 0.5, "def": 0.4, "crit": 0.12, "guard": 0.1},
	&"muaythai": {"atk": 1.0, "crit": 0.25, "speed": 0.2, "guard": 0.22, "hit_heal": 0.1, "self_only": true},
}
## The buff's wind-up gesture and clip, per class (the star buffs' own).
const BUFF_LOOK := {
	&"warrior": ["ward", "Cheer"], &"archer": ["weave", "Dodge_Backward"], &"lancer": ["ward", "Cheer"],
	&"mage": ["channel", "Spellcast_Raise"], &"priest": ["prayer", "Spellcasting"], &"summoner": ["invoke", "Cheer"],
	&"defender": ["ward", "Cheer"], &"assassin": ["weave", "Dodge_Backward"], &"darklord": ["invoke", "Cheer"],
	&"bard": ["serenade", "Cheer"], &"muaythai": ["resolve", "Cheer"],
}
## The Ascension's palette per class: [primary, bright core, deep shade] (StarSkillArt.look).
## Every ultimate wears white-gold heavens over its class hue; every buff its class hue.
const COLORS := {
	"emperor_heavensword": ["ffb43a", "fff4c0", "6a1a2a"], "sovereign_awakening": ["ffcf5a", "fff8dc", "7a3010"],
	"starfall_emperor_arrow": ["6af0c8", "eafff8", "123a5a"], "zenith_hawkeye": ["3ae0b0", "f0fff8", "0e4a4a"],
	"dragon_emperor_lance": ["4ad0ff", "f0fbff", "122a6a"], "celestial_phalanx": ["6ab8ff", "fff4d0", "1a2a6a"],
	"cosmos_genesis": ["9a6aff", "f6eeff", "1a0a4a"], "arcane_singularity": ["c07aff", "fbf0ff", "2a0a5a"],
	"eternal_dawn_judgment": ["ffd84a", "ffffff", "8a4a6a"], "halo_of_eternity": ["ffe88a", "fffff0", "6a5a8a"],
	"primordial_beast_court": ["3af0a0", "e8fff4", "0a3a3a"], "covenant_of_beasts": ["8af05a", "f8ffe8", "1a4a2a"],
	"eternal_bastion_fall": ["5a9aff", "f0f6ff", "0e1e5a"], "aegis_of_eternity": ["8ac4ff", "fbfdff", "1a3a7a"],
	"timeless_night_execution": ["ff3a7a", "ffe6f0", "1a0420"], "veil_of_eternity": ["b05aff", "f4e6ff", "1a0a3e"],
	"heaven_hell_sovereign": ["c06aff", "ffe8a0", "1a0630"], "crown_of_dual_realms": ["f0c050", "fff6d8", "3a1060"],
	"universe_hymn": ["ff6ae0", "fff0fb", "2a0a4a"], "aria_of_eternity": ["ffb0e8", "fff8fc", "5a2a6a"],
	"heavenly_master_fist": ["ffa030", "fff4d0", "5a1a08"], "sacred_ring_vow": ["ff7a1a", "ffd23c", "4a1206"],
}

static var _pools := {}


static func pool(cls: StringName) -> Array:
	if _pools.has(cls):
		return _pools[cls]
	var out: Array = []
	if not IDS.has(cls):
		return out
	var star_pool := StarSkillData.pool(cls)
	var god: Dictionary = star_pool[star_pool.size() - 1]
	# The ultimate: the god skill's body, the Ascension's power.
	var ult := god.duplicate(true)
	ult.merge({"id": IDS[cls][0], "name": NAMES[cls][0], "desc": DESCS[cls][0], "star": STAR, "ascend": true,
		"mp": ULT_MP, "cd": ULT_CD, "mult": float(god.mult) * ULT_POWER, "radius": maxf(float(god.get("radius", 9.0)), 10.0),
		"range": maxf(float(god.get("range", 12.0)), 13.0), "art": GOD_OF[cls], "icon": "star", "color": Color(COLORS[IDS[cls][0]][0])}, true)
	var fx: Dictionary = (god.get("fx", {}) as Dictionary).duplicate(true)
	fx.merge(ULT_FX[cls], true)
	ult["fx"] = fx
	var finisher: Dictionary = FINISHERS.get(String(ult.id), {})
	if not finisher.is_empty():
		ult.merge({"shape": finisher.shape, "hit_delay": float(finisher.hit_delay), "dash": float(finisher.dash)}, true)
	out.append(ult)
	# The buff: a star buff in the class's colours, a minute long.
	var look: Array = BUFF_LOOK[cls]
	var buff := {"id": IDS[cls][1], "name": NAMES[cls][1], "desc": DESCS[cls][1], "class": cls, "level": 100, "star": STAR, "ascend": true,
		"mp": BUFF_MP, "cd": BUFF_CD, "shape": "self", "range": 12.0, "radius": 9.0, "mult": 0.0, "hit_delay": 0.8,
		"anim": look[1], "gesture": look[0], "vfx": &"light", "color": Color(COLORS[IDS[cls][1]][0]), "icon": "star",
		"fx": {"buff": (BUFFS[cls] as Dictionary).merged({"secs": BUFF_SECS}, true)}}
	if cls == &"defender":
		buff.fx["heal"] = 0.3
	out.append(buff)
	_pools[cls] = out
	return out


## One of the Ascension's skills (ultimate or buff).
static func is_ascend(skill: Dictionary) -> bool:
	return bool(skill.get("ascend", false))


static func is_ult(skill: Dictionary) -> bool:
	return is_ascend(skill) and String(skill.get("shape", "")) != "self"


## A finisher ultimate (FINISHERS): one blow at the end, not the god skill's waves.
static func is_finisher(skill: Dictionary) -> bool:
	return FINISHERS.has(String(skill.get("id", "")))


## The contact beats of a god-tier skill (StarSkillSequence, GodSkillArt): the god skill's
## four waves and finale (StarSkillData.GOD_BEATS), or a finisher's single blow.
static func god_beats(skill: Dictionary) -> Array:
	return FINISHER_BEATS if is_finisher(skill) else StarSkillData.GOD_BEATS


## Every Ascension skill id.
static func all_ids() -> Array:
	var out: Array = []
	for cls in IDS:
		out.append_array(IDS[cls])
	return out
