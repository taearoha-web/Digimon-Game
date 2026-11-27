extends Node3D
## ดินแดนเทวาลัย's gate giants and golden naga, sculpted in code: the jade
## ยักษ์ทวารบาล and the ท้าวยักษ์ gatekeeper (HeavenYaksha, HeavenYakshaVisual) and the
## seven-headed พญานาคทอง (HeavenNaga, HeavenNagaVisual).
## - The templates name their sculpt and drop the generic halo; the monster factory
##   builds them; their stats and fallback rigs are unchanged.
## - At every quality: one shared mesh per kind, the lite one lighter, in budget; the
##   body stands at its template height; no lights.
## - The motion: the idle breathes; the jade smash glows the club and lands at the
##   cleave's impact; the king whirls a whole turn and comes back facing forward; the
##   naga rears, gapes and strikes; a hurt flinch never cancels a swing; death kneels or
##   sinks and fades away.
## - Real Mobs of all three spawn, attack a victim with their MobAttack moves and die.
##   godot --headless --path . res://tests/integration/heaven_guardians_test.tscn
var checks := 0
var failures := 0

const IDS := [&"jade_yaksha", &"heaven_gatekeeper", &"celestial_naga"]

class Victim:
	extends Node3D
	var hits := 0
	func is_dead() -> bool: return false
	func take_damage(_amount: float, _source: Node) -> void: hits += 1
	func apply_slow(_s: float) -> void: pass
	func apply_freeze(_s: float) -> void: pass


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", note)


