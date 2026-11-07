class_name PetData
extends RefCounted
## The village pets: one of three, chosen once per character at the pet keeper
## (ผู้ดูแลสัตว์เลี้ยง, next to the pet pen) and kept for good (profile["pet"]).
## The pet follows its hero everywhere it fights (fields, the tower, the raid, the guild
## war; not the 1v1 duels, see allowed_in) and fights on its own (Pet).
##
## Elements are theme only: a fire pet does not hit an earth monster harder, there is no
## element advantage anywhere (each kit just leans to its flavour: fire hits, water
## heals, earth guards).
##
## Power follows the hero: the pet's level is the hero's level and its ATK / HP / DEF /
## crit are shares of the hero's current stats (STAT formula in stats_for). Its eight
## skills unlock with the hero's level (UNLOCK_LEVELS) and cast themselves.

## Skill unlock levels, one per skill slot (the 8th is the ultimate).
const UNLOCK_LEVELS: Array[int] = [1, 10, 20, 35, 50, 65, 80, 100]
## Seconds a fallen pet takes to come back to its hero.
const RESPAWN := 30.0
## Seconds between two of the pet's basic hits.
const ATTACK_INTERVAL := 1.3
## The shortest gap between two of its skills (one skill at a time).
const SKILL_GAP := 1.6
const ORDER: Array[String] = ["fire", "water", "earth"]

