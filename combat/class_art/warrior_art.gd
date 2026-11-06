class_name WarriorArt
extends RefCounted
## The Warrior's signature layers (MeleeArt): heavy steel and fire. Blade arcs
## with a white-hot leading edge and a cooling, lagging smear, sparks shearing
## off the edge, slams that crack the ground with glowing seams and throw hot
## rock, a war banner and a flame aura for the buffs, and Grand Cross as a
## burning cross of light carved into the ground. Rig-local: the caster stands
## at the origin facing +Z, the target at (0, 0, reach).

const FIRE := [Color("ff7a2a"), Color("fff0c8"), Color("4a0e06")]
const BLOOD := [Color("ff3b24"), Color("ffd6a8"), Color("320404")]
const HOLY := [Color("ffc24a"), Color("fffbe6"), Color("5a2c0c")]
const STEEL := [Color("9cc4ec"), Color("ffffff"), Color("16243c")]
const GALE := [Color("5cf0b8"), Color("f0fff6"), Color("0a3a2c")]
const ROCK := Color("8a6c58")
## The elite war cries: a magic circle, rune rings and a pillar of light (MeleeArt.ascend).
const GRAND := ["berserker", "triumph_of_valhalla", "godly_shield"]

const PALETTE := {
	"rage_of_zecram": BLOOD, "destroyer": BLOOD, "berserker": BLOOD, "gladiator": BLOOD, "avenging_crash": BLOOD, "brandish": BLOOD,
	"grand_cross": HOLY, "sword_of_justice": HOLY, "godly_shield": HOLY, "holy_valor": HOLY, "divine_piercing": HOLY, "triumph_of_valhalla": HOLY,
	"drastic_spirit": STEEL, "swift_axe": GALE, "crown_breaker": BLOOD, "royal_vanguard": HOLY, "celestial_swordfall": HOLY, "divine_edict": FIRE,
}


static func palette(id: String) -> Array:
	return PALETTE.get(id, FIRE)


## Wind-up: embers are drawn into the blade, a heat ring tightens at the feet
## and, for the strong skills and the buffs, a low heat aura flickers.
static func charge(rig: MeleeArt, skill: Dictionary, ctx: Dictionary, duration: float) -> void:
	var c := palette(ctx.id)
	var p: float = ctx.power
	var t := maxf(duration, 0.15)
	var hand := Vector3(0.3, 1.15, 0.45)
	rig.gather(MeleeArt.SPARK, int(8 + 14 * p), hand, 1.4 + p, c[0].lerp(c[1], 0.3), 0.07, t * 0.9)
	# A heat ring that tightens round the feet as the blow gathers.
	rig.ring(c, Vector3(0, 0.05, 0), 1.6 + p, 0.7, 0.0, t + 0.08, Vector3.ZERO, {"opacity": 0.55, "grow": t}, true)
	if ctx.shape == "self" or p >= 0.4 or ctx.star > 0:
		rig.layer("aura", MeleeArt.AURA, c, Vector3.ZERO, Vector3(0.75, 1.5 + p, 0.75), Vector3.ZERO, t * 0.3, t * 0.8 + 0.12, {"initial": 0.4, "opacity": 0.4, "dissolve": 0.7, "fade_in": 0.3})
	if ctx.id in GRAND:
		# The circle draws itself under the feet while the cry gathers.
		rig.layer("sigil", MeleeArt.RING, c, Vector3(0, 0.05, 0), Vector3.ONE * 2.6, Vector3.ZERO, 0.0, t + 0.1, {"initial": 0.2, "grow": t, "spin": 0.9, "opacity": 0.45, "fade_in": 0.35, "dissolve": 0.9})
	if ctx.star > 0:
		rig.layer("blade", MeleeArt.SOLID, c, Vector3(0, 1.0, -0.2), Vector3(1.9, 1.9, 1.9), Vector3.ZERO, 0.0, t, {"bill": Vector3.UP, "initial": 0.3, "grow": t * 0.8, "opacity": 0.55, "fade_in": 0.4, "dissolve": 0.85, "sweep": t * 0.9, "tail": 1.0})


