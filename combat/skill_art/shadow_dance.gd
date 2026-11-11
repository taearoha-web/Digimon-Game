extends RefCounted
## Assassin Lv.68 "Shadow Dance": the assassin melts into shadow and dances from foe to foe.
## Wind-up: shadow smoke curls round the assassin's feet and a violet trail of afterimages
## turns about. Release: the assassin bursts into smoke and, link by link of the chain (the
## order the hits are dealt), a shadow of the assassin flickers in beside each foe, a crossed
## pair of violet cuts opens on it and an ink trail joins it to the last; when the dance is
## done the smoke gathers again round the assassin. Violet, ink and lilac.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const G := preload("res://combat/skill_art/_guard.gd")
const ID := "shadow_dance"
const VIOLET := Color("9a6bff")
const LILAC := Color("e4d6ff")
const PLUM := Color("3a1a6e")
const INK := Color(0.05, 0.02, 0.08)
static var _dance := {}


static func _figure() -> ArrayMesh:
	return M.solid("sd_figure", M.figure(INK, PLUM, VIOLET))


## Two crossed cuts facing +Z (radius 1) with ink cores.
static func _cuts() -> ArrayMesh:
	if M.has("sd_cuts"):
		return M.get_mesh("sd_cuts")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	G.crescent(st, Vector3(0.2, 0.1, 0), Vector3(0.7, -0.7, 0).normalized(), Vector3(0.7, 0.7, 0).normalized(), 1.0, -2.2, -0.9, 0.36, M.a(VIOLET, 0.95), M.a(LILAC, 0.9), M.a(INK, 1.0), 0.0, 14)
	G.crescent(st, Vector3(-0.2, 0.1, 0), Vector3(-0.7, -0.7, 0).normalized(), Vector3(-0.7, 0.7, 0).normalized(), 1.0, -2.2, -0.9, 0.36, M.a(VIOLET, 0.95), M.a(LILAC, 0.9), M.a(INK, 1.0), 0.06, 14)
	return M.keep("sd_cuts", K.finish(st, Vector3.ONE * 0.4, false))


static func _smoke() -> ArrayMesh:
	return K.burst("sd_smoke", "puff", G.n(14), 0.2, 0.8, 1.2, 1.6, [Color(0.1, 0.04, 0.16), Color(0.18, 0.08, 0.3), INK], 0.6, 0.15, 681, 0.05, 0.6)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	G.note(skill, visual, origin, aim)
	var time := maxf(duration, 0.12)
	var r := G.windup(parent, origin, time + 0.06, "Skill_%s_windup" % ID, G.yaw(origin, aim), visual)
	if r == null:
		return false
	G.bits(r, _smoke(), "Smoke", Vector3.ZERO, time + 0.04, {"life": time + 0.1, "gravity": -0.8, "drag": 2.0, "piece": 0.6, "swell": 1.6, "alpha": 0.6, "shrink": 0.5, "spin": 2.0}, {"fade_in": 0.1, "decay": 0.95})
	G.flat(r, G.glints("sd_glints", VIOLET, 4), "Trail", Vector3.UP * 0.9, Vector3.ONE * 0.9, time + 0.04, G.lit(LILAC, 0.7, 0.6), {"initial": 1.4, "grow_time": 0.9, "fade_in": 0.1, "decay": 0.95, "spin": -11.0})
	G.flat(r, K.glow_disc("sd_pool", Color(0.06, 0.02, 0.1, 0.6)), "Pool", Vector3.UP * 0.04, Vector3.ONE * 1.5, time + 0.04, {"soft": 0.6, "add": 0.0}, {"initial": 0.3, "grow_time": 0.8, "fade_in": 0.1, "decay": 0.97})
	G.done(r)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var who := G.caster_of(skill, origin)
	var caster: Node3D = who[0]
	_dance[ID] = {"caster": weakref(caster) if caster else null, "hops": 0}
	var r := G.open(parent, Vector3(origin.x, 0.0, origin.z), 0.9, "Skill_%s_vanish" % ID, G.yaw(origin, center, G.facing(caster)), caster, 3)
	if r:
		G.bits(r, _smoke(), "Vanish", Vector3.ZERO, 0.85, {"life": 0.75, "gravity": -1.2, "drag": 2.0, "piece": 0.7, "swell": 1.8, "alpha": 0.7, "shrink": 0.5, "spin": 2.0}, {"decay": 0.85})
		M.shock(r, "sd_ring", VIOLET, 1.6, 0.0, 0.3, 0.14)
		G.done(r)
	VfxBudget.carry(Callable(load("res://combat/skill_art/shadow_dance.gd"), "_return").bind(parent, skill)).call_deferred()
	return true


