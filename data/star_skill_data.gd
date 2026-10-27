class_name StarSkillData
extends RefCounted
## Authored post-cap skills. `mult` is TOTAL damage for the timed sequence.
## Skill rank never changes the promised ten swords or six Heartseeker contacts.
const IDS := {
	&"warrior": ["lionfang_cleave", "crown_breaker", "royal_vanguard", "celestial_swordfall"],
	&"archer": ["moonpiercer", "hunters_verdict", "sylph_step", "celestial_hunt"],
	&"lancer": ["spiral_impaler", "heartseeker", "aegis_formation", "worldsplitter"],
	&"mage": ["arcane_prism", "crystal_prison", "astral_convergence", "genesis_nova"],
	&"priest": ["sanctified_chain", "seraph_aegis", "sacred_sanctuary", "dawn_salvation"],
	&"summoner": ["moonwolf_pact", "leviathan_surge", "spirit_court", "eclipse_sovereign"],
	&"defender": ["titan_shieldbreak", "judgment_rebound", "eternal_aegis", "heavens_bulwark"],
	&"assassin": ["umbral_lacerate", "shadow_execution", "veil_of_night", "eclipse_requiem"],
	&"darklord": ["chaos_inferno", "raven_sovereign", "lords_dominion", "imperial_cataclysm"],
	&"bard": ["starlight_overture", "heartbreak_sonata", "celestial_stage", "cosmic_encore"],
}
const NAMES := {
	&"warrior": ["Lionfang Cleave", "Crown Breaker", "Royal Vanguard", "Celestial Swordfall"],
	&"archer": ["Moonpiercer", "Hunter's Verdict", "Sylph Step", "Celestial Hunt"],
	&"lancer": ["Spiral Impaler", "Heartseeker", "Aegis Formation", "Worldsplitter"],
	&"mage": ["Arcane Prism", "Crystal Prison", "Astral Convergence", "Genesis Nova"],
	&"priest": ["Sanctified Chain", "Seraph's Aegis", "Sacred Sanctuary", "Dawn of Salvation"],
	&"summoner": ["Wind Monkey King", "Leviathan's Surge", "Spirit Court", "Poseidon, Lord of Tides"],
	&"defender": ["Titan Shieldbreak", "Judgment Rebound", "Eternal Aegis", "Heaven's Bulwark"],
	&"assassin": ["Umbral Lacerate", "Shadow Execution", "Veil of Night", "Eclipse Requiem"],
	&"darklord": ["Chaos Inferno", "Raven Sovereign", "Lord's Dominion", "Imperial Cataclysm"],
	&"bard": ["Starlight Overture", "Heartbreak Sonata", "Celestial Stage", "Cosmic Encore"],
}
const DESCS := {
	&"warrior": ["คมเขี้ยวราชสีห์ • ฟันรูปพัดด้านหน้า 2 จังหวะ", "ดาบทำลายราชัน • 2 ฮิตเดี่ยว ลดเกราะ 20% นาน 6 วิ", "แนวหน้าราชัน • ทีมในระยะรับความเสียหายลด 22% ป้องกัน +60% นาน 1 นาที", "ฝนดาบราชันสวรรค์ • ต้องสวมปีก บินสูง 5 เมตร เรียกดาบที่ถือ 10 เล่มโจมตีพื้นที่"],
	&"archer": ["ศรทะลวงจันทรา • ศรเงินทะลุศัตรูเป็นแนวตรง", "ศรตัดสินนักล่า • ยิงเป้าหมายเดียว 3 นัด นัดสุดท้ายแรงเป็นสองเท่า", "ก้าวแห่งภูตลม • วิ่งเร็ว +25% หลบ +15% โจมตี +35% นาน 1 นาที", "ล่าหมู่ดาว • ล็อกศัตรูในวง ยิง 3 ระลอก ก่อนศรปิดฉากใส่เป้าหมายหลัก"],
	&"lancer": ["หอกเกลียวทะลวง • แทงผ่านแนวศัตรู 3 จังหวะ", "หอกเจาะหัวใจ • แทงเร็ว 5 ครั้ง ปิดด้วยแทงหนัก 1 ครั้ง รวม 6 ฮิต", "กระบวนทัพพิทักษ์ • ลดความเสียหายทีม 28% ป้องกัน +45% นาน 1 นาที", "หอกแยกพิภพ • หอกปะทุตามแนวรอยแยก 4 ระลอก"],
	&"mage": ["ปริซึมเวท • ยิงพลัง 4 ธาตุใส่เป้าหมายเดียว", "คุกผลึกเหมันต์ • ชะลอในวง ผลึกระเบิด 2 จังหวะ", "บรรจบแห่งดวงดาว • ดึงศัตรูทั่วไปเข้าศูนย์กลาง ระเบิด 3 ระลอก", "โนวากำเนิดธาตุ • รวม 4 ธาตุเป็นแกนพลัง ปล่อยคลื่น 4 ระลอก"],
	&"priest": ["สายใยศักดิ์สิทธิ์ • แสงเชื่อมศัตรูสูงสุด 5 ตัว ฟื้น HP ทีม 12%", "ปีกพิทักษ์เซราฟ • โล่ทีมดูดซับ 25% ของ HP สูงสุด นาน 1 นาที", "วิหารศักดิ์สิทธิ์ • วงฟื้น HP 6% ทุก 2 วิ นาน 10 วิ และต้านความเสียหาย 15% นาน 1 นาที", "รุ่งอรุณแห่งการกอบกู้ • คลื่นศักดิ์สิทธิ์ 3 ครั้ง ทำดาเมจหมู่และฟื้น HP ทีมรวม 30%"],
	&"summoner": ["ราชาวานรวายุ • อัญเชิญราชาวานรแห่งสายลม 2 นาที ฟาดกระบองระยะประชิด • สกิล 1 พายุวานร โจมตีหมู่รอบตัว • สกิล 2 กระบองฟาดพื้น โจมตีหมู่และมึน 5 วิ", "กระแสเลวีอาธาน • อสูรทะเลและคลื่นกวาดด้านหน้า 3 ครั้ง", "ราชสำนักภูต • ผู้ร่ายและทีมโจมตี +55% ป้องกัน +40% นาน 1 นาที", "โพไซดอนจ้าวสมุทร • อัญเชิญจ้าวสมุทร 2 นาที ยิงลูกน้ำระยะไกล • สกิล 1 คลื่นน้ำวน โจมตีหมู่และมึน 5 วิ • สกิล 2 ผลึกน้ำแข็ง โจมตีหมู่และแช่แข็ง 5 วิ • คลื่นยักษ์ก่อนจากไป"],
	&"defender": ["โล่ไททันพิฆาต • ทุบพื้นด้วยโล่ยักษ์ 2 จังหวะ มึน 1.5 วิ", "โล่พิพากษาเด้ง • ขว้างโล่แสงถล่มพื้นที่ 3 ครั้ง ลดเกราะ 20% นาน 6 วิ", "อีจิสอมตะ • ทีมในระยะลดความเสียหาย 30% ป้องกัน +50% โล่ดูดซับ 20% ของ HP นาน 1 นาที", "ปราการสวรรค์ • ต้องสวมปีก บินขึ้นแล้วกระแทกโล่แสงยักษ์ลงพื้น 4 ระลอก ศัตรูมึนและหันมาโจมตีคุณ"],
	&"assassin": ["คมเงาฉีกสะบั้น • ฟันมีดคู่ไขว้เป็นกากบาทรอบตัว 2 จังหวะ ศัตรูติดเลือดไหล 5 วิ", "ประหารเงา • ฟันเป้าหมายเดียวต่อเนื่อง 6 ฮิต ฮิตสุดท้ายแรงสุด ลดเกราะ 20% นาน 6 วิ", "ม่านราตรี • ทีมในระยะคริติคอล +20% หลบ +15% โจมตี +40% นาน 1 นาที", "บทเพลงสุริยคราส • ต้องสวมปีก บินขึ้นกลางฟ้ามืด โปรยมีดเงาลงพื้นที่ 5 ระลอก ศัตรูมึน 1.5 วิ"],
	&"darklord": ["นรกโกลาหล • คทาปักพื้น เพลิงมืดปะทุเป็นวงรอบตัว 2 จังหวะ ศัตรูติดไฟ 5 วิ", "ราชันอีกา • อีกาเงายักษ์โฉบเป้าหมายเดียว 6 ครั้ง ครั้งสุดท้ายแรงสุด ลดเกราะ 20% นาน 6 วิ", "อาณาจักรแห่งลอร์ด • ทีมในระยะโจมตี +45% ป้องกัน +35% คริติคอล +10% นาน 1 นาที", "มหาวิบัติจักรพรรดิ • ต้องสวมผ้าคลุม ลอยขึ้นกลางฟ้า ฟาดสายฟ้าและเพลิงมืดลงพื้นที่ 5 ระลอก ศัตรูมึน 1.5 วิ"],
	&"bard": ["โหมโรงแสงดาว • โน้ตดาวตกถล่มพื้นที่เป้าหมาย 3 จังหวะ ศัตรูอ่อนแรง 15% นาน 6 วิ", "โซนาตาสลายใจ • ยิงโน้ตใส่เป้าหมายเดียวต่อเนื่อง 6 จังหวะ จังหวะสุดท้ายแรงสุด เกราะแตก 25% นาน 8 วิ", "เวทีสรวงสวรรค์ • ไม่ใช่เพลง ใช้คู่กับเพลงได้ ทีมในระยะโจมตี +45% ป้องกัน +35% คริ +10% ลดดาเมจ 8% นาน 1 นาที", "อังกอร์แห่งจักรวาล • ต้องสวมปีก บินขึ้นบรรเลงกลางฟ้า ห่าดาวโน้ต 5 ระลอกถล่มพื้นที่ มึน 1.5 วิ ศัตรูอ่อนแรง 20% นาน 8 วิ"],
}