static func play(rig: MeleeArt, skill: Dictionary, ctx: Dictionary) -> void:
	var id: String = ctx.id
	var c := palette(id)
	var r: float = ctx.radius
	var reach: float = ctx.reach
	var d: float = ctx.d
	var p: float = ctx.power
	var hit := Vector3(0, 0, reach)
	match id:
		"raving":
			for k in 3:
				rig.slash(c, hit + Vector3(0, 1.0 + 0.1 * k, -0.6), 1.5, 0.0, [0.5, -0.6, 0.2][k], d + 0.07 * k, k % 2 == 1, "arc150", 0.07, 6)
			rig.embers(hit + Vector3.UP * 0.6, 6, 0.4, c[0], d + 0.1)
		"impact", "avenging_crash":
			var big := id == "avenging_crash"
			_overhead(rig, c, hit, 1.5 if big else 1.2, d)
			_slam(rig, c, hit, 1.6 if big else 1.2, d + 0.06, p, big)
		"triple_impact":
			for k in 3:
				rig.slash(c, hit + Vector3(0, 1.0, -0.4), 1.1 + 0.2 * k, 0.2 * k, [0.7, -0.7, 1.35][k], d + 0.1 * k, k == 1, "arc150", 0.08, 6)
			_slam(rig, c, hit, 1.3, d + 0.24, p, false)
		"brutal_swing", "rage_of_zecram", "cyclone_strike":
			var reach_r := r * 0.82
			rig.slash(c, Vector3(0, 0.95, 0), reach_r, 0.0, 0.08, d, false, "arc330", 0.16, 12, true, 0.6)
			if id != "brutal_swing":
				rig.slash(c, Vector3(0, 0.7, 0), reach_r * 0.9, PI, -0.22, d + 0.08, true, "arc330", 0.16, 10, false, 0.6)
			rig.ring(c, Vector3(0, 0.04, 0), reach_r * 0.4, reach_r, d, 0.8, Vector3.ZERO, {"opacity": 0.7})
			if id == "cyclone_strike":
				rig.layer("spiral", MeleeArt.RIBBON, c, Vector3.ZERO, Vector3(r * 0.55, 3.2, r * 0.55), Vector3.ZERO, d, 0.9, {"sweep": 0.3, "tail": 0.8, "thick": 0.7, "spin": 7.0, "initial": 0.6, "grow": 0.3, "dissolve": 0.45})
			if id == "rage_of_zecram":
				rig.layer("aura", MeleeArt.AURA, c, Vector3.ZERO, Vector3(0.9, 2.2, 0.9), Vector3.ZERO, d, 0.9, {"initial": 0.5, "grow": 0.2, "opacity": 0.75, "dissolve": 0.5})
				rig.cracks(c, Vector3.ZERO, r * 0.6, d + 0.05)
			rig.embers(Vector3(0, 0.5, 0), 10, r * 0.5, c[0], d + 0.1, 1.2)
		"roar":
			for k in 3:
				rig.ring(c, Vector3(0, 0.9, 0), 0.6, r * (0.55 + 0.2 * k), d + 0.1 * k, 0.55, Vector3.ZERO, {"opacity": 0.7 - 0.15 * k}, k == 0)
			rig.ring(c, Vector3(0, 0.05, 0), 0.8, r * 0.9, d, 0.7, Vector3.ZERO, {"opacity": 0.55})
			rig.cracks(c, Vector3.ZERO, r * 0.45, d)
			rig.layer("aura", MeleeArt.AURA, c, Vector3.ZERO, Vector3(0.8, 1.8, 0.8), Vector3.ZERO, d, 0.7, {"initial": 0.4, "grow": 0.15, "opacity": 0.6})
			rig.chips(Vector3.ZERO, 8, 4.5, ROCK, 0.6, 0.16, d)
		"bone_crash", "double_crash":
			_overhead(rig, c, Vector3(0, 0, 1.2), 1.6, d)
			_slam(rig, c, Vector3(0, 0, 1.0), r * 0.7, d + 0.05, p, true)
			if id == "double_crash":
				rig.cracks(c, Vector3(0, 0, 1.0), r * 0.85, d + 0.3, 1.2, true)
				rig.ring(c, Vector3(0, 0.06, 1.0), 0.5, r * 0.9, d + 0.3, 0.55, Vector3.ZERO, {"opacity": 0.7})
				rig.chips(Vector3(0, 0, 1.0), 10, 6.0, ROCK, 0.8, 0.2, d + 0.3)
		"destroyer", "brandish", "gladiator":
			var ult := id == "gladiator"
			if id != "destroyer":
				rig.slash(c, hit + Vector3(0, 1.1, -0.5), 1.6 + 0.4 * p, 0.0, 0.9, d, false, "arc150", 0.08, 8)
				rig.slash(c, hit + Vector3(0, 1.1, -0.5), 1.6 + 0.4 * p, 0.0, -0.9, d + 0.08, true, "arc150", 0.08, 8)
			_overhead(rig, c, hit, 1.8 + 0.6 * p, d + (0.12 if id != "destroyer" else 0.0))
			if ult:
				_falling_blade(rig, c, hit, 3.4, d)
			_slam(rig, c, hit, 1.8 + 0.8 * p, d + 0.14, p, true)
		"sword_blast":
			var flight := clampf(reach / 20.0, 0.12, 0.6)
			rig.layer("arc150", MeleeArt.RIBBON, c, Vector3(0, 1.0, 0.0), Vector3(2.2, 1, 2.2), Vector3(0, 0, 0.25), d, flight + 0.3, {"travel": Vector3(0, 0, reach - 2.2), "ease": "linear", "initial": 0.7, "grow": flight, "sweep": 0.06, "tail": 0.9, "thick": 0.7, "dissolve": 0.8}, true)
			rig.streak(c, Vector3(0, 1.0, 0.6), Vector3(0, 1.0, reach), 0.5, d, flight + 0.3, flight, {"opacity": 0.5, "thick": 0.4})
			rig.ring(c, hit + Vector3.UP * 1.0, 0.3, 1.5, d + flight, 0.4, Vector3(PI / 2, 0, 0))
			rig.emit(MeleeArt.SPARK, 12, hit + Vector3.UP, Vector3(0, 2, 6), 0.6, c[0].lerp(c[1], 0.4), 0.12, 0.5, d + flight, 9.0)
			rig.cracks(c, hit, 1.4, d + flight, 1.1)
		"piercing", "divine_piercing":
			var lanes := 1 if id == "piercing" else 5
			for k in lanes:
				var a := (float(k) - float(lanes - 1) * 0.5) * 0.18
				var tip := Vector3(sin(a), 0, cos(a)) * (9.0 if id == "piercing" else 12.0) + Vector3.UP * 1.0
				rig.streak(c, Vector3(0, 1.05, 0.5), tip, 0.55 if lanes == 1 else 0.4, d + 0.02 * k, 0.6, 0.1, {}, k == lanes / 2)
			rig.slash(c, Vector3(0, 1.0, 0.6), 1.3, 0.0, 0.1, d, false, "arc150", 0.07, 6, false)
			rig.emit(MeleeArt.SPARK, 14, Vector3(0, 1.0, 1.0), Vector3(0, 0.6, 9.0), 0.25, c[0].lerp(c[1], 0.4), 0.1, 0.5, d, 4.0, 1.0)
		"grand_cross":
			_grand_cross(rig, c, Vector3.ZERO, r, d, 1.0)
		"sword_of_justice":
			_falling_blade(rig, c, hit, 3.0, d)
			_slam(rig, c, hit, 2.0, d + 0.12, p, true)
			rig.layer("light_cross", MeleeArt.SOLID, c, hit, Vector3.ONE * 2.6, Vector3.ZERO, d + 0.12, 0.8, {"bill": "upright", "initial": 0.6, "grow": 0.18, "overshoot": true, "opacity": 0.75, "dissolve": 0.4})
		"concentration", "swift_axe", "berserker", "holy_valor", "drastic_spirit", "godly_shield", "triumph_of_valhalla":
			_rally(rig, c, id, d, p)
		_:
			rig.slash(c, hit + Vector3(0, 1.0, -0.4), 1.4, 0.0, 0.6, d)