## Each pet: name, element (theme), the model and how it is shown, its stat shares of
## the hero (atk / hp / def / crit), its fighting reach, and its eight skills.
##   model  a baked runtime GLB (tools/bake_pets.gd: model + KayKit clips named Idle,
##          Walk, Run, Attack, Skill1, Skill2, Hit, Death) or a MonsterVisual path.
##   skin   an optional repainted palette texture swapped onto the model ("" = its own).
## A pet's look is these entries only: to give a pet another model, point "model" (and
## "skin", or "" for none) at the new file and set its "height". Nothing else refers to
## the model.
##
## Skill kinds (Pet._cast): bolt (one target, from range), bite (melee on the target),
## cone (a fan in front of the pet), blast (a circle on the target), nova (a circle round
## the pet), line (a strip from the pet through the target), pull (blast that drags
## monsters in), owner_buff (a buff on the hero through its buff list, ally slot),
## owner_heal (heals the hero now), owner_hot (heals the hero and nearby allies over
## time), self_buff (on the pet itself; "taunt" pulls monsters onto it).
## power: multiplier of the pet's ATK per hit; cd: seconds; fx: burn [share of pet ATK
## per second, seconds], slow / stun seconds, knock metres.
const PETS := {
	"fire": {
		"id": "fire", "name": "คาอิจูเร็กซ์", "element": "fire", "element_name": "ธาตุไฟ",
		"desc": "เจ้าไดโนน้อยชุดเปลวเพลิง ดุดันสายโจมตี พ่นไฟเผาศัตรูทั้งฝูง",
		"model": "res://assets/models/pets/KaijuRex.glb", "skin": "res://assets/models/pets/skins/kaiju_rex_flame.png",
		"height": 1.45, "tint": Color.WHITE, "color": Color("ff7a2a"), "glow": Color("ffb347"),
		"ratios": {"atk": 0.40, "hp": 1.0, "def": 0.8, "crit": 0.5},
		"range": 2.2, "speed": 6.2,
		"skills": [
			{"id": "fireball", "name": "ลูกไฟ", "desc": "พ่นลูกไฟใส่ศัตรูหนึ่งตัวจากระยะไกล", "kind": "bolt", "power": 1.6, "cd": 5.0, "range": 9.0, "clip": "skill2"},
			{"id": "flame_bite", "name": "กัดเพลิง", "desc": "พุ่งกัดด้วยเขี้ยวไฟ ติดไฟไหม้ 4 วินาที", "kind": "bite", "power": 1.4, "cd": 8.0, "fx": {"burn": [0.15, 4.0]}, "clip": "attack"},
			{"id": "flame_breath", "name": "พ่นไฟ", "desc": "พ่นไฟเป็นรูปพัดใส่ศัตรูข้างหน้า", "kind": "cone", "power": 1.1, "cd": 10.0, "range": 6.0, "angle": 70.0, "clip": "skill2"},
			{"id": "fire_burst", "name": "ระเบิดเพลิง", "desc": "ระเบิดไฟเป็นวงรอบเป้าหมาย", "kind": "blast", "power": 1.5, "cd": 12.0, "radius": 3.5, "fx": {"burn": [0.1, 3.0]}, "clip": "skill1"},
			{"id": "rally", "name": "ปลุกพลัง", "desc": "คำรามปลุกใจเจ้าของ พลังโจมตี +10% 15 วินาที", "kind": "owner_buff", "cd": 40.0, "buff": {"atk": 0.10, "secs": 15.0}, "clip": "skill2"},
			{"id": "fire_armor", "name": "เกราะไฟ", "desc": "ห่อตัวด้วยเปลวไฟ ป้องกัน +30% สะท้อนความเสียหาย 25% และเผาศัตรูรอบตัว", "kind": "self_buff", "cd": 30.0, "buff": {"def": 0.3, "reflect": 0.25, "secs": 12.0}, "power": 0.6, "radius": 3.0, "fx": {"burn": [0.1, 4.0]}, "clip": "skill1"},
			{"id": "mini_meteor", "name": "อุกกาบาตน้อย", "desc": "เรียกอุกกาบาตลูกเล็กตกใส่เป้าหมาย สตัน 0.8 วินาที", "kind": "blast", "power": 2.6, "cd": 18.0, "radius": 4.0, "delay": 0.6, "fx": {"stun": 0.8}, "clip": "skill2"},
			{"id": "inferno", "name": "นรกเพลิง", "desc": "ท่าไม้ตาย: ทะเลเพลิง 3 ระลอกรอบเป้าหมาย พร้อมไฟไหม้", "kind": "blast", "power": 1.4, "hits": 3, "cd": 45.0, "radius": 6.0, "fx": {"burn": [0.2, 5.0]}, "clip": "skill1", "ultimate": true},
		],
	},
	"water": {
		"id": "water", "name": "โกเลมน้ำแข็ง", "element": "water", "element_name": "ธาตุน้ำ",
		"desc": "ยักษ์น้ำแข็งใจดี สายสนับสนุน ฮีลและกันดาเมจให้เจ้าของ",
		"model": "res://assets/models/pets/FrostGolem.glb", "skin": "",
		"height": 1.75, "tint": Color.WHITE, "color": Color("5cc8ff"), "glow": Color("bff4ff"),
		"ratios": {"atk": 0.30, "hp": 1.2, "def": 0.9, "crit": 0.5},
		"range": 2.4, "speed": 5.6,
		"skills": [
			{"id": "water_jet", "name": "สายน้ำ", "desc": "ฉีดสายน้ำใส่ศัตรูหนึ่งตัวจากระยะไกล", "kind": "bolt", "power": 1.4, "cd": 5.0, "range": 9.0, "clip": "attack"},
			{"id": "bubble", "name": "ฟองน้ำ", "desc": "ฟองน้ำแตกเป็นวงเล็ก ศัตรูเคลื่อนที่ช้าลง 3 วินาที", "kind": "blast", "power": 1.0, "cd": 9.0, "radius": 2.5, "fx": {"slow": 3.0}, "clip": "attack"},
			{"id": "owner_heal", "name": "ฮีลเจ้าของ", "desc": "รักษาเจ้าของ 12% ของ HP สูงสุด (เมื่อเลือดต่ำกว่า 75%)", "kind": "owner_heal", "cd": 14.0, "heal": 0.12, "below": 0.75, "clip": "skill1"},
			{"id": "water_shield", "name": "เกราะน้ำ", "desc": "โล่น้ำบนตัวเจ้าของ ดูดซับความเสียหาย 10% ของ HP สูงสุด 10 วินาที", "kind": "owner_buff", "cd": 30.0, "buff": {"shield": 0.10, "secs": 10.0}, "clip": "skill1"},
			{"id": "wave", "name": "คลื่นซัด", "desc": "คลื่นรูปพัดซัดศัตรูกระเด็นถอยหลัง", "kind": "cone", "power": 1.5, "cd": 12.0, "range": 7.0, "angle": 80.0, "fx": {"knock": 4.0}, "clip": "skill2"},
			{"id": "whirlpool", "name": "น้ำวน", "desc": "น้ำวนดูดศัตรูรอบเป้าหมายเข้าหากัน และช้าลง", "kind": "pull", "power": 1.4, "cd": 16.0, "radius": 4.5, "fx": {"slow": 3.0}, "clip": "skill2"},
			{"id": "cleansing_rain", "name": "ฝนชำระ", "desc": "ฝนรักษาเจ้าของและเพื่อนรอบตัว 3% ทุกวินาที 8 วินาที", "kind": "owner_hot", "cd": 35.0, "heal": 0.03, "every": 1.0, "ticks": 8, "clip": "skill1"},
			{"id": "tsunami", "name": "สึนามิ", "desc": "ท่าไม้ตาย: คลื่นยักษ์กวาดเป็นแนวยาว 2 ระลอก ศัตรูกระเด็นและช้าลง", "kind": "line", "power": 2.2, "hits": 2, "cd": 45.0, "range": 12.0, "width": 5.0, "fx": {"knock": 3.0, "slow": 3.0}, "clip": "skill2", "ultimate": true},
		],
	},
	"earth": {
		"id": "earth", "name": "ดรูอิดป่า", "element": "earth", "element_name": "ธาตุดิน",
		"desc": "ผู้พิทักษ์ป่าตัวน้อย ใช้เวทหินและพลังธรรมชาติ ทนทานสายแทงค์ ยั่วศัตรูและกันดาเมจให้เจ้าของ",
		"model": "res://assets/models/pets/GroveDruid.glb", "skin": "",
		"height": 1.4, "tint": Color.WHITE, "color": Color("8fc25a"), "glow": Color("c8f08a"),
		"ratios": {"atk": 0.32, "hp": 1.5, "def": 1.1, "crit": 0.5},
		"range": 2.4, "speed": 5.4,
		"skills": [
			{"id": "rock_throw", "name": "หินกระแทก", "desc": "ขว้างก้อนหินใส่ศัตรูหนึ่งตัวจากระยะไกล", "kind": "bolt", "power": 1.5, "cd": 5.0, "range": 9.0, "clip": "skill2", "projectile": "orb"},
			{"id": "root_bind", "name": "รากพัน", "desc": "รากไม้พันขาศัตรูรอบเป้าหมาย หยุดนิ่ง 0.8 วินาทีแล้วช้าลง", "kind": "blast", "power": 0.9, "cd": 10.0, "radius": 2.5, "fx": {"stun": 0.8, "slow": 3.0}, "clip": "skill1"},
			{"id": "stone_wall", "name": "กำแพงหิน", "desc": "กำแพงหินคุ้มกันเจ้าของ ความเสียหายที่ได้รับ -15% 10 วินาที", "kind": "owner_buff", "cd": 30.0, "buff": {"guard": 0.15, "secs": 10.0}, "clip": "skill1"},
			{"id": "quake", "name": "แผ่นดินไหว", "desc": "กระทืบพื้นสะเทือนรอบตัว ศัตรูมึน 1.2 วินาที", "kind": "nova", "power": 1.4, "cd": 16.0, "radius": 5.0, "fx": {"stun": 1.2}, "clip": "skill1"},
			{"id": "earth_spikes", "name": "หนามพื้นดิน", "desc": "หนามหินพุ่งจากพื้นเป็นแนวยาวไปทางเป้าหมาย", "kind": "line", "power": 1.8, "cd": 12.0, "range": 10.0, "width": 2.5, "clip": "skill2"},
			{"id": "nature_power", "name": "พลังธรรมชาติ", "desc": "พลังธรรมชาติฟื้นฟูเจ้าของและเพื่อนรอบตัว 2% ทุก 2 วินาที 10 วินาที", "kind": "owner_hot", "cd": 30.0, "heal": 0.02, "every": 2.0, "ticks": 5, "clip": "skill1"},
			{"id": "stone_armor", "name": "เกราะหิน", "desc": "ร่างกลายเป็นหิน ป้องกัน +50% ความเสียหายที่ได้รับ -25% และยั่วศัตรูรอบตัวมาตีตัวเอง", "kind": "self_buff", "cd": 30.0, "buff": {"def": 0.5, "guard": 0.25, "secs": 15.0}, "taunt": 4.0, "radius": 6.0, "clip": "skill2"},
			{"id": "mountain_fall", "name": "ภูผาถล่ม", "desc": "ท่าไม้ตาย: ภูเขาหินถล่มทับวงกว้าง ศัตรูมึน 1.5 วินาที", "kind": "blast", "power": 3.2, "cd": 45.0, "radius": 6.0, "delay": 0.7, "fx": {"stun": 1.5}, "clip": "skill2", "ultimate": true},
		],
	},
}


