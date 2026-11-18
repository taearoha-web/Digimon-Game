class_name StarMoves
extends RefCounted
## The signature moves of the ordinary and elite monsters of the star regions
## (★1-200, StarMonsters) and of the lotus sanctum (★200, DivineRegionData),
## keyed by their template "behavior". MonsterMove runs them; this file holds
## the plans: pure functions of the positions locked when the move starts, so
## nothing chases a dodging player and tests can inspect every shape.
##
## A plan is {"parts": [...], "dash"?: {...}, "leap"?: {...}, "shots"?: [...]}.
## A part is one telegraphed area:
##   shape  "circle" (pos, r) | "cone" (pos = apex, dir, r, half = half-angle)
##          | "line" (pos = start, dir, len, w) | "ring" (pos, r_in, r)
##   at     seconds after the start when it lands (the warning is drawn from 0)
##   dmg    x the monster's attack; an actor is hit once per wave, MAX_HITS a move
##   wave   int; fx: the impact effect; slow / knock (m) on hit;
##   linger seconds the area stays a hazard afterwards (tick: x atk each 0.8 s)
## A shot is a visible projectile {from_up, to, t0, t1, kind, arc} that arrives
## exactly when its part lands (it is art: the part decides the hit).
## Bosses keep their own moves (StarAttack / DivineAttack special, BossAttack).

const MAX_HITS := 2
const HAZARD_TICK := 0.8
## Damage bands a move must stay in (x atk) for one actor that ignores it:
## the first blow stays a basic attack, the whole move near one (elites a bit more).
const NORMAL_TOTAL := 1.25
const ELITE_TOTAL := 1.6
const FIRST_HIT := 1.0
## The shortest warning for ordinary monsters and for elites (seconds).
const NORMAL_WARN := 0.8
const ELITE_WARN := 0.9

## th: the move's Thai name (shown for elites and sent with the online cast).
const MOVES := {
	"pounce": {"th": "ตะครุบ"},
	"headbutt": {"th": "พุ่งขวิดใบไม้"},
	"charge": {"th": "พุ่งชน"},
	"pollen": {"th": "ละอองเกสร"},
	"ice_bolt": {"th": "หอกน้ำแข็ง"},
	"wind_bolt": {"th": "ลมกรรโชก"},
	"cleave": {"th": "ฟันกวาด"},
	"void_bolt": {"th": "ลูกแก้วจันทร์ดับ"},
	"lotus_bolt": {"th": "ลำแสงกลีบบัว"},
	"divine_slam": {"th": "ทุบพสุธาเทวะ"},
	"jade_charge": {"th": "มังกรหยกพุ่งทะยาน"},
	"lotus_leap": {"th": "กระโจนใบบัว"},
	"jade_palm": {"th": "ฝ่ามือหยกสามกระบวน"},
}
## Elite versions: a bigger or extra phase of the same move.
const ELITE_TH := {
	"pounce": "ตะครุบสองจังหวะ",
	"charge": "พุ่งชนระเบิด",
	"pollen": "บุปผาเกสรวิญญาณ",
	"cleave": "ฟันกวาดผ่าพสุธา",
	"void_bolt": "เก็บเกี่ยวจันทร์ดับ",
}

## Region palettes: [main, accent, deep].
const PALETTES := {
	"dawn": [Color("ffa8c8"), Color("ffd76a"), Color("9be070")],
	"crystal": [Color("a9eaff"), Color("f2fdff"), Color("5fa8ff")],
	"sky": [Color("ffe39a"), Color("fffaf0"), Color("bfe6ff")],
	"eclipse": [Color("b07aff"), Color("ffe8b0"), Color("3a2160")],
	"lotus": [Color("ffb8e4"), Color("7fe3c0"), Color("ffd98a")],
}
const REGION_STYLE := {&"dawn_forest": "dawn", &"crystal_valley": "crystal", &"sky_citadel": "sky", &"eclipse_realm": "eclipse"}


static func knows(template: Dictionary) -> bool:
	return not bool(template.get("boss", false)) and MOVES.has(String(template.get("behavior", "")))


