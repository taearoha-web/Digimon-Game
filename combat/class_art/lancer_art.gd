class_name LancerArt
extends RefCounted
## The Lancer's signature layers (MeleeArt): speed, wind and dragon. A thrust
## leaves a long piercing streak whose white head outruns a lagging, cooling
## tail, wind rings slide out along it, spear afterimages trail the strike and
## air motes whip past. Spins wind a spiral vortex, the dragon skills breathe a
## scaled dragon head of fire down the line, and Gungnir is a thrown spear of
## light dragging a comet tail. Rig-local: caster at the origin facing +Z.

const WIND := [Color("4fd2ff"), Color("eefcff"), Color("0e2c5a")]
const GALE := [Color("5ef0c4"), Color("f0fff8"), Color("0a3838")]
const DRAGON := [Color("ff6a2a"), Color("fff0b0"), Color("4a0a18")]
const HOLY := [Color("ffd25a"), Color("fffbe6"), Color("22306e")]
const BRASS := [Color("ffc85a"), Color("fff4d0"), Color("4a2608")]
const STEEL := [Color("a8c4ec"), Color("ffffff"), Color("1a2846")]
const HEART := [Color("ff3a5a"), Color("ffe0e6"), Color("3a0616")]

const PALETTE := {
	"stagger": BRASS, "hook_strike": BRASS, "war_cry": BRASS, "focus": BRASS, "charge_dash": BRASS, "lancer_rush": DRAGON,
	"wind_stance": GALE, "typhoon_spear": GALE, "gale_cyclone": GALE, "iron_resolve": STEEL,
	"dragon_tooth": DRAGON, "dragon_lance": DRAGON, "dragon_stance": DRAGON,
	"sky_pierce": HOLY, "valkyrie_blessing": HOLY, "gungnir": HOLY, "heaven_rend": HOLY, "ragnarok_lance": HOLY,
	"heartseeker": HEART, "aegis_formation": HOLY, "worldsplitter": HOLY, "heavenrend_spear": WIND,
}
const ROCK := Color("5f5a52")


static func palette(id: String) -> Array:
	return PALETTE.get(id, WIND)


## Wind-up: air is drawn in toward the spear tip in streaks, a ring of wind
## tightens around the shaft and the stance pulls a little gale off the ground.
static func charge(rig: MeleeArt, skill: Dictionary, ctx: Dictionary, duration: float) -> void:
	var c := palette(ctx.id)
	var p: float = ctx.power
	var t := maxf(duration, 0.15)
	var tip := Vector3(0.15, 1.1, 0.9)
	rig.gather(MeleeArt.SPARK, int(8 + 12 * p), tip, 1.8 + p, c[0].lerp(c[1], 0.5), 0.06, t * 0.9)
	rig.ring(c, tip, 1.4, 0.35, 0.0, t + 0.05, Vector3(PI * 0.5, 0, 0), {"opacity": 0.6, "grow": t}, true)
	if ctx.shape in ["burst", "self"] or p >= 0.5 or ctx.star > 0:
		rig.layer("spiral", MeleeArt.RIBBON, c, Vector3.ZERO, Vector3(0.9, 1.6 + p, 0.9), Vector3.ZERO, 0.0, t + 0.1, {"sweep": t, "tail": 0.7, "thick": 0.4, "spin": 6.0, "initial": 0.7, "opacity": 0.55, "dissolve": 0.8})
	if ctx.id in ["dragon_tooth", "dragon_lance", "dragon_stance", "ragnarok_lance"] or ctx.star >= 200:
		rig.layer("dragon", MeleeArt.SOLID, c, Vector3(-0.6, 1.5, -0.6), Vector3.ONE * 1.3, Vector3.ZERO, t * 0.2, t * 0.85, {"bill": "upright", "pattern": 1.0, "initial": 0.5, "grow": t * 0.6, "opacity": 0.55, "fade_in": 0.4, "dissolve": 0.8, "travel": Vector3.UP * 0.3})