static func exists(id: String) -> bool:
	return PETS.has(id)


static func get_pet(id: String) -> Dictionary:
	return PETS.get(id, {})


## The hero's pet id ("" before one is chosen).
static func chosen(profile: Dictionary) -> String:
	var id: Variant = profile.get("pet", "")
	return String(id) if id is String and PETS.has(id) else ""


## The skills of `id` the hero has unlocked at `level`.
static func unlocked(id: String, level: int) -> Array:
	var out: Array = []
	var skills: Array = get_pet(id).get("skills", [])
	for i in skills.size():
		if level >= UNLOCK_LEVELS[i]:
			out.append(skills[i])
	return out


## The level skill `index` (0-7) unlocks at.
static func unlock_level(index: int) -> int:
	return UNLOCK_LEVELS[clampi(index, 0, UNLOCK_LEVELS.size() - 1)]


# ---------------------------------------------------------------------------
# Forms: the pet grows with its owner (look only)
# ---------------------------------------------------------------------------

## A pet grows through six forms with its owner's level and, at Lv.100, its owner's
## stars (★, the paragon level): young (Lv.1-34), grown (Lv.35-79), full-grown (Lv.80+),
## then the star forms ★100 awakened, ★200 holy and ★300 god (the ★ of the hero's God
## promotion, JobData.GOD_STARS). Each form is a little bigger (STAGE_SCALE, capped so the
## god form is not absurd) and the hero's own pet wears more layers of light (PetForm).
## The forms are look only: the pet's power still follows the owner's level and stats
## (stats_for), and nothing is saved for them (the owner's level and ★ decide).
const STAGE_LEVELS := [1, 35, 80, 100, 100, 100]
const STAGE_STARS := [0, 0, 0, 100, 200, 300]
const STAGE_NAMES := ["ร่างเด็ก", "ร่างโต", "ร่างเต็มวัย", "ร่างตื่นรู้", "ร่างศักดิ์สิทธิ์", "ร่างเทพ"]
const STAGE_SCALE := [0.72, 1.0, 1.35, 1.45, 1.55, 1.65]
## The first star form and the god form.
const STAR_STAGE := 3
const GOD_STAGE := 5
## The title a pet in its god form wears over its name, by element.
const GOD_TITLES := {"fire": "เทพอัคคี", "water": "เทพวารี", "earth": "เทพพนาไพร"}


