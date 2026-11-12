extends RefCounted
## Archer Lv.64 "Force of Nature" (พลังแห่งธรรมชาติ): two beasts of the wild answer the
## call. Cosmetic only. Wind-up: a leaf sigil writes itself round the archer, vines of light
## rise out of it and leaves spiral up into the raised bow. Release: the sigil flares and
## two grove gates open where the creatures really stand: a ring of green light, a column
## of sap-gold light they grow up through, a burst of leaves and seeds; leaves drift down
## over both as they take their place.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const GROVE := {"c_core": Color("e2ffb0"), "c_mid": Color("7ce87a"), "c_edge": Color("2c8a4e")}
const SAP := {"c_core": Color("fff2b0"), "c_mid": Color("b6f06a"), "c_edge": Color("3f9a3a")}
const LEAF := {"tint": Color("7ed98a"), "ember": Color("c8ff9a"), "glow": Color("e6ffd0"), "rim": 0.45, "shadow": Color("2c6a3a")}
const PETAL := {"tint": Color("ffd6e8"), "ember": Color("fff0c0"), "glow": Color("fff4f8"), "rim": 0.5, "shadow": Color("a05a7a")}


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.3, visual)
	var r := c.toward(origin, aim, duration + 0.3, "Windup", duration)
	if not r:
		return true
	A.sigil(r, Vector3.UP * 0.05, 2.2, 6.0, GROVE, 0.0, duration + 0.3, duration * 0.9, 0.5, 0.4)
	A.flash(r, r.to_local(c.hand()), 1.0, SAP, 0.0, duration + 0.15, 0.5, {"grow": duration, "from": 0.2})
	if c.has(1):
		for k in c.n(2, 3, 5):
			var a := float(k) * TAU / float(c.n(2, 3, 5)) + 0.4
			var foot := Vector3(sin(a), 0.05, cos(a)) * 1.9
			A.beam(r, foot, foot * 0.35 + Vector3.UP * 2.2, 0.32, GROVE, 0.04 * float(k), duration + 0.2, 0.45, 5.0)
		A.drift(r, LEAF, Vector3.ZERO, 1.8, c.n(3, 5, 8), 0.4, 0.32, 0.0, duration + 0.4, Vector3(0, 3.0, 0), 2.0)
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := A.cast(parent, skill, origin, 1.8)
	var r := c.root(origin, 1.2, "Call", origin)
	if r:
		A.ring(r, Vector3.UP * 0.07, 3.0, GROVE, 0.0, 0.6, 0.55)
		A.flash(r, r.to_local(c.hand()), 1.6, SAP, 0.0, 0.3, 0.5)
	# The creatures are placed this frame (Summon._ready): open their gates where they stand.
	(func():
		if c.hero:
			VfxBudget.hero_begin()
		_gates(c)
		if c.hero:
			VfxBudget.hero_end()).call_deferred()
	return true


static func _gates(c: A.Cast) -> void:
	if not is_instance_valid(c.parent) or not c.parent.is_inside_tree():
		return
	var found := 0
	for node in c.parent.get_tree().get_nodes_in_group("summons"):
		if found >= 3 or not node is Node3D or String(node.get("skill_id")) != c.id:
			continue
		if is_instance_valid(c.caster) and node.get("summoner") != c.caster:
			continue
		var spot := A.flat((node as Node3D).global_position)
		if is_instance_valid(c.caster) and A.flat(c.caster.global_position).distance_to(spot) > 6.0:
			continue
		found += 1
		var g := c.root(spot, 1.6, "Gate%d" % found, c.origin)
		if not g:
			return
		A.sigil(g, Vector3.UP * 0.05, 1.5, 6.0, GROVE, 0.0, 1.4, 0.3, 0.55, -0.6)
		A.column(g, Vector3.ZERO, 0.75, 3.4, SAP, 0.0, 0.9, 0.42, 4.0, {"to": Vector3(0.5, 1.0, 0.5)})
		A.ring(g, Vector3.UP * 0.08, 2.2, GROVE, 0.0, 0.55, 0.6)
		if c.has(0):
			A.drift(g, LEAF, Vector3.UP * 0.4, 0.6, c.n(3, 5, 8), 1.2, 0.34, 0.0, 1.3, Vector3(0, 3.2, 0), float(found) * 3.0)
		if c.has(1):
			A.drift(g, PETAL, Vector3.UP * 0.2, 1.1, c.n(2, 3, 5), 2.2, 0.26, 0.25, 1.4, Vector3.ZERO, float(found) * 5.0)
			A.S.motes(g, Vector3.ZERO, 1.0, c.n(4, 6, 9), SAP, 0.22, 0.05, 0.4, 0.9, 1.6, 9, 3.0)
