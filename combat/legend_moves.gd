class_name LegendMoves
extends RefCounted
## The two skills of each legend summon (the summoner's Wind Monkey King and
## Poseidon), shared by the hero's summons (Summon) and the AI's (SummonMob).
## A move is an area around the caster ("self", the staff) or around its target
## ("target", the trident): everyone inside takes a multiple of the summon's
## basic hit and may be stunned or frozen. The clip (Skill1 / Skill2 of the glb)
## plays first; the hit lands at [member impact] seconds, when the body comes down.

## kind -> its moves. power = multiples of the summon's basic hit.
const MOVES := {
	"wind_king": [
		{"id": "gale_storm", "name": "พายุวานร", "clip": "skill1", "cd": 9.0, "radius": 5.0, "power": 2.4, "shape": "self", "style": "storm", "impact": 0.55, "lock": 1.1},
		{"id": "staff_quake", "name": "กระบองฟาดพื้น", "clip": "skill2", "cd": 14.0, "radius": 4.6, "power": 3.0, "shape": "self", "style": "quake", "impact": 0.6, "lock": 1.2, "stun": 5.0},
	],
	"poseidon": [
		{"id": "maelstrom", "name": "คลื่นน้ำวน", "clip": "skill1", "cd": 10.0, "radius": 5.0, "power": 2.4, "shape": "target", "style": "whirl", "impact": 0.65, "lock": 1.2, "stun": 5.0},
		{"id": "glacial_bloom", "name": "ผลึกน้ำแข็ง", "clip": "skill2", "cd": 15.0, "radius": 5.0, "power": 3.0, "shape": "target", "style": "ice", "impact": 0.6, "lock": 1.3, "freeze": 5.0},
	],
}
const STYLE_COLORS := {"storm": Color("9affc8"), "quake": Color("e8c08a"), "whirl": Color("5cc8ff"), "ice": Color("bff4ff")}


static func has(kind: String) -> bool:
	return MOVES.has(kind)


static func moves(kind: String) -> Array:
	return MOVES.get(kind, [])


## Strike effects of a move at [param pos]; budget-gated VfxKit helpers only.
static func impact_vfx(parent: Node3D, style: String, pos: Vector3, radius: float) -> void:
	if not is_instance_valid(parent):
		return
	var color: Color = STYLE_COLORS.get(style, Color.WHITE)
	match style:
		"storm":
			VfxKit.vortex(parent, pos, color, 4.0, 0.9)
			VfxKit.shockwave(parent, pos + Vector3(0, 0.1, 0), color, radius)
			VfxArt.motes(parent, pos + Vector3(0, 1.0, 0), Color("d8ffe6"), "leaf", 12, 0.5, 2.0, 1.0)
		"quake":
			VfxKit.slam(parent, pos, color, radius)
			VfxKit.spikes(parent, pos, radius * 0.8, color, 8, 1.6)
		"whirl":
			VfxKit.vortex(parent, pos, color, 3.0, 1.0)
			VfxKit.ground_circle(parent, pos, color, radius, 1.2)
			VfxKit.shockwave(parent, pos + Vector3(0, 0.1, 0), color, radius)
		"ice":
			ElementFx.ice_field(parent, pos, radius, 2, true)
			VfxKit.spikes(parent, pos, radius * 0.75, color, 9, 2.4)
			ElementFx.shatter(parent, pos + Vector3(0, 1.0, 0), 1.2, 6)
		_:
			VfxKit.shockwave(parent, pos + Vector3(0, 0.1, 0), color, radius)


## Stun / freeze of a move on a victim (monsters, fighters, the hero or an ally).
static func afflict(move: Dictionary, victim: Node) -> void:
	if victim == null or not is_instance_valid(victim):
		return
	var frozen := float(move.get("freeze", 0.0))
	var stunned := float(move.get("stun", 0.0))
	if frozen > 0.0:
		if victim.has_method("apply_freeze"):
			victim.apply_freeze(frozen)
		elif victim.has_method("apply_slow"):
			victim.apply_slow(frozen)
	elif stunned > 0.0:
		if victim.has_method("apply_stun"):
			victim.apply_stun(stunned)
		elif victim.has_method("apply_slow"):
			victim.apply_slow(stunned * 0.6)
