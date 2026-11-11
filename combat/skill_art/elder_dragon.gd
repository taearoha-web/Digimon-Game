extends RefCounted
## Summoner Lv.100: Elder Dragon (มังกรโบราณ), the Summoner's greatest call. A golden
## dragon-eye seal opens where the dragon will land, a ring of golden cloud gathers high
## in the sky over it round a burning gate of light, and the Summoner stands in a rising
## coil of gold. On the release the gate opens: a pillar of golden light drives down from
## the sky onto the seal, a coil of golden fire spirals down it, the clouds are blown out
## in a ring, golden scales and sparks burst out and a shock of gold rolls over the field;
## for a moment a golden aura coils round the dragon as the sky closes. The creature
## (Summon) and its AI are untouched. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const GOLD := Color("ffd84a")
const GOLD_HI := Color("fff2b8")
const GOLD_DK := Color("a8701c")
const EMBER := Color("ff9a3a")
const CLOUD_TOP := Color("fff4d8")
const CLOUD_UNDER := Color("e8b860")
const JADE := Color("6fe0b0")
const CLOUD_LOOK := {"rim_color": Color("fffbe8"), "rim": 0.8, "shadow_tint": Color(0.92, 0.75, 0.55)}
const SKY := 7.0
const TALL := 8.5


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.18
	var spot := M.formation(skill, 0, 1)
	c.fit = K.frame(parent, origin + spot, origin, TALL, 0.0)
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		art.rotation.y = 0.0
		var at := spot / c.fit
		var gate := at + M.away(parent) * 3.0 / c.fit + Vector3.UP * SKY
		K.put(art, K.VEIL, M.sigil("dragon_eye", GOLD_HI, Color(GOLD, 0.2), 12, 5, 12), "DragonSeal", at + Vector3.UP * 0.05, Vector3.ONE * 2.8, Vector3.ZERO, t, {"initial": 0.3, "grow_time": 0.8, "fade_in": 0.2, "spin": 0.8, "decay": 0.95})
		K.put(art, K.VEIL, S.spiral("dragon_coil", Color(1.0, 0.85, 0.35, 0.8), Color(1.0, 0.95, 0.7, 0.0), 3, 1.6, 0.4), "DragonCoilUp", Vector3.UP * 0.1, Vector3(1.4, 3.2, 1.4), Vector3.ZERO, t, {"initial": 0.5, "grow_time": 0.7, "fade_in": 0.2, "spin": 6.0, "decay": 0.9})
		K.put(art, K.SOLID, S.cloud_ring("dragon_sky", CLOUD_TOP, CLOUD_UNDER, 16, 0.18), "DragonClouds", gate, Vector3(1.9, 0.9, 1.9), Vector3.ZERO, t, {"initial": 0.4, "grow_time": 0.9, "fade_in": 0.3, "spin": 0.8, "decay": 0.97, "cull": 6.0}, CLOUD_LOOK)
		K.put(art, K.VEIL, S.twinkle("dragon_gate", Color(GOLD, 0.9), EMBER), "DragonGate", gate, Vector3.ONE * 1.1, Vector3.ZERO, t, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.3, "decay": 0.97, "pulse": true}, {"billboard": true, "opacity": 0.7})
		M.show(art)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var call := c.open(origin, 1.0, "Call", c.caster)
	if call:
		K.put(call, K.VEIL, K.shock(GOLD, GOLD_HI, GOLD_DK), "DragonCallRing", Vector3.UP * 0.08, Vector3.ONE * 3.0, Vector3.ZERO, 0.6, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.8})
		M.show(call)
	(VfxBudget.carry(func(): _arrive(c))).call_deferred()
	return true


