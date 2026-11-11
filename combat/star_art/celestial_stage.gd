extends RefCounted
## Bard 150 stars: เวทีสรวงสวรรค์. A round stage of night-violet inlaid with a gold star
## rises under the Bard; behind it a golden crescent moon climbs before a curtain of
## hanging stars, and three pastel spotlights swing down from the sky onto the Bard. With
## the buff the spotlights flare, a fanfare of notes and confetti bursts up and a ring of
## gold sweeps out over everyone the stage reaches. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const ID := "celestial_stage"
const GOLD := Color("ffc24a")
const GOLD_DK := Color("c8861e")
const GOLD_HI := Color("fff0b8")
const NIGHT := Color("3a2458")
const NIGHT_HI := Color("5a3a80")
const ROSE := Color("ff8ac0")
const LILAC := Color("b9a0ff")
const SKYBLUE := Color("9ad8ff")
const STAGE := 2.5
const MOON := Vector3(0, 3.9, 3.2)
const LOOK := {"rim_color": Color("fff4d8"), "rim": 0.55, "shadow_tint": Color(0.7, 0.6, 0.85)}


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var origin := caster.global_position
	var parent := art.get_parent() as Node3D
	var stay := time + 2.2
	var set_root := S.root(parent, origin, stay, "StarStageSet_" + ID, origin)
	if set_root:
		S.face_away(set_root)
		var rise := {"fade_in": 0.06, "decay": 0.86}
		K.put(set_root, K.SOLID, stage_mesh(), "StageFloor", Vector3.ZERO, Vector3.ONE, Vector3.ZERO, stay, rise.merged({"spin": 0.12}, true), LOOK.merged({"slide": Vector3(0, -0.6, 0), "slide_time": time * 0.6, "slide_ease": -2.0}))
		K.put(set_root, K.SOLID, moon_mesh(), "StageMoon", MOON, Vector3.ONE * 1.55, Vector3(-0.35, 0, 0), stay, {"fade_in": 0.12, "decay": 0.86, "cull": 4.0}, LOOK.merged({"slide": Vector3(0, -2.8, 0), "slide_time": time * 0.9, "slide_ease": -2.2, "flap": 0.1, "flap_rate": 2.4}))
		K.put(set_root, K.GLOW, spotlights_mesh(), "StageSpotlights", Vector3.ZERO, Vector3.ONE, Vector3.ZERO, stay, {"fade_in": time / stay * 0.7, "decay": 0.8, "priority": -1}, {"noise_amt": 0.4, "noise_scale": Vector2(4.0, 0.6), "flow": Vector2(0.3, 0.0), "bias": -0.3, "taper": 0.0})
		K.put(set_root, K.GLOW, curtain_mesh(), "StageCurtain", Vector3.ZERO, Vector3.ONE, Vector3.ZERO, stay, {"initial": 0.6, "grow_time": time / stay, "fade_in": time / stay * 0.8, "decay": 0.85, "priority": -1}, {"flicker": 0.15})
		K.put(set_root, K.GLOW, K.sprite(), "StageMoonGlow", MOON + Vector3(0, 0.0, 0.3), Vector3.ONE * 3.0, Vector3.ZERO, stay, {"fade_in": 0.2, "decay": 0.85, "priority": -2}, {"radial": 1.8, "billboard": true, "tint": Color("ffcf70"), "opacity": 0.35})
		set_root._draw()
	K.put(art, K.VEIL, S.spiral("stage_rise", Color(1.0, 0.8, 0.4, 0.7), Color(1.0, 0.5, 0.85, 0.0), 3, 1.2, 0.3), "StageRise", Vector3.UP * 0.2, Vector3(1.6, 2.6, 1.6), Vector3.ZERO, time, {"initial": 0.6, "grow_time": 0.6, "fade_in": 0.2, "spin": 3.5, "decay": 0.85})
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var reach := clampf(float(skill.get("radius", 8.0)), 4.0, 9.0)
	# The fanfare: the spotlights flare, notes and confetti burst up, gold sweeps out.
	K.put(art, K.GLOW, S.twinkle("stage_flash", Color(1.0, 0.78, 0.45, 0.95), Color(1.0, 0.6, 0.85)), "StageFlash", Vector3.UP * 1.6, Vector3.ONE * 2.6, Vector3.ZERO, 0.45, {"initial": 0.3, "grow_time": 0.35, "fade_in": 0.01, "decay": 0.4}, {"billboard": true})
	K.put(art, K.VEIL, K.shock(GOLD, GOLD_HI, ROSE), "StageSweep", Vector3.UP * 0.12, Vector3.ONE * reach, Vector3.ZERO, 0.75, {"initial": 0.12, "grow_time": 0.9, "fade_in": 0.02, "decay": 0.45}, {"opacity": 0.6})
	K.put(art, K.SOLID, S.note_spray("stage_fanfare", [GOLD, ROSE, LILAC, SKYBLUE, Color("ffd27a")], 16, 9.0, 3.5), "StageFanfare", Vector3.UP * 0.3, Vector3.ONE * 1.1, Vector3.ZERO, 1.6, {"cull": 12.0, "decay": 0.85}, LOOK.merged({"burst": 1.0, "gravity": 8.0, "drag": 1.0, "life": 1.6}))
	K.put(art, K.SOLID, S.DS.confetti_mesh(), "StageConfetti", Vector3.UP * 0.2, Vector3.ONE * 0.75, Vector3.ZERO, 1.8, {"cull": 12.0, "decay": 0.85}, LOOK.merged({"burst": 1.0, "gravity": 5.0, "drag": 2.0, "life": 1.8, "flap": 0.0}))
	K.put(art, K.GLOW, K.sprite(), "StagePool", Vector3.UP * 0.1, Vector3.ONE * STAGE * 1.2, Vector3(-PI / 2, 0, 0), 1.2, {"initial": 0.6, "grow_time": 0.2, "fade_in": 0.02, "decay": 0.5}, {"radial": 1.3, "tint": Color("ffb860"), "opacity": 0.45})
	K.put(art, K.VEIL, S.sparkles("stage", [GOLD, ROSE, LILAC, GOLD_HI], 24, 5.0, 3.0), "StageSparkles", Vector3.UP * 0.4, Vector3.ONE * 1.2, Vector3.ZERO, 1.5, {"cull": 10.0, "decay": 0.85}, {"burst": 1.0, "gravity": -0.8, "drag": 1.6, "life": 1.5})
	return true