func _ready() -> void:
	Game.set_process(false)
	_templates()
	for q in [0, 1, 2]:
		GameSettings.quality = q
		_meshes(q)
	GameSettings.quality = 1
	await _giant_motion()
	await _naga_motion()
	await _mobs()
	GameSettings.quality = 1
	print("heaven_guardians_test: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _templates() -> void:
	var want := {&"jade_yaksha": ["yaksha", "jade", "cleave", "remaster/big/Tribal"],
		&"heaven_gatekeeper": ["yaksha", "king", "spin", "remaster/big/BlueDemon"],
		&"celestial_naga": ["naga", "gold", "mortar", "remaster/flying/Dragon_Evolved"]}
	for id in IDS:
		var t := MonsterData.get_monster(id)
		var w: Array = want[id]
		check(String(t.get(w[0], "")) == w[1], "%s is sculpted (%s: %s)" % [id, w[0], w[1]])
		check(not t.has("aura") and not t.has("tint"), "%s dresses itself (no halo, no tint)" % id)
		check(String(t.behavior) == w[2] and String(t.model) == w[3], "%s keeps its move and fallback rig" % id)
		check(MobAttack.knows(t), "%s fights with a MobAttack move" % id)
	check(bool(MonsterData.get_monster(&"heaven_gatekeeper").elite) and bool(MonsterData.get_monster(&"celestial_naga").elite), "the gatekeeper and the naga stay elites")
	check(not HeavenYaksha.has("") and not HeavenNaga.has("") and not HeavenYaksha.has("gold"), "only the named kinds are sculpted")


func _meshes(q: int) -> void:
	for kind in ["jade", "king"]:
		var m := HeavenYaksha.mesh(kind)
		check(m != null and m.get_surface_count() > 0, "q%d %s: a mesh" % [q, kind])
		check(HeavenYaksha.mesh(kind) == m, "q%d %s: one shared mesh" % [q, kind])
		var tris := HeavenYaksha.triangles(m)
		check(tris > 1500 and tris < (9000 if q == 0 else 16000), "q%d %s: %d triangles in budget" % [q, kind, tris])
	check(HeavenYaksha.figure_height("king") > HeavenYaksha.figure_height("jade") * 0.9, "the king's crown towers")
	var n := HeavenNaga.mesh()
	check(n != null and n.get_surface_count() > 0 and HeavenNaga.mesh() == n, "q%d naga: one shared mesh" % q)
	var ntris := HeavenNaga.triangles(n)
	check(ntris > 1500 and ntris < (12000 if q == 0 else 22000), "q%d naga: %d triangles in budget" % [q, ntris])
	check(HeavenNaga.head_count() == (5 if q == 0 else 7), "q%d naga: %d heads" % [q, HeavenNaga.head_count()])
	if q == 0:
		return
	# The lite meshes are lighter.
	GameSettings.quality = 0
	var lite_jade := HeavenYaksha.triangles(HeavenYaksha.mesh("jade"))
	var lite_naga := HeavenNaga.triangles(HeavenNaga.mesh())
	GameSettings.quality = q
	check(lite_jade < HeavenYaksha.triangles(HeavenYaksha.mesh("jade")), "q%d: the lite giant is lighter" % q)
	check(lite_naga < HeavenNaga.triangles(HeavenNaga.mesh()), "q%d: the lite naga is lighter" % q)
	# The factory builds them at their heights.
	for id in IDS:
		var t := MonsterData.get_monster(id)
		var holder := Node3D.new()
		add_child(holder)
		var v := CelestialDragonVisual.make(holder, t)
		var right := (v is HeavenNagaVisual) if t.has("naga") else (v is HeavenYakshaVisual)
		check(right, "q%d %s: the factory builds its sculpt" % [q, id])
		check(absf(v.height - float(t.height) - float(t.get("hover", 0.0))) < 0.05, "q%d %s: stands %.2f m (template %.2f)" % [q, id, v.height, float(t.height)])
		check(holder.find_children("*", "Light3D", true, false).is_empty(), "q%d %s: no lights" % [q, id])
		check(holder.find_children("*", "GPUParticles3D", true, false).is_empty(), "q%d %s: no particles" % [q, id])
		if v is HeavenYakshaVisual:
			check(((v as HeavenYakshaVisual).line != null) == (q > 0) or MemoryGuard.pressure >= 2, "q%d %s: the ink outline above low quality" % [q, id])
		holder.free()


func _chest(v: HeavenYakshaVisual) -> Vector3:
	return v.pose_now.get("chest", Vector3.ZERO) as Vector3


func _giant_motion() -> void:
	var jade := HeavenYakshaVisual.new()
	add_child(jade)
	jade.build("jade", 2.9)
	var king := HeavenYakshaVisual.new()
	add_child(king)
	king.build("king", 3.9)
	king.position.x = 4.0
	await _wait(0.3)
	# The idle breathes.
	var a := _chest(jade)
	var top_a: Vector3 = jade.pose_now.get("neck", Vector3.ZERO)
	await _wait(0.9)
	check(_chest(jade) != a or jade.pose_now.get("neck", Vector3.ZERO) != top_a, "the guard stance breathes")
	check(float(jade.pose_now.get("glow", 0.0)) < 0.05, "the club rests unlit")
	# The jade smash: the club raised and glowing in the wind-up, slammed at the cleave's impact.
	var rest := _chest(jade)
	jade.action("attack", 1200)
	await _wait(0.45)
	check(float(jade.pose_now.get("glow", 0.0)) > 0.2, "the raised club glows (%.2f)" % float(jade.pose_now.get("glow", 0.0)))
	check(_chest(jade).x < rest.x - 4.0, "the jade giant rears back to raise the club")
	jade.action("hurt", 200)
	await _wait(0.4)
	check(_chest(jade).x > rest.x + 10.0, "the smash folds him forward at the impact (a hurt does not cancel it)")
	await _wait(1.4)
	check(jade._track.is_empty() and _chest(jade).distance_to(rest) < 6.0, "the jade giant is back in his stance")
	# The king's whirl: a whole turn through the blow, then facing forward again.
	king.action("attack", 1300)
	var turned := 0.0
	var start := Time.get_ticks_msec()
	var flinched := false
	while Time.get_ticks_msec() - start < 1300:
		await get_tree().process_frame
		turned = maxf(turned, absf(wrapf(king.model.rotation.y, -PI, PI)))
		if not flinched and Time.get_ticks_msec() - start > 600:
			flinched = true
			king.action("hurt", 200)
	await _wait(1.0)
	check(turned > 2.0, "the king whirls round (%.2f rad)" % turned)
	check(absf(king.model.rotation.y) < 0.01 and king._track.is_empty(), "the king ends facing forward, at rest")
	# The quick basic blow is a short smash, not a whirl.
	king.action("attack", 450)
	await _wait(0.2)
	check(absf(king.model.rotation.y) < 0.01, "the basic blow does not spin")
	await _wait(0.8)
	# Walking: the gait moves the legs.
	jade.play("walk")
	await _wait(0.6)
	var leg_a: Vector3 = jade.pose_now.get("hip_l", Vector3.ZERO)
	await _wait(0.35)
	check(jade.pose_now.get("hip_l", Vector3.ZERO) != leg_a, "the giant stomps")
	jade.play("idle")
	# Death: kneels, slumps and dissolves; no action wakes him.
	for v in [jade, king]:
		v.hold("die")
	await _wait(0.6)
	check(_chest(jade).x > 20.0, "the giant kneels and slumps")
	jade.action("attack", 1200)
	check(String(jade.current) == "die", "nothing wakes the dead giant")
	await _wait(1.0)
	check(jade.fade < 0.05 and king.fade < 0.05, "both fade away (%.2f, %.2f)" % [jade.fade, king.fade])
	jade.queue_free()
	king.queue_free()
	await get_tree().process_frame


func _naga_motion() -> void:
	var naga := HeavenNagaVisual.new()
	add_child(naga)
	naga.build("gold", 4.1, 0.6)
	await _wait(0.3)
	check(naga.model.position.y > 0.5, "the naga hovers on its cloud")
	check(absf(naga.scalar("gape")) < 0.01, "the mouths rest closed")
	naga.action("attack", 1600)
	await _wait(0.7)
	check(naga.scalar("lean") < -0.25 and naga.scalar("spread") > 0.5 and naga.scalar("gape") > 0.4, "the naga rears with its hood fanned and mouths gaping")
	naga.action("hurt", 200)
	await _wait(0.55)
	check(naga.scalar("lean") > 0.2, "it strikes forward at the mortar's impact (a hurt does not cancel it)")
	await _wait(1.2)
	check(absf(naga.scalar("lean")) < 0.05 and absf(naga.scalar("gape")) < 0.05, "the naga settles back")
	naga.hold("die")
	await _wait(1.5)
	check(naga.scalar("sink") > 0.4 and naga.fade < 0.05, "it sinks into its cloud and fades away")
	naga.queue_free()
	await get_tree().process_frame


func _mobs() -> void:
	var victim := Victim.new()
	add_child(victim)
	for id in IDS:
		victim.hits = 0
		victim.position = Vector3(2.2, 0, 0)
		var mob := Mob.new()
		mob.setup(id, HeavenRealmData.CAMP_MIN, Vector3.ZERO, victim)
		add_child(mob)
		mob.set_physics_process(false)
		await _wait(0.5)
		var right := (mob.visual is HeavenNagaVisual) if mob.template.has("naga") else (mob.visual is HeavenYakshaVisual)
		check(right, "%s: the Mob wears its sculpt" % id)
		check(mob.visual.get_node_or_null("DeepAura") == null, "%s: no halo" % id)
		mob._victim = victim
		mob.hostile = true
		check(MobAttack.launch(mob), "%s: launches its %s" % [id, mob.template.behavior])
		await _wait(2.4)
		check(victim.hits > 0, "%s: the blow lands (%d)" % [id, victim.hits])
		check(String(mob.visual.current) != "die", "%s: still standing" % id)
		mob.take_hit(10_000_000, false)
		await get_tree().process_frame
		check(mob.is_dead() and String(mob.visual.current) == "die", "%s: dies" % id)
		await _wait(2.0)
	victim.queue_free()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
