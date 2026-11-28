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
## the Priest's and the Bard's reach the party, and the Defender's ผู้พิทักษ์ทีม:
## ClassData.PARTY_BUFF_SKILLS), in the own-buff slots (BuffBook.own_limit).

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
	&"warrior": ["ดาบเหินฟ้า", "โลหิตราชันเดือด"],
	&"archer": ["เลนส์ตะวัน", "ลมหายใจนักล่า"],
	&"lancer": ["หอกพายุบูมเมอแรง", "หอกทะลวงเกราะ"],
	&"mage": ["ประตูมิติร้อยบาน", "ร่ายซ้ำ"],
	&"priest": ["เทวทูตคุ้มชีวิต", "แสงฟื้นต่อเนื่อง"],
	&"summoner": ["หลอมรวมอสูร", "พันธสัญญาไททัน"],
	&"defender": ["กำแพงโล่ถล่ม","ผู้พิทักษ์ทีม"],
	&"assassin": ["ประหารเลือดพร่อง","ล่าต่อเนื่อง"],
	&"darklord": ["สัญญาโลหิต", "เพลิงมืดเผาผลาญ"],
	&"bard": ["ระบำสะกดใจ", "เสียงสะท้อน"],
	&"muaythai": ["หมัดบรมครูเทวะ", "สัจจะวงประเจียดเทวา"],
}
const DESCS := {
	&"warrior": ["สกิลเทวาลัย • ฟันเสยขึ้นฟ้า ศัตรูทุกตัวในระยะ 10 เมตรรอบตัวปลิวลอยกลางอากาศ ทำอะไรไม่ได้ 1.5 วิ แล้วกระโดดตามขึ้นไปฟันกลางอากาศ 4 ดาบ ก่อนดิ่งลงกระแทกทุกตัวจมพื้นพร้อมคลื่นกระแทก (ฟันเสย 20% ฟันกลางอากาศ 4×10% กระแทก 40% ของพลังทั้งหมด) มึน 2 วิ เกราะแตก 30% นาน 10 วิ บอสที่ปลิวไม่ได้โดนครบทุกดาบและมึนสั้นๆ",
		"สกิลเทวาลัย • โลหิตราชันเดือดพล่าน โจมตี +100% แต่เสีย HP 3% ของ HP สูงสุดทุกวินาที (ไม่ทำให้ตาย หยุดที่ HP 1) นาน 1 นาที (เฉพาะตัว)"],
	&"archer": ["สกิลเทวาลัย • รวมแสงอาทิตย์ผ่านเลนส์ทองยักษ์ ยิงลำแสงต่อเนื่อง 3 วิ (ยืนนิ่งขณะยิง) ลำแสงหันตามเป้า เป้าล้มจะกวาดไปหาศัตรูที่ใกล้ที่สุด เผาทุกตัวในแนวลำแสงทุก 0.2 วิ รวม 15 ครั้ง (โดนครบทั้ง 15 ครั้งเท่ากับพลังสกิลเต็ม) ศัตรูในลำแสงช้าลง ครั้งสุดท้ายเกราะแตก 20% นาน 6 วิ",
		"สกิลเทวาลัย • ยืนนิ่ง 1 วิ เพื่อเล็ง การโจมตีครั้งถัดไป (ตีธรรมดาหรือสกิล) คริแน่นอนและแรงคริ +50% ขณะเคลื่อนที่วิ่งเร็ว +30% นาน 1 นาที (เฉพาะตัว)"],
	&"lancer": ["สกิลเทวาลัย • ขว้างหอกยักษ์หมุนติ้วไปข้างหน้า 14 เมตร กลายเป็นพายุหมุนกว้าง 2.4 เมตร ฟาดทุกตัวตลอดทาง (ขาไป 3 ครั้ง รวม 35%) แล้ววกกลับเข้ามือแบบบูมเมอแรง ฟาดซ้ำอีก 3 ครั้ง (รวม 65%) และลากศัตรูเข้าหาตัวครั้งละ 0.6 เมตร ครั้งสุดท้ายมึน 1.5 วิ เกราะแตก 30% นาน 10 วิ",
		"สกิลเทวาลัย • ปลายหอกทะลวงทุกเกราะ ทุกการโจมตีเจาะเกราะ 40% (ไม่สนป้องกันของเป้าหมาย 40%) นาน 1 นาที (เฉพาะตัว)"],
	&"mage": ["สกิลเทวาลัย • เปิดประตูมิติ 6 บานล้อมพื้นที่เป้า ยิงลูกเวทรัว 12 ระลอกใน 3 วิ สลับไฟ น้ำแข็ง สายฟ้า ใส่ศัตรูทุกตัวในวงรัศมี 8 ม. (โดนครบ 12 ระลอกเท่ากับพลังสกิลเต็ม) ไฟเผาต่อ 2 วิ น้ำแข็งช้าลง 1.5 วิ สายฟ้าระลอกสุดท้ายมึน 1 วิ",
		"สกิลเทวาลัย • เวทสะท้อนก้อง ทุกสกิลที่ร่ายมีโอกาส 25% ร่ายซ้ำทันทีฟรี (ไม่ใช้ MP ไม่ติดคูลดาวน์ แรงเต็ม) ร่ายซ้ำไม่ซ้ำต่อ ไม่รวมสกิลเทวาลัยและบัฟ นาน 1 นาที (เฉพาะตัว)"],
	&"priest": ["สกิลเทวาลัย • เทวทูตผู้พิทักษ์ลงมาพร้อมแสงศักดิ์สิทธิ์ ทำดาเมจหมู่ 60% ของพลังสกิล มึน 1.5 วิ แล้วคุ้มครองทีม 10 วิ: ใครจะล้มจะฟื้นทันทีด้วย HP 30% (คนละ 1 ครั้ง) พร้อมระเบิดแสงรอบตัว 5 ม. ดาเมจ 20% ของพลังสกิล (ศัตรูแต่ละตัวโดนระเบิดได้ไม่เกิน 2 ครั้ง)",
		"สกิลเทวาลัย • แสงฟื้นต่อเนื่องโอบทีม ฟื้น HP 3% ของ HP สูงสุดทุกวินาที และชำระล้างสถานะผิดปกติ (ไหม้ เพลิงมืด ช้าลง เกราะแตก อ่อนแรง มึน) ทุก 5 วิ นาน 1 นาที (ทั้งทีม)"],
	&"summoner": ["สกิลเทวาลัย • อสูรอัญเชิญทุกตัวของคุณพุ่งเข้าหลอมรวมเป็นอสูรไคเมร่ายักษ์ ทุบพื้นที่เป้าหมายครั้งเดียว ดาเมจ 80% ของพลังสกิล +10% ต่ออสูรที่หลอม (สูงสุด 4 ตัว = 120%) มึน 2 วิ เกราะแตก 25% นาน 8 วิ อสูรที่หลอมจะหายไป (ไททันไม่ถูกหลอม ไม่มีอสูรก็ใช้ได้)",
		"สกิลเทวาลัย • เรียกไททันยักษ์มาสู้เคียงข้าง 1 นาที อสูรที่อัญเชิญไว้ทุกตัว (ไททันด้วย) โจมตี ป้องกัน HP และความเร็ว +40% และอยู่นานขึ้น 1.5 เท่า (ตัวที่อัญเชิญระหว่างบัฟด้วย) นาน 1 นาที"],
	&"defender": ["สกิลเทวาลัย • กำแพงโล่เทวะยักษ์ผุดขึ้นตรงหน้า แล้วดันไปข้างหน้า 10 เมตร ศัตรูที่ชนโดน 25% ของพลังและถูกดันติดกำแพงไป จบด้วยโล่ล้มทับบดขยี้ 75% ดาเมจคิดจาก ATK 50% + DEF 50% (นับ DEF ปัจจุบันรวมบัฟ สูงสุด 3 เท่าของ ATK) มึน 2.5 วิ ศัตรูหันมาโจมตีคุณ 5 วิ",
		"สกิลเทวาลัย • ผู้พิทักษ์รับความเสียหายแทนเพื่อนร่วมทีม 50% (รับผ่านเกราะของตัวเอง) ป้องกันทั้งทีม +40% ผู้พิทักษ์ฟื้น HP 3% ของ HP สูงสุดทุกวินาที นาน 1 นาที (ทั้งทีม)"],
	&"assassin": ["สกิลเทวาลัย • หายตัวไปโผล่หลังเป้าหมายเดียว (ไม่มีเป้าจะเลือกศัตรูใกล้สุดในระยะ) แล้วประหารด้วยคมเดียว เจาะเกราะ 100% ยิ่งเลือดเป้าหมายน้อยยิ่งแรง x1 ตอนเลือดเต็ม ไต่ขึ้นต่อเนื่องถึง x3 เมื่อเลือดต่ำกว่า 30% เลือดไหล 8 วิ เกราะแตก 25% นาน 8 วิ",
		"สกิลเทวาลัย • สังหารศัตรูแล้วพุ่งเข้าหาศัตรูที่ใกล้ที่สุดในระยะ 10 เมตรทันที (กำแพงขวางได้) ตีเป้านั้นครั้งถัดไปคริแน่นอน (พุ่งได้ทุก 0.3 วิ) นาน 1 นาที (เฉพาะตัว)"],
	&"darklord": ["สกิลเทวาลัย • ทำสัญญาโลหิต จ่าย HP 20% ของ HP ปัจจุบัน (ไม่มีวันตาย เหลืออย่างน้อย 1) ระเบิดโลหิตรอบตัวรัศมี 10 เมตร 3 ระลอก (30% / 30% / 40%) ยิ่งจ่ายมากยิ่งแรง: พลัง 50% บวก 2.5% ต่อ HP สูงสุดที่จ่ายทุก 1% (เต็ม 100% เมื่อร่ายตอน HP เต็ม) จากนั้น 10 วิ ทุกการโจมตีดูดเลือด 20% ของดาเมจ",
		"สกิลเทวาลัย • ทุกการโจมตีจุดเพลิงมืดใส่ศัตรู 5 วิ ไหม้ 10% ของพลังโจมตีต่อวิ และศัตรูที่ติดเพลิงมืดรับความเสียหายจากทุกแหล่ง +15% นาน 1 นาที (เฉพาะตัว)"],
	&"bard": ["สกิลเทวาลัย • ไม่ใช่เพลง บรรเลงทำนองระบำสะกดใจ ศัตรูทุกตัวในรัศมี 10 เมตรโดนดาเมจ 30% แล้วถูกบังคับให้เต้นรำ 3 วิ โจมตีและทำอะไรไม่ได้ (บอสและผู้เล่นเต้น 1.2 วิ) ระหว่างเต้นรับดาเมจจากทุกแหล่ง +20% ปิดท้ายด้วยระเบิดฟินาเล่ 70%",
		"สกิลเทวาลัย • ไม่ใช่เพลง ใช้คู่กับเพลงได้ เพลงที่ผู้ร่ายร้องระหว่างนี้แรงขึ้น 50% และนานขึ้น 2 เท่า ทีมในระยะความเร็วโจมตี +20% วิ่งเร็ว +20% นาน 1 นาที"],
	&"muaythai": ["สกิลเทวาลัย • บรมครูเทวะลงมาไหว้ครูกลางเทวาลัย แล้วพุ่งเข้าใส่เป้าหมายพร้อมบรมครู ปล่อยหมัดเทวะหมัดเดียวระเบิดวงใหญ่ (หนักแต่ช้า) มึน 2 วิ ศัตรูติดไฟ 6 วิ ใช้คอมโบทั้งหมดเพิ่มพลัง",
		"สกิลเทวาลัย • ATK +100% คริ +25% วิ่งเร็ว +20% ลดความเสียหาย 22% ตีแล้วฟื้นเลือด 10% ของดาเมจ นาน 1 นาที (เฉพาะตัว)"],
}
## Each ultimate's own effects (on top of its god skill's shape).
const ULT_FX := {
	&"warrior": {"stun": 2.0, "shred": [0.3, 10.0]},
	&"archer": {"slow": 1.0, "shred": [0.2, 6.0]},
	&"lancer": {"stun": 1.5, "shred": [0.3, 10.0]},
	&"mage": {"burn": [0.2, 2.0], "slow": 1.5, "stun": 1.0},
	&"priest": {"stun": 1.5},
	&"summoner": {"stun": 2.0, "shred": [0.25, 8.0]},
	&"defender": {"stun": 2.5, "taunt": 5.0},
	&"assassin": {"burn": [0.5, 8.0], "shred": [0.25, 8.0]},
	&"darklord": {"own_fx": true, "blood_price": 0.2, "pact_leech": [0.2, 10.0]},
	&"bard": {"own_fx": true, "stun": 3.0, "dance_taken": 0.2},
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
## Ultimates whose own script (AscendUlt) plays another body than their god skill's:
## id -> what changes (merged over the ultimate after FINISHERS).
const ULT_BODY := {
	# ดาบเหินฟ้า: round the warrior itself (combat/ascend_ult/emperor_heavensword.gd).
	"emperor_heavensword": {"shape": "burst", "gesture": "draw_cut"},
	# หอกพายุบูมเมอแรง: a throw (combat/ascend_ult/dragon_emperor_lance.gd).
	"dragon_emperor_lance": {"gesture": "spear_throw"},
	# สัญญาโลหิต: the blood bursts round the dark lord itself (combat/ascend_ult/heaven_hell_sovereign.gd).
	"heaven_hell_sovereign": {"shape": "burst"},
}
## The finisher's single beat (seconds after the release).
const FINISHER_BEATS := [0.0]
## The dash ends this long before the blow, and takes this long.
const DASH_LEAD := 0.08
const DASH_TIME := 0.34
## Each buff (60 s): self_only keeps a stance on its caster.
const BUFFS := {
	## ★500 buffs: sovereign_awakening / zenith_hawkeye / celestial_phalanx / arcane_singularity /
	## veil_of_eternity are mechanics (AscendBuffs: drain, still_shot, armor_pen, echo, hunt).
	&"warrior": {"atk": 1.0, "drain": 0.03},
	&"archer": {"still_shot": 0.5, "speed": 0.3},
	&"lancer": {"armor_pen": 0.4},
	&"mage": {"echo": 0.25},
	## ★500 buffs: halo_of_eternity / covenant_of_beasts / aegis_of_eternity / crown_of_dual_realms /
	## aria_of_eternity are mechanics (AscendBuffsB: regen + cleanse, titan + summon_boost +
	## summon_life, aegis, dark_fire, song_boost + aspd). "grow" holds their mechanic numbers
	## still at every skill star (SkillRank.buff_value); their stat numbers grow as usual.
	&"priest": {"regen": 0.03, "cleanse": 5.0, "grow": {"regen": 0.0, "cleanse": 0.0}},
	&"summoner": {"titan": true, "summon_boost": 0.4, "summon_life": 1.5, "grow": {"summon_boost": 0.0, "summon_life": 0.0}},
	&"defender": {"def": 0.4, "aegis": 0.5, "regen": 0.03, "party": ["def", "aegis", "aegis_by"], "grow": {"aegis": 0.0, "regen": 0.0}},
	&"assassin": {"hunt": 10.0},
	&"darklord": {"dark_fire": 5.0, "dark_fire_dps": 0.1, "dark_fire_vuln": 0.15, "grow": {"dark_fire": 0.0, "dark_fire_vuln": 0.0}},
	&"bard": {"aspd": 0.2, "speed": 0.2, "song_boost": 0.5, "song_time": 2.0, "party": ["aspd", "speed"], "grow": {"song_boost": 0.0, "song_time": 0.0}},
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
	"heaven_hell_sovereign": ["e0203a", "ffb0a8", "2a0410"], "crown_of_dual_realms": ["f0c050", "fff6d8", "3a1060"],
	"universe_hymn": ["ff5aa8", "ffe9a0", "3a0a3a"], "aria_of_eternity": ["ffb0e8", "fff8fc", "5a2a6a"],
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
	# "own_fx": an ultimate with mechanics of its own (AscendUlt) keeps only its own effects.
	var own_fx := bool(ULT_FX[cls].get("own_fx", false))
	var fx: Dictionary = {} if own_fx else (god.get("fx", {}) as Dictionary).duplicate(true)
	fx.merge(ULT_FX[cls], true)
	fx.erase("own_fx")
	ult["fx"] = fx
	var finisher: Dictionary = FINISHERS.get(String(ult.id), {})
	if not finisher.is_empty():
		ult.merge({"shape": finisher.shape, "hit_delay": float(finisher.hit_delay), "dash": float(finisher.dash)}, true)
	ult.merge(ULT_BODY.get(String(ult.id), {}), true)
	out.append(ult)
	# The buff: a star buff in the class's colours, a minute long.
	var look: Array = BUFF_LOOK[cls]
	var buff := {"id": IDS[cls][1], "name": NAMES[cls][1], "desc": DESCS[cls][1], "class": cls, "level": 100, "star": STAR, "ascend": true,
		"mp": BUFF_MP, "cd": BUFF_CD, "shape": "self", "range": 12.0, "radius": 9.0, "mult": 0.0, "hit_delay": 0.8,
		"anim": look[1], "gesture": look[0], "vfx": &"light", "color": Color(COLORS[IDS[cls][1]][0]), "icon": "star",
		"fx": {"buff": (BUFFS[cls] as Dictionary).merged({"secs": BUFF_SECS}, true)}}
	## ★500 buff: aegis_of_eternity no longer heals 30% on the cast (it regenerates instead).
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