## The form (0 young .. 5 god) of a pet whose owner is Lv.[param level] with
## [param stars] ★.
static func stage_for(level: int, stars := 0) -> int:
	var stage := 0
	for i in STAGE_LEVELS.size():
		if level >= int(STAGE_LEVELS[i]) and stars >= int(STAGE_STARS[i]):
			stage = i
	return stage


static func stage_scale(level: int, stars := 0) -> float:
	return float(STAGE_SCALE[stage_for(level, stars)])


static func stage_name(level: int, stars := 0) -> String:
	return form_name(stage_for(level, stars))


static func form_name(stage: int) -> String:
	return String(STAGE_NAMES[clampi(stage, 0, STAGE_NAMES.size() - 1)])


## What form [param stage] asks of the owner: "Lv.35", "Lv.100 ★200".
static func form_requirement(stage: int) -> String:
	var i := clampi(stage, 0, STAGE_LEVELS.size() - 1)
	var stars := int(STAGE_STARS[i])
	return "Lv.%d%s" % [int(STAGE_LEVELS[i]), " ★%d" % stars if stars > 0 else ""]


## The hero's ★ in [param profile] (its paragon level), read without touching it.
static func profile_stars(profile: Dictionary) -> int:
	var p: Variant = profile.get("paragon", {})
	return maxi(0, int((p as Dictionary).get("level", 0))) if p is Dictionary else 0


## The Thai line shown when pet [param id] grows into form [param stage] while its hero
## plays.
static func growth_line(id: String, stage: int) -> String:
	var pet_name := String(get_pet(id).get("name", ""))
	match stage:
		3:
			return "%s ตื่นรู้แล้ว! พลังธาตุลุกโชนทั่วร่าง (ร่างตื่นรู้ ★100)" % pet_name
		4:
			return "%s จุติเป็นร่างศักดิ์สิทธิ์! (★200)" % pet_name
		5:
			return "%s ตื่นรู้เป็นร่างเทพ! %s ลงมาจุติ (★300)" % [pet_name, String(GOD_TITLES.get(id, "เทพ"))]
	return "%s เติบโตเป็น%sแล้ว!" % [pet_name, form_name(stage)]