## The war cry of the buffs: a flame aura, the banner raised behind, a ring of
## heat and embers.
static func _rally(rig: MeleeArt, c: Array, id: String, d: float, p: float) -> void:
	var big := id in GRAND
	rig.layer("aura", MeleeArt.AURA, c, Vector3.ZERO, Vector3(0.85, 2.0 + p, 0.85), Vector3.ZERO, d, 1.3, {"initial": 0.3, "grow": 0.3, "overshoot": true, "opacity": 0.55, "dissolve": 0.55, "fade_in": 0.1}, true)
	# The circle, rune rings, pillar and the aura that stays with the Warrior.
	rig.ascend(c, 2.2 + 0.4 * p if big else 1.7, d, 2.6 if big else 1.8, big)
	rig.ring(c, Vector3(0, 0.05, 0), 0.4, 2.4 + p, d, 0.7, Vector3.ZERO, {"opacity": 0.5})
	if id == "swift_axe":
		for k in 4:
			var a := TAU * float(k) / 4.0 + 0.4
			rig.streak(c, Vector3(sin(a) * 0.9, 0.2, cos(a) * 0.9), Vector3(sin(a + 0.6) * 0.8, 2.6, cos(a + 0.6) * 0.8), 0.18, d + 0.05 * k, 0.55, 0.18, {"opacity": 0.7})
	elif id == "concentration":
		rig.ring(c, Vector3(0, 1.1, 0), 1.6, 0.5, d, 0.6, Vector3.ZERO, {"initial": 1.0, "opacity": 0.6})
	else:
		var banners := 2 if id == "triumph_of_valhalla" else 1
		for k in banners:
			var side := 0.0 if banners == 1 else (-1.0 if k == 0 else 1.0)
			rig.layer("banner", MeleeArt.SOLID, c, Vector3(side * 1.1 - 0.15, 0, -0.75), Vector3.ONE * (1.7 + 0.3 * p), Vector3.ZERO, d + 0.06 * k, 1.6, {"bill": "upright", "drop": -1.0, "land": 0.22, "wave": 0.16, "initial": 1.0, "opacity": 0.95, "dissolve": 0.65, "fade_in": 0.1, "ink": true})
	if id in ["godly_shield", "holy_valor", "drastic_spirit"]:
		rig.layer("light_cross", MeleeArt.SOLID, c, Vector3(0, 0.2, -0.3), Vector3.ONE * 1.6, Vector3.ZERO, d + 0.1, 1.1, {"bill": "upright", "initial": 0.5, "overshoot": true, "grow": 0.25, "opacity": 0.6, "travel": Vector3.UP * 0.4})
	if id == "triumph_of_valhalla":
		# A crown of light settles over the head.
		rig.ring(c, Vector3(0, 2.75, 0), 1.5, 0.55, d + 0.15, 1.6, Vector3.ZERO, {"grow": 0.5, "opacity": 0.6, "dissolve": 0.6})
	if big:
		rig.cracks(c, Vector3.ZERO, 1.8 + p, d)
	rig.embers(Vector3(0, 0.3, 0), 14 if big else 9, 0.9, c[0].lerp(c[1], 0.3), d, 1.3, 2.2)


