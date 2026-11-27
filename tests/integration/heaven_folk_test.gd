extends Node3D
## ดินแดนเทวาลัย's code-sculpted folk (HeavenFolk, HeavenFolkVisual): เทวดาน้อยถือโคม
## (heaven_lantern) and พระฤๅษีนั่งเมฆ (cloud_hermit). Their templates keep their ids, roles,
## moves and stat lines; the monster factory draws them from one shared mesh per kind
## (lighter at quality 0, inside the isle kirin's budget) with their own material and an ink
## outline at quality 1-2 only (none under strict memory pressure); no lights, particles or
## textures. At every quality, as real field monsters: they hover, move, wind up and release
## their MobAttack move in time with its blows (the deva's light orbs, the hermit's mantra
## seal), flinch, flash, burn away on death and free cleanly; the quest reads the new name.
## godot --headless --path . res://tests/integration/heaven_folk_test.tscn
var checks := 0
var failures := 0

const IDS := {&"heaven_lantern": "deva", &"cloud_hermit": "hermit"}


class Victim:
	extends Node3D
	var hits := 0
	func is_dead() -> bool: return false
	func take_damage(_amount: float, _source: Node) -> void:
		hits += 1


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", note)


func _ready() -> void:
	Game.set_process(false)
	_templates()
	_meshes()
	var saved := GameSettings.quality
	for q in [0, 1, 2]:
		GameSettings.quality = q
		for id in IDS:
			await _in_the_field(id, q)
	GameSettings.quality = saved
	await _memory_pressure()
	print("HEAVEN FOLK: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _templates() -> void:
	var names := {&"heaven_lantern": "เทวดาน้อยถือโคม", &"cloud_hermit": "พระฤๅษีนั่งเมฆ"}
	for id in IDS:
		var t := MonsterData.get_monster(id)
		check(HeavenMonsters.NORMALS.has(id) and String(t.name) == names[id] and String(t.get("folk", "")) == IDS[id], "%s is %s (folk %s)" % [id, names[id], IDS[id]])
		check(String(t.attack) == "ranged" and String(t.behavior) == ("volley" if id == &"heaven_lantern" else "mortar") and MobAttack.knows(t), "%s keeps its ranged move" % id)
		check(not bool(t.get("elite", false)) and not bool(t.get("boss", false)) and is_equal_approx(float(HeavenMonsters.MONSTERS[id].hp), 2.1), "%s keeps its role and stat line" % id)
	for text in [String(QuestData.QUESTS.heaven_lanterns.desc), String(QuestData.QUESTS.heaven_lanterns.name)]:
		check(not text.contains("ภูตโคมสวรรค์") and not text.contains("ฤๅษีเมฆาเหาะ"), "the quest no longer names the old monsters")
	check(String(QuestData.QUESTS.heaven_lanterns.desc).contains("เทวดาน้อยถือโคม"), "the lantern quest names the lantern deva")
	check(not HeavenFolk.SHADER.code.contains("sampler2D") and not HeavenFolk.LINE_SHADER.code.contains("sampler2D"), "no textures")


func _meshes() -> void:
	var saved := GameSettings.quality
	for kind in ["deva", "hermit"]:
		var tris := {}
		for q in [0, 1, 2]:
			GameSettings.quality = q
			tris[q] = HeavenFolk.triangles(HeavenFolk.mesh(kind))
		check(tris[1] == tris[2] and tris[2] >= 1800 and tris[2] <= 3800, "%s q1-2: one mesh about the kirin's budget (%d triangles)" % [kind, tris[2]])
		check(tris[0] < tris[2] * 0.76 and tris[0] >= 900, "%s q0: a lighter mesh (%d triangles)" % [kind, tris[0]])
		GameSettings.quality = 2
		check(HeavenFolk.mesh(kind) == HeavenFolk.mesh(kind) and HeavenFolk.mesh(kind).custom_aabb.has_volume(), "%s: built once, with room for its moves" % kind)
	GameSettings.quality = saved


func _spawn(id: StringName, victim: Victim) -> Mob:
	var mob := Mob.new()
	mob.setup(id, 220, Vector3.ZERO, victim)
	add_child(mob)
	mob.set_physics_process(false)
	mob._victim = victim
	return mob


func _in_the_field(id: StringName, q: int) -> void:
	var kind: String = IDS[id]
	var tag := "%s q%d" % [id, q]
	var victim := Victim.new()
	victim.position = Vector3(0, 0, 6)
	add_child(victim)
	var nodes_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var a := _spawn(id, victim)
	var b := _spawn(id, victim)
	var va := a.visual as HeavenFolkVisual
	var vb := b.visual as HeavenFolkVisual
	check(va != null and vb != null, "%s: the factory builds the sculpted folk" % tag)
	if va == null or vb == null:
		a.queue_free()
		b.queue_free()
		victim.queue_free()
		return
	check(va.kind == kind and va.body_mesh.mesh == HeavenFolk.mesh(kind) and vb.body_mesh.mesh == va.body_mesh.mesh and va.mat != vb.mat and va.mat.shader == HeavenFolk.SHADER, "%s: one shared mesh, each its own material" % tag)
	check((va.line != null) == (q > 0) and (q == 0 or (va.mat.next_pass == va.line and va.line.shader == HeavenFolk.LINE_SHADER and va.line != vb.line)), "%s: ink outline only at quality 1-2" % tag)
	var t := MonsterData.get_monster(id)
	check(is_equal_approx(va.height, float(t.height) + float(t.get("hover", 0.0))), "%s: fitted to %.1f m over a %.1f m hover" % [tag, float(t.height), float(t.get("hover", 0.0))])
	check(a.find_children("*", "Light3D", true, false).is_empty() and a.find_children("*", "GPUParticles3D", true, false).is_empty() and a.find_children("*", "CPUParticles3D", true, false).is_empty(), "%s: no lights or particles" % tag)
	check(va.find_children("*", "MeshInstance3D", true, false).size() <= 8, "%s: few draw calls (%d meshes)" % [tag, va.find_children("*", "MeshInstance3D", true, false).size()])
	var pf := func(key: String) -> Variant:
		var value: Variant = va.mat.get_shader_parameter(key)
		return 0.0 if value == null else value
	check(float(pf.call("seed")) != float(vb.mat.get_shader_parameter("seed")) or a.get_instance_id() % 997 == b.get_instance_id() % 997, "%s: each bobs in its own phase" % tag)
	# Movement.
	va.play("run")
	await get_tree().create_timer(0.7).timeout
	check(float(pf.call("stream")) > 0.5 and float(pf.call("lean")) > 0.08, "%s: on the move it leans in, ribbons streaming (stream %.2f)" % [tag, float(pf.call("stream"))])
	va.play("idle")
	await get_tree().create_timer(0.7).timeout
	check(float(pf.call("stream")) < 0.2, "%s: and settles when it stops" % tag)
	# Its MobAttack move: the charge grows until just before the blows land, then is released.
	var started := MobAttack.launch(a)
	check(started, "%s: its move starts" % tag)
	var move: MobAttack = null
	for child in a.get_children():
		if child is MobAttack:
			move = child
	var contact := 99.0
	if move != null:
		for shot in move.shots:
			contact = minf(contact, float(shot.at))
	check(contact > 0.6 and contact < 2.0, "%s: its blows land %.2f s in" % [tag, contact])
	await get_tree().create_timer(contact * 0.6).timeout
	check(float(pf.call("seal")) > 0.6 and float(pf.call("charge")) > 0.6 and (pf.call("arm_a") as Vector3).length() > 0.3 and float(pf.call("seal_rise")) < 0.05, "%s: the wind-up gathers the charge (seal %.2f)" % [tag, float(pf.call("seal"))])
	await get_tree().create_timer(contact * 0.3).timeout
	check(float(pf.call("seal_rise")) > 0.5, "%s: and flings it as the blows land (rise %.2f)" % [tag, float(pf.call("seal_rise"))])
	await get_tree().create_timer(1.2).timeout
	check(float(pf.call("seal")) < 0.05 and (pf.call("arm_a") as Vector3).length() < 0.05 and absf(float(pf.call("lean"))) < 0.05, "%s: and rests again" % tag)
	check(victim.hits >= 0 and not is_instance_valid(move), "%s: the move ends cleanly" % tag)
	# The basic ranged attack: a quick throw.
	va.action("attack", 450)
	await get_tree().create_timer(0.14).timeout
	check(float(pf.call("seal_rise")) > 0.2, "%s: the basic attack throws quickly" % tag)
	await get_tree().create_timer(0.7).timeout
	# Hit: the flash lights the material, it flinches.
	a.take_hit(1, false, Color.WHITE, null)
	check(float(pf.call("glow")) > 0.4, "%s: the hit flash lights it" % tag)
	check(va.body_mesh.material_overlay == null, "%s: no overlay (it would draw unposed)" % tag)
	await get_tree().create_timer(0.06).timeout
	check(float(pf.call("flinch")) > 0.3, "%s: it flinches" % tag)
	# Death: it burns away into gold and frees.
	a.take_hit(a.hp + 10, false, Color.WHITE, null)
	await get_tree().create_timer(0.8).timeout
	check(a.is_dead() and va.current == "die" and float(pf.call("dissolve")) > 0.4 and float(pf.call("sink")) > 0.4, "%s: it sinks and dissolves (%.2f)" % [tag, float(pf.call("dissolve"))])
	await get_tree().create_timer(1.0).timeout
	check(not is_instance_valid(a), "%s: the body is gone" % tag)
	b.queue_free()
	victim.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) <= nodes_before, "%s: frees cleanly (%d -> %d nodes)" % [tag, nodes_before, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	check(HeavenFolk.mesh(kind) != null, "%s: the shared mesh outlives them" % tag)


func _memory_pressure() -> void:
	var saved := GameSettings.quality
	var level := MemoryGuard.pressure
	GameSettings.quality = 2
	MemoryGuard.pressure = 2
	var holder := Node3D.new()
	add_child(holder)
	var v := HeavenFolkVisual.make(holder, MonsterData.get_monster(&"cloud_hermit")) as HeavenFolkVisual
	check(v != null and v.line == null and v.mat.next_pass == null, "strict memory pressure drops the outline")
	MemoryGuard.pressure = level
	GameSettings.quality = saved
	holder.queue_free()
	await get_tree().process_frame
