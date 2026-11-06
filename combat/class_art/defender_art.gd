class_name DefenderArt
extends RefCounted
## The Defender's signature layers (MeleeArt): holy shield and stone. Shield
## light assembles out of hexagonal panels that ripple where they are struck;
## slams heave the earth, crack it and throw rock chips; Provoke throws chains
## of light from the Defender to every foe it taunts; Blood Swell (เบ่งเลือด,
## id "brace") beats as a red heart aura with veins of blood-light; reflection
## spins mirrored shards. Rig-local: caster at the origin facing +Z.

const AEGIS := [Color("8cc6ff"), Color("f4fbff"), Color("16305e")]
const GOLD := [Color("ffd05a"), Color("fffbe8"), Color("5a3a12")]
const EARTH := [Color("e0a860"), Color("fff0c8"), Color("3e2410")]
const BLOOD := [Color("e8142e"), Color("ffc8c0"), Color("2a0008")]
const TAUNT := [Color("ff7a3a"), Color("ffe2b0"), Color("561608")]
const MIRROR := [Color("bfe4ff"), Color("ffffff"), Color("2e3e62")]
const METEOR := [Color("ff8a3a"), Color("ffc27a"), Color("4a1408")]
const STONE := Color("8c7a62")
## The elite wards: a magic circle, rune rings and a pillar of light (MeleeArt.ascend).
const GRAND := ["aegis_of_ages", "sanctuary_wall", "holy_rampart", "meteor_shield"]

const PALETTE := {
	"brace": BLOOD, "provoke": TAUNT, "grand_provoke": TAUNT,
	"ground_quake": EARTH, "quake_slam": EARTH, "titan_quake": EARTH, "bulwark_charge": EARTH, "bastion_crush": EARTH, "meteor_shield": EARTH,
	"thorn_guard": MIRROR, "unbreakable": MIRROR, "judgment_rebound": GOLD,
	"guardian_oath": GOLD, "holy_rampart": GOLD, "judgment_shield": GOLD, "sanctuary_wall": GOLD, "world_bastion": GOLD,
	"titan_shieldbreak": EARTH, "heavens_bulwark": AEGIS, "eternal_aegis": AEGIS, "pantheon_bastion": GOLD,
}


static func palette(id: String) -> Array:
	return PALETTE.get(id, AEGIS)


## Wind-up: hexagonal panels of shield light gather in front of the Defender,
## the ground hums with a tightening ring; Blood Swell starts its heartbeat.
static func charge(rig: MeleeArt, skill: Dictionary, ctx: Dictionary, duration: float) -> void:
	var c := palette(ctx.id)
	var p: float = ctx.power
	var t := maxf(duration, 0.15)
	if ctx.id == "brace":
		rig.layer("aura", MeleeArt.AURA, c, Vector3.ZERO, Vector3(0.7, 1.6, 0.7), Vector3.ZERO, 0.0, t + 0.1, {"initial": 0.5, "grow": t, "opacity": 0.55, "veins": 1.0, "pulse": 150.0, "dissolve": 0.85}, true)
		rig.gather(MeleeArt.SPARK, 12, Vector3(0, 1.0, 0), 1.6, c[0], 0.06, t * 0.9)
		return
	if ctx.id in GRAND:
		rig.layer("sigil", MeleeArt.RING, c, Vector3(0, 0.05, 0), Vector3.ONE * 2.6, Vector3.ZERO, 0.0, t + 0.1, {"initial": 0.2, "grow": t, "spin": 0.8, "opacity": 0.42, "fade_in": 0.35, "dissolve": 0.9})
	# Shown to the camera: the shield of light is read face-on whatever the facing.
	rig.layer("hexwall", MeleeArt.PANEL, c, Vector3(0, 0, 0.5), Vector3(1.0, 1.1, 1.0) * (0.9 + 0.3 * p), Vector3.ZERO, 0.0, t + 0.08, {"bill": "upright", "sweep": t * 0.9, "initial": 0.85, "grow": t, "opacity": 0.7, "dissolve": 0.85, "fade_in": 0.2}, true)
	rig.ring(c, Vector3(0, 0.05, 0), 1.8 + p, 0.8, 0.0, t + 0.05, Vector3.ZERO, {"opacity": 0.5, "grow": t})
	rig.gather(MeleeArt.SPARK, int(6 + 10 * p), Vector3(0, 1.0, 0.6), 1.5 + p, c[1].lerp(c[0], 0.4), 0.05, t * 0.9)


