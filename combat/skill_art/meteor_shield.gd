extends RefCounted
## Defender Lv.92 "Meteor Shield": the defender's shield comes down on the pack like a
## meteor. Wind-up: over the target area a flaming shield plunges out of the sky trailing
## fire, its shadow and a ring of fire marking where it will land. Release: it lands point
## first and stands in a crater, a fire ring and a quake ring roll out to the edge, molten
## fissures open, rock spikes burst up round the crater, rubble and embers fountain, dust
## rolls and the stars of the stun spin. Ember orange, lava red, gold and basalt.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const G := preload("res://combat/skill_art/_guard.gd")
const ID := "meteor_shield"
const ORANGE := Color("ffb04a")
const LAVA := Color("ff5a1e")
const GOLD := Color("ffe08a")
const BASALT := Color("3e3430")
const ROCK := Color("5e4c40")
const HIGH := 9.0


static func _shield() -> ArrayMesh:
	return M.solid("ms_shield", M.shield(Color("8a3a14"), ORANGE, GOLD), Vector3(1, 12, 1))


## A comet's tail of fire above the shield (unit beam up +Y), crossed planes.
static func _tail() -> ArrayMesh:
	if M.has("ms_tail"):
		return M.get_mesh("ms_tail")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.beam(st, Vector3.ZERO, 1.0, 1.0, M.a(LAVA, 0.9), 3, 0.0, 0.0, 0.1)
	K.beam(st, Vector3.ZERO, 0.7, 0.55, M.a(GOLD, 0.9), 2, 0.0, 0.0, 0.05)
	return M.keep("ms_tail", K.finish(st, Vector3.ONE * 0.5, false))