## A downward cut: a near-vertical crescent coming over the top onto `at`.
static func _overhead(rig: MeleeArt, c: Array, at: Vector3, size: float, d: float) -> void:
	rig.slash(c, at + Vector3(0, size * 0.98 + 0.08, -size * 0.55), size, 0.0, PI * 0.5 - 0.15, d, true, "arc150", 0.08, 9)


## The ground breaking under a heavy blow: glowing cracks, a hot ring, rock
## chips with gravity and a flash.
static func _slam(rig: MeleeArt, c: Array, at: Vector3, size: float, d: float, p: float, heavy: bool) -> void:
	rig.cracks(c, at, size, d, 1.3, heavy, true)
	rig.ring(c, at + Vector3.UP * 0.12, 0.3, size * 1.15, d, 0.42, Vector3.ZERO, {"opacity": 0.6})
	rig.chips(at, 8 if heavy else 5, 4.0 + 2.0 * p, ROCK, 0.9, 0.12 + 0.06 * p, d)
	rig.emit(MeleeArt.SPARK, 12 if heavy else 8, at + Vector3.UP * 0.3, Vector3.UP * 6.0, 0.8, c[0].lerp(c[1], 0.35), 0.1, 0.55, d, 10.0, 1.0)
	if heavy:
		rig.light(at + Vector3.UP * 0.8, c[0], 2.0, 5.0, d, 0.4)