static func _arrive(c: M.Cast) -> void:
	var found := M.summons(c.parent, c.id, c.origin)
	var follow: Node3D = found[0] if not found.is_empty() else null
	var at := follow.global_position if follow else c.origin + M.formation(c.skill, 0, 1)
	at.y = c.origin.y
	c.fit = K.frame(c.parent, at, c.origin, TALL, 0.0)
	var gate := c.open(at, 1.8, "Gate", null)
	if gate:
		gate.rotation.y = 0.0
		K.put(gate, K.VEIL, K.column("dragon_beam", [Color(1.0, 0.8, 0.3, 0.7), Color(1.0, 0.86, 0.4, 0.55), Color(1.0, 0.92, 0.6, 0.35), Color(1.0, 0.95, 0.7, 0.1)], 0.85, 18), "DragonBeam", Vector3.ZERO, Vector3(1.6, SKY + 0.6, 1.6), Vector3.ZERO, 0.6, {"initial": 0.5, "grow_time": 0.12, "fade_in": 0.01, "decay": 0.3}, {"opacity": 0.5, "noise_amt": 0.6, "noise_scale": Vector2(6.0, 1.5), "flow": Vector2(0.0, 5.0), "bias": 0.1, "taper": 0.3, "fres": 0.5})
		K.put(gate, K.VEIL, S.spiral("dragon_fire", Color(1.0, 0.65, 0.2, 0.95), Color(1.0, 0.9, 0.5, 0.3), 4, 2.6, 0.9), "DragonCoil", Vector3.ZERO, Vector3(1.6, 4.4, 1.6), Vector3.ZERO, 1.0, {"initial": 0.6, "grow_time": 0.25, "fade_in": 0.01, "spin": -9.0, "decay": 0.45, "front": true})
		K.put(gate, K.SOLID, S.puffs("dragon_clouds", CLOUD_TOP, CLOUD_UNDER, 12, 8.0), "DragonCloudBurst", Vector3.UP * 0.3, Vector3.ONE * 0.75, Vector3.ZERO, 1.2, {"cull": 14.0, "decay": 0.75}, CLOUD_LOOK.merged({"burst": 1.0, "gravity": -0.6, "drag": 2.4, "life": 1.2}))
		K.put(gate, K.VEIL, K.shock(GOLD, GOLD_HI, EMBER), "DragonShock", Vector3.UP * 0.1, Vector3.ONE * 6.0, Vector3.ZERO, 0.7, {"initial": 0.12, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.85})
		K.put(gate, K.SOLID, K.debris("dragon_scales", [GOLD, GOLD_DK, JADE, GOLD_HI], 26, 0.26), "DragonScales", Vector3.UP * 1.2, Vector3.ONE, Vector3.ZERO, 1.4, {"cull": 14.0, "decay": 0.9}, M.GOLD_LOOK.merged({"burst": 1.0, "gravity": 9.0, "drag": 1.2, "life": 1.4}))
		K.put(gate, K.VEIL, M.sigil("dragon_eye", GOLD_HI, Color(GOLD, 0.2), 12, 5, 12), "DragonSealBurn", Vector3.UP * 0.05, Vector3.ONE * 3.4, Vector3.ZERO, 1.7, {"initial": 0.8, "grow_time": 0.2, "fade_in": 0.01, "spin": 0.5, "decay": 0.6, "priority": -1})
		M.show(gate)
	var high := M.away(c.parent) * 3.0 / c.fit + Vector3.UP * SKY
	var sky := c.open(at, 1.6, "Sky", null)
	if sky:
		sky.rotation.y = 0.0
		K.put(sky, K.SOLID, S.cloud_ring("dragon_sky", CLOUD_TOP, CLOUD_UNDER, 16, 0.18), "DragonSkyOpen", high, Vector3(1.9, 0.9, 1.9), Vector3.ZERO, 1.0, {"initial": 1.0, "grow_time": 0.8, "fade_in": 0.001, "spin": 1.2, "decay": 0.4, "cull": 6.0}, CLOUD_LOOK.merged({"slide": Vector3(0, 0.0, 0)}))
		K.put(sky, K.VEIL, S.twinkle("dragon_gate", Color(GOLD, 0.9), EMBER), "DragonGateFlare", high, Vector3.ONE * 2.0, Vector3.ZERO, 0.5, {"initial": 0.5, "grow_time": 0.3, "fade_in": 0.01, "decay": 0.35}, {"billboard": true, "opacity": 0.75})
		K.put(sky, K.VEIL, K.shock(GOLD_HI, GOLD, EMBER), "DragonSkyRing", high, Vector3.ONE * 3.0, Vector3.ZERO, 0.7, {"initial": 0.3, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.4}, {"opacity": 0.7})
		K.put(sky, K.GLOW, K.embers("dragon_sparks", [GOLD, EMBER, GOLD_HI], 30, 3.5, 4.0), "DragonSparks", Vector3.UP * 0.5, Vector3.ONE * 1.3, Vector3.ZERO, 1.5, {"cull": 12.0, "decay": 0.8}, {"burst": 1.0, "gravity": 2.0, "drag": 1.4, "life": 1.5, "opacity": 0.85})
		M.show(sky)
	if follow and c.rich:
		var aura := c.open(at, 2.6, "Aura", follow)
		if aura:
			aura.rotation.y = 0.0
			K.put(aura, K.VEIL, S.spiral("dragon_aura", Color(1.0, 0.8, 0.35, 0.7), Color(1.0, 0.95, 0.7, 0.0), 2, 1.8, 0.7), "DragonAura", Vector3.UP * 0.3, Vector3(2.0, 3.4, 2.0), Vector3.ZERO, 2.6, {"initial": 0.8, "grow_time": 0.3, "fade_in": 0.1, "spin": 3.5, "decay": 0.6, "delay": 0.4})
			K.put(aura, K.VEIL, S.wash("dragon_glow", Color(1.0, 0.85, 0.4, 0.4), Color(1.0, 0.7, 0.3, 0.25)), "DragonGround", Vector3.UP * 0.03, Vector3.ONE * 2.6, Vector3.ZERO, 2.6, {"initial": 0.5, "grow_time": 0.3, "fade_in": 0.1, "decay": 0.6, "delay": 0.3, "priority": -2})
			M.show(aura)
