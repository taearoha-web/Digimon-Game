extends RefCounted
## Summoner Lv.60: Alpha Wolves (หมาป่าจ่าฝูง). A pale frost moon rises behind the
## Summoner and frost runes open at the three spots where the pack will stand; on the
## release a howl of cold rolls out from the Summoner and each wolf bursts out of a
## whirl of snow on its own rune, frost spreading under its paws, a mist of cold riding
## with it for a moment. The creatures (Summon) and their AI are untouched. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const ES := preload("res://combat/star_art/eclipse_sovereign.gd")
const FROST := Color("9ad0ff")
const FROST_HI := Color("dff4ff")
const FROST_DK := Color("2c5a9a")
const SNOW := [Color("dff4ff"), Color("9ad0ff"), Color("bfe6ff")]


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.15
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		# The frost moon climbs behind the Summoner; a rune turns at the feet.
		K.put(art, K.VEIL, M.moon("wolves", FROST_HI, FROST), "WolfMoon", Vector3(0, 3.1, -1.1), Vector3.ONE * 0.95, Vector3.ZERO, t, {"initial": 0.5, "grow_time": 0.6, "fade_in": 0.3, "decay": 0.9, "face_camera": true}, {"opacity": 0.9, "slide": Vector3(0, -0.9, 0), "slide_time": t, "slide_ease": -2.0})
		K.put(art, K.VEIL, M.sigil("wolves", FROST_HI, Color(FROST, 0.18), 6, 2, 3), "WolfRune", Vector3.UP * 0.05, Vector3.ONE * 1.5, Vector3.ZERO, t, {"initial": 0.4, "grow_time": 0.6, "fade_in": 0.2, "spin": 1.4, "decay": 0.9})
		K.put(art, K.VEIL, S.spiral("wolves_call", Color(0.7, 0.88, 1.0, 0.7), Color(0.9, 0.97, 1.0, 0.0), 3, 1.2, 0.4), "WolfCall", Vector3.UP * 0.1, Vector3(1.3, 2.2, 1.3), Vector3.ZERO, t, {"initial": 0.6, "grow_time": 0.7, "fade_in": 0.25, "spin": -5.0, "decay": 0.85})
		M.show(art)
	var marks := c.open(origin, t, "Runes", c.caster)
	if marks:
		marks.rotation.y = 0.0
		var n := int(skill.get("summon", {}).get("count", 3))
		for i in mini(n, 3):
			var spot := M.formation(skill, i, n)
			K.put(marks, K.VEIL, M.sigil("wolves_spot", FROST_HI, Color(FROST, 0.3), 5, 2, 0), "WolfSpot%d" % i, spot + Vector3.UP * 0.06, Vector3.ONE * 0.9, Vector3.ZERO, t, {"initial": 0.2, "grow_time": 0.8, "fade_in": 0.2, "spin": -2.0, "decay": 0.92, "delay": 0.04 * i})
		M.show(marks)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var howl := c.open(origin, 1.0, "Howl", c.caster)
	if howl:
		K.put(howl, K.VEIL, K.shock(FROST, FROST_HI, FROST_DK), "WolfHowl", Vector3.UP * 0.1, Vector3.ONE * 4.2, Vector3.ZERO, 0.6, {"initial": 0.15, "grow_time": 0.9, "fade_in": 0.02, "decay": 0.35}, {"opacity": 0.8})
		K.put(howl, K.VEIL, DS_arcs(), "WolfHowlArcs", Vector3(0, 1.4, 0.4), Vector3.ONE * 0.8, Vector3.ZERO, 0.55, {"initial": 0.4, "grow_time": 0.8, "fade_in": 0.02, "decay": 0.4}, {"tint": Color("c8e8ff"), "opacity": 0.7})
		K.put(howl, K.VEIL, M.moon("wolves", FROST_HI, FROST), "WolfMoonFull", Vector3(0, 2.6, -1.1), Vector3.ONE * 1.1, Vector3.ZERO, 0.8, {"initial": 0.95, "grow_time": 0.3, "fade_in": 0.01, "decay": 0.4, "face_camera": true}, {"opacity": 0.85, "slide": Vector3(0, -0.4, 0), "slide_time": 0.8, "slide_ease": -2.0})
		M.show(howl)
	# The wolves exist once the release has run (Summon._ready): each bursts from its rune.
	(VfxBudget.carry(func(): _arrive(c))).call_deferred()
	return true


static func _arrive(c: M.Cast) -> void:
	var pack := M.summons(c.parent, c.id, c.origin)
	for i in mini(pack.size(), 3):
		var wolf: Node3D = pack[i]
		var at := c.open(wolf.global_position, 1.7, "Wolf%d" % i, wolf)
		if not at:
			return
		at.rotation.y = 0.0
		var lag := 0.05 * i
		K.put(at, K.VEIL, S.spiral("wolves_burst", Color(0.75, 0.9, 1.0, 0.9), Color(0.95, 1.0, 1.0, 0.0), 4, 1.6, 0.5), "WolfWhirl", Vector3.ZERO, Vector3(1.2, 2.6, 1.2), Vector3.ZERO, 0.75, {"initial": 0.3, "grow_time": 0.3, "fade_in": 0.02, "spin": 9.0, "decay": 0.4, "delay": lag, "front": true})
		K.put(at, K.VEIL, ES.frost_mesh(), "WolfFrost", Vector3.UP * 0.04, Vector3.ONE * 1.7, Vector3(0, i, 0), 1.6, {"initial": 0.3, "grow_time": 0.25, "fade_in": 0.02, "decay": 0.6, "delay": lag, "priority": -1})
		K.put(at, K.VEIL, S.sparkles("wolves_snow", SNOW, 18, 3.5, 2.2), "WolfSnow", Vector3.UP * 0.5, Vector3.ONE * 0.8, Vector3.ZERO, 1.2, {"cull": 6.0, "decay": 0.85, "delay": lag}, {"burst": 1.0, "gravity": 1.2, "drag": 2.0, "life": 1.2})
		K.put(at, K.VEIL, K.shock(FROST_HI, FROST, FROST_DK), "WolfRing", Vector3.UP * 0.08, Vector3.ONE * 1.8, Vector3.ZERO, 0.5, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.02, "decay": 0.35, "delay": lag}, {"opacity": 0.75})
		# The cold rides with the wolf as it runs off.
		K.put(at, K.VEIL, S.wash("wolves_mist", Color(0.8, 0.93, 1.0, 0.4), Color(0.6, 0.82, 1.0, 0.3)), "WolfMist", Vector3.UP * 0.05, Vector3.ONE * 1.1, Vector3.ZERO, 1.7, {"initial": 0.6, "grow_time": 0.3, "fade_in": 0.1, "decay": 0.5, "delay": 0.2 + lag, "priority": -2})
		M.show(at)


static func DS_arcs() -> ArrayMesh:
	return M.DS.arcs_mesh()
