extends RefCounted
## Dark Lord 200 stars: มหาวิบัติจักรพรรดิ. Risen into the sky, the Dark Lord calls an
## imperial storm: a wheel of thunderclouds gathers over the target round a turning gold
## vortex, the ground under it darkens and an imperial seal burns into it. Four waves
## alternate gold lightning splitting the ground and pillars of violet hellfire; for the
## fifth the storm collapses into one colossal bolt that crowns the field in a ring of
## dark fire, shattering the ground. Close to the god tier, without its throne. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const ID := "imperial_cataclysm"
const BEATS := [0.0, 0.32, 0.64, 0.96, 1.36]
const SKY := 7.6
const TALL := 8.6
const GOLD := Color("ffc83a")
const GOLD_HI := Color("fff2b8")
const VIOLET := Color("8a3cff")
const VIOLET_DK := Color("2a0f55")
const STORM := Color("3a3150")
const STORM_DK := Color("1a1428")
const FIRE := [Color(1.0, 0.82, 0.45, 0.95), Color(1.0, 0.35, 0.55, 0.95), Color(0.6, 0.15, 0.95, 0.92), Color(0.26, 0.05, 0.5, 0.88), Color(0.1, 0.02, 0.2, 0.8)]
const FIRE_LOOK := {"noise_amt": 1.0, "noise_scale": Vector2(5.0, 1.5), "flow": Vector2(0.0, -3.2), "bias": 0.12, "taper": 0.95, "sway": 0.4, "edge_heat": 0.8, "hot": Color(1.0, 0.6, 0.95)}
const STORM_LOOK := {"noise_amt": 1.0, "noise_scale": Vector2(7.0, 3.0), "flow": Vector2(0.35, 0.0), "bias": 0.25, "taper": 0.6}
static var _fit := 1.0


static func _r(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 7.5)), 4.0, 9.0)


static func _root(parent: Node3D, point: Vector3, seconds: float, label: String, source: Vector3) -> StarSkillArt:
	return S.root(parent, Vector3(point.x, 0, point.z), seconds, label, source, null, _fit)