# ---------------------------------------------------------------------------
# Meshes
# ---------------------------------------------------------------------------
## The round stage (radius STAGE, a hand high): night-violet boards, a gold rim and a
## gold five-pointed star inlaid, small lamps round the edge.
static func stage_mesh() -> ArrayMesh:
	return K.cached("star_stage_floor", func():
		var b := K.Builder.new()
		var r := STAGE
		b.lathe([[r * 1.04, -0.05, GOLD_DK], [r * 1.04, 0.08, GOLD], [r, 0.11, GOLD_HI], [r * 0.95, 0.1, GOLD], [r * 0.94, 0.06, NIGHT_HI]], 40)
		b.annulus(0.0, r * 0.94, 40, NIGHT_HI, NIGHT, 0.06)
		b.emit = 0.55
		b.annulus(r * 0.78, r * 0.8, 48, GOLD, GOLD, 0.065)
		var pts := [Vector3(0, 0.07, 0)]
		for j in 11:
			var a := TAU * j / 10.0
			var rr := r * (0.62 if j % 2 == 0 else 0.26)
			pts.append(Vector3(sin(a) * rr, 0.07, cos(a) * rr))
		b.fan(pts, GOLD_HI, GOLD)
		for i in 16:
			var a := TAU * (i + 0.5) / 16.0
			b.ball(Vector3(sin(a), 0, cos(a)) * r * 0.98 + Vector3.UP * 0.13, Vector3.ONE * 0.07, GOLD_HI if i % 2 else Color("ffc0e0"), GOLD, 6, 3)
		b.emit = 0.0
		return b.mesh())


## The crescent moon behind the stage (radius 1, upright in XY, horns up), bobbing gently.
static func moon_mesh() -> ArrayMesh:
	return K.cached("star_stage_moon", func():
		var b := K.Builder.new()
		b.weight = 1.0
		var steps := 22
		var prev_o := Vector3.ZERO
		var prev_i := Vector3.ZERO
		for k in steps + 1:
			var f := float(k) / steps
			var a := lerpf(-2.5, 2.5, f) + PI
			var w := sin(PI * f)
			var outer := Vector3(sin(a), cos(a), 0)
			var inner := outer * (1.0 - 0.42 * w) + Vector3(0, 0.22 * w, 0)
			if k > 0:
				var c0 := GOLD.lerp(GOLD_HI, 0.5 * w)
				b.quad(prev_i + Vector3.BACK * -0.12, prev_o + Vector3.BACK * -0.12, outer + Vector3.BACK * -0.12, inner + Vector3.BACK * -0.12, c0)
				b.quad(prev_i + Vector3.BACK * 0.12, prev_o + Vector3.BACK * 0.12, outer + Vector3.BACK * 0.12, inner + Vector3.BACK * 0.12, GOLD_DK)
				b.quad(prev_o + Vector3.BACK * -0.12, prev_o + Vector3.BACK * 0.12, outer + Vector3.BACK * 0.12, outer + Vector3.BACK * -0.12, GOLD)
				b.quad(prev_i + Vector3.BACK * -0.12, prev_i + Vector3.BACK * 0.12, inner + Vector3.BACK * 0.12, inner + Vector3.BACK * -0.12, GOLD_DK)
			prev_o = outer
			prev_i = inner
		b.emit = 0.9
		b.gem(Vector3(-0.95, 0.9, -0.05), Vector3(0.12, 0.2, 0.06), GOLD_HI, Color.WHITE)
		b.gem(Vector3(1.0, 0.5, -0.05), Vector3(0.09, 0.15, 0.05), Color("ffc0e0"), Color.WHITE)
		b.emit = 0.0
		b.weight = 0.0
		return b.mesh())


