extends Node3D
## The sky team's signatures: the Archer's, Mage's and Priest's Lv.60-100 class skills
## (combat/skill_art, SkillSignature). Each has its own script that owns the show (so the
## shared class overlays stay out), casts through the real hero path and a companion's at
## every quality and under memory pressure without script errors, draws inside the VFX
## budget (a companion lighter than the hero), still hits (the art is cosmetic), frees its
## roots after the cast with the budget back to baseline, and goes away at once when the
## caster dies mid-cast. Armageddon, Thunder Storm and Judgment Ray keep their own
## sequences: their signature dresses the wind-up only.
const CLASSES := [&"archer", &"mage", &"priest"]
const SEQUENCES := ["armageddon", "thunder_storm", "judgment_ray"]
const SHARED := ["SkillWindup_", "SkillFlight_", "SkillLink_", "SkillContact_", "SkillSpectacle_", "MartialContact_", "ClassFlourish_", "CreatureArrival", "FlourishFlightGlow", "WeaponCharge"]
var checks := 0
var failures := 0
## The most pieces the hero's own cast of each skill held at once (quality 2).
var hero_pieces := {}

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
	Game.new_profile(cls, "Sky Art QA")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.look = {"gender": 0}
	Game.profile.party = []
	Game.profile.equip = {}
	Game.profile.hp = 100000
	Game.profile.mp = 100000


static func skills(cls: StringName) -> Array:
	var out := []
	for skill in ClassData.pool(cls):
		var level := int(skill.get("level", 1))
		if not skill.has("star") and level >= 60 and level <= 100:
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
	await _companions()
	await _cut_short()
	MemoryGuard.force(-1, get_tree())
	GameSettings.quality = 2
	Engine.time_scale = 1.0
	Game.has_profile = false
	print("SKILL ART SKY: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(failures)


## Every one of the 33 skills has its signature, which owns its show.
func _ownership() -> void:
	var total := 0
	for cls in CLASSES:
		var list := skills(cls)
		check(list.size() == 11, "%s has eleven Lv.60-100 skills (%d)" % [cls, list.size()])
		for skill in list:
			total += 1
			var id := String(skill.id)
			var own := SkillSignature.script_for(id)
			check(own != null, "signature script for " + id)
			if own:
				check(own.has_method("anticipate") and own.has_method("play"), "%s draws its wind-up and its release" % id)
			check(SkillSignature.owns(skill), "%s is owned by its signature" % id)
			check(GodSkillArt.owns(skill), "%s keeps the shared class overlays out (GodSkillArt.owns)" % id)
	check(total == 33, "33 skills in all")
	check(SkillSignature.script_for("_sky") == null, "the team kit is never a skill's signature")
	var star := {"id": "fierce_wind", "star": 50, "class": &"archer", "shape": "fan"}
	check(not SkillSignature.owns(star), "a star lookalike borrowing the id keeps its own path")


func _field(cls: StringName) -> Array:
	var field := Node3D.new()
	field.name = "SkyField"
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
	hero._facing = PI * 0.5
	var mobs: Array = []
	for spot in [Vector3(2, 0, 0), Vector3(3.5, 0, -1.6), Vector3(3.3, 0, 1.8), Vector3(1.0, 0, 2.4)]:
		var mob := Target.new()
		mob.setup(&"forest_orc", 100, spot, hero)
		mob.position = spot
		field.add_child(mob)
		mob.set_physics_process(false)
		mob.hp = 100000000
		mob.max_hp = mob.hp
		mobs.append(mob)
	hero.target = mobs[0]
	return [field, hero, mobs]


func _roots(field: Node, id: String) -> int:
	var count := 0
	for node in field.get_children():
		if node is GodRangedKit and String(node.name).begins_with("Sky_" + id + "_"):
			count += 1
	return count


## Pieces (one decoration each) the signature's roots of [param id] hold now.
func _pieces(field: Node, id: String) -> int:
	var count := 0
	for node in field.get_children():
		if node is GodRangedKit and String(node.name).begins_with("Sky_" + id + "_"):
			count += (node as GodRangedKit).pieces.size()
	return count


func _shared(field: Node, id: String) -> String:
	for node in field.get_children():
		var name := String(node.name)
		if node is SignatureKit or node is StarSkillArt:
			return name
		for prefix in SHARED:
			if name.begins_with(prefix):
				return name
		if name.contains(id) and not name.begins_with("Sky_"):
			return name
	return ""


func _show_time(skill: Dictionary) -> float:
	match String(skill.id):
		"armageddon": return 9.5
		"thunder_storm": return 4.5
		"judgment_ray": return 3.2
	return float(skill.hit_delay) + 3.0


## Real hero casts of all 33 at every quality and under memory pressure.
func _casts() -> void:
	for mode in [[2, 0], [0, 0], [2, 2]]:
		GameSettings.quality = mode[0]
		MemoryGuard.force(mode[1], get_tree())
		var label := "q%d p%d" % mode
		for cls in CLASSES:
			for skill in skills(cls):
				var id := String(skill.id)
				profile(cls)
				var parts := _field(cls)
				var field: Node3D = parts[0]
				var hero: Hero = parts[1]
				var mobs: Array = parts[2]
				await get_tree().process_frame
				var base_objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
				SkillLayers.last = {"layers": [], "emitters": 0, "rings": 0, "lights": 0, "hazes": 0, "particles": 0}
				hero._cast(skill)
				check(float(hero.cooldowns.get(skill.id, 0.0)) > 0.0, "%s cast starts %s" % [id, label])
				var drawn := _roots(field, id) > 0
				var generic := ""
				var over := 0
				var peak := 0
				var pieces := 0
				Engine.time_scale = 3.0
				var t := 0.0
				while t < _show_time(skill):
					await get_tree().process_frame
					t += get_process_delta_time()
					drawn = drawn or _roots(field, id) > 0
					pieces = maxi(pieces, _pieces(field, id))
					var seen := _shared(field, id)
					if generic == "" and seen != "":
						generic = seen
					var held := int(VfxBudget.counters().decorations)
					peak = maxi(peak, held)
					if held > VfxBudget.decoration_limit() + VfxBudget.hero_decoration_room():
						over += 1
				Engine.time_scale = 1.0
				if label == "q2 p0":
					hero_pieces[id] = pieces
				check(drawn, "%s signature roots drawn %s" % [id, label])
				check(generic == "", "%s no shared class overlay under the signature %s (%s)" % [id, label, generic])
				check((SkillLayers.last.layers as Array).is_empty(), "%s the shared layer stack stays out %s" % [id, label])
				check(over == 0, "%s within the decoration budget %s (peak %d)" % [id, label, peak])
				if float(skill.get("mult", 0.0)) > 0.0 and String(skill.shape) != "summon":
					var hits := 0
					for mob in mobs:
						hits += (mob as Target).contacts
					check(hits > 0, "%s still hits (art is cosmetic) %s" % [id, label])
				if String(skill.shape) == "summon":
					check(hero._summons.filter(func(s): return is_instance_valid(s)).size() > 0, "%s still calls its creatures %s" % [id, label])
				await get_tree().create_timer(0.8).timeout
				check(_roots(field, id) == 0, "%s roots free themselves after the cast %s (%d left)" % [id, label, _roots(field, id)])
				check(hero.get_children().filter(func(n): return String(n.name).begins_with("SkyWatch_")).is_empty(), "%s its caster watch is gone %s" % [id, label])
				field.queue_free()
				await field.tree_exited
				await get_tree().process_frame
				check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "%s budget back to baseline %s %s" % [id, label, VfxBudget.counters()])
				var grown := int(Performance.get_monitor(Performance.OBJECT_COUNT)) - base_objects
				check(grown < 400, "%s no object growth %s (%d)" % [id, label, grown])
	MemoryGuard.force(-1, get_tree())
	GameSettings.quality = 2


