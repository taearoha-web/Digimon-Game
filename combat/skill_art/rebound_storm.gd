extends RefCounted
## Defender Lv.68 "Rebound Storm": the shield thrown like a discus, ricocheting from foe to
## foe and home again. Wind-up: a steel buckler spins up at the defender's side, ringed by
## whirling arcs of ice-blue light. Release: the spinning buckler leaves the hand, and each
## link of the chain (SkillTableau.link, in the order the hits are dealt) is a hop of it with
## a steel-blue trail, a ring and a burst of sparks where it rebounds; after the last foe it
## comes spinning back to the defender's hand. Steel blue, ice and navy.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const G := preload("res://combat/skill_art/_guard.gd")
const ID := "rebound_storm"
const STEEL := Color("c8e4ff")
const ICE := Color("7fc4ff")
const NAVY := Color("2a4a8a")
const SILVER := Color("9aa8bc")
static var _chain := {}


static func _buckler() -> ArrayMesh:
	if M.has("rs_buckler"):
		return M.get_mesh("rs_buckler")
	var st := K.begin()
	# A round shield lying level (face up), radius 1.
	K.stamp(st, G.aegis(NAVY, SILVER, STEEL, ICE), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO), 0.0, 1.0)
	return M.keep("rs_buckler", K.finish(st, Vector3.ONE * 2.0))


## Whirling arcs round the buckler (radius 1, level).
static func _whirl() -> ArrayMesh:
	if M.has("rs_whirl"):
		return M.get_mesh("rs_whirl")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var a0 := TAU * float(k) / 3.0
		K.ribbon(st, M.arc(Vector3.ZERO, 1.0, a0, a0 + 1.7, 0.0, 0.0, 14, 0.8), 0.14, M.a(ICE, 1.0), 0.0, 0.0, Vector3.UP, 1.0, 0.0, 1.0, M.a(STEEL, 0.0))
	return M.keep("rs_whirl", K.finish(st, Vector3.ONE * 0.2, false))


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	G.note(skill, visual, origin, aim)
	var time := maxf(duration, 0.12)
	var r := G.windup(parent, origin, time + 0.06, "Skill_%s_windup" % ID, G.yaw(origin, aim), visual)
	if r == null:
		return false
	var hand := Vector3(0.55, 1.15, 0.45)
	G.solid(r, _buckler(), "Spin", hand, Vector3.ONE * 0.55, time + 0.04, {"rim_color": STEEL, "rim": 1.2, "glow_color": ICE, "dim": 1.0}, {"initial": 0.3, "grow_time": 0.5, "fade_in": 0.06, "decay": 0.98, "spin": 22.0}, Vector3(0.25, 0, 0))
	G.flat(r, _whirl(), "Whirl", hand, Vector3.ONE * 0.95, time + 0.04, G.lit(ICE, 0.7, 0.6), {"initial": 0.5, "grow_time": 0.4, "fade_in": 0.05, "decay": 0.95, "spin": -16.0}, Vector3(0.25, 0, 0))
	M.sparks(r, "rs_glint", [ICE, STEEL], G.n(10), 0.1, 0.6, 1.5, 1.5, 0.08, 0.0, time + 0.04, hand, 1.0, 681, -0.2, 0.2)
	G.flat(r, G.sigil("rs_sigil", ICE, 2, 16, 0, 0.0), "Sigil", Vector3.UP * 0.05, Vector3.ONE * 1.4, time + 0.04, G.lit(ICE, 0.45, 0.5), {"initial": 0.5, "grow_time": 0.8, "fade_in": 0.1, "decay": 0.95, "spin": 2.0})
	G.done(r)
	return true


## The throw itself; the hops come with the links of the chain in the same frame.
static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var who := G.caster_of(skill, origin)
	var caster: Node3D = who[0]
	_chain[ID] = {"caster": weakref(caster) if caster else null, "frame": Engine.get_process_frames(), "hops": 0, "last": Vector3.INF}
	var r := G.open(parent, origin, 0.5, "Skill_%s_throw" % ID, G.yaw(origin, center, G.facing(caster)), caster, 3)
	if r:
		M.shock(r, "rs_throw_ring", ICE, 1.4, 0.0, 0.3, 0.16, 1.1)
		M.sparks(r, "rs_throw", [ICE, STEEL], G.n(10), 0.1, 0.4, 3.5, 1.5, 0.08, 0.0, 0.4, Vector3(0.4, 1.1, 0.5), 2.0, 682, -0.1, 0.1)
		G.done(r)
	# After this frame's links, the buckler flies home.
	VfxBudget.carry(Callable(load("res://combat/skill_art/rebound_storm.gd"), "_home").bind(parent, skill)).call_deferred()
	return true


## One rebound: from the last foe (or the hand) to the next one.
static func link(parent: Node3D, skill: Dictionary, from: Vector3, to: Vector3) -> void:
	var index := G.hop(skill)
	var state: Dictionary = _chain.get(ID, {})
	state["hops"] = index + 1
	state["last"] = to
	_chain[ID] = state
	if index > 0 and not G.hero() and index % 2 == 1:
		return # other casters draw every other hop
	var r := G.carry(parent, skill, _buckler(), from, to, G.HOP * float(index), G.HOP, 0.7, [ICE, STEEL], "hop%d" % index, {"rim": 1.4, "heat": 0.6}, 26.0, Vector3.ZERO, 0.3, 0.55)
	if r == null:
		return
	M.shock(r, "rs_hit_ring", ICE, 2.0, G.HOP * float(index + 1), 0.36, 0.2, 0.0)
	G.flat(r, G._hit_star(), "Clang", Vector3.ZERO, Vector3.ONE * 1.1, 0.26, G.lit(ICE, 0.7), {"delay": G.HOP * float(index + 1), "initial": 0.4, "grow_time": 0.3, "fade_in": 0.01, "decay": 0.4, "face_camera": true})
	M.sparks(r, "rs_hit", [ICE, STEEL, SILVER], G.n(12), 0.05, 0.3, 4.0, 2.5, 0.09, G.HOP * float(index + 1), 0.45, Vector3.ZERO, 6.0, 683, -0.3, 0.3)
	G.done(r)


## The buckler comes spinning back from the last foe to the defender's hand.
static func _home(parent: Node3D, skill: Dictionary) -> void:
	var state: Dictionary = _chain.get(ID, {})
	_chain.erase(ID)
	if state.is_empty() or int(state.get("hops", 0)) <= 0 or not is_instance_valid(parent):
		return
	var ref: WeakRef = state.get("caster")
	var caster := ref.get_ref() as Node3D if ref else null
	if not is_instance_valid(caster):
		return
	var hand := StarSkillArt._body_point(caster)
	var last: Vector3 = state.last
	var hops := int(state.hops)
	G.carry(parent, skill, _buckler(), last, hand, G.HOP * float(hops), G.HOP * 1.6, 0.6, [STEEL, ICE], "home", {"rim": 1.2}, 22.0, Vector3.ZERO, 0.08, 0.5)


## The hits land with the hops (drawn there).
static func contact(_parent: Node3D, _skill: Dictionary, _at: Vector3, _crit: bool) -> void:
	pass
