extends RefCounted
## Bard Lv.88: Eternal Echo (เสียงก้องนิรันดร์). A bell of light swings into being over the
## Bard on rings of aqua sound. On the release the bell tolls: a ring of its sound rolls out
## from the Bard, and the echo leaps from foe to foe (the real chain's links) as a ribbon of
## aqua light with a note riding it; on each foe it rings again in three spreading ripples
## and a little shower of notes, the echoes overlapping as they fade. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const AQUA := Color("9fe8ff")
const AQUA_HI := Color("e8faff")
const AQUA_DK := Color("2a7ab0")
const ROSE := Color("ff8ac8")
const GOLD := Color("f0c870")
const NOTES := [Color("9fe8ff"), Color("ffb3dc"), Color("f0c870")]


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.12
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		K.put(art, K.SOLID, M.DS.bell_mesh(), "EchoBell", Vector3(0, 4.9, -0.4), Vector3.ONE * 0.8, Vector3.ZERO, t + 0.35, {"initial": 0.3, "grow_time": 0.6, "fade_in": 0.2, "decay": 0.85, "turn": Vector3(0, 0, 0.5)}, M.NOTE_LOOK)
		K.put(art, K.VEIL, K.shock(AQUA, AQUA_HI, AQUA_DK), "EchoGather", Vector3.UP * 0.08, Vector3.ONE * 1.5, Vector3.ZERO, t, {"initial": 2.2, "grow_time": 1.0, "fade_in": 0.2, "decay": 0.95}, {"opacity": 0.75})
		K.put(art, K.VEIL, M.staff("echo", AQUA, [ROSE, GOLD, AQUA_HI]), "EchoStaff", Vector3.UP * 0.05, Vector3.ONE * 1.5, Vector3.ZERO, t, {"initial": 0.4, "grow_time": 0.7, "fade_in": 0.2, "spin": -1.2, "decay": 0.9})
		M.show(art)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var art := c.open(origin, 1.2, "Toll", c.caster)
	if art:
		K.put(art, K.SOLID, M.DS.bell_mesh(), "EchoToll", Vector3(0, 4.9, -0.4), Vector3.ONE * 0.8, Vector3(0, 0, 0.5), 0.8, {"initial": 1.0, "fade_in": 0.001, "decay": 0.5, "turn": Vector3(0, 0, -1.0)}, M.NOTE_LOOK)
		K.put(art, K.VEIL, M.DS.ripple_mesh(), "EchoTollRipple", Vector3.UP * 0.07, Vector3.ONE * 4.0, Vector3.ZERO, 0.8, {"initial": 0.15, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.45}, {"tint": Color("a8ecff"), "opacity": 0.85})
		K.put(art, K.VEIL, K.shock(AQUA_HI, AQUA, AQUA_DK), "EchoTollRing", Vector3(0, 2.8, -0.4), Vector3.ONE * 1.6, Vector3(0.9, 0, 0), 0.5, {"initial": 0.3, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.4}, {"opacity": 0.75})
		M.show(art)
	return true


## One leap of the echo: a ribbon of aqua light with a note riding it.
static func link(parent: Node3D, skill: Dictionary, from: Vector3, to: Vector3) -> void:
	var c := M.beat(parent, skill, from)
	var art := c.open(from, 0.5, "Leap", null)
	if not art:
		return
	art.rotation.y = 0.0
	M.span(art, K.VEIL, M.beam("echo_ribbon", Color(0.65, 0.95, 1.0, 0.9), Color(1.0, 0.75, 0.9, 0.5), 0.6), "EchoRibbon", from, to, 0.7, 0.45, {"initial": 0.05, "grow_time": 0.35, "fade_in": 0.01, "decay": 0.55}, {"noise_amt": 0.5, "noise_scale": Vector2(2.0, 6.0), "flow": Vector2(0.0, -5.0), "bias": 0.4, "taper": 0.0})
	if VfxBudget.for_hero():
		var tone: Color = NOTES[int(absf(to.x * 3.0 + to.z * 7.0)) % NOTES.size()]
		K.put(art, K.SOLID, S.note("echo_" + tone.to_html(), tone), "EchoRider", art.to_local(from), Vector3.ONE * 0.8, Vector3.ZERO, 0.18, {"initial": 1.0, "travel": to - from, "fade_in": 0.01, "decay": 0.9, "face_camera": true, "front": true}, M.NOTE_LOOK)
	M.show(art)


static func contact(parent: Node3D, skill: Dictionary, at: Vector3, _crit: bool) -> void:
	if not M.contact_ok(String(skill.id), 80, 4 if VfxBudget.for_hero() else 2):
		return
	var c := M.beat(parent, skill, at)
	var art := c.open(Vector3(at.x, 0.0, at.z), 1.0, "Ring", null)
	if not art:
		return
	K.put(art, K.VEIL, M.DS.ripple_mesh(), "EchoRipple", Vector3.UP * 0.07, Vector3.ONE * 1.8, Vector3.ZERO, 0.8, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.5}, {"tint": Color("a8ecff"), "opacity": 0.85})
	K.put(art, K.SOLID, S.note_spray("echo_hit", NOTES, 6, 4.0, 2.0), "EchoNotes", Vector3.UP * at.y, Vector3.ONE * 0.6, Vector3.ZERO, 0.8, {"cull": 5.0, "decay": 0.75}, M.NOTE_LOOK.merged({"burst": 1.0, "gravity": 7.0, "drag": 1.4, "life": 0.8}))
	K.put(art, K.VEIL, K.sprite(), "EchoGlint", Vector3.UP * at.y, Vector3.ONE * 1.0, Vector3.ZERO, 0.3, {"initial": 0.4, "grow_time": 0.5, "fade_in": 0.01, "decay": 0.3}, {"radial": 1.6, "billboard": true, "tint": Color("40a8d8"), "opacity": 0.8})
	M.show(art)