## One step of the dance: the shadow beside the next foe, its cuts, the ink trail to it.
static func link(parent: Node3D, skill: Dictionary, from: Vector3, to: Vector3) -> void:
	var index := G.hop(skill)
	var state: Dictionary = _dance.get(ID, {})
	state["hops"] = index + 1
	state["last"] = to
	_dance[ID] = state
	if not G.hero() and index % 2 == 1:
		return
	var step := G.HOP * 1.15
	var delay := step * float(index)
	var ground := Vector3(to.x, 0.0, to.z)
	var r := G.open(parent, ground, delay + 0.6, "Skill_%s_step%d" % [ID, index], G.yaw(from, to), null, 5)
	if r == null:
		return
	var side := 1.0 if index % 2 == 0 else -1.0
	G.solid(r, _figure(), "Shade", Vector3(side * 0.9, 0, -0.7), Vector3.ONE * 1.1, 0.36, {"rim_color": VIOLET, "rim": 2.0, "glow_color": LILAC, "dim": 0.9}, {"delay": delay, "fade_in": 0.01, "decay": 0.45}, Vector3(0, -side * 0.6, 0))
	var mat := G.flat(r, _cuts(), "Cuts", Vector3.UP * 1.1, Vector3.ONE * 1.7, 0.48, G.lit(VIOLET, 0.75, 0.55, {"sweep": 0.08, "tail": 6.0}), {"delay": delay + 0.03, "fade_in": 0.01, "decay": 0.65, "face_camera": true})
	var d := from - to
	var length := Vector2(d.x, d.z).length()
	if length > 0.3:
		G.flat(r, G.streak("sd_trail", M.a(VIOLET, 0.75), M.a(INK, 0.2), M.a(INK, 0.9)), "Trail", Vector3.UP * 0.6, Vector3(0.9, 0.9, length), 0.45, G.lit(VIOLET, 0.6, 0.7, {"sweep": step, "tail": 1.6}), {"delay": maxf(0.0, delay - step), "fade_in": 0.01, "decay": 0.6}, Vector3(0, atan2(d.x, d.z) - r.rotation.y, 0))
	M.shock(r, "sd_splash", VIOLET, 1.8, delay + 0.03, 0.35, 0.2)
	M.sparks(r, "sd_sparks", [VIOLET, LILAC], G.n(10), 0.05, 0.3, 3.0, 2.0, 0.09, delay + 0.03, 0.45, Vector3.UP * 1.0, 6.0, 682, -0.2, 0.2)
	if mat == null:
		return
	G.done(r)


## The dance ends: the smoke gathers round the assassin again.
static func _return(parent: Node3D, _skill: Dictionary) -> void:
	var state: Dictionary = _dance.get(ID, {})
	_dance.erase(ID)
	var ref: WeakRef = state.get("caster")
	var caster := ref.get_ref() as Node3D if ref else null
	if not is_instance_valid(caster) or not is_instance_valid(parent):
		return
	var delay := G.HOP * 1.15 * float(int(state.get("hops", 0)))
	var r := G.open(parent, caster.global_position * Vector3(1, 0, 1), delay + 0.7, "Skill_%s_return" % ID, 0.0, caster, 2)
	if r:
		G.bits(r, G.inward("sd_gather", "puff", G.n(12), 0.8, 1.6, [Color(0.1, 0.04, 0.16), Color(0.18, 0.08, 0.3)], 0.5, 4.0, 0.6, 0.1, 683, 0.2, 1.2), "Gather", Vector3.ZERO, delay + 0.6, {"life": 0.5, "gravity": 0.0, "drag": 4.0, "piece": 0.5, "alpha": 0.6, "shrink": 0.6, "spin": 2.0}, {"delay": delay, "decay": 0.9})
		M.shock(r, "sd_ring_b", LILAC, 1.3, delay + 0.35, 0.3, 0.1)
		G.done(r)


## The hits land with the steps (drawn there).
static func contact(_parent: Node3D, _skill: Dictionary, _at: Vector3, _crit: bool) -> void:
	pass