## A hexagonal plate of shield light at `at`, facing `toward` (rig-local yaw),
## rippling from its centre, with a burst of sparks.
static func plate(rig: MeleeArt, c: Array, at: Vector3, size: float, yaw: float, d: float, core := true) -> void:
	rig.layer("hexplate", MeleeArt.PANEL, c, at, Vector3.ONE * size, Vector3(0, yaw, 0), d, 0.55, {"sweep": 0.05, "initial": 0.5, "grow": 0.12, "overshoot": true, "opacity": 0.85, "dissolve": 0.45, "fade_in": 0.02}, core)
	rig.ring(c, at, 0.2, size * 1.6, d, 0.4, Vector3(PI * 0.5, yaw, 0), {"opacity": 0.75})
	rig.emit(MeleeArt.SPARK, 8, at, Basis(Vector3.UP, yaw) * Vector3(0, 0.6, 1.0) * 6.0, 0.7, c[1].lerp(c[0], 0.3), 0.08, 0.4, d, 7.0)


## The earth heaves: cracks with glowing seams, a ring of dust, heavy rock chips.
static func heave(rig: MeleeArt, c: Array, at: Vector3, size: float, d: float, chips: int, core := true) -> void:
	rig.cracks(c, at, size, d, 1.4, chips > 8, core)
	rig.ring(EARTH, at + Vector3.UP * 0.08, 0.3, size * 1.1, d, 0.55, Vector3.ZERO, {"opacity": 0.6})
	rig.chips(at, chips, 5.0 + size * 0.4, STONE, 0.35, 0.18 + size * 0.02, d)
	rig.emit(MeleeArt.SPARK, chips, at + Vector3.UP * 0.2, Vector3.UP * 3.0, 0.9, Color("b49a7a"), 0.09, 0.7, d, 3.0, 1.6, 2.0, size * 0.4)
	rig.light(at + Vector3.UP * 0.6, c[0], 1.6, size * 2.5, d, 0.35)


## A dome of hexagonal panels lighting from the ground up round the caster.
static func dome(rig: MeleeArt, c: Array, size: float, d: float, seconds := 1.4, core := true) -> void:
	rig.layer("hexdome", MeleeArt.PANEL, c, Vector3.ZERO, Vector3(size, size * 0.9, size), Vector3.ZERO, d, seconds, {"sweep": 0.35, "initial": 0.85, "grow": 0.3, "overshoot": true, "opacity": 0.6, "dissolve": 0.6, "spin": 0.3}, core)
	rig.ring(c, Vector3(0, 0.05, 0), 0.5, size * 1.15, d, 0.6, Vector3.ZERO, {"opacity": 0.6})


## Chains of light from the Defender to each foe in reach (cosmetic tether: the
## real taunt is applied by the combat code). Each chain is heavy links over a
## glowing core that runs out from the hand; then pulses of light race down it
## and burst on the foe it hooks.
static func chains(rig: MeleeArt, c: Array, r: float, d: float) -> void:
	var foes: Array = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		for node in tree.get_nodes_in_group("mobs"):
			var mob := node as Node3D
			if mob and mob.is_inside_tree() and mob.global_position.distance_to(rig.position) <= r + 0.5:
				foes.append(rig.transform.affine_inverse() * mob.global_position)
				if foes.size() >= 4:
					break
	if foes.is_empty():
		for k in 4:
			var a := TAU * float(k) / 4.0 + 0.4
			foes.append(Vector3(sin(a), 0, cos(a)) * r * 0.6)
	var hand := Vector3(0, 1.0, 0.2)
	var hot: Color = (c[1] as Color).lerp(c[0], 0.35)
	for k in foes.size():
		var to: Vector3 = foes[k] + Vector3.UP * 0.9
		var dir := to - hand
		var length := dir.length()
		if length < 0.3:
			continue
		var start := d + 0.03 * k
		# The links: blended, so their dark rim keeps them read as metal on any ground.
		# Ten links whatever the length: their height follows it so they stay links, not hoops.
		var girth := clampf(length * 1.5, 4.0, 8.0)
		rig.layer("chain", MeleeArt.SOLID, c, hand, Vector3(length, girth, girth), Vector3.ZERO, start, 1.15, {"bill": dir.normalized(), "sweep": 0.16, "tail": 1.0, "initial": 1.0, "opacity": 1.0, "dissolve": 0.6, "fade_in": 0.02, "ink": true, "front": 1}, k == 0)
		# The glowing core under the links, running out with them.
		rig.streak(c, hand, to, 0.42, start, 1.05, 0.16, {"tail": 1.2, "thick": 0.5, "opacity": 0.55, "dissolve": 0.55}, false)
		# Pulses of light racing down the chain to the foe, bursting where they land.
		var speed := 11.0
		var run := length / speed
		for beat in 2:
			var at := start + 0.18 + 0.38 * float(beat)
			rig.emit(MeleeArt.SPARK, 4, hand, dir / length * speed, 0.02, hot, 0.13, run, at, 0.0, 0.0)
			rig.emit(MeleeArt.SPARK, 5, to, Vector3.UP * 3.0, 0.9, c[0].lerp(c[1], 0.3), 0.08, 0.4, at + run, 5.0, 1.4)