static func title(template: Dictionary) -> String:
	var move := String(template.get("behavior", ""))
	if bool(template.get("elite", false)) and ELITE_TH.has(move):
		return String(ELITE_TH[move])
	return String(MOVES.get(move, {}).get("th", move))


## dawn / crystal / sky / eclipse from the star region, lotus for the sanctum.
static func style_of(template: Dictionary) -> String:
	return String(REGION_STYLE.get(StringName(template.get("region", "")), "lotus"))


static func palette(style: String) -> Array:
	return PALETTES.get(style, PALETTES.lotus)


## Every behaviour a star or lotus normal / elite uses: {behavior: [monster ids]}.
static func used() -> Dictionary:
	var out := {}
	var lists := [StarMonsters.MONSTERS, DivineRegionData.MONSTERS]
	for list in lists:
		for id in list:
			var t: Dictionary = list[id]
			if bool(t.get("boss", false)):
				continue
			var move := String(t.get("behavior", ""))
			if not out.has(move):
				out[move] = []
			(out[move] as Array).append(id)
	return out


# ---------------------------------------------------------------------------
# Plans
# ---------------------------------------------------------------------------

## [param body]: the monster's body radius (melee reach); [param ranged]: its attack kind.
static func plan(move: String, elite: bool, o: Vector3, f: Vector3, h: Vector3, body: float, rng: RandomNumberGenerator) -> Dictionary:
	o = o * Vector3(1, 0, 1)
	h = h * Vector3(1, 0, 1)
	f = (f * Vector3(1, 0, 1)).normalized() if (f * Vector3(1, 0, 1)).length_squared() > 0.0001 else Vector3.FORWARD
	var side := Vector3(-f.z, 0, f.x)
	var reach := (h - o).length()
	var parts: Array[Dictionary] = []
	var out := {"parts": parts}
	var shots: Array[Dictionary] = []
	match move:
		"pounce":
			# A hop in a high arc onto the target; the elite pack leader springs twice.
			var land := o + f * clampf(reach - 0.2, 1.5, 5.0)
			if not elite:
				parts.append(_circle(land, 2.0, 0.85, 1.0, 0, "pounce"))
				out["leap"] = {"to": land, "t0": 0.47, "t1": 0.85, "height": 1.6}
			else:
				var second := land + f * 3.6
				parts.append(_circle(land, 2.2, 0.95, 0.8, 0, "pounce"))
				var p2 := _circle(second, 2.5, 1.6, 0.6, 1, "pounce_big")
				p2["slow"] = 1.5
				parts.append(p2)
				out["leap"] = {"to": land, "t0": 0.55, "t1": 0.95, "height": 1.8, "to2": second, "t2": 1.25, "t3": 1.6}
		"headbutt":
			# Head down, the leafy spirit rams a short lane and throws whoever it meets.
			var lane := _line(o + f * 0.4, f, 4.4, 1.9, 0.9, 1.0, 0, "headbutt")
			lane["knock"] = 3.0
			parts.append(lane)
			out["dash"] = {"to": o + f * clampf(reach - 0.8, 0.5, 3.2), "t0": 0.62, "t1": 0.9}
		"charge":
			# A straight rush through the target and beyond; elites burst at the end of it.
			var length := clampf(reach + 2.0, 4.0, 8.5)
			var rush := _line(o, f, length, 2.2, 1.0 if not elite else 1.05, 1.0 if not elite else 0.85, 0, "charge")
			rush["knock"] = 2.2
			parts.append(rush)
			var stop := o + f * (length - 0.8)
			out["dash"] = {"to": stop, "t0": rush.at - 0.35, "t1": rush.at}
			if elite:
				parts.append(_circle(o + f * length, 2.8, 1.55, 0.55, 1, "charge_burst"))
		"pollen":
			# Pollen balls lobbed onto the target and beside it; the clouds stay and slow.
			if not elite:
				var spots: Array[Vector3] = [h]
				spots.append_array(_around(h, 2, 2.4, 3.0, rng))
				for p in spots:
					var cloud := _circle(p, 1.6, 1.0, 0.9, 0, "pollen")
					cloud["slow"] = 1.5
					cloud["linger"] = 2.5
					cloud["tick"] = 0.1
					parts.append(cloud)
			else:
				var heart := _circle(h, 1.9, 1.0, 0.75, 0, "pollen")
				heart["slow"] = 1.5
				heart["linger"] = 3.0
				heart["tick"] = 0.1
				parts.append(heart)
				for p in _ring_points(h, 3.3, 4, rng.randf() * TAU):
					var petal := _circle(p, 1.7, 1.45, 0.5, 1, "pollen_bloom")
					petal["slow"] = 1.5
					parts.append(petal)
		"ice_bolt":
			# An ice lance lobbed at the target: it shatters and leaves a slowing frost patch.
			var frost := _circle(h, 1.9, 1.0, 1.0, 0, "ice")
			frost["slow"] = 2.0
			frost["linger"] = 2.5
			frost["tick"] = 0.08
			parts.append(frost)
		"wind_bolt":
			# A fan of wind (and gold feathers) blasts out toward the target and blows it back.
			var gust := _cone(o, f, clampf(reach + 2.5, 5.0, 9.5), deg_to_rad(21.0), 0.95, 1.0, 0, "gust")
			gust["knock"] = 3.2
			parts.append(gust)
		"cleave":
			# A wide sweep in front; elite captains follow it with an overhead blow down a lane.
			var r := 2.4 + body * 1.0
			parts.append(_cone(o, f, r, deg_to_rad(62.0), 0.85 if not elite else 0.9, 1.0 if not elite else 0.8, 0, "cleave"))
			if elite:
				var rend := _line(o + f * 0.6, f, 6.6, 1.9, 1.5, 0.6, 1, "rend")
				rend["knock"] = 1.5
				parts.append(rend)
		"void_bolt":
			# A dead-moon orb drops on the target and bursts; then its ring of void flares outward.
			if not elite:
				parts.append(_circle(h, 1.8, 1.0, 0.8, 0, "void"))
				parts.append(_ring(h, 1.8, 3.4, 1.5, 0.45, 1, "void_ring"))
			else:
				parts.append(_circle(h, 1.7, 1.0, 0.8, 0, "void"))
				for k in [-1.0, 1.0]:
					parts.append(_circle(h + side * (3.1 * k) - f * 1.1, 1.7, 1.0, 0.8, 0, "void"))
				parts.append(_ring(h, 2.4, 4.4, 1.65, 0.6, 1, "void_ring"))
		"lotus_bolt":
			# A thin guide line, then a beam of petals down it.
			parts.append(_line(o + f * 0.5, f, clampf(reach + 2.0, 5.0, 10.0), 1.5, 1.0, 1.0, 0, "beam"))
		"divine_slam":
			# The temple golem rises and pounds the floor, then a jade wave rolls out from it.
			var at := o + f * 1.6
			var slam := _circle(at, 3.0, 1.1, 0.85, 0, "slam")
			slam["knock"] = 2.6
			parts.append(slam)
			var wave := _ring(at, 3.0, 5.8, 1.65, 0.55, 1, "slam_ring")
			wave["slow"] = 1.5
			parts.append(wave)
			out["leap"] = {"to": o, "t0": 0.35, "t1": 1.1, "height": 1.2}
		"jade_charge":
			# The jade dragon streaks through the target and leaves a burning jade trail.
			var length := clampf(reach + 2.5, 4.5, 9.0)
			var streak := _line(o, f, length, 2.0, 1.0, 0.9, 0, "jade_trail")
			streak["linger"] = 2.0
			streak["tick"] = 0.1
			streak["knock"] = 1.8
			parts.append(streak)
			out["dash"] = {"to": o + f * (length - 0.6), "t0": 0.65, "t1": 1.0}
		"lotus_leap":
			# The golden frog leaps onto the target; the splash sends a slowing ripple out.
			var land := o + f * clampf(reach, 1.5, 6.0)
			parts.append(_circle(land, 2.1, 1.0, 0.9, 0, "leap"))
			var ripple := _ring(land, 2.1, 3.9, 1.3, 0.3, 1, "ripple")
			ripple["slow"] = 2.0
			parts.append(ripple)
			out["leap"] = {"to": land, "t0": 0.5, "t1": 1.0, "height": 2.4}
		"jade_palm":
			# Three palm strikes step forward; the last one throws.
			for i in 3:
				var palm := _circle(o + f * (1.6 + 1.5 * i), 1.35, 0.85 + 0.15 * i, 0.5, i, "palm")
				if i == 2:
					palm["knock"] = 2.6
				parts.append(palm)
			out["dash"] = {"to": o + f * minf(2.0, maxf(reach - 1.0, 0.0)), "t0": 0.6, "t1": 1.15}
	# The flights of the ranged moves end as their parts land.
	if move in ["pollen", "ice_bolt", "void_bolt"]:
		for part in parts:
			if int(part.wave) == 0:
				var flight := 0.55 if move != "void_bolt" else 0.62
				shots.append({"to": part.pos, "t0": float(part.at) - flight, "t1": float(part.at),
					"kind": {"pollen": "pollen", "ice_bolt": "ice", "void_bolt": "void"}[move], "arc": 2.2 if move != "ice_bolt" else 1.2})
	out["shots"] = shots
	return out


