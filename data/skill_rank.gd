class_name SkillRank
## What each star (1-5) of a skill does, in one place: the hero's combat code
## reads its numbers from here and the Skill Master shows the same numbers, so
## the screen always matches what a cast really does.
##
## Every star raises the skill:
##   damage +15% (burn and summon hits too), area +8%, cooldown -3%,
##   heal +10% (beyond full HP the rest becomes a 1-minute shield), buff strength +8%, stun / slow / taunt time +6%,
##   summon HP +60%; chains and fans gain a target at ★3 and ★5,
##   multi-creature summons gain one at ★5. MP cost rises 4% a star.
## Passive skills add their bonus once per star.

const MAX := 5
const POWER_PER_STAR := 0.15
const MP_PER_STAR := 0.04
const CD_PER_STAR := 0.03
const RADIUS_PER_STAR := 0.08
const HEAL_PER_STAR := 0.10
const BUFF_PER_STAR := 0.08
const CONTROL_PER_STAR := 0.06
const SUMMON_HP_PER_STAR := 0.6
## HeroStats.SKILL_POWER and Summon.HIT_SHARE, kept here so the numbers on screen
## are the damage of one hit in % of ATK (those scripts need autoloads).
const SKILL_POWER := 0.4
const SUMMON_HIT_SHARE := 0.14
const BUFF_LABELS := {"atk": "โจมตี", "def": "ป้องกัน", "speed": "ความเร็ว", "crit": "คริ", "shield": "โล่", "reflect": "สะท้อน", "guard": "ลดดาเมจ", "dodge": "หลบ"}
const PASSIVE_LABELS := {"atk": "โจมตี", "def": "ป้องกัน", "hp": "HP สูงสุด", "mp": "MP สูงสุด", "crit": "คริ", "speed": "ความเร็ว", "dodge": "หลบ"}


static func _step(rank: int) -> float:
	return float(clampi(rank, 1, MAX) - 1)


static func power(rank: int) -> float:
	return 1.0 + POWER_PER_STAR * _step(rank)


static func mp_scale(rank: int) -> float:
	return 1.0 + MP_PER_STAR * _step(rank)


static func cd_scale(rank: int) -> float:
	return 1.0 - CD_PER_STAR * _step(rank)


static func radius_scale(rank: int) -> float:
	return 1.0 + RADIUS_PER_STAR * _step(rank)


static func heal_scale(rank: int) -> float:
	return 1.0 + HEAL_PER_STAR * _step(rank)


static func buff_scale(rank: int) -> float:
	return 1.0 + BUFF_PER_STAR * _step(rank)


static func control_scale(rank: int) -> float:
	return 1.0 + CONTROL_PER_STAR * _step(rank)


static func summon_hp_scale(rank: int) -> float:
	return 1.0 + SUMMON_HP_PER_STAR * float(maxi(rank, 1) - 1)


## Targets of a chain or arrows of a fan: +1 at ★3 and +1 at ★5.
static func hits(skill: Dictionary, rank: int) -> int:
	var base := int(skill.get("hits", 1))
	if String(skill.get("shape", "")) not in ["chain", "fan"]:
		return base
	return base + (1 if rank >= 3 else 0) + (1 if rank >= 5 else 0)


## Creatures a summon calls: one more at ★5 when the skill calls several.
static func summon_count(skill: Dictionary, rank: int) -> int:
	var base := int((skill.get("summon", {}) as Dictionary).get("count", 1))
	return base + (1 if rank >= 5 and base > 1 else 0)


static func mp(skill: Dictionary, rank: int) -> int:
	return int(ceil(float(skill.get("mp", 0)) * mp_scale(rank)))


static func cooldown(skill: Dictionary, rank: int) -> float:
	return float(skill.get("cd", 0.0)) * cd_scale(rank)


## The skill as cast at [param rank]: area, target count, heal, buff and control
## effects grown by the stars (damage grows through [method power]).
static func scaled(skill: Dictionary, rank: int) -> Dictionary:
	if rank <= 1:
		return skill
	var grown := skill.duplicate()
	if grown.has("radius"):
		grown["radius"] = float(skill.radius) * radius_scale(rank)
	if grown.has("hits"):
		grown["hits"] = hits(skill, rank)
	if skill.get("fx") is Dictionary and not (skill.fx as Dictionary).is_empty():
		grown["fx"] = scaled_fx(skill.fx, rank)
	return grown


static func scaled_fx(fx: Dictionary, rank: int) -> Dictionary:
	var out := fx.duplicate(true)
	if out.has("heal"):
		out["heal"] = minf(float(fx.heal) * heal_scale(rank), 1.0)
		var extra := overheal(fx, rank)
		if extra > 0.0:
			var buff: Dictionary = (out.get("buff", {}) as Dictionary).duplicate()
			if buff.is_empty():
				# A heal-only skill: its shield does not take one of the two buff slots.
				buff["overheal"] = true
			buff["shield"] = float(buff.get("shield", 0.0)) + extra
			buff["secs"] = float(buff.get("secs", 60.0))
			out["buff"] = buff
	for key in ["stun", "slow", "taunt"]:
		if out.has(key) and (out[key] is float or out[key] is int):
			out[key] = float(fx[key]) * control_scale(rank)
	if fx.get("buff") is Dictionary:
		var buff: Dictionary = out.buff
		for key in fx.buff:
			if key != "secs" and (fx.buff[key] is float or fx.buff[key] is int):
				buff[key] = float(buff[key]) - float(fx.buff[key]) + float(fx.buff[key]) * buff_scale(rank)
	return out