## A greatsword of light plunges from the sky onto `at`.
static func _falling_blade(rig: MeleeArt, c: Array, at: Vector3, size: float, d: float) -> void:
	rig.layer("blade", MeleeArt.SOLID, c, at + Vector3(0, size * 0.98, 0), Vector3.ONE * size, Vector3.ZERO, d - 0.02, 0.75, {"bill": Vector3.DOWN, "drop": 4.0, "land": 0.12, "initial": 1.0, "opacity": 0.85, "dissolve": 0.45, "fade_in": 0.04, "front": 1}, true)


## Grand Cross: a cross of fire carved outward through the ground, a broken
## ring, a standing cross of light rising over the centre, flame at the arms'
## ends and a pillar of heat.
static func _grand_cross(rig: MeleeArt, c: Array, at: Vector3, r: float, d: float, scale: float) -> void:
	var size := r * 0.9 * scale
	rig.layer("cross", MeleeArt.GROUND, c, at + Vector3.UP * 0.04, Vector3.ONE * size, Vector3.ZERO, d, 1.7, {"sweep": 0.35, "initial": 1.0, "dissolve": 0.62, "fade_in": 0.02, "opacity": 0.75}, true)
	rig.layer("cross", MeleeArt.GROUND, FIRE, at + Vector3.UP * 0.06, Vector3.ONE * size, Vector3.ZERO, d, 1.5, {"sweep": 0.35, "initial": 1.0, "dissolve": 0.5, "fade_in": 0.02, "opacity": 1.0, "ink": false, "narrow": 0.45}, true)
	rig.layer("light_cross", MeleeArt.SOLID, c, at, Vector3.ONE * 4.6 * scale, Vector3.ZERO, d + 0.05, 1.2, {"bill": "upright", "drop": -2.0, "land": 0.3, "initial": 0.7, "grow": 0.3, "overshoot": true, "opacity": 0.8, "dissolve": 0.5, "front": 1}, true)
	rig.layer("aura", MeleeArt.AURA, c, at, Vector3(0.7, 4.0, 0.7) * Vector3(scale, 1, scale), Vector3.ZERO, d, 1.1, {"initial": 0.3, "grow": 0.25, "opacity": 0.7, "dissolve": 0.5})
	rig.ring(c, at + Vector3.UP * 0.1, 0.5, size * 1.1, d + 0.05, 0.6, Vector3.ZERO, {"opacity": 0.7})
	rig.cracks(c, at, size * 0.55, d + 0.1, 1.4, true)
	for k in 4:
		var a := float(k) * PI * 0.5
		var tip := at + Vector3(sin(a), 0, cos(a)) * size * 0.95
		rig.embers(tip, 5, 0.3, c[0], d + 0.3, 1.0, 2.6, 0.08)
		rig.emit(MeleeArt.SPARK, 5, tip + Vector3.UP * 0.2, Vector3.UP * 5.0, 0.5, c[0].lerp(c[1], 0.4), 0.1, 0.5, d + 0.3, 9.0)
	rig.light(at + Vector3.UP * 1.5, c[0], 3.0, size * 1.6, d, 0.8)


