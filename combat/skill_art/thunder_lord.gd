extends RefCounted
## Dark Lord Lv.68: Thunder Lord (จ้าวสายฟ้า). A small storm cloud gathers over the Lord
## and lightning crackles round the scepter over a sky-blue seal. On the release a bolt
## drops from the cloud into the Lord, and the lightning leaps from foe to foe (the real
## chain's links: SkillTableau.link hands each one over) as jagged ice-blue bolts edged in
## violet; each foe it strikes is lit by a burst of blue sparks in a crackling ring.
## Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const BOLT := Color("8fd8ff")
const BOLT_CORE := Color("c8f0ff")
const VIOLET := Color("8a4dff")
const STORM := Color("5a6a9a")
const STORM_DK := Color("2a3060")
const CLOUD_LOOK := {"rim_color": Color("b8e8ff"), "rim": 0.7, "shadow_tint": Color(0.6, 0.62, 0.8)}


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.12
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		K.put(art, K.SOLID, S.cloud("lord_storm", STORM, STORM_DK, 10, 0.45, 9), "LordCloud", Vector3(0, 4.4, -0.3), Vector3(1.8, 1.0, 1.8), Vector3.ZERO, t, {"initial": 0.3, "grow_time": 0.6, "fade_in": 0.2, "spin": 0.8, "decay": 0.97, "cull": 3.0}, CLOUD_LOOK)
		K.put(art, K.VEIL, M.lightning("lord_crackle", Color(BOLT_CORE, 0.95), Color(BOLT, 0.7), 4, 2.2, 31, 0.8), "LordCrackle", Vector3.UP * 0.2, Vector3.ONE * 0.9, Vector3.ZERO, t, {"initial": 0.6, "grow_time": 0.5, "fade_in": 0.2, "spin": 3.0, "decay": 0.9}, {"flicker": 0.5})
		K.put(art, K.VEIL, M.sigil("lord_bolt", BOLT_CORE, Color(BOLT, 0.2), 7, 3, 7), "LordSeal", Vector3.UP * 0.05, Vector3.ONE * 1.6, Vector3.ZERO, t, {"initial": 0.4, "grow_time": 0.7, "fade_in": 0.2, "spin": 2.0, "decay": 0.9})
		M.show(art)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var art := c.open(origin, 0.8, "Call", c.caster)
	if art:
		K.put(art, K.VEIL, M.lightning("lord_drop", Color(BOLT_CORE, 0.95), Color(VIOLET, 0.7), 1, 4.4, 5, 0.05), "LordDrop", Vector3.UP * 0.2, Vector3.ONE, Vector3.ZERO, 0.3, {"initial": 1.0, "fade_in": 0.01, "decay": 0.4}, {"flicker": 0.3})
		K.put(art, K.SOLID, S.cloud("lord_storm", STORM, STORM_DK, 10, 0.45, 9), "LordCloudFade", Vector3(0, 4.4, -0.3), Vector3(1.8, 1.0, 1.8), Vector3.ZERO, 0.32, {"initial": 1.0, "fade_in": 0.001, "spin": 1.5, "decay": 0.2, "cull": 3.0}, CLOUD_LOOK)
		K.put(art, K.VEIL, K.shock(BOLT, BOLT_CORE, VIOLET), "LordRing", Vector3.UP * 0.08, Vector3.ONE * 2.4, Vector3.ZERO, 0.45, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.8})
		M.show(art)
	return true


## One leap of the chain lightning.
static func link(parent: Node3D, skill: Dictionary, from: Vector3, to: Vector3) -> void:
	var c := M.beat(parent, skill, from)
	var art := c.open(from, 0.4, "Leap", null)
	if not art:
		return
	art.rotation.y = 0.0
	M.span(art, K.VEIL, M.bolt_link("lord_leap", Color(BOLT_CORE, 0.95), Color(VIOLET, 0.8), 4), "LordLeap", from, to, 1.6, 0.32, {"initial": 1.0, "fade_in": 0.01, "decay": 0.5}, {"flicker": 0.35})
	if VfxBudget.for_hero():
		M.span(art, K.VEIL, M.bolt_link("lord_leap2", Color(BOLT, 0.8), Color(VIOLET, 0.6), 9), "LordLeap2", from, to, 2.0, 0.24, {"initial": 1.0, "fade_in": 0.01, "decay": 0.5, "delay": 0.06}, {"flicker": 0.5})
	M.show(art)


static func contact(parent: Node3D, skill: Dictionary, at: Vector3, _crit: bool) -> void:
	if not M.contact_ok(String(skill.id), 80, 4 if VfxBudget.for_hero() else 2):
		return
	var c := M.beat(parent, skill, at)
	var art := c.open(at, 0.6, "Zap", null)
	if not art:
		return
	K.put(art, K.VEIL, M.lightning("lord_zap", Color(BOLT_CORE, 0.9), Color(BOLT, 0.6), 4, 1.2, 13, 0.6), "LordZap", Vector3.DOWN * 0.6, Vector3.ONE * 1.4, Vector3.ZERO, 0.3, {"initial": 0.8, "fade_in": 0.01, "spin": 6.0, "decay": 0.5}, {"flicker": 0.5})
	K.put(art, K.VEIL, S.sparkles("lord_sparks", [BOLT, BOLT_CORE, Color("b090ff")], 14, 2.5, 2.5), "LordSparks", Vector3.ZERO, Vector3.ONE * 0.5, Vector3.ZERO, 0.55, {"cull": 4.0, "decay": 0.7}, {"burst": 1.0, "gravity": 4.0, "drag": 2.0, "life": 0.55})
	K.put(art, K.VEIL, K.sprite(), "LordFlash", Vector3.ZERO, Vector3.ONE * 1.3, Vector3.ZERO, 0.25, {"initial": 0.4, "grow_time": 0.5, "fade_in": 0.01, "decay": 0.3}, {"radial": 1.6, "billboard": true, "tint": Color("3a8ae0"), "opacity": 0.8})
	M.show(art)