static func _spot(index: int, r: float) -> Vector3:
	return [Vector3(-0.42, 0, 0.1), Vector3(0.4, 0, 0.32), Vector3(-0.1, 0, -0.38), Vector3(0.22, 0, -0.1)][index % 4] * r


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var origin := caster.global_position
	var parent := art.get_parent() as Node3D
	_fit = K.frame(parent, point, origin, TALL, 0.0)
	var r := _r(skill) / _fit
	# The Dark Lord rises in a ring of gold lightning.
	K.put(art, K.VEIL, K.shock(VIOLET, GOLD, VIOLET_DK), "CataclysmCallRing", Vector3.UP * 0.08, Vector3.ONE * 2.0, Vector3.ZERO, time, {"initial": 0.3, "grow_time": 0.5, "spin": -1.4, "decay": 0.9}, {"opacity": 0.8})
	K.put(art, K.GLOW, S.spiral("cataclysm_rise", Color(1.0, 0.8, 0.3, 0.7), Color(0.6, 0.3, 1.0, 0.0), 3, 1.6, 0.4), "CataclysmRise", Vector3.UP * 0.2, Vector3(1.6, 5.5, 1.6), Vector3.ZERO, time, {"initial": 0.4, "grow_time": 0.5, "fade_in": 0.2, "spin": 4.5, "decay": 0.85})
	# The storm stands over the target from now until the finale has burnt out.
	var stay := time + float(BEATS[4]) + 0.9
	var storm := _root(parent, point, stay, "StarCataclysmStorm_" + ID, origin)
	if storm:
		var come := {"initial": 0.2, "grow_time": time / stay * 0.8, "fade_in": time / stay * 0.5}
		K.put(storm, K.VEIL, storm_mesh(), "CataclysmClouds", Vector3.UP * SKY, Vector3.ONE * r, Vector3.ZERO, stay, {"spin": 0.45, "decay": 0.86, "priority": -1}.merged(come, true), STORM_LOOK)
		K.put(storm, K.VEIL, vortex_mesh(), "CataclysmVortex", Vector3.UP * (SKY + 0.1), Vector3.ONE * r * 0.78, Vector3.ZERO, stay, {"spin": -1.6, "decay": 0.86, "priority": -1}.merged(come, true))
		K.put(storm, K.VEIL, sigil_mesh(), "CataclysmSeal", Vector3.UP * 0.06, Vector3.ONE * r, Vector3.ZERO, stay, {"spin": 0.25, "decay": 0.86}.merged(come, true))
		K.put(storm, K.VEIL, S.wash("cataclysm_dark", Color(0.1, 0.05, 0.2, 0.45), Color(0.14, 0.06, 0.26, 0.3)), "CataclysmShadow", Vector3.UP * 0.03, Vector3.ONE * r * 1.15, Vector3.ZERO, stay, {"decay": 0.86, "priority": -2}.merged(come, true))
		K.put(storm, K.GLOW, sky_bolts(), "CataclysmSkyBolts", Vector3.UP * SKY, Vector3.ONE * r * 0.7, Vector3.ZERO, stay, {"spin": 0.9, "decay": 0.86, "delay": time * 0.35}, {"flicker": 0.6, "opacity": 0.85})
		storm._draw()
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var r := _r(skill) / _fit
	art.scale = Vector3.ONE * _fit
	if index >= 4:
		return _finale(art, parent, r, point, source)
	var spot := _spot(index, r)
	if index % 2 == 0:
		# Gold lightning splits the ground; hellfire spurts from the crack.
		K.put(art, K.GLOW, bolt_mesh(), "CataclysmBolt", spot, Vector3(1.0, SKY / 8.0, 1.0), Vector3(0, index * 1.7, 0), 0.4, {"fade_in": 0.01, "decay": 0.55, "front": true, "cull": 6.0}, {"flicker": 0.45, "heat": 0.4, "hot": GOLD_HI})
		K.put(art, K.VEIL, S.flame_cluster("cataclysm", FIRE), "CataclysmSpurt", spot, Vector3(1.6, 2.6, 1.6), Vector3(0, index, 0), 0.8, {"initial": 0.3, "grow_time": 0.18, "fade_in": 0.02, "decay": 0.5, "delay": 0.04}, FIRE_LOOK)
	else:
		# A pillar of violet hellfire bursts up; violet lightning answers it.
		K.put(art, K.VEIL, S.flame_cluster("cataclysm", FIRE), "CataclysmPillar", spot, Vector3(2.2, 5.2, 2.2), Vector3(0, index * 2.0, 0), 0.9, {"initial": 0.25, "grow_time": 0.16, "fade_in": 0.02, "decay": 0.5, "front": true}, FIRE_LOOK)
		K.put(art, K.GLOW, bolt_mesh(), "CataclysmBoltViolet", spot + Vector3(0.6, 0, -0.4), Vector3(0.7, SKY / 8.0, 0.7), Vector3(0, index * 1.3, 0), 0.32, {"fade_in": 0.01, "decay": 0.55, "delay": 0.06, "cull": 6.0}, {"flicker": 0.5, "tint": Color(0.75, 0.5, 1.0)})
	K.put(art, K.VEIL, K.cracks("cataclysm", Color(0.06, 0.02, 0.1), Color(1.0, 0.75, 0.3), 9, 0.35), "CataclysmScar", spot + Vector3.UP * 0.05, Vector3.ONE * 2.8, Vector3(0, index, 0), 1.4, {"initial": 0.35, "grow_time": 0.1, "decay": 0.6, "priority": -1})
	K.put(art, K.VEIL, K.shock(VIOLET, GOLD, VIOLET_DK), "CataclysmRing", spot + Vector3.UP * 0.1, Vector3.ONE * 3.2, Vector3.ZERO, 0.45, {"initial": 0.15, "grow_time": 0.9, "decay": 0.3}, {"opacity": 0.85})
	K.put(art, K.VEIL, K.embers("cataclysm", [GOLD, Color("ff70c0"), VIOLET]), "CataclysmEmbers", spot + Vector3.UP * 0.3, Vector3.ONE * 0.9, Vector3.ZERO, 1.0, {"cull": 10.0, "decay": 0.9}, {"burst": 1.0, "gravity": -2.0, "drag": 1.5, "life": 0.95})
	if S.rich():
		K.put(art, K.SOLID, K.debris("cataclysm_rock", [Color("2a2038"), Color("4a3a60"), Color("6a4a20")], 18, 0.32), "CataclysmRocks", spot + Vector3.UP * 0.2, Vector3.ONE * 0.9, Vector3.ZERO, 1.0, {"cull": 10.0, "decay": 0.9}, {"burst": 1.0, "gravity": 15.0, "drag": 1.0, "life": 0.95, "rim_color": GOLD, "rim": 0.6})
	return true