## Three pastel spotlights from high over the back and both wings onto the stage, each
## with its pool of light (in metres; +Z is the back of the stage).
static func spotlights_mesh() -> ArrayMesh:
	return K.cached("star_stage_spotlights", func():
		var b := K.Builder.new()
		var tops := [Vector3(-6.0, 8.5, 3.5), Vector3(6.0, 8.5, 3.5), Vector3(0.0, 9.5, 6.5)]
		var feet := [Vector3(-0.4, 0.1, 0.2), Vector3(0.4, 0.1, 0.2), Vector3(0.0, 0.1, -0.3)]
		var tones := [Color("ff8ac8"), Color("7ab8ff"), Color("ffc84a")]
		for k in 3:
			var top: Vector3 = tops[k]
			var foot: Vector3 = feet[k]
			var tone: Color = tones[k]
			var along := (foot - top).normalized()
			var side := along.cross(Vector3.UP).normalized()
			for across in [side, side.cross(along)]:
				var a := b.v.size()
				b.pt(top - across * 0.12, Vector3.UP, Color(tone, 0.0), Vector2(0, 0))
				b.pt(top, Vector3.UP, Color(tone, 0.2), Vector2(0.5, 0))
				b.pt(top + across * 0.12, Vector3.UP, Color(tone, 0.0), Vector2(1, 0))
				b.pt(foot - across * 1.3, Vector3.UP, Color(tone, 0.0), Vector2(0, 1))
				b.pt(foot, Vector3.UP, Color(tone, 0.16), Vector2(0.5, 1))
				b.pt(foot + across * 1.3, Vector3.UP, Color(tone, 0.0), Vector2(1, 1))
				for j in 2:
					b.tri(a + j, a + j + 1, a + j + 4); b.tri(a + j, a + j + 4, a + j + 3)
			b.xf = Transform3D(Basis.IDENTITY, foot)
			b.annulus(0.0, 1.1, 18, Color(tone, 0.3), Color(tone, 0.18))
			b.annulus(1.1, 1.5, 18, Color(tone, 0.18), Color(tone, 0.0))
			b.xf = Transform3D.IDENTITY
		return b.mesh())


## A curtain of hanging stars behind the stage: strings of light dropping from an arch (+Z).
static func curtain_mesh() -> ArrayMesh:
	return K.cached("star_stage_curtain", func():
		var b := K.Builder.new()
		var tones := [Color("ffe08a"), Color("ffb8d8"), Color("c8b8ff"), Color("b8e8ff")]
		for i in 11:
			var f := float(i) / 10.0
			var a := lerpf(-1.2, 1.2, f)
			var base := Vector3(sin(a) * 3.6, 0, cos(a) * 3.6 - 0.4)
			var top := base + Vector3.UP * (5.2 - 1.4 * absf(f - 0.5) * 2.0)
			var low := top - Vector3.UP * (1.4 + 1.2 * float(i % 3))
			var tone: Color = tones[i % tones.size()]
			var side := Vector3(cos(a), 0, -sin(a)) * 0.012
			b.quad(low - side, low + side, top + side, top - side, Color(tone, 0.12), Color(tone, 0.4))
			for k in 3:
				var at := top.lerp(low, float(k + 1) / 3.0)
				var s := 0.16 if k == 2 else 0.1
				for plane in 2:
					var u := Vector3(cos(a), 0, -sin(a)) if plane == 0 else Vector3.UP
					var v := Vector3.UP if plane == 0 else Vector3(cos(a), 0, -sin(a))
					b.fan([at, at - u * s * 1.7, at + v * s * 0.3, at + u * s * 1.7, at - v * s * 0.3, at - u * s * 1.7], Color(tone, 0.95), Color(tone, 0.0))
		return b.mesh())