## The spear line of one thrust: streak, white needle, sliding wind rings,
## afterimages, air motes and the sparks at the tip.
static func thrust(rig: MeleeArt, c: Array, from: Vector3, to: Vector3, width: float, d: float, rings := 3, images := 3, core := true) -> void:
	var dir := (to - from).normalized()
	var length := from.distance_to(to)
	rig.streak(c, from, to, 0.95 * width, d, 0.8, 0.07, {"tail": 0.9, "dissolve": 0.5}, core)
	rig.streak([c[1], Color.WHITE, c[0]], from + dir * 0.2, to + dir * 0.4, 0.16 * width, d, 0.3, 0.05, {"thick": 0.45, "tail": 0.6}, false)
	var yaw := atan2(dir.x, dir.z)
	for k in rings:
		var at := from + dir * (0.5 + 0.55 * k)
		rig.ring(c, at, 0.3 * width, 0.75 * width + 0.15 * k, d + 0.035 * k, 0.5, Vector3(PI * 0.5, yaw, 0), {"travel": dir * length * (0.45 + 0.1 * k), "opacity": 0.7 - 0.12 * k, "ease": "out"})
	for k in images:
		rig.layer("spear", MeleeArt.SOLID, c, from + dir * (0.4 + 0.5 * k), Vector3.ONE * 1.9 * width, Vector3.ZERO, d + 0.025 * k, 0.24, {"bill": dir, "travel": dir * (0.8 + 0.3 * k), "initial": 1.0, "opacity": 0.55 - 0.13 * k, "dissolve": 0.25, "fade_in": 0.02, "sweep": 0.01})
	rig.emit(MeleeArt.SPARK, 10, from + dir * 0.6, dir * 15.0, 0.07, c[1].lerp(c[0], 0.3), 0.05, 0.32, d, 0.0, 2.0, 0.0, 0.35)
	rig.emit(MeleeArt.SPARK, 8, to, (dir + Vector3.UP * 0.3) * 7.0, 0.5, c[0].lerp(c[1], 0.4), 0.08, 0.4, d + 0.04, 8.0, 1.2)


## A spiral vortex of wind round the caster with a ring slash and swirling motes.
static func vortex(rig: MeleeArt, c: Array, r: float, d: float, power: float, core := true) -> void:
	rig.layer("spiral", MeleeArt.RIBBON, c, Vector3.ZERO, Vector3(r * 0.5, 2.4 + power, r * 0.5), Vector3.ZERO, d, 0.85, {"sweep": 0.28, "tail": 0.75, "thick": 0.7, "spin": 9.0, "initial": 0.55, "grow": 0.3, "dissolve": 0.45}, core)
	rig.layer("spiral", MeleeArt.RIBBON, [c[2].lerp(c[0], 0.5), c[0], c[2]], Vector3.ZERO, Vector3(r * 0.72, 1.5, r * 0.72), Vector3(0, PI, 0), d + 0.06, 0.8, {"sweep": 0.3, "tail": 0.9, "thick": 0.35, "spin": -6.0, "initial": 0.7, "opacity": 0.55, "dissolve": 0.4})
	rig.slash(c, Vector3(0, 0.9, 0), r * 0.82, 0.0, 0.06, d, false, "arc330", 0.15, 9, false, 0.55)
	rig.ring(c, Vector3(0, 0.06, 0), 0.4, r * 0.95, d, 0.6, Vector3.ZERO, {"opacity": 0.6})
	rig.emit(MeleeArt.SPARK, 14, Vector3(0, 0.4, 0), Vector3.UP * 2.5, 0.7, c[1].lerp(c[0], 0.3), 0.06, 0.9, d, -0.5, 0.6, 9.0, r * 0.45)


## A dragon's head of fire racing down the line, scales burning on it.
static func dragon(rig: MeleeArt, c: Array, from: Vector3, to: Vector3, size: float, d: float, core := false) -> void:
	var dir := (to - from).normalized()
	var travel := (to - from) * 0.85
	rig.layer("dragon", MeleeArt.SOLID, c, from + Vector3.UP * 0.15, Vector3.ONE * size, Vector3.ZERO, d, 0.62, {"bill": dir, "travel": travel, "ease": "out", "pattern": 1.0, "initial": 0.5, "grow": 0.12, "overshoot": true, "opacity": 0.9, "dissolve": 0.55, "fade_in": 0.03, "front": 1}, core)
	rig.embers(from + travel * 0.5 + Vector3.UP * 0.2, 10, 1.0, c[0], d + 0.1, 0.9, 1.4, 0.07)