static func _finale(art: StarSkillArt, parent: Node3D, r: float, point: Vector3, source: Vector3) -> bool:
	# The storm collapses into one colossal bolt that crowns the field in dark fire.
	K.put(art, K.GLOW, K.column("cataclysm_core", [Color(1.0, 0.85, 0.45, 0.95), Color(1.0, 0.7, 0.3, 0.8), Color(0.75, 0.4, 1.0, 0.5), Color(0.6, 0.3, 1.0, 0.0)], 0.7, 14), "CataclysmColumn", Vector3.ZERO, Vector3(1.5, SKY + 1.0, 1.5), Vector3.ZERO, 0.6, {"initial": 0.4, "grow_time": 0.15, "fade_in": 0.01, "decay": 0.35, "front": true}, {"noise_amt": 0.6, "noise_scale": Vector2(6.0, 2.0), "flow": Vector2(0.0, -8.0), "bias": -0.25, "taper": 0.25, "fres": 0.6})
	K.put(art, K.GLOW, bolt_mesh(), "CataclysmGreatBolt", Vector3.ZERO, Vector3(2.0, SKY / 8.0, 2.0), Vector3.ZERO, 0.5, {"fade_in": 0.01, "decay": 0.55, "front": true, "cull": 8.0}, {"flicker": 0.4, "heat": 0.5, "hot": GOLD_HI})
	K.put(art, K.VEIL, S.flame_ring("cataclysm_crown", FIRE, 12, 0.1, 0.9, 0.6), "CataclysmCrownFire", Vector3.ZERO, Vector3(r * 0.7, 5.0, r * 0.7), Vector3.ZERO, 1.3, {"initial": 0.4, "grow_time": 0.16, "fade_in": 0.02, "decay": 0.5, "delay": 0.05, "front": true}, FIRE_LOOK)
	K.put(art, K.VEIL, K.shock(VIOLET, GOLD_HI, GOLD), "CataclysmShock", Vector3.UP * 0.12, Vector3.ONE * r * 1.15, Vector3.ZERO, 0.75, {"initial": 0.08, "grow_time": 0.75, "fade_in": 0.02, "decay": 0.45}, {"opacity": 0.85})
	K.put(art, K.VEIL, K.cracks("cataclysm_big", Color(0.06, 0.02, 0.1), Color(1.0, 0.75, 0.3), 14, 0.0), "CataclysmRift", Vector3.UP * 0.05, Vector3.ONE * r * 1.05, Vector3.ZERO, 1.9, {"initial": 0.5, "grow_time": 0.08, "fade_in": 0.01, "decay": 0.7, "priority": -1})
	K.put(art, K.SOLID, K.debris("cataclysm_big_rock", [Color("2a2038"), Color("4a3a60"), Color("6a4a20"), Color("1a1428")], 30, 0.5), "CataclysmDebris", Vector3.UP * 0.4, Vector3.ONE * 1.5, Vector3.ZERO, 1.6, {"cull": 20.0, "decay": 0.92}, {"burst": 1.0, "gravity": 14.0, "drag": 0.9, "life": 1.4, "rim_color": GOLD, "rim": 0.6})
	var extras := GodSkillArt.extra_roots(2)
	if extras < 1:
		return true
	var after := _root(parent, point, 2.0, "StarCataclysmAfter_" + ID, source)
	if after:
		K.put(after, K.VEIL, K.shock(GOLD, GOLD_HI, VIOLET), "CataclysmSecondShock", Vector3.UP * 0.14, Vector3.ONE * r * 0.8, Vector3.ZERO, 0.8, {"initial": 0.08, "grow_time": 0.8, "decay": 0.4, "delay": 0.14})
		K.put(after, K.VEIL, K.embers("cataclysm_big", [GOLD, Color("ff70c0"), VIOLET], 34, 4.5, 4.0), "CataclysmEmbersBig", Vector3.UP * 0.4, Vector3(2.0, 1.4, 2.0), Vector3.ZERO, 1.8, {"cull": 20.0, "decay": 0.9}, {"burst": 1.0, "gravity": -2.5, "drag": 1.2, "life": 1.7})
		K.put(after, K.VEIL, K.column("cataclysm_smoke", [Color(0.16, 0.08, 0.24, 0.0), Color(0.2, 0.1, 0.3, 0.5), Color(0.14, 0.06, 0.22, 0.3), Color(0.1, 0.04, 0.16, 0.0)], 1.3, 24), "CataclysmSmoke", Vector3.ZERO, Vector3(r * 0.7, 4.0, r * 0.7), Vector3.ZERO, 1.8, {"initial": 0.7, "grow_time": 0.5, "fade_in": 0.2, "travel": Vector3.UP * 1.0, "decay": 0.55, "delay": 0.3, "priority": -1}, {"noise_amt": 1.0, "noise_scale": Vector2(9.0, 1.2), "flow": Vector2(0.15, -0.8), "bias": -0.1, "taper": 0.6})
		after._draw()
	if extras < 2:
		return true
	var sky := _root(parent, point, 1.6, "StarCataclysmBreak_" + ID, source)
	if sky:
		# The storm tears open and thins away; the light of it fades over the field.
		K.put(sky, K.VEIL, storm_mesh(), "CataclysmCloudsBreak", Vector3.UP * SKY, Vector3.ONE * r, Vector3.ZERO, 1.2, {"initial": 1.0, "grow_time": 0.8, "fade_in": 0.001, "decay": 0.25, "spin": 1.2, "priority": -1}, STORM_LOOK.merged({"bias": -0.2}, true))
		K.put(sky, K.VEIL, K.sprite(), "CataclysmAfterglow", Vector3.UP * 0.2, Vector3.ONE * r * 0.9, Vector3(-PI / 2, 0, 0), 1.6, {"fade_in": 0.05, "decay": 0.35, "priority": -1}, {"radial": 1.2, "tint": Color("c070ff"), "opacity": 0.45})
		sky._draw()
	return true