## A companion casts each of them too: no errors, drawn lighter than the hero's own cast,
## everything freed.
func _companions() -> void:
	GameSettings.quality = 2
	for cls in CLASSES:
		for skill in skills(cls):
			var id := String(skill.id)
			profile(cls)
			var parts := _field(cls)
			var field: Node3D = parts[0]
			var hero: Hero = parts[1]
			var mobs: Array = parts[2]
			var mate := Companion.new()
			mate.setup({"name": "Sky Mate", "class": cls, "level": 100, "stars": 0, "stance": "follow"}, 0, hero, field)
			field.add_child(mate)
			mate.set_physics_process(false)
			mate.global_position = Vector3(-3, 0, 2)
			mate.target = mobs[0]
			mate.mp = 100000.0
			await get_tree().process_frame
			mate._cast(skill)
			var drawn := false
			var peak := 0
			var generic := ""
			Engine.time_scale = 3.0
			var t := 0.0
			while t < _show_time(skill):
				await get_tree().process_frame
				t += get_process_delta_time()
				drawn = drawn or _roots(field, id) > 0
				peak = maxi(peak, _pieces(field, id))
				var seen := _shared(field, id)
				if generic == "" and seen != "":
					generic = seen
			Engine.time_scale = 1.0
			check(drawn, "%s a companion's cast draws its signature" % id)
			check(generic == "", "%s no shared class overlay under a companion's cast (%s)" % [id, generic])
			check(peak <= 30 and peak <= int(hero_pieces.get(id, 0)), "%s a companion's cast is lighter than the hero's (%d pieces at most, the hero's %d)" % [id, peak, int(hero_pieces.get(id, 0))])
			await get_tree().create_timer(0.8).timeout
			check(_roots(field, id) == 0, "%s a companion's roots free themselves (%d left)" % [id, _roots(field, id)])
			field.queue_free()
			await field.tree_exited
			await get_tree().process_frame
			check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "%s companion cast: budget back to baseline %s" % [id, VfxBudget.counters()])


## A caster who falls mid-cast takes the art away at once.
func _cut_short() -> void:
	for pair in [[&"archer", "phoenix_rain", 0.75], [&"mage", "hell_meteor", 0.95], [&"priest", "last_judgement", 1.1], [&"priest", "divine_judgment", 0.5], [&"archer", "meteor_arrow", 0.3]]:
		var id: String = pair[1]
		profile(pair[0])
		var parts := _field(pair[0])
		var field: Node3D = parts[0]
		var hero: Hero = parts[1]
		hero._cast(ClassData.find_skill(pair[0], id))
		var t := 0.0
		while t < float(pair[2]):
			await get_tree().process_frame
			t += get_process_delta_time()
		check(_roots(field, id) > 0, "%s art is up mid-cast" % id)
		hero._dead = true
		await get_tree().create_timer(0.6).timeout
		check(_roots(field, id) == 0, "%s art leaves at once when the caster falls (%d left)" % [id, _roots(field, id)])
		hero._dead = false
		await get_tree().create_timer(0.8).timeout
		field.queue_free()
		await field.tree_exited
		await get_tree().process_frame
		check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "%s cut short: budget released %s" % [id, VfxBudget.counters()])