## Rock spikes in a ring (radius 1) leaning out, each up on its own moment.
static func _spikes() -> ArrayMesh:
	if M.has("ms_spikes"):
		return M.get_mesh("ms_spikes")
	var rng := RandomNumberGenerator.new()
	rng.seed = 921
	var st := K.begin()
	for i in 14:
		var ang := TAU * float(i) / 14.0 + rng.randf_range(-0.12, 0.12)
		var dir := Vector3(sin(ang), 0, cos(ang))
		var size := rng.randf_range(0.11, 0.17)
		var basis := Basis(Vector3(dir.z, 0, -dir.x), -rng.randf_range(0.3, 0.55)).scaled(Vector3(size, size * rng.randf_range(1.8, 2.6), size))
		K.stamp(st, K.spike(rng, ROCK if i % 2 == 0 else BASALT, 0.2), Transform3D(basis, dir * rng.randf_range(0.85, 1.0) + Vector3.DOWN * 0.03), 0.015 * float(i % 4), 1.0)
	return M.keep("ms_spikes", K.finish(st, Vector3(1, 2, 1)))


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	G.note(skill, visual, origin, aim)
	var time := maxf(duration, 0.12)
	var spot := Vector3(aim.x, 0.0, aim.z)
	var radius := float(skill.get("radius", 7.0))
	var r := G.windup(parent, spot, time + 0.06, "Skill_%s_windup" % ID, G.yaw(origin, spot), visual)
	if r == null:
		return false
	var high := G.sky_height(r, Vector3.ZERO, HIGH)
	# The shield plunges point-first out of the sky, a tail of fire above it.
	G.solid(r, _shield(), "Plunge", Vector3.UP * 0.4, Vector3.ONE * 2.4, time + 0.04, {"drop": (high - 0.4) / 2.4, "flight": time + 0.02, "ease": 0.0, "rim_color": GOLD, "rim": 1.2, "glow_color": LAVA, "heat": 0.0}, {"fade_in": 0.05, "decay": 0.99}, Vector3(0, K.facing(r), 0))
	G.flat(r, _tail(), "Tail", Vector3.UP * (high + 2.0), Vector3(1.1, high * 0.55, 1.1), time + 0.04, G.lit(LAVA, 0.7, 1.4, {"flow": 4.0}), {"travel": Vector3.DOWN * (high - 0.4), "accelerate": true, "fade_in": 0.1, "decay": 0.95})
	G.flat(r, G.sigil("ms_mark", LAVA, 2, 24, 0, 0.35), "Mark", Vector3.UP * 0.05, Vector3.ONE * radius, time + 0.04, G.lit(ORANGE, 0.55, 0.5), {"initial": 0.5, "grow_time": 0.9, "fade_in": 0.1, "decay": 0.97, "spin": 0.6})
	G.flat(r, K.glow_disc("ms_shadow", Color(0.12, 0.03, 0.0, 0.6)), "Shadow", Vector3.UP * 0.04, Vector3.ONE * 1.6, time + 0.04, {"soft": 0.8, "add": 0.0}, {"initial": 0.2, "grow_time": 1.0, "fade_in": 0.1, "decay": 0.98})
	G.done(r)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var who := G.caster_of(skill, origin)
	var caster: Node3D = who[0]
	var spot := Vector3(center.x, 0.0, center.z)
	var radius := float(skill.get("radius", 7.0))
	var turn := G.yaw(origin, spot, G.facing(caster))
	var r := G.open(parent, spot, 1.9, "Skill_%s_crater" % ID, turn, caster)
	if r == null:
		return false
	G.solid(r, _shield(), "Planted", Vector3.DOWN * 0.45, Vector3.ONE * 2.4, 1.5, {"drop": 0.85 / 2.4, "flight": 0.05, "heat": 1.0, "rim_color": GOLD, "rim": 1.0, "glow_color": LAVA}, {"fade_in": 0.01, "decay": 0.72}, Vector3(0, K.facing(r), 0))
	M.shock(r, "ms_ring", ORANGE, radius * 1.05, 0.0, 0.5, 0.22)
	M.cracks(r, "ms_cracks", LAVA, radius * 0.7, 0.02, 1.6, 10, 922, 0.07)
	M.rubble(r, "ms_rubble", [ROCK, BASALT, ROCK.darkened(0.2)], G.n(26), 0.5, 2.0, 5.0, 8.0, 0.3, 0.0, 1.3, Vector3.ZERO, 923)
	M.sparks(r, "ms_embers", [ORANGE, LAVA, GOLD], G.n(28), 0.2, 1.5, 4.0, 9.0, 0.13, 0.0, 1.2, Vector3.ZERO, 7.0, 924, 0.2, 0.8)
	M.dust(r, "ms_dust", Color("b89a80"), G.n(20), radius * 0.4, radius * 0.75, 0.05, 1.4, Vector3.ZERO, 1.1, 925)
	G.done(r)
	var more := G.extras(2)
	if more > 0:
		var fire := G.open(parent, spot, 1.6, "Skill_%s_fire" % ID, turn, caster)
		if fire:
			G.solid(fire, _spikes(), "Spikes", Vector3.ZERO, Vector3(radius * 0.5, radius * 0.32, radius * 0.5), 1.3, {"drop": -1.2, "flight": 0.15, "ease": 1.0, "rim_color": LAVA, "rim": 0.6, "glow_color": LAVA, "heat": 0.5}, {"delay": 0.04, "decay": 0.8})
			M.flash(fire, "ms_flash", LAVA, radius * 0.45, 0.0, 0.4)
			M.shock(fire, "ms_ring_b", LAVA, radius * 0.75, 0.08, 0.5, 0.3)
			M.pillar(fire, "ms_pillar", ORANGE, 1.6, 4.5, 0.0, 0.45)
			G.daze(fire, Color("ffe070"), Vector3(0, 2.6, 0), 1.0, 1.3, 0.12)
			M.shock(fire, "ms_ring_c", GOLD, radius * 1.18, 0.2, 0.55, 0.08)
			G.done(fire)
	return true


static func contact(parent: Node3D, skill: Dictionary, at: Vector3, crit: bool) -> void:
	G.hit(parent, skill, at, [ORANGE, GOLD], crit)