# ---------------------------------------------------------------------------
# Meshes
# ---------------------------------------------------------------------------
## A gold bolt from 8 m down to the ground (thin violet corona), with a forked branch.
static func bolt_mesh() -> ArrayMesh:
	return K.cached("star_cataclysm_bolt", func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 33
		K.bolt(b, Vector3(0.4, 8.0, -0.3), Vector3.ZERO, 0.55, Color(1.0, 0.85, 0.4, 0.95), Color(0.65, 0.3, 1.0, 1.0), rng, 7, 1.0)
		K.bolt(b, Vector3(0.1, 4.6, 0.0), Vector3(1.5, 0.0, 0.6), 0.3, Color(1.0, 0.8, 0.35, 0.9), Color(0.65, 0.3, 1.0, 1.0), rng, 4, 0.6)
		rng.seed = 33
		K.bolt(b, Vector3(0.4, 8.0, -0.3), Vector3.ZERO, 0.16, Color(1.0, 0.97, 0.85, 1.0), Color(1.0, 0.9, 0.6, 1.0), rng, 7, 1.0)
		return b.mesh())


## The storm's wheel of cloud (radius 1): heavy and dark at the rim, thin round the eye,
## the shader's noise tearing it into drifting rags (UV.y runs rim to eye).
static func storm_mesh() -> ArrayMesh:
	return K.cached("star_cataclysm_storm", func():
		var b := K.Builder.new()
		var segs := 40
		var bands := [[1.12, Color(STORM_DK, 0.0)], [0.98, Color(STORM, 0.62)], [0.72, Color(STORM.lerp(VIOLET, 0.3), 0.66)], [0.42, Color(VIOLET_DK, 0.4)], [0.22, Color(VIOLET, 0.0)]]
		for k in bands.size() - 1:
			var base := b.v.size()
			for j in segs + 1:
				var a := TAU * j / float(segs)
				var d := Vector3(sin(a), 0, cos(a))
				b.pt(d * float(bands[k][0]), Vector3.UP, bands[k][1], Vector2(float(j) / segs * 3.0, float(k) / 4.0))
				b.pt(d * float(bands[k + 1][0]) + Vector3.UP * 0.12 * k, Vector3.UP, bands[k + 1][1], Vector2(float(j) / segs * 3.0, float(k + 1) / 4.0))
			for j in segs:
				var q := base + j * 2
				b.tri(q, q + 1, q + 3); b.tri(q, q + 3, q + 2)
		return b.mesh())


