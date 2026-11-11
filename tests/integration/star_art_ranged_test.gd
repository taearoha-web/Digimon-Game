extends Node3D
## The ranged star signatures (combat/star_art: the Archer's, Mage's and Priest's 50 to 200
## star skills). Each has its own script that owns the show (StarSignature, and through it
## GodSkillArt.owns, so the shared class overlays stay out), casts on a real field at every
## quality and under memory pressure without script errors, draws its roots inside the
## VFX budget, leaves nothing behind (nodes and budget back to the baseline), and its art
## goes away at once when the cast stops early. Monsters borrowing a star id keep the
## shared art; the god skills keep theirs.
const CLASSES := [&"archer", &"mage", &"priest"]
var checks := 0
var failures := 0

class Target:
	extends Mob
	var contacts := 0
	func take_hit(amount: int, crit: bool, color := Color.WHITE, attacker: Node = null) -> bool:
		contacts += 1
		return super.take_hit(amount, crit, color, attacker)


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", note)


func profile(cls: StringName) -> void:
	Game.new_profile(cls, "Ranged Star QA")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.paragon = {"level": 300, "points": 300, "spent": 0, "exp": 0, "alloc": {}}
	Game.profile.look = {"gender": 0}
	Game.profile.party = []
	Game.profile.equip = {}
	for slot in ItemData.EQUIP_SLOTS:
		Game.profile.equip[slot] = StarProgression.item(cls, 100 if slot == "wings" else 200, slot, Game.rng)
	Game.profile.hp = 100000
	Game.profile.mp = 100000


func stars(cls: StringName) -> Array:
	var out := []
	for skill in ClassData.pool(cls):
		if skill.has("star") and not StarSkillData.is_god(skill):
			out.append(skill)
	return out