static func play(rig: MeleeArt, skill: Dictionary, ctx: Dictionary) -> void:
	var id: String = ctx.id
	var c := palette(id)
	var r: float = ctx.radius
	var reach: float = ctx.reach
	var d: float = ctx.d
	var p: float = ctx.power
	var length := clampf(maxf(reach + 1.2, float(skill.get("pierce", {}).get("len", reach + 1.5))), 2.5, 16.0)
	var hand := Vector3(0, 1.05, 0.35)
	var tip := Vector3(0, 1.0, length)
	match id:
		"thrust", "skewer", "impale", "vanguard_strike", "stagger", "hook_strike", "dragon_tooth", "sky_pierce", "spear_wave":
			var w := 0.9 + 0.5 * p
			thrust(rig, c, hand, tip, w, d, 2 + int(p * 2.0), 2 + int(p * 2.0))
			if id in ["stagger", "hook_strike"]:
				rig.ring(c, Vector3(0, 1.0, reach), 0.3, 1.3, d + 0.05, 0.45, Vector3.ZERO, {"opacity": 0.75})
				rig.emit(MeleeArt.SPARK, 8, Vector3(0, 1.1, reach), Vector3.UP * 4.0, 0.9, c[0].lerp(c[1], 0.4), 0.09, 0.45, d, 6.0)
			if id == "hook_strike":
				rig.slash(c, Vector3(0, 1.0, reach - 0.9), 1.1, PI, -0.3, d + 0.12, true, "arc150", 0.08, 6, false)
			if id == "dragon_tooth":
				dragon(rig, c, hand, tip, 1.5, d)
			if id == "spear_wave":
				rig.layer("arc150", MeleeArt.RIBBON, c, Vector3(0, 0.9, 0.2), Vector3(1.6, 1, 1.6), Vector3(0, 0, 0.1), d, 0.5, {"travel": Vector3(0, 0, length - 1.8), "ease": "out", "sweep": 0.06, "tail": 0.9, "thick": 0.6, "initial": 0.7, "grow": 0.2, "dissolve": 0.6})
			if id == "sky_pierce":
				rig.streak(c, Vector3(0, 0.2, reach), Vector3(0, 7.0, reach + 0.6), 0.8, d + 0.08, 0.55, 0.1, {"opacity": 0.75})
				rig.ring(c, Vector3(0, 0.08, reach), 0.3, 1.8, d + 0.08, 0.5)
			if id == "impale":
				rig.ring(c, Vector3(0, 0.06, reach), 0.3, 1.2, d + 0.05, 0.6, Vector3.ZERO, {"opacity": 0.6})
		"charge_dash":
			# The dash leaves a row of spear afterimages along the run and kicks up dust.
			thrust(rig, c, hand, tip, 1.0, d, 3, 0)
			for k in 4:
				rig.layer("spear", MeleeArt.SOLID, c, Vector3(0, 1.05, -0.6 + reach * 0.22 * k), Vector3.ONE * 2.0, Vector3.ZERO, d + 0.03 * k, 0.3, {"bill": Vector3.BACK, "initial": 1.0, "opacity": 0.25 + 0.12 * k, "dissolve": 0.3, "fade_in": 0.02})
			rig.emit(MeleeArt.SPARK, 10, Vector3(0, 0.1, reach * 0.4), Vector3(0, 1.5, -2.0), 0.7, Color("c8b49a"), 0.08, 0.6, d, 2.0, 1.5, 3.0, reach * 0.3)
		"whirl", "spinning_pike", "typhoon_spear", "gale_cyclone":
			vortex(rig, c, r, d, p)
			if id in ["typhoon_spear", "gale_cyclone"]:
				for k in 2:
					rig.ring(c, Vector3(0, 0.6 + 0.9 * k, 0), 0.5, r * (0.7 - 0.15 * k), d + 0.08 * k, 0.55, Vector3.ZERO, {"opacity": 0.6, "spin": 4.0})
				rig.emit(MeleeArt.SPARK, 12, Vector3(0, 0.3, 0), Vector3.UP * 3.5, 0.5, c[1], 0.05, 1.0, d + 0.05, -0.3, 0.5, 11.0, r * 0.6)
		"war_cry":
			for k in 3:
				rig.ring(c, Vector3(0, 0.9, 0), 0.5, r * (0.5 + 0.2 * k), d + 0.09 * k, 0.5, Vector3.ZERO, {"opacity": 0.7 - 0.15 * k}, k == 0)
			for k in 8:
				var a := TAU * float(k) / 8.0
				rig.streak(c, Vector3(sin(a) * 0.8, 0.8, cos(a) * 0.8), Vector3(sin(a) * r * 0.85, 0.5, cos(a) * r * 0.85), 0.3, d + 0.02 * k, 0.45, 0.14, {"opacity": 0.6}, false)
			rig.layer("aura", MeleeArt.AURA, c, Vector3.ZERO, Vector3(0.8, 1.9, 0.8), Vector3.ZERO, d, 0.7, {"initial": 0.4, "grow": 0.15, "opacity": 0.55})
		"dragon_lance":
			thrust(rig, c, hand, tip, 1.5, d, 3, 2)
			dragon(rig, c, hand, tip, 2.3, d, true)
			rig.layer("spiral", MeleeArt.RIBBON, c, hand, Vector3(0.7, length * 0.9, 0.7), Vector3(PI * 0.5, 0, 0), d, 0.6, {"sweep": 0.15, "tail": 0.7, "thick": 0.5, "roll": 0.0, "initial": 1.0, "opacity": 0.75, "dissolve": 0.45})
			rig.light(tip, c[0], 2.0, 6.0, d, 0.5)
		"gungnir", "ragnarok_lance":
			var ult := id == "ragnarok_lance"
			throw(rig, c, hand + Vector3.UP * 0.3, tip, 2.6 if not ult else 3.4, d)
			thrust(rig, c, hand, tip, 1.6 if ult else 1.2, d, 4, 2, false)
			if ult:
				dragon(rig, DRAGON, hand, tip, 2.6, d + 0.05)
				rig.cracks(c, Vector3(0, 0, reach), 2.6, d + 0.12, 1.3, true)
		"heaven_rend":
			vortex(rig, c, r, d, p)
			for k in 6:
				var a := TAU * float(k) / 6.0 + 0.3
				var at := Vector3(sin(a), 0, cos(a)) * r * 0.62
				rig.layer("spear", MeleeArt.SOLID, c, at + Vector3.UP * 2.4, Vector3.ONE * 2.4, Vector3.ZERO, d + 0.04 * k, 0.75, {"bill": Vector3.DOWN, "drop": 5.0, "land": 0.14, "initial": 1.0, "opacity": 0.85, "dissolve": 0.45, "fade_in": 0.03})
			rig.cracks(c, Vector3.ZERO, r * 0.6, d + 0.12, 1.4, true)
		"focus", "wind_stance", "iron_resolve", "lancer_rush", "dragon_stance", "valkyrie_blessing":
			stance(rig, c, id, d, p)
		_:
			thrust(rig, c, hand, tip, 1.0, d)