static func _part(shape: String, pos: Vector3, at: float, dmg: float, wave: int, fx: String) -> Dictionary:
	return {"shape": shape, "pos": pos * Vector3(1, 0, 1), "at": at, "dmg": dmg, "wave": wave, "fx": fx,
		"dir": Vector3.FORWARD, "r": 0.0, "r_in": 0.0, "half": 0.0, "len": 0.0, "w": 0.0}


static func _circle(pos: Vector3, r: float, at: float, dmg: float, wave: int, fx: String) -> Dictionary:
	var p := _part("circle", pos, at, dmg, wave, fx)
	p.r = r
	return p


static func _cone(apex: Vector3, dir: Vector3, r: float, half: float, at: float, dmg: float, wave: int, fx: String) -> Dictionary:
	var p := _part("cone", apex, at, dmg, wave, fx)
	p.dir = dir
	p.r = r
	p.half = half
	return p


static func _line(start: Vector3, dir: Vector3, length: float, w: float, at: float, dmg: float, wave: int, fx: String) -> Dictionary:
	var p := _part("line", start, at, dmg, wave, fx)
	p.dir = dir
	p.len = length
	p.w = w
	return p


static func _ring(c: Vector3, r_in: float, r: float, at: float, dmg: float, wave: int, fx: String) -> Dictionary:
	var p := _part("ring", c, at, dmg, wave, fx)
	p.r_in = r_in
	p.r = r
	return p