func _ready() -> void:
	Game.set_process(false)
	InputSetup.ensure_defaults()
	GameSettings.load_settings()
	GameSettings.quality = 2
	GameSettings.ult_cutin = false
	ZoneData.ensure()
	_ownership()
	await _casts()
	await _cut_short()
	MemoryGuard.force(-1, get_tree())
	GameSettings.quality = 2
	Engine.time_scale = 1.0
	Game.has_profile = false
	print("STAR ART RANGED: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(failures)


## Every ranged star skill has its signature, which owns its show; borrowed ids and the god
## skills do not go through it.
func _ownership() -> void:
	for cls in CLASSES:
		var list := stars(cls)
		check(list.size() == 4, "%s has four star skills below the god tier" % cls)
		for skill in list:
			var id := String(skill.id)
			var own := StarSignature.script_for(id)
			check(own != null, "signature script for " + id)
			if own:
				check(own.has_method("telegraph") and own.has_method("strike"), "%s draws its wind-up and its contacts" % id)
			check(StarSignature.owns(skill), "%s is owned by its signature" % id)
			check(GodSkillArt.owns(skill), "%s keeps the shared class overlays out (GodSkillArt.owns)" % id)
	var god := ClassData.find_skill(&"mage", "astral_apocalypse")
	check(not StarSignature.owns(god) and GodSkillArt.owns(god), "the god skill keeps its own god art")
	var borrowed := {"id": "crystal_prison", "star": 50, "radius": 3.0, "class": &"warrior", "shape": "blast"}
	check(not StarSignature.owns(borrowed), "a monster's borrowed star id keeps the shared art")
	check(StarSignature.script_for("") == null and StarSignature.script_for("_kit_star") == null, "kits are never a skill's signature")
	check(not StarSignature.owns({"id": "_kit_star", "star": 50, "class": &"archer"}), "a kit is never a skill's signature")


func _field(cls: StringName) -> Array:
	var field := Node3D.new()
	add_child(field)
	var camera := Camera3D.new()
	camera.fov = 40.0
	field.add_child(camera)
	camera.position = Vector3(0, 16, 15)
	camera.look_at(Vector3(0, 1, 0))
	camera.make_current()
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.position = Vector3(-4, 0, 0)
	var target: Target = null
	for spot in [Vector3(2, 0, 0), Vector3(3.5, 0, -1.6), Vector3(3.3, 0, 1.8)]:
		var mob := Target.new() if target == null else Mob.new()
		mob.setup(&"dawn_stag", 100, spot, hero)
		mob.position = spot
		field.add_child(mob)
		mob.set_physics_process(false)
		mob.hp = 100000000
		mob.max_hp = mob.hp
		if target == null:
			target = mob
	hero.target = target
	return [field, hero, target]


func _roots(field: Node, id: String) -> int:
	var count := 0
	for node in field.get_children():
		if node is GodRangedKit and String(node.name).contains(id):
			count += 1
	return count


## Real casts of all twelve at every quality (and under memory pressure): the signature
## draws, no shared class overlay plays, the budget holds, everything is freed.
func _casts() -> void:
	for mode in [[2, 0], [1, 0], [0, 0], [2, 2]]:
		GameSettings.quality = mode[0]
		MemoryGuard.force(mode[1], get_tree())
		var label := "q%d p%d" % mode
		for cls in CLASSES:
			for skill in stars(cls):
				var id := String(skill.id)
				profile(cls)
				var parts := _field(cls)
				var field: Node3D = parts[0]
				var hero: Hero = parts[1]
				var target: Target = parts[2]
				await get_tree().process_frame
				var base_objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
				var hp0 := target.hp
				hero._cast(skill)
				var seq := hero.get_node_or_null("StarCast_" + id) as StarSkillSequence
				check(seq != null, "%s cast starts %s" % [id, label])
				if seq == null:
					field.queue_free()
					await field.tree_exited
					continue
				var drawn := _roots(field, id) > 0
				var generic := false
				var over := 0
				Engine.time_scale = 3.0
				var frames := 0
				while (is_instance_valid(seq) and not seq.is_queued_for_deletion()) and frames < 3000:
					await get_tree().process_frame
					frames += 1
					drawn = drawn or _roots(field, id) > 0
					for node in field.get_children():
						var name := String(node.name)
						if name.begins_with("CasterArt_") or name.begins_with("ClassFlourish_") or node is SignatureKit:
							generic = true
					if int(VfxBudget.counters().decorations) > VfxBudget.decoration_limit() + VfxBudget.hero_decoration_room():
						over += 1
				# Let the last roots play out.
				for k in 40:
					await get_tree().process_frame
				Engine.time_scale = 1.0
				check(frames < 3000, "%s cast ends %s" % [id, label])
				check(drawn, "%s signature roots drawn %s" % [id, label])
				check(not generic, "%s no shared class overlay under the signature %s" % [id, label])
				check(over == 0, "%s within the decoration budget %s" % [id, label])
				if float(skill.mult) > 0.0:
					check(target.hp < hp0 and target.contacts > 0, "%s still hits (art is cosmetic) %s" % [id, label])
				await get_tree().create_timer(2.2).timeout
				var left := 0
				for node in field.get_children():
					if (node is GodRangedKit or node is StarSkillArt) and String(node.name).contains(id):
						left += 1
				check(left == 0, "%s roots free themselves after the cast %s (%d left)" % [id, label, left])
				field.queue_free()
				await field.tree_exited
				await get_tree().process_frame
				check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "%s budget back to baseline %s %s" % [id, label, VfxBudget.counters()])
				var grown := int(Performance.get_monitor(Performance.OBJECT_COUNT)) - base_objects
				check(grown < 400, "%s no object growth %s (%d)" % [id, label, grown])
	MemoryGuard.force(-1, get_tree())
	GameSettings.quality = 2


## A cast that stops early (the hero falls in the middle of it) takes its art away at once.
func _cut_short() -> void:
	for pair in [[&"priest", "sacred_sanctuary"], [&"mage", "genesis_nova"], [&"archer", "celestial_hunt"]]:
		var id: String = pair[1]
		profile(pair[0])
		var parts := _field(pair[0])
		var field: Node3D = parts[0]
		var hero: Hero = parts[1]
		hero._cast(ClassData.find_skill(pair[0], id))
		var t := 0.0
		while t < 1.4:
			await get_tree().process_frame
			t += get_process_delta_time()
		check(_roots(field, id) > 0, "%s art is up mid-cast" % id)
		hero._dead = true
		await get_tree().create_timer(0.6).timeout
		check(_roots(field, id) == 0, "%s art leaves at once when the cast stops early (%d left)" % [id, _roots(field, id)])
		hero._dead = false
		field.queue_free()
		await field.tree_exited
		await get_tree().process_frame
		check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "%s cut short: budget released %s" % [id, VfxBudget.counters()])