## Gungnir's throw: the spear of light flies down the line in a blink, a comet
## tail of light and sparks dragging behind it, a ring bursting at the release.
static func throw(rig: MeleeArt, c: Array, from: Vector3, to: Vector3, size: float, d: float) -> void:
	var dir := (to - from).normalized()
	var flight := 0.14
	rig.layer("spear", MeleeArt.SOLID, c, from, Vector3.ONE * size, Vector3.ZERO, d, flight + 0.16, {"bill": dir, "travel": to - from - dir * size * 0.7, "ease": "in", "initial": 1.0, "opacity": 0.95, "dissolve": 0.7, "fade_in": 0.02, "front": 1}, true)
	rig.streak(c, from, to, 1.0, d, 0.75, flight, {"tail": 0.95, "thick": 0.7, "dissolve": 0.35})
	rig.ring(c, from + dir * 0.3, 0.2, 1.4, d, 0.35, Vector3(PI * 0.5, atan2(dir.x, dir.z), 0), {"opacity": 0.8})
	for k in 4:
		var f := 0.25 + 0.22 * k
		rig.emit(MeleeArt.SPARK, 5, from.lerp(to, f), (Vector3.UP * 0.4 - dir * 0.3) * 4.0, 0.9, c[0].lerp(c[1], 0.5), 0.07, 0.6, d + flight * f, 4.0, 1.4, 3.0)
	rig.ring(c, to, 0.3, 2.0, d + flight, 0.4, Vector3(PI * 0.5, atan2(dir.x, dir.z), 0), {"opacity": 0.75})
	rig.light(to, c[0], 2.5, 6.0, d + flight, 0.45)