## Blood Swell: a red heart aura that beats, veins of blood-light running up
## it, a ring on the ground at every beat and blood motes rising.
static func blood_swell(rig: MeleeArt, c: Array, d: float) -> void:
	var bpm := 96.0
	# A body of dark blood light (blended, so it stays red on any ground) ...
	rig.layer("aura", MeleeArt.AURA, c, Vector3.ZERO, Vector3(0.8, 2.1, 0.8), Vector3.ZERO, d, 1.9, {"initial": 0.4, "grow": 0.25, "overshoot": true, "opacity": 0.6, "pulse": bpm, "dissolve": 0.7, "ink": true}, true)
	# ... veins of glowing blood running up it, swelling on every beat ...
	rig.layer("aura", MeleeArt.AURA, c, Vector3.ZERO, Vector3(0.84, 2.3, 0.84), Vector3.ZERO, d + 0.03, 1.85, {"initial": 0.5, "grow": 0.3, "overshoot": true, "opacity": 0.9, "veins": 1.0, "pulse": bpm, "dissolve": 0.65})
	# ... and a heart-shaped swell of light at the chest.
	rig.layer("aura", MeleeArt.AURA, [c[0], c[1], c[2]], Vector3(0, 0.7, 0), Vector3(0.5, 0.9, 0.5), Vector3.ZERO, d, 1.8, {"initial": 0.7, "opacity": 0.55, "pulse": bpm, "dissolve": 0.6})
	for k in 3:
		rig.ring(c, Vector3(0, 0.06, 0), 0.5, 2.6, d + 60.0 / bpm * k, 0.5, Vector3.ZERO, {"opacity": 0.8 - 0.15 * k}, k == 0)
		rig.ring(c, Vector3(0, 1.1, 0), 0.4, 1.4, d + 60.0 / bpm * k + 0.02, 0.35, Vector3.ZERO, {"opacity": 0.55 - 0.12 * k})
	rig.emit(MeleeArt.SPARK, 16, Vector3(0, 0.4, 0), Vector3.UP * 1.8, 0.5, c[0], 0.1, 1.4, d, -0.4, 0.7, 4.0, 0.7)


## Reflection: mirrored shards orbit and glint round the Defender over a dome.
static func mirror(rig: MeleeArt, c: Array, d: float, size: float) -> void:
	dome(rig, c, size, d, 1.3)
	var n := rig.emit(MeleeArt.SHARD, 16, Vector3(0, 1.0, 0), Vector3.UP * 0.5, 0.2, c[0], 0.42, 1.6, d, 0.0, 0.3, 0.0, 0.0)
	if n > 0:
		var s := rig._pset(MeleeArt.SHARD)
		for k in n:
			var i := int(s.count) - n + k
			var a := TAU * float(k) / float(n)
			var radius := size * randf_range(0.75, 1.05)
			s.pos[i] = Vector3(sin(a) * radius, randf_range(0.3, 2.0), cos(a) * radius)
			s.vel[i] = Vector3(cos(a), randf_range(-0.1, 0.4), -sin(a)) * 2.6
			s.turb[i] = 2.0