## Star skills: every real contact beat.
static func star(rig: MeleeArt, skill: Dictionary, ctx: Dictionary) -> void:
	var id: String = ctx.id
	var c := palette(id)
	var i: int = ctx.index
	var reach: float = ctx.reach
	var r: float = ctx.radius
	var back := Vector3(0, 0, -reach)
	match id:
		"lionfang_cleave":
			# The rig stands on the area centre (the caster): two great fanned cuts.
			rig.slash(c, Vector3(0, 0.9, 0.2), r * 0.85, 0.0, 0.12 * (1 if i == 0 else -1), 0.0, i == 1, "arc220", 0.13, 16, true, 0.65)
			rig.slash(FIRE, Vector3(0, 0.6, 0.2), r * 0.65, 0.0, -0.1, 0.05, i == 0, "arc150", 0.12, 8, false)
			if i == 1:
				_slam(rig, c, Vector3(0, 0, 2.0), r * 0.6, 0.05, 1.0, true)
		"crown_breaker":
			if i == 0:
				rig.slash(c, Vector3(0, 1.1, -0.4), 2.2, 0.0, 0.9, 0.0, false, "arc150", 0.08, 10)
				rig.slash(c, Vector3(0, 1.1, -0.4), 2.2, 0.0, -0.9, 0.07, true, "arc150", 0.08, 10)
			else:
				_falling_blade(rig, c, Vector3.ZERO, 4.0, 0.0)
				_slam(rig, c, Vector3.ZERO, 3.0, 0.1, 1.0, true)
		"royal_vanguard":
			for k in 3:
				var a := (float(k) - 1.0) * 0.8
				rig.layer("banner", MeleeArt.SOLID, c, Vector3(sin(a) * 1.4, 0, -cos(a) * 1.0), Vector3.ONE * 1.6, Vector3.ZERO, 0.05 * k, 1.7, {"bill": "upright", "drop": -1.0, "land": 0.22, "wave": 0.16, "initial": 1.0, "opacity": 0.95, "dissolve": 0.65, "ink": true}, k == 1)
			rig.layer("aura", MeleeArt.AURA, c, Vector3.ZERO, Vector3(1.0, 2.6, 1.0), Vector3.ZERO, 0.0, 1.5, {"initial": 0.3, "grow": 0.3, "overshoot": true, "opacity": 0.7, "dissolve": 0.55})
			rig.ring(c, Vector3(0, 0.05, 0), 0.5, 3.5, 0.0, 0.8, Vector3.ZERO, {"opacity": 0.7})
			rig.embers(Vector3(0, 0.3, 0), 16, 1.2, c[0].lerp(c[1], 0.3), 0.0, 1.4, 2.4)
		"celestial_swordfall":
			rig.cracks(c, Vector3.ZERO, 1.5, 0.0, 1.0, i % 2 == 1, true)
			rig.ring(c, Vector3.UP * 0.08, 0.3, 1.8, 0.0, 0.4, Vector3.ZERO, {"opacity": 0.6})
			rig.emit(MeleeArt.SPARK, 8, Vector3.UP * 0.3, Vector3.UP * 6.0, 0.8, c[0].lerp(c[1], 0.4), 0.1, 0.5, 0.0, 10.0)
			if i % 3 == 0:
				rig.chips(Vector3.ZERO, 5, 5.0, ROCK, 0.8, 0.16)
		"divine_edict":
			if i < 4:
				rig.slash(c, Vector3(0, 1.0, 0), r * (0.45 + 0.1 * i), float(i) * 0.8, 0.15 * (1 if i % 2 == 0 else -1), 0.0, i % 2 == 1, "arc330", 0.14, 10, true, 0.55)
				rig.cracks(c, Vector3.ZERO, r * 0.4, 0.0, 0.9, i % 2 == 1)
			else:
				_grand_cross(rig, HOLY, Vector3.ZERO, r, 0.0, 1.25)
				rig.chips(Vector3.ZERO, 12, 7.0, ROCK, 1.0, 0.24)
		_:
			rig.slash(c, Vector3(0, 1.0, 0), 1.6, 0.0, 0.5, 0.0)