## Flickering bolts inside the clouds (radius 1, flat).
static func sky_bolts() -> ArrayMesh:
	return K.cached("star_cataclysm_sky_bolts", func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 9
		for i in 5:
			var a := TAU * i / 5.0
			var from := Vector3(sin(a), 0.05, cos(a)) * 0.95
			var to := Vector3(sin(a + 1.5), -0.25, cos(a + 1.5)) * 0.35
			K.bolt(b, from, to, 0.05, Color(1.0, 0.85, 0.4, 0.9), Color(0.7, 0.4, 1.0, 1.0), rng, 5, 0.15)
		return b.mesh())


## The gold vortex in the eye of the storm (radius 1): spiral arms over a violet disc.
static func vortex_mesh() -> ArrayMesh:
	return K.cached("star_cataclysm_vortex", func():
		var b := K.Builder.new()
		b.annulus(0.0, 1.0, 36, Color(0.5, 0.25, 0.95, 0.5), Color(0.2, 0.08, 0.4, 0.0))
		for arm in 4:
			var prev := Vector3.ZERO
			for k in range(1, 25):
				var f := float(k) / 24.0
				var a := TAU * arm / 4.0 + f * 4.0
				var here := Vector3(sin(a), -0.02, cos(a)) * f
				var w := 0.08 * f + 0.01
				var side := (here - prev).cross(Vector3.UP).normalized()
				b.quad(prev - side * w, prev + side * w, here + side * w, here - side * w, Color(1.0, 0.85, 0.45, 0.9 - 0.6 * f), Color(1.0, 0.75, 0.35, 0.85 - 0.75 * f))
				prev = here
		return b.mesh())


## The imperial seal burnt into the ground under the storm (radius 1).
static func sigil_mesh() -> ArrayMesh:
	return K.cached("star_cataclysm_sigil", func():
		var b := K.Builder.new()
		var line := Color(1.0, 0.78, 0.3, 0.9)
		b.annulus(0.94, 0.98, 48, line, Color(1.0, 0.9, 0.6, 0.9))
		b.annulus(0.98, 1.05, 48, Color(0.6, 0.3, 1.0, 0.6), Color(0.6, 0.3, 1.0, 0.0))
		b.annulus(0.62, 0.65, 40, line, line)
		for i in 6:
			var a := TAU * i / 6.0
			var c := Vector3(sin(a), 0, cos(a)) * 0.8
			b.xf = Transform3D(Basis.IDENTITY, c + Vector3.UP * 0.004)
			b.annulus(0.1, 0.13, 14, line, line)
			b.xf = Transform3D.IDENTITY
		# A six-pointed star drawn across the inner field.
		for k in 2:
			for j in 3:
				var a0 := TAU * (j + k * 0.5) / 3.0
				var a1 := TAU * (j + 1 + k * 0.5) / 3.0
				var p := Vector3(sin(a0), 0.003, cos(a0)) * 0.62
				var q := Vector3(sin(a1), 0.003, cos(a1)) * 0.62
				var side := (q - p).cross(Vector3.UP).normalized() * 0.015
				b.quad(p - side, p + side, q + side, q - side, line)
		return b.mesh())