static func pool(cls: StringName) -> Array:
	var out: Array = []
	if not IDS.has(cls): return out
	for i in 4:
		var melee := cls in [&"warrior", &"lancer", &"defender", &"assassin", &"darklord"]
		var s := {"id": IDS[cls][i], "name": NAMES[cls][i], "desc": DESCS[cls][i], "class": cls,
			"level": 100, "star": (i + 1) * 50, "mp": [100, 140, 170, 240][i], "cd": [14.0, 19.0, 32.0, 48.0][i],
			"shape": "blast", "range": 12.0, "radius": 6.5 + i * 0.6, "mult": [15.0, 23.0, 25.0, 38.0][i],
			"hit_delay": [0.48, 0.62, 0.8, 1.2][i], "anim": "2H_Melee_Attack_Stab" if cls == &"lancer" else "Block_Attack" if cls == &"defender" else "Dualwield_Melee_Attack_Chop" if cls == &"assassin" else "Spellcast_Raise" if cls == &"darklord" else "Spellcast_Raise" if cls == &"bard" else "1H_Melee_Attack_Chop" if melee else "2H_Ranged_Shoot" if cls == &"archer" else "Spellcast_Raise",
			"vfx": &"light", "color": Color("ffd36b") if cls == &"warrior" else Color("a8d0ff") if cls == &"defender" else Color("b58cff") if cls == &"assassin" else Color("e8b64a") if cls == &"darklord" else Color("ff9ad2") if cls == &"bard" else Color("86e4ff") if cls in [&"archer", &"lancer"] else Color("c4a1ff") if cls == &"mage" else Color("fff0b0") if cls == &"priest" else Color("79dfce"),
			"icon": "star", "gesture": "thrust" if cls == &"lancer" else "cleave" if melee else "aim" if cls == &"archer" else "raise"}
		match String(s.id):
			"lionfang_cleave": s.merge({"shape":"burst", "range":5.0, "radius":7.0, "gesture":"cross_cut"}, true)
			"crown_breaker": s.merge({"shape":"single", "range":3.5, "mult":27.0, "gesture":"execution", "fx":{"shred": [0.2,6.0]}}, true)
			"royal_vanguard": s.merge({"shape":"self", "mult":0.0, "gesture":"ward", "fx":{"buff":{"def":0.6,"guard":0.22,"secs":60.0}}},true)
			"celestial_swordfall": s.merge({"requires_wings":true,"hit_delay":1.6,"gesture":"raise", "radius":8.0},true)
			"moonpiercer": s.merge({"shape":"single","range":14.0,"line":true,"width":1.5,"length":18.0},true)
			"hunters_verdict": s.merge({"shape":"single","range":14.0,"mult":27.0,"gesture":"volley"},true)
			"sylph_step": s.merge({"shape":"self","mult":0.0,"gesture":"weave","fx":{"buff":{"atk":0.35,"speed":0.25,"dodge":0.15,"secs":60.0}}},true)
			"celestial_hunt": s["gesture"]="skyshot"
			"spiral_impaler": s.merge({"shape":"single","range":6.0,"line":true,"width":1.7,"length":13.0},true)
			"heartseeker": s.merge({"shape":"single","range":4.8,"mult":27.0},true)
			"aegis_formation": s.merge({"shape":"self","mult":0.0,"gesture":"ward","fx":{"buff":{"def":0.45,"guard":0.28,"secs":60.0}}},true)
			"worldsplitter": s.merge({"shape":"burst","radius":10.0,"gesture":"ground_slam"},true)
			"arcane_prism": s.merge({"shape":"single","range":12.0,"gesture":"bolt"},true)
			"crystal_prison": s["fx"]={"slow":4.0}
			"astral_convergence": s["gesture"]="channel"
			"genesis_nova": s["gesture"]="channel"
			"sanctified_chain": s.merge({"shape":"chain","hits":5,"mult":17.0,"gesture":"bolt"},true)
			"seraph_aegis": s.merge({"shape":"self","mult":0.0,"gesture":"prayer","fx":{"buff":{"shield":0.25,"secs":60.0}}},true)
			"sacred_sanctuary": s.merge({"shape":"self","mult":0.0,"gesture":"prayer","radius":8.0,"fx":{"buff":{"guard":0.15,"secs":60.0}}},true)
			"dawn_salvation": s["gesture"]="channel"
			"moonwolf_pact": s.merge({"shape":"summon","gesture":"invoke","mult":16.0,"summon":{"kind":"wind_king","count":1,"secs":120.0}},true)
			"leviathan_surge": s.merge({"shape":"burst","radius":10.0,"mult":28.0,"gesture":"raise"},true)
			"spirit_court": s.merge({"shape":"self","mult":0.0,"gesture":"invoke","fx":{"buff":{"atk":0.55,"def":0.4,"secs":60.0}}},true)
			"titan_shieldbreak": s.merge({"shape":"burst", "range":5.0, "radius":7.0, "gesture":"ground_slam", "fx":{"stun":1.5}}, true)
			"judgment_rebound": s.merge({"shape":"blast", "range":12.0, "radius":6.0, "gesture":"cleave", "fx":{"shred":[0.2,6.0]}}, true)
			"eternal_aegis": s.merge({"shape":"self", "mult":0.0, "gesture":"ward", "radius":8.0, "fx":{"buff":{"guard":0.3, "def":0.5, "shield":0.2, "secs":60.0}}}, true)
			"heavens_bulwark": s.merge({"shape":"burst", "requires_wings":true, "hit_delay":1.3, "radius":10.0, "gesture":"ground_slam", "fx":{"stun":1.5, "taunt":4.0}}, true)
			"umbral_lacerate": s.merge({"shape":"burst", "range":5.0, "radius":5.0, "mult":7.5, "gesture":"cross_cut", "fx":{"burn":[0.35,5.0]}}, true)
			"shadow_execution": s.merge({"shape":"single", "range":3.6, "mult":27.0, "gesture":"execution", "fx":{"shred":[0.2,6.0]}}, true)
			"veil_of_night": s.merge({"shape":"self", "mult":0.0, "gesture":"weave", "radius":8.0, "anim":"Dodge_Backward", "fx":{"buff":{"crit":0.2, "dodge":0.15, "atk":0.4, "secs":60.0}}}, true)
			"eclipse_requiem": s.merge({"shape":"burst", "requires_wings":true, "hit_delay":1.4, "radius":6.5, "mult":18.0, "gesture":"raise", "fx":{"stun":1.5}}, true)
			"chaos_inferno": s.merge({"shape":"burst", "range":5.0, "radius":6.0, "mult":7.5, "gesture":"ground_slam", "fx":{"burn":[0.4,5.0]}}, true)
			"raven_sovereign": s.merge({"shape":"single", "range":10.0, "mult":27.0, "gesture":"bolt", "fx":{"shred":[0.2,6.0]}}, true)
			"lords_dominion": s.merge({"shape":"self", "mult":0.0, "gesture":"invoke", "radius":8.0, "anim":"Cheer", "fx":{"buff":{"atk":0.45, "def":0.35, "crit":0.1, "secs":60.0}}}, true)
			"imperial_cataclysm": s.merge({"shape":"blast", "requires_wings":true, "hit_delay":1.4, "radius":7.5, "mult":38.0, "gesture":"raise", "fx":{"stun":1.5}}, true)
			# Bard: the overture calls star-notes from the sky (raise), the sonata is a tense strum,
			# the stage a song (serenade) and the encore a long crescendo.
			"starlight_overture": s.merge({"shape":"blast", "range":12.0, "radius":6.5, "mult":14.0, "gesture":"raise", "fx":{"weaken":[0.15,6.0]}}, true)
			"heartbreak_sonata": s.merge({"shape":"single", "range":12.0, "mult":27.0, "gesture":"strum", "fx":{"shred":[0.25,8.0]}}, true)
			"celestial_stage": s.merge({"shape":"self", "mult":0.0, "gesture":"serenade", "radius":8.0, "anim":"Cheer", "fx":{"buff":{"atk":0.45, "def":0.35, "crit":0.1, "guard":0.08, "secs":60.0}}}, true)
			"cosmic_encore": s.merge({"shape":"blast", "requires_wings":true, "hit_delay":1.4, "radius":7.5, "mult":36.0, "gesture":"crescendo", "fx":{"stun":1.5, "weaken":[0.2,8.0]}}, true)
			"eclipse_sovereign": s.merge({"shape":"summon","gesture":"channel","mult":22.0,"summon":{"kind":"poseidon","count":1,"secs":120.0}},true)
		s["mult"] = float(s.mult) * ClassData.skill_tune(cls, 100, true, String(s.shape))
		out.append(s)
	return out

static func unlock_label(skill: Dictionary) -> String:
	return "ดาว %d" % int(skill.star) if skill.has("star") else "Lv.%d" % int(skill.get("level",1))