## The stance buffs: a gale aura and rising spiral, rings of wind; the dragon
## stance raises a dragon behind the Lancer, the Valkyrie a ring of spears.
static func stance(rig: MeleeArt, c: Array, id: String, d: float, p: float) -> void:
	rig.layer("aura", MeleeArt.AURA, c, Vector3.ZERO, Vector3(0.8, 2.0 + p, 0.8), Vector3.ZERO, d, 1.2, {"initial": 0.3, "grow": 0.3, "overshoot": true, "opacity": 0.6, "dissolve": 0.55}, true)
	rig.layer("spiral", MeleeArt.RIBBON, c, Vector3.ZERO, Vector3(1.1, 2.6 + p, 1.1), Vector3.ZERO, d, 1.0, {"sweep": 0.4, "tail": 0.8, "thick": 0.45, "spin": 5.0, "initial": 0.8, "opacity": 0.75, "dissolve": 0.5})
	rig.ring(c, Vector3(0, 0.05, 0), 0.4, 2.4 + p, d, 0.65, Vector3.ZERO, {"opacity": 0.6})
	match id:
		"dragon_stance":
			rig.layer("dragon", MeleeArt.SOLID, c, Vector3(-0.4, 1.6, -0.5), Vector3.ONE * 2.0, Vector3.ZERO, d, 1.3, {"bill": "upright", "pattern": 1.0, "travel": Vector3.UP * 0.6, "initial": 0.4, "grow": 0.35, "overshoot": true, "opacity": 0.85, "dissolve": 0.55})
		"valkyrie_blessing":
			for k in 6:
				var a := TAU * float(k) / 6.0
				rig.layer("spear", MeleeArt.SOLID, c, Vector3(sin(a) * 1.5, 0.0, cos(a) * 1.5), Vector3.ONE * 2.0, Vector3.ZERO, d + 0.04 * k, 1.2, {"bill": Vector3.UP, "drop": -1.5, "land": 0.25, "initial": 1.0, "opacity": 0.75, "dissolve": 0.55})
		"lancer_rush":
			for k in 4:
				var a := TAU * float(k) / 4.0 + 0.4
				rig.streak(c, Vector3(sin(a) * 0.9, 0.2, cos(a) * 0.9), Vector3(sin(a + 0.6) * 0.8, 2.6, cos(a + 0.6) * 0.8), 0.18, d + 0.05 * k, 0.55, 0.18, {"opacity": 0.7}, false)
	rig.emit(MeleeArt.SPARK, 12, Vector3(0, 0.3, 0), Vector3.UP * 2.2, 0.6, c[1].lerp(c[0], 0.3), 0.05, 1.1, d, -0.4, 0.6, 7.0, 0.9)