## The part of a heal past full HP at [param rank] (it becomes a shield).
static func overheal(fx: Dictionary, rank: int) -> float:
	return maxf(float(fx.get("heal", 0.0)) * heal_scale(rank) - 1.0, 0.0)


# --- what the Skill Master shows -----------------------------------------------

## One hit in % of ATK at [param rank] (summons: one creature's hit).
static func hit_percent(skill: Dictionary, rank: int) -> float:
	var mult := float(skill.get("mult", 0.0)) * SKILL_POWER * power(rank) * 100.0
	return mult * SUMMON_HIT_SHARE if String(skill.get("shape", "")) == "summon" else mult


## Rows of [label, [value at ★1 .. ★5]] for an active skill; only the rows that
## the skill has. Values are display strings.
static func table(skill: Dictionary) -> Array:
	var rows: Array = []
	var shape := String(skill.get("shape", ""))
	var fx: Dictionary = skill.get("fx", {}) if skill.get("fx") is Dictionary else {}
	if float(skill.get("mult", 0.0)) > 0.0:
		var label := "ดาเมจ/ฮิต (%ATK)" if shape != "summon" else "ดาเมจผู้ช่วย/ฮิต"
		rows.append([label, _each(func(r): return "%d%%" % int(round(hit_percent(skill, r))))])
	if fx.get("burn") is Array:
		rows.append(["ไฟเผา/วิ (%ATK)", _each(func(r): return "%d%%" % int(round(float(fx.burn[0]) * power(r) * 100.0)))])
	if shape in ["chain", "fan"] and skill.has("hits"):
		rows.append(["จำนวนเป้า" if shape == "chain" else "จำนวนลูกธนู", _each(func(r): return str(hits(skill, r)))])
	if skill.has("radius"):
		rows.append(["รัศมี (ม.)", _each(func(r): return "%.1f" % (float(skill.radius) * radius_scale(r)))])
	if shape == "summon":
		rows.append(["จำนวนตัว", _each(func(r): return str(summon_count(skill, r)))])
		rows.append(["HP ผู้ช่วย", _each(func(r): return "×%.1f" % summon_hp_scale(r))])
	if fx.has("heal"):
		rows.append(["ฟื้น HP", _each(func(r): return "%d%%" % int(round(minf(float(fx.heal) * heal_scale(r), 1.0) * 100.0)))])
		if overheal(fx, MAX) > 0.0:
			rows.append(["โล่จากฮีลเกิน", _each(func(r): return "-" if overheal(fx, r) <= 0.0 else "%d%% HP" % int(round(overheal(fx, r) * 100.0)))])
	if fx.get("buff") is Dictionary:
		for key in fx.buff:
			if key == "secs" or not BUFF_LABELS.has(key):
				continue
			var base := float(fx.buff[key])
			rows.append(["บัฟ" + String(BUFF_LABELS[key]), _each(func(r): return "+%d%%" % int(round(base * buff_scale(r) * 100.0)))])
	if fx.has("stun"):
		rows.append(["มึน (วิ)", _each(func(r): return "%.1f" % (float(fx.stun) * control_scale(r)))])
	if fx.has("slow"):
		rows.append(["ช้าลง (วิ)", _each(func(r): return "%.1f" % (float(fx.slow) * control_scale(r)))])
	if fx.has("taunt"):
		rows.append(["ยั่วยุ (วิ)", _each(func(r): return "%.1f" % (float(fx.taunt) * control_scale(r)))])
	rows.append(["คูลดาวน์ (วิ)", _each(func(r): return "%.1f" % cooldown(skill, r))])
	rows.append(["MP", _each(func(r): return str(mp(skill, r)))])
	return rows


## Rows for a passive skill: its bonus once per star.
static func passive_table(skill: Dictionary) -> Array:
	var rows: Array = []
	var bonus: Dictionary = skill.get("bonus", {})
	for key in bonus:
		var base := float(bonus[key])
		var label := "%s" % PASSIVE_LABELS.get(key, String(key))
		rows.append([label, _each(func(r): return "+%s%%" % _num(base * float(r) * 100.0))])
	return rows


## What one more star adds, e.g. "ดาเมจ/ฮิต (%ATK) 120% → 138%", one entry per
## row that changes ([] at ★5).
static func next_changes(rows: Array, rank: int) -> PackedStringArray:
	var out: PackedStringArray = []
	if rank >= MAX:
		return out
	var at := clampi(rank, 1, MAX) - 1
	for row in rows:
		var values: Array = row[1]
		if values[at] != values[at + 1]:
			out.append("%s %s → %s" % [row[0], values[at], values[at + 1]])
	return out


static func _each(value: Callable) -> Array:
	var out: Array = []
	for r in range(1, MAX + 1):
		out.append(String(value.call(r)))
	return out


static func _num(value: float) -> String:
	return str(int(round(value))) if absf(value - round(value)) < 0.05 else "%.1f" % value
