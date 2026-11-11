extends RefCounted
## Bard Lv.60: Cascade of Notes (โน้ตพรั่งพรู). Notes bubble up out of the lute and swirl
## round the Bard like spray over a ring of staff lines. On the release a wave of sound
## breaks forward in a fan, and each of the six notes (the real projectiles' flights) pours
## on its foe like a drop of a waterfall, a pink note riding a stream of aqua light; where it
## lands it splashes: drops of aqua light and little notes fly up and ripples run out.
## Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const ROSE := Color("ff6fb5")
const TONE := Color("ffb3dc")
const AQUA := Color("9fe8ff")
const AQUA_DK := Color("2a8ab8")
const GOLD := Color("f0c870")
const NOTES := [Color("ffb3dc"), Color("9fe8ff"), Color("ff8ac8"), Color("f0c870")]


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.1
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		K.put(art, K.SOLID, M.note_ring("cascade", NOTES, 8), "CascadeNotes", Vector3.UP * 1.1, Vector3.ONE * 0.9, Vector3.ZERO, t, {"initial": 0.3, "grow_time": 0.8, "fade_in": 0.2, "spin": 5.0, "decay": 0.92}, M.NOTE_LOOK.merged({"slide": Vector3(0, -0.8, 0), "slide_time": t, "slide_ease": -2.0}))
		K.put(art, K.VEIL, S.spiral("cascade_spray", Color(0.6, 0.9, 1.0, 0.75), Color(1.0, 0.75, 0.9, 0.0), 3, 1.4, 0.4), "CascadeSpray", Vector3.UP * 0.1, Vector3(1.2, 2.2, 1.2), Vector3.ZERO, t, {"initial": 0.5, "grow_time": 0.7, "fade_in": 0.2, "spin": 6.0, "decay": 0.9})
		K.put(art, K.VEIL, M.staff("cascade", AQUA, [ROSE, GOLD, TONE]), "CascadeStaff", Vector3.UP * 0.05, Vector3.ONE * 1.5, Vector3.ZERO, t, {"initial": 0.4, "grow_time": 0.7, "fade_in": 0.2, "spin": 1.5, "decay": 0.9})
		M.show(art)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var art := c.open(origin, 1.0, "Wave", c.caster)
	if art:
		var hand := c.local(art, c.hand()) + Vector3(0, 0, 0.3)
		K.put(art, K.VEIL, M.DS.arcs_mesh(), "CascadeArcs", hand - Vector3.UP * 0.3, Vector3.ONE * 1.5, Vector3.ZERO, 0.5, {"initial": 0.3, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.4}, {"tint": Color("a0e8ff"), "opacity": 0.85})
		K.put(art, K.SOLID, S.note_spray("cascade", NOTES, 12, 4.0, 4.0), "CascadeBurst", hand, Vector3.ONE * 0.7, Vector3.ZERO, 0.9, {"cull": 6.0, "decay": 0.75}, M.NOTE_LOOK.merged({"burst": 1.0, "gravity": 7.0, "drag": 1.6, "life": 0.9}))
		K.put(art, K.VEIL, K.shock(AQUA, Color("e8faff"), AQUA_DK), "CascadeRing", Vector3.UP * 0.08, Vector3.ONE * 2.6, Vector3.ZERO, 0.5, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.75})
		M.show(art)
	return true


## One note pouring on its foe on a stream of aqua light.
static func flight(parent: Node3D, skill: Dictionary, from: Vector3, to: Vector3, seconds: float, _size: float) -> Node3D:
	var c := M.beat(parent, skill, from)
	var art := c.open(from, seconds + 0.05, "Drop", null)
	if not art:
		return null
	art.rotation.y = 0.0
	var dir := to - from
	var go := {"initial": 1.0, "travel": dir, "fade_in": 0.02, "decay": 0.96}
	var tone: Color = NOTES[int(absf(to.x * 3.0 + to.z * 5.0)) % NOTES.size()]
	K.put(art, K.SOLID, S.note("cascade_" + tone.to_html(), tone), "CascadeNote", Vector3.ZERO, Vector3.ONE * 1.0, Vector3.ZERO, seconds, go.merged({"front": true, "face_camera": true}), M.NOTE_LOOK)
	K.put(art, K.VEIL, S.tail("cascade_stream", Color(0.6, 0.92, 1.0, 0.9), Color(1.0, 0.75, 0.9, 0.4)), "CascadeStream", Vector3.ZERO, Vector3(0.9, 2.4, 0.9), M.along(-dir), seconds, go, {"noise_amt": 0.4, "noise_scale": Vector2(3.0, 5.0), "flow": Vector2(0.0, 3.0), "bias": 0.4, "taper": 0.3})
	M.show(art)
	return art


## The splash where a note lands.
static func contact(parent: Node3D, skill: Dictionary, at: Vector3, _crit: bool) -> void:
	if not M.contact_ok(String(skill.id), 50, 3 if VfxBudget.for_hero() else 1):
		return
	var c := M.beat(parent, skill, at)
	var art := c.open(Vector3(at.x, 0.0, at.z), 1.0, "Splash", null)
	if not art:
		return
	K.put(art, K.VEIL, S.spray("cascade_drops", [AQUA, Color("e8faff"), TONE], 18, 5.0, 2.5), "CascadeDrops", Vector3.UP * at.y * 0.8, Vector3.ONE * 0.45, Vector3.ZERO, 0.8, {"cull": 5.0, "decay": 0.75}, {"burst": 1.0, "gravity": 11.0, "drag": 1.0, "life": 0.8, "opacity": 0.9})
	K.put(art, K.VEIL, M.DS.ripple_mesh(), "CascadeRipple", Vector3.UP * 0.06, Vector3.ONE * 1.7, Vector3.ZERO, 0.7, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.5}, {"tint": Color("a0e8ff"), "opacity": 0.85})
	K.put(art, K.SOLID, S.note_spray("cascade_hit", NOTES, 6, 4.0, 2.0), "CascadeHitNotes", Vector3.UP * at.y * 0.8, Vector3.ONE * 0.6, Vector3.ZERO, 0.8, {"cull": 5.0, "decay": 0.75}, M.NOTE_LOOK.merged({"burst": 1.0, "gravity": 8.0, "drag": 1.4, "life": 0.8}))
	M.show(art)
