extends SceneTree
## Skill-by-skill balance audit: every active skill of every class with its
## effective damage (after ClassData.damage_curve), what one cast is worth
## against one target and against a group, and how that compares with the
## other skills of the class unlocked at the same point.
##   godot --headless --path . -s res://tools/skill_audit.gd
## Columns: lv, kind, mult = multiplier of one hit on the main target,
## group = damage of one cast against a pack (fan/chain victims, chain decay,
## 3 monsters inside an area, 2 behind a pierce), /cd = group damage per
## second of cooldown, /mp = group damage per MP. The class block ends with
## the best single hit and the best three /cd values at each level band.

const BANDS := [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
## Summon.HIT_SHARE (that script needs the Game autoload, which -s scripts cannot see).
const SUMMON_HIT_SHARE := 0.14


func _init() -> void:
	for cls in ClassData.IDS:
		print("== %s" % cls)
		print("  %-22s %3s %-7s %5s %6s %6s %6s %4s   %s" % ["skill", "lv", "kind", "mult", "group", "/cd", "/mp", "mp", "notes"])
		var rows: Array = []
		for skill in ClassData.pool(cls):
			var row := _row(skill)
			rows.append(row)
			if row.group > 0.0:
				print("  %-22s %3d %-7s %5.1f %6.1f %6.2f %6.3f %4d   %s" % [row.id, row.lv, row.kind, row.mult, row.group, row.per_cd, row.per_mp, row.mp, row.notes])
			else:
				print("  %-22s %3d %-7s %5s %6s %6s %6s %4d   %s" % [row.id, row.lv, row.kind, "-", "-", "-", "-", row.mp, row.notes])
		for band in BANDS:
			var open := rows.filter(func(r): return r.group > 0.0 and r.lv <= band and r.star == 0)
			if open.is_empty():
				continue
			var best_hit := 0.0
			for r in open:
				best_hit = maxf(best_hit, float(r.mult))
			open.sort_custom(func(a, b): return a.per_cd > b.per_cd)
			var top := 0.0
			for i in mini(3, open.size()):
				top += float(open[i].per_cd)
			print("  band Lv.%3d: best hit %5.1f  top3 /cd %5.2f  (%s)" % [band, best_hit, top, ", ".join(open.slice(0, 3).map(func(r): return String(r.id)))])
		var stars := rows.filter(func(r): return r.star > 0 and r.group > 0.0)
		for r in stars:
			print("  star %3d: %-20s hit %5.1f  group %5.1f  /cd %5.2f" % [r.star, r.id, r.mult, r.group, r.per_cd])
	quit()


func _row(skill: Dictionary) -> Dictionary:
	var mult := float(skill.get("mult", 0.0))
	var shape := String(skill.shape)
	var cd := maxf(float(skill.cd), 0.1)
	var mp := int(skill.mp)
	var group := 0.0
	var notes: PackedStringArray = []
	var fx: Dictionary = skill.get("fx", {})
	match shape:
		"single":
			group = mult
			if skill.has("pierce"):
				group += mult * float(skill.pierce.get("k", 0.7)) * 2.0
				notes.append("pierce %d" % int(skill.pierce.n))
		"fan":
			group = mult * float(skill.hits)
			notes.append("%d arrows" % int(skill.hits))
		"chain":
			for i in int(skill.hits):
				group += mult * pow(0.85, i)
			notes.append("%d links" % int(skill.hits))
		"burst", "blast":
			group = mult * 3.0
			notes.append("r%.1f" % float(skill.get("radius", 0.0)))
		"summon":
			# Summon.HIT_SHARE of the multiplier per hit, every interval, for 2 minutes (capped at 45 s of fighting).
			var spec: Dictionary = skill.summon
			var hits := 45.0 / maxf(float(spec.get("interval", 1.0)), 0.3)
			group = mult * SUMMON_HIT_SHARE * hits * float(spec.get("count", 1))
			mult = mult * SUMMON_HIT_SHARE
			notes.append("x%d every %.1fs" % [int(spec.get("count", 1)), float(spec.get("interval", 1.0))])
	for key in ["stun", "slow", "burn", "taunt", "shred", "weaken"]:
		if fx.has(key):
			notes.append("%s %s" % [key, str(fx[key])])
	if fx.has("heal"):
		notes.append("heal %d%%" % int(float(fx.heal) * 100.0))
	if fx.has("buff"):
		var parts: PackedStringArray = []
		for key in fx.buff:
			# Flags such as "song" or "self_only" are bools, not strengths.
			if key != "secs" and (fx.buff[key] is float or fx.buff[key] is int):
				parts.append("%s %+d%%" % [key, int(round(float(fx.buff[key]) * 100.0))])
		notes.append("buff %s %ds" % [" ".join(parts), int(fx.buff.get("secs", 0))])
	return {"id": String(skill.id), "lv": int(skill.level), "star": int(skill.get("star", 0)), "kind": shape, "mult": mult, "group": group,
		"per_cd": group / cd, "per_mp": group / maxf(float(mp), 1.0), "mp": mp, "notes": " ".join(notes)}