## Star skills: every real contact beat. The rig stands on the contact point;
## the caster is at (0, 0, -reach).
static func star(rig: MeleeArt, skill: Dictionary, ctx: Dictionary) -> void:
	var id: String = ctx.id
	var c := palette(id)
	var i: int = ctx.index
	var reach: float = ctx.reach
	var r: float = ctx.radius
	var from := Vector3(0, 1.05, -reach + 0.4)
	match id:
		"spiral_impaler":
			thrust(rig, c, from, Vector3(0, 1.0, 3.0 + i), 1.4, 0.0, 3, 1)
			rig.layer("spiral", MeleeArt.RIBBON, c, from, Vector3(0.75, reach + 3.0, 0.75), Vector3(PI * 0.5, 0, 0), 0.0, 0.55, {"sweep": 0.14, "tail": 0.8, "thick": 0.55, "roll": 0.0, "initial": 1.0, "opacity": 0.8, "dissolve": 0.45})
		"heartseeker":
			var final := i >= 5
			var off := Vector3(0.25 * float(i % 3 - 1), 0.15 * float(i % 2), 0)
			thrust(rig, c, from + off, Vector3(0, 1.1, 1.2 if not final else 3.0) + off, 1.8 if final else 0.9, 0.0, 3 if final else 1, 2 if final else 1)
			if final:
				rig.ring(c, Vector3(0, 1.1, 0), 0.3, 2.6, 0.0, 0.5, Vector3(PI * 0.5, 0, 0), {"opacity": 0.85})
				rig.emit(MeleeArt.SPARK, 18, Vector3(0, 1.1, 0), Vector3(0, 1.0, 6.0), 0.8, c[0].lerp(c[1], 0.4), 0.1, 0.55, 0.0, 6.0)
				rig.light(Vector3(0, 1.2, 0), c[0], 2.5, 5.0, 0.0, 0.45)
		"aegis_formation":
			for k in 8:
				var a := TAU * float(k) / 8.0
				rig.layer("spear", MeleeArt.SOLID, c, Vector3(sin(a) * 1.9, 0.0, cos(a) * 1.9), Vector3.ONE * 2.3, Vector3.ZERO, 0.03 * k, 1.5, {"bill": Vector3.UP, "drop": -2.0, "land": 0.25, "initial": 1.0, "opacity": 0.8, "dissolve": 0.6}, k == 0)
			stance(rig, c, "aegis_formation", 0.0, 1.0)
		"worldsplitter":
			rig.cracks(c, Vector3.ZERO, r * 0.45, 0.0, 1.3, i % 2 == 1, true)
			for k in 3:
				var at := Vector3(float(k - 1) * 1.1, 0.0, float(k % 2) * 0.8)
				rig.layer("spear", MeleeArt.SOLID, c, at, Vector3.ONE * (2.2 + 0.4 * (k % 2)), Vector3.ZERO, 0.04 * k, 0.75, {"bill": Vector3.UP, "drop": -2.2, "land": 0.12, "initial": 1.0, "opacity": 0.85, "dissolve": 0.45})
			rig.chips(Vector3.ZERO, 8, 6.0, ROCK, 0.6, 0.18)
			rig.ring(c, Vector3.UP * 0.08, 0.4, r * 0.4, 0.0, 0.5)
		"heavenrend_spear":
			if i < 4:
				for k in 4:
					var a := TAU * float(k) / 4.0 + float(i) * 0.5
					var at := Vector3(sin(a), 0, cos(a)) * r * (0.35 + 0.1 * i)
					rig.layer("spear", MeleeArt.SOLID, c, at + Vector3.UP * 2.0, Vector3.ONE * 2.0, Vector3.ZERO, 0.03 * k, 0.6, {"bill": Vector3.DOWN, "drop": 4.0, "land": 0.12, "initial": 1.0, "opacity": 0.85, "dissolve": 0.45}, k == 0)
				rig.ring(c, Vector3.UP * 0.08, 0.5, r * 0.5, 0.0, 0.5)
			else:
				rig.layer("spear", MeleeArt.SOLID, HOLY, Vector3(0, 6.2, 0), Vector3.ONE * 6.4, Vector3.ZERO, -0.05, 0.9, {"bill": Vector3.DOWN, "drop": 6.0, "land": 0.16, "initial": 1.0, "opacity": 0.95, "dissolve": 0.5, "front": 1}, true)
				vortex(rig, c, r * 0.8, 0.1, 1.0, false)
				rig.cracks(HOLY, Vector3.ZERO, r * 0.7, 0.12, 1.5, true)
				rig.chips(Vector3.ZERO, 12, 7.0, ROCK, 0.8, 0.22, 0.12)
				rig.light(Vector3.UP * 1.5, HOLY[0], 3.0, r * 1.5, 0.12, 0.7)
		_:
			thrust(rig, c, from, Vector3(0, 1.0, 1.5), 1.0, 0.0)