static func play(rig: MeleeArt, skill: Dictionary, ctx: Dictionary) -> void:
	var id: String = ctx.id
	var c := palette(id)
	var r: float = ctx.radius
	var reach: float = ctx.reach
	var d: float = ctx.d
	var p: float = ctx.power
	var hit := Vector3(0, 1.0, reach)
	match id:
		"shield_bash", "shield_slam", "aegis_strike":
			plate(rig, c, hit - Vector3(0, 0, 0.5), 0.8 + 0.4 * p, PI, d)
			if id != "shield_bash":
				heave(rig, c, Vector3(0, 0, reach), 1.1 + p, d + 0.04, 5, false)
		"bastion_crush", "judgment_shield":
			rig.layer("hexplate", MeleeArt.PANEL, c, Vector3(0, 0.08, reach), Vector3.ONE * 1.6, Vector3(-PI * 0.5, 0, 0), d, 0.9, {"drop": 3.5, "land": 0.12, "sweep": 0.1, "initial": 1.0, "opacity": 0.85, "dissolve": 0.5}, true)
			heave(rig, c, Vector3(0, 0, reach), 2.2, d + 0.1, 9)
			if id == "judgment_shield":
				rig.layer("light_cross", MeleeArt.SOLID, c, Vector3(0, 0, reach), Vector3.ONE * 2.6, Vector3.ZERO, d + 0.1, 0.9, {"bill": "upright", "initial": 0.6, "grow": 0.2, "overshoot": true, "opacity": 0.7, "dissolve": 0.45})
		"brace":
			blood_swell(rig, c, d)
		"provoke", "grand_provoke":
			chains(rig, c, r, d)
			rig.ring(c, Vector3(0, 0.06, 0), 0.5, r * 0.9, d, 0.6, Vector3.ZERO, {"opacity": 0.6})
			rig.layer("aura", MeleeArt.AURA, c, Vector3.ZERO, Vector3(0.75, 1.7, 0.75), Vector3.ZERO, d, 0.8, {"initial": 0.4, "grow": 0.15, "opacity": 0.55})
			rig.layer("runes", MeleeArt.RING, c, Vector3(0, 0.95, 0), Vector3.ONE * 1.1, Vector3(0.18, 0, 0), d, 0.9, {"initial": 0.4, "grow": 0.15, "overshoot": true, "spin": 2.6, "opacity": 0.5, "dissolve": 0.6})
		"ground_quake", "quake_slam", "titan_quake", "shockwave_wall":
			var size := r * 0.75
			heave(rig, c, Vector3(0, 0, 0.6), size, d, 6 + int(6 * p))
			rig.ring(c, Vector3(0, 0.15, 0.6), 0.4, r, d + 0.05, 0.55, Vector3.ZERO, {"opacity": 0.65})
			if id == "shockwave_wall":
				rig.layer("hexwall", MeleeArt.PANEL, c, Vector3(0, 0, 0.0), Vector3(r * 0.45, 1.3, r * 0.45), Vector3.ZERO, d, 0.8, {"sweep": 0.18, "initial": 0.6, "grow": 0.2, "overshoot": true, "travel": Vector3(0, 0, r * 0.4), "opacity": 0.75, "dissolve": 0.5}, true)
		"shield_toss", "rebound_storm":
			plate(rig, c, Vector3(0, 1.0, 0.6), 0.6, 0.0, d)
			rig.layer("hexplate", MeleeArt.PANEL, c, Vector3(0, 1.0, 0.6), Vector3.ONE * 0.55, Vector3(PI * 0.5, 0, 0), d, 0.35, {"travel": Vector3(0, 0, reach - 0.8), "ease": "linear", "spin": 18.0, "sweep": 0.02, "initial": 1.0, "opacity": 0.9, "dissolve": 0.7})
			plate(rig, c, hit - Vector3(0, 0, 0.3), 0.7, PI, d + 0.12, false)
		"bulwark_charge", "shield_wave":
			rig.layer("hexwall", MeleeArt.PANEL, c, Vector3(0, 0, 0.3), Vector3(0.9, 1.0, 0.9), Vector3.ZERO, d, 0.5, {"sweep": 0.1, "initial": 0.8, "grow": 0.12, "travel": Vector3(0, 0, reach * 0.7), "opacity": 0.8, "dissolve": 0.5}, true)
			rig.streak(c, Vector3(0, 0.9, 0.4), Vector3(0, 0.9, reach + 1.5), 1.2, d, 0.5, 0.12, {"opacity": 0.5, "thick": 0.4})
			if id == "bulwark_charge":
				rig.emit(MeleeArt.SPARK, 10, Vector3(0, 0.1, reach * 0.4), Vector3(0, 1.5, -2.0), 0.7, Color("c8b49a"), 0.08, 0.6, d, 2.0, 1.5, 3.0, reach * 0.3)
			plate(rig, c, hit - Vector3(0, 0, 0.4), 0.9, PI, d + 0.1, false)
		"iron_wall", "guardian_oath", "aegis_of_ages", "sanctuary_wall":
			dome(rig, c, 1.5 + 0.7 * p, d, 1.5)
			# The circle, rune rings, pillar and the aura that stays with the Defender.
			rig.ascend(c, 2.2 + 0.3 * p if id in GRAND else 1.7, d, 2.6 if id in GRAND else 1.8, id in GRAND)
			rig.layer("hexwall", MeleeArt.PANEL, c, Vector3(0, 0, -0.1), Vector3(1.1, 1.2, 1.1), Vector3.ZERO, d, 1.0, {"sweep": 0.2, "initial": 0.8, "grow": 0.2, "opacity": 0.7, "dissolve": 0.5})
			if id in ["guardian_oath", "sanctuary_wall", "aegis_of_ages"]:
				rig.layer("light_cross", MeleeArt.SOLID, c, Vector3(0, 0.3, -0.4), Vector3.ONE * 1.8, Vector3.ZERO, d + 0.1, 1.2, {"bill": "upright", "travel": Vector3.UP * 0.5, "initial": 0.5, "overshoot": true, "grow": 0.25, "opacity": 0.6})
			rig.embers(Vector3(0, 0.3, 0), 10, 1.2, c[1].lerp(c[0], 0.4), d, 1.3, 1.8, 0.05)
		"thorn_guard", "unbreakable":
			mirror(rig, c, d, 1.6 + 0.4 * p)
			rig.ascend(c, 1.7, d, 1.8, false)
		"meteor_shield":
			# A circle of runes opens in the sky and the shield falls through it as a
			# meteor, dragging a burning tail ...
			rig.layer("runes", MeleeArt.RING, GOLD, Vector3(0, 6.4, 0), Vector3.ONE * 2.3, Vector3.ZERO, maxf(d - 0.3, 0.0), 0.75, {"initial": 0.3, "grow": 0.18, "overshoot": true, "spin": 2.8, "opacity": 0.6, "dissolve": 0.5, "fade_in": 0.05})
			rig.layer("hexplate", MeleeArt.PANEL, c, Vector3(0, 0.3, 0), Vector3.ONE * 2.4, Vector3(-PI * 0.5, 0, 0), d - 0.05, 1.0, {"drop": 6.0, "land": 0.14, "sweep": 0.1, "initial": 1.0, "opacity": 0.85, "dissolve": 0.5}, true)
			rig.streak(METEOR, Vector3(0, 7.0, 0), Vector3(0, 0.4, 0), 2.4, d - 0.05, 0.45, 0.14, {"opacity": 0.5, "thick": 0.8})
			rig.streak(GOLD, Vector3(0, 7.0, 0), Vector3(0, 0.4, 0), 1.2, d - 0.05, 0.4, 0.14, {"opacity": 0.5})
			# ... lands in a seal burnt into the ground, a column of fire leaps up and
			# rune rings ride the shock out while embers rise.
			rig.layer("sigil", MeleeArt.RING, METEOR, Vector3(0, 0.06, 0), Vector3.ONE * r * 0.85, Vector3.ZERO, d + 0.09, 1.8, {"initial": 0.3, "grow": 0.25, "overshoot": true, "spin": 0.5, "opacity": 0.6, "dissolve": 0.7, "fade_in": 0.04}, true)
			rig.layer("aura", MeleeArt.AURA, METEOR, Vector3.ZERO, Vector3(r * 0.22, 4.2, r * 0.22), Vector3.ZERO, d + 0.09, 0.7, {"initial": 0.15, "grow": 0.12, "overshoot": true, "opacity": 0.5, "dissolve": 0.35, "fade_in": 0.03})
			rig.layer("runes", MeleeArt.RING, GOLD, Vector3(0, 1.0, 0), Vector3.ONE * r * 0.4, Vector3(0.2, 0, 0), d + 0.14, 1.3, {"initial": 0.3, "grow": 0.3, "overshoot": true, "spin": -2.0, "opacity": 0.55, "dissolve": 0.6})
			heave(rig, c, Vector3.ZERO, r * 0.7, d + 0.09, 12)
			rig.embers(Vector3.ZERO, 14, r * 0.45, METEOR[0], d + 0.2, 1.4, 2.4, 0.07)
		"holy_rampart", "world_bastion":
			for k in 3:
				rig.layer("hexwall", MeleeArt.PANEL, c, Vector3.ZERO, Vector3(r * 0.5, 1.6, r * 0.5), Vector3(0, TAU * float(k) / 3.0, 0), d + 0.05 * k, 1.3, {"drop": -1.8, "land": 0.22, "sweep": 0.25, "initial": 1.0, "opacity": 0.7, "dissolve": 0.55}, k == 0)
			dome(rig, c, r * 0.4, d + 0.1, 1.3, false)
			heave(rig, EARTH if id == "world_bastion" else c, Vector3.ZERO, r * 0.7, d, 10, false)
			if id == "world_bastion":
				chains(rig, TAUNT, r, d + 0.15)
			rig.ascend(c, r * 0.45, d, 2.4, id in GRAND)
		_:
			plate(rig, c, hit, 1.0, PI, d)