## The pet's stats from its hero's: level = the hero's level, ATK / HP / DEF / crit are
## the pet's shares (ratios) of the hero's current atk / max_hp / def / crit. A level-1
## hero's pet keeps a small floor (HP 120, ATK 4) so it is not a one-hit paper target.
## Pets were too easy to drop: every hit on a pet is cut to this share, and a pet that
## has not been hit for REGEN_AFTER seconds gets REGEN of its max HP back each second.
const TAKEN := 0.6
const REGEN := 0.02
const REGEN_AFTER := 4.0


static func stats_for(id: String, owner_stats: Dictionary, level: int) -> Dictionary:
	var r: Dictionary = get_pet(id).get("ratios", {"atk": 0.35, "hp": 0.5, "def": 0.5, "crit": 0.5})
	return {
		"level": maxi(1, level),
		"atk": maxf(4.0, float(owner_stats.get("atk", 10.0)) * float(r.atk)),
		"max_hp": maxi(120, int(round(float(owner_stats.get("max_hp", 400)) * float(r.hp)))),
		"def": float(owner_stats.get("def", 1.0)) * float(r.def),
		"crit": float(owner_stats.get("crit", 0.0)) * float(r.crit),
	}


## Whether pets come along in zone `data` (ZoneData entry): everywhere with fighting or
## not (they walk with their owners in the village too), except the PvP zones: the 1v1
## duels (ranked duels and real-player duels: zone "pvp") stay hero against hero, and in
## the guild war (zone "guildwar") the players fight on their own, nobody's pet comes.
static func allowed_in(data: Dictionary) -> bool:
	return not bool(data.get("pvp", false)) and not bool(data.get("guildwar", false))


# ---------------------------------------------------------------------------
# Everyone else's pet: every AI player has one, picked from its name
# ---------------------------------------------------------------------------

## The pet of an AI player (a world player, a party member, a guild fighter) named
## [param player_name]: one of ORDER picked from the name alone, so every device shows the
## same pet for the same player, the three kinds spread about evenly. "" for no name.
static func of_player(player_name: String) -> String:
	if player_name == "":
		return ""
	return ORDER[posmod(hash("pet|" + player_name), ORDER.size())]


## The pet shown with a real online player: the id their game sent (Online `pet`), only
## when it is a pet; "" (none shown) otherwise.
static func clean_id(raw: Variant) -> String:
	if (raw is String or raw is StringName) and PETS.has(String(raw)):
		return String(raw)
	return ""


# ---------------------------------------------------------------------------
# The starter quest: รับสัตว์เลี้ยงคู่ใจ
# ---------------------------------------------------------------------------

## A hero without a pet is sent to the pet keeper once the newcomer tutorial is over
## (or skipped: from Tutorial.SKIP_AT on), new heroes and older characters alike. The
## quest is done when the pet is chosen (Game.choose_pet), which pays QUEST_GOLD and the
## potions once (profile flag QUEST_FLAG).
const QUEST_NAME := "รับสัตว์เลี้ยงคู่ใจ"
const QUEST_FLAG := "pet_q"
const QUEST_GOLD := 500
const QUEST_ITEMS := [["hp_s", 5], ["mp_s", 3]]
const QUEST_TEXT := "ไปหาผู้ดูแลสัตว์เลี้ยงที่คอกสัตว์เลี้ยง (ย่านฝึกยุทธ์ ฝั่งตะวันตกของหมู่บ้าน) แล้วเลือกสัตว์เลี้ยงคู่ใจ 1 ตัว"


## Whether the starter quest is open for [param profile]: no pet yet and the tutorial
## finished or skipped.
static func quest_open(profile: Dictionary) -> bool:
	if profile.is_empty() or chosen(profile) != "":
		return false
	var flags: Variant = profile.get("flags", {})
	var tut := int((flags as Dictionary).get(Tutorial.FLAG, 0)) if flags is Dictionary else 0
	return tut >= Tutorial.DONE or int(profile.get("level", 1)) >= Tutorial.SKIP_AT


## The Thai lines a skill shows in the selection screen: "Lv.20 · พ่นไฟ — ..."
static func skill_line(skill: Dictionary, index: int) -> String:
	return "Lv.%d · %s%s — %s" % [unlock_level(index), String(skill.name), " (ท่าไม้ตาย)" if bool(skill.get("ultimate", false)) else "", String(skill.desc)]