static func _around(c: Vector3, n: int, lo: float, hi: float, rng: RandomNumberGenerator) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var base := rng.randf() * TAU
	for i in n:
		var a := base + TAU * float(i) / float(n) + rng.randf_range(-0.3, 0.3)
		out.append(c + Vector3(cos(a), 0, sin(a)) * rng.randf_range(lo, hi))
	return out


static func _ring_points(c: Vector3, radius: float, n: int, offset: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in n:
		var a := offset + TAU * float(i) / float(n)
		out.append(c + Vector3(cos(a), 0, sin(a)) * radius)
	return out


# ---------------------------------------------------------------------------
# Geometry
# ---------------------------------------------------------------------------

## Whether the ground point [param p] lies in the part's area.
static func inside(part: Dictionary, p: Vector3) -> bool:
	var d := (p - (part.pos as Vector3)) * Vector3(1, 0, 1)
	match String(part.shape):
		"circle":
			return d.length() <= float(part.r)
		"ring":
			var l := d.length()
			return l >= float(part.r_in) and l <= float(part.r)
		"cone":
			var l := d.length()
			if l > float(part.r):
				return false
			if l < 0.6:
				return true
			return (part.dir as Vector3).angle_to(d) <= float(part.half)
		"line":
			var dir: Vector3 = part.dir
			var along := d.dot(dir)
			var lateral := absf(d.dot(Vector3(-dir.z, 0, dir.x)))
			return along >= 0.0 and along <= float(part.len) and lateral <= float(part.w) * 0.5
	return false


## The middle of a part (where its effect bursts, where a dash ends up).
static func center(part: Dictionary) -> Vector3:
	match String(part.shape):
		"cone":
			return (part.pos as Vector3) + (part.dir as Vector3) * float(part.r) * 0.55
		"line":
			return (part.pos as Vector3) + (part.dir as Vector3) * float(part.len) * 0.5
	return part.pos


## Circles that cover the part, for the online cast (EntitySync sends circles only,
## at most 12 a move); a remote player sees at least the area that can hit.
static func cover(part: Dictionary) -> Array:
	var out: Array = []
	var at := float(part.at)
	var pos: Vector3 = part.pos
	match String(part.shape):
		"circle":
			out.append([pos, float(part.r), at])
		"line":
			var w := float(part.w)
			var dir: Vector3 = part.dir
			var n := maxi(1, ceili(float(part.len) / (w * 1.25)))
			var step := float(part.len) / float(n)
			var r := sqrt(pow(step * 0.5, 2.0) + pow(w * 0.5, 2.0))
			for i in n:
				out.append([pos + dir * (step * (i + 0.5)), r, at])
		"cone":
			var bands := 1 if float(part.r) < 4.0 else 2
			var dr := float(part.r) / float(bands)
			var dir: Vector3 = part.dir
			for j in bands:
				var r_out := dr * (j + 1)
				var mid := dr * (j + 0.5)
				var arc := r_out * float(part.half) * 2.0
				var m := clampi(ceili(arc / (dr * 1.3)), 1, 4)
				var da := float(part.half) * 2.0 / float(m)
				var radius := sqrt(pow(dr * 0.5, 2.0) + pow(r_out * sin(da * 0.5), 2.0))
				for k in m:
					var a := -float(part.half) + da * (k + 0.5)
					out.append([pos + dir.rotated(Vector3.UP, a) * mid, radius, at])
		"ring":
			var w := float(part.r) - float(part.r_in)
			var mid := (float(part.r) + float(part.r_in)) * 0.5
			var m := clampi(ceili(TAU * mid / (w * 1.4)), 6, 9)
			var half_chord := float(part.r) * sin(PI / float(m))
			var radius := maxf(w * 0.5, sqrt(pow(w * 0.5, 2.0) + pow(half_chord, 2.0)) * 0.92)
			for k in m:
				var a := TAU * float(k) / float(m)
				out.append([pos + Vector3(cos(a), 0, sin(a)) * mid, radius, at])
	return out


## All the circles of a plan, earliest first, capped at the 12 one cast carries.
static func sync_circles(parts: Array) -> Array:
	var out: Array = []
	for part in parts:
		out.append_array(cover(part))
	out.sort_custom(func(a, b): return float(a[2]) < float(b[2]))
	return out.slice(0, 12)


## The most one actor who ignores the move can take (x atk): the best MAX_HITS waves
## plus every hazard tick it could stand in.
static func worst_damage(p: Dictionary) -> float:
	var by_wave := {}
	var ticks := 0.0
	for part in p.parts:
		var w := int(part.wave)
		by_wave[w] = maxf(float(by_wave.get(w, 0.0)), float(part.dmg))
		if float(part.get("linger", 0.0)) > 0.0:
			ticks = maxf(ticks, floorf(float(part.linger) / HAZARD_TICK) * float(part.get("tick", 0.0)))
	var hits: Array = by_wave.values()
	hits.sort()
	hits.reverse()
	var total := 0.0
	for i in mini(MAX_HITS, hits.size()):
		total += float(hits[i])
	return total + ticks


## The warned area in square metres (elites draw a bigger move).
static func area(p: Dictionary) -> float:
	var total := 0.0
	for part in p.parts:
		match String(part.shape):
			"circle": total += PI * pow(float(part.r), 2.0)
			"ring": total += PI * (pow(float(part.r), 2.0) - pow(float(part.r_in), 2.0))
			"cone": total += float(part.half) * pow(float(part.r), 2.0)
			"line": total += float(part.len) * float(part.w)
	return total