## Star skills: every real contact beat. The rig stands on the contact point.
static func star(rig: MeleeArt, skill: Dictionary, ctx: Dictionary) -> void:
	var id: String = ctx.id
	var c := palette(id)
	var i: int = ctx.index
	var r: float = ctx.radius
	match id:
		"titan_shieldbreak":
			rig.layer("hexplate", MeleeArt.PANEL, AEGIS, Vector3(0, 0.1, 0), Vector3.ONE * (2.4 + 0.6 * i), Vector3(-PI * 0.5, 0, 0), -0.04, 0.9, {"drop": 3.0, "land": 0.1, "sweep": 0.1, "initial": 1.0, "opacity": 0.85, "dissolve": 0.5}, true)
			heave(rig, c, Vector3.ZERO, 2.6 + 1.0 * i, 0.04, 10 + 4 * i)
		"judgment_rebound":
			plate(rig, c, Vector3(0, 1.0, -0.2), 1.1, PI, 0.0)
			rig.layer("light_cross", MeleeArt.SOLID, c, Vector3.ZERO, Vector3.ONE * 2.0, Vector3.ZERO, 0.02, 0.7, {"bill": "upright", "initial": 0.6, "grow": 0.15, "overshoot": true, "opacity": 0.7, "dissolve": 0.45})
			rig.cracks(c, Vector3.ZERO, 1.8, 0.0, 1.0, i % 2 == 1)
		"eternal_aegis":
			dome(rig, c, 2.6, 0.0, 1.8)
			mirror(rig, MIRROR, 0.1, 2.2)
		"heavens_bulwark":
			rig.layer("hexplate", MeleeArt.PANEL, c, Vector3(0, 0.1, 0), Vector3.ONE * 3.2, Vector3(-PI * 0.5, 0, 0), -0.05, 1.0, {"drop": 6.0, "land": 0.14, "sweep": 0.1, "initial": 1.0, "opacity": 0.85, "dissolve": 0.5}, true)
			heave(rig, EARTH, Vector3.ZERO, r * 0.5, 0.09, 12)
			if i == 3:
				chains(rig, TAUNT, r, 0.12)
		"pantheon_bastion":
			if i < 4:
				rig.layer("hexwall", MeleeArt.PANEL, c, Vector3.ZERO, Vector3(r * 0.42, 1.8, r * 0.42), Vector3(0, float(i) * PI * 0.5, 0), 0.0, 1.0, {"drop": -2.0, "land": 0.2, "sweep": 0.2, "initial": 1.0, "opacity": 0.75, "dissolve": 0.5}, true)
				heave(rig, EARTH, Vector3.ZERO, r * 0.35, 0.02, 6)
			else:
				dome(rig, c, r * 0.5, 0.0, 1.6)
				rig.layer("hexplate", MeleeArt.PANEL, c, Vector3(0, 0.1, 0), Vector3.ONE * 4.0, Vector3(-PI * 0.5, 0, 0), -0.05, 1.1, {"drop": 7.0, "land": 0.16, "sweep": 0.1, "initial": 1.0, "opacity": 0.85, "dissolve": 0.5}, true)
				heave(rig, EARTH, Vector3.ZERO, r * 0.7, 0.11, 14)
				chains(rig, TAUNT, r, 0.15)
		_:
			plate(rig, c, Vector3(0, 1.0, 0), 1.0, PI, 0.0)
