extends Node3D
## The arcane classes' regular skills from Lv.60 (Summoner, Dark Lord, Bard; 33 skills,
## combat/skill_art via SkillSignature, team kit _mystic.gd): every skill casts through the
## real hero path at high and low quality and under memory pressure, and through a
## companion, without script errors; its own signature owns the show (no shared class art,
## flights, links or contacts under it), every root keeps the layer cap and the budget, the
## art never touches the skill's data, a companion's cast stays lighter than the hero's,
## every root is freed after the cast, the budget returns to its baseline, and the caster
## dying in the wind-up or the aftermath clears the set piece at once.
const CLASSES := [&"summoner", &"darklord", &"bard"]
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
	Game.new_profile(cls, "Mystic QA")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.look = {"gender": 0}
	Game.profile.party = []
	Game.profile.hp = 100000
	Game.profile.mp = 100000
	if Game.profile.get("flags") is Dictionary:
		Game.profile.flags["raven_attack"] = 0


func skills() -> Array:
	var out: Array = []
	for cls in CLASSES:
		for skill in ClassData.pool(cls):
			if not skill.has("star") and int(skill.level) >= 60 and int(skill.level) <= 100:
				out.append([cls, skill])
	return out


func _ready() -> void:
	Game.set_process(false)
	InputSetup.ensure_defaults()
	GameSettings.load_settings()
	GameSettings.quality = 2
	GameSettings.ult_cutin = false
	ZoneData.ensure()
	_hooks()
	for mode in [[2, 0], [0, 0], [1, 2]]:
		GameSettings.quality = int(mode[0])
		MemoryGuard.force(int(mode[1]), get_tree())
		for entry in skills():
			await _cast(entry[0], entry[1], int(mode[0]), int(mode[1]))
	MemoryGuard.force(-1, get_tree())
	GameSettings.quality = 2
	for entry in skills():
		await _companion(entry[0], entry[1])
	for id in ["alpha_wolves", "world_tree", "dark_comet", "thunder_lord", "imperial_judgment", "grand_finale", "eternal_echo"]:
		for entry in skills():
			if String(entry[1].id) == id:
				await _death(entry[0], entry[1], true)
				await _death(entry[0], entry[1], false)
	Game.has_profile = false
	print("SKILL ART MYSTIC: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(failures)


## All 33 skills have their own signature script and own their show; kits are never skills.
func _hooks() -> void:
	check(skills().size() == 33, "33 regular skills from Lv.60 (%d)" % skills().size())
	check(SkillSignature.script_for("_mystic") == null, "a kit is never a skill's own art")
	for entry in skills():
		var skill: Dictionary = entry[1]
		var id := String(skill.id)
		var own := SkillSignature.script_for(id)
		check(own != null and own.has_method("anticipate") and own.has_method("play"), "%s has its own signature art" % id)
		check(SkillSignature.owns(skill) and GodSkillArt.owns(skill), "%s owns its show" % id)
		var shape := String(skill.shape)
		if shape == "chain":
			check(own.has_method("link") and own.has_method("contact"), "%s draws its own links and hits" % id)
		if (shape == "fan" or shape == "single") and bool(skill.get("projectile", false)):
			check(own.has_method("flight") and own.has_method("contact"), "%s flies its own carriers" % id)


func _field(cls: StringName) -> Array:
	profile(cls)
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	var targets: Array = []
	for at in [Vector3(0, 0, 2.6), Vector3(1.8, 0, 4.2), Vector3(-1.8, 0, 4.0)]:
		var target := Target.new()
		target.setup(&"forest_orc", 100, at, hero)
		target.position = at
		field.add_child(target)
		target.set_physics_process(false)
		target.set_process(false)
		target.hp = 100000000
		target.max_hp = target.hp
		targets.append(target)
	hero.target = targets[0]
	return [field, hero, targets]


## Whether [param node] is a shared system's art for [param id] (anything of the cast's
## that is not this signature's own roots, its watch or the creatures themselves).
func _foreign(node: Node, id: String) -> bool:
	var label := String(node.name)
	# A Dark Lord's own raven pecks on its own (DarkRaven): not the skill's art.
	if label.begins_with("LordArt_Raven"):
		return false
	if node is SculptureArt:
		return true
	if node is StarSkillArt or node is Summon or label.begins_with("SkillWatch_"):
		return false
	return label.contains(id) or label == "CreatureArrival"


func _watch(field: Node3D, id: String, quality: int, seconds: float, stats: Dictionary) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0 / Engine.time_scale)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		if int(VfxBudget.counters().decorations) > VfxBudget.decoration_limit() + VfxBudget.hero_decoration_room():
			stats.over_budget += 1
		var live := 0
		var layers := 0
		for node in field.get_children():
			if _foreign(node, id):
				stats.foreign += 1
				if stats.foreign == 1:
					printerr("  foreign: ", node.name, " ", node.get_class())
			if node is StarSkillArt and String(node.name).contains(id):
				var root := node as StarSkillArt
				if root.layers.size() > [2, 4, 6][quality]:
					stats.over_cap += 1
				if not root.layers.is_empty():
					stats.roots[root.get_instance_id()] = true
					live += 1
					layers += root.layers.size()
		stats.live = maxi(int(stats.live), live)
		stats.layers = maxi(int(stats.layers), layers)


func _left(field: Node3D, id: String) -> int:
	var left := 0
	for node in field.get_children():
		if (node is StarSkillArt and String(node.name).contains(id)) or String(node.name).begins_with("SkillWatch_" + id):
			left += 1
			printerr("  left: ", node.name)
	return left


func _cast(cls: StringName, skill: Dictionary, quality: int, pressure: int) -> void:
	var id := String(skill.id)
	var tag := "%s q%d p%d" % [id, quality, pressure]
	await get_tree().process_frame
	var base := VfxBudget.counters()
	var parts := _field(cls)
	var field: Node3D = parts[0]
	var hero: Hero = parts[1]
	var targets: Array = parts[2]
	await get_tree().process_frame
	var snapshot: Dictionary = skill.duplicate(true)
	var stats := {"over_budget": 0, "over_cap": 0, "foreign": 0, "roots": {}, "live": 0, "layers": 0}
	Engine.time_scale = 3.0
	hero._cast(skill)
	await _watch(field, id, quality, float(skill.hit_delay) + 1.2, stats)
	Engine.time_scale = 1.0
	check(not stats.roots.is_empty(), "%s draws its own signature roots" % tag)
	check(stats.foreign == 0, "%s: no shared class art, flights, links or contacts under it (%d)" % [tag, stats.foreign])
	check(stats.over_cap == 0, "%s every root within the layer cap" % tag)
	check(stats.over_budget == 0, "%s decorations stay within the budget" % tag)
	check(skill == snapshot, "%s art leaves the combat data untouched" % tag)
	var shape := String(skill.shape)
	if shape in ["single", "fan", "chain", "burst", "blast"]:
		var hits := 0
		for t in targets:
			hits += (t as Target).contacts
		check(hits > 0, "%s still lands its hits (%d)" % [tag, hits])
	if shape == "summon":
		check(field.get_children().any(func(n): return n is Summon), "%s its creatures are called" % tag)
	Engine.time_scale = 3.0
	await get_tree().create_timer(3.2).timeout
	Engine.time_scale = 1.0
	check(_left(field, id) == 0, "%s roots are freed after the cast" % tag)
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame
	check(VfxBudget.counters() == base, "%s the budget returns to its baseline %s -> %s" % [tag, base, VfxBudget.counters()])


## A companion casts the same skill: drawn by the same signature, lighter than the hero's.
func _companion(cls: StringName, skill: Dictionary) -> void:
	var id := String(skill.id)
	var tag := "%s companion" % id
	await get_tree().process_frame
	var base := VfxBudget.counters()
	var parts := _field(cls)
	var field: Node3D = parts[0]
	var hero: Hero = parts[1]
	var targets: Array = parts[2]
	var buddy := Companion.new()
	buddy.setup({"class": String(cls), "name": "Ally", "level": 100, "exp": 0, "gender": 0}, 0, hero, field)
	field.add_child(buddy)
	buddy.set_physics_process(false)
	buddy.global_position = Vector3(1.0, 0, -0.5)
	buddy.target = targets[0]
	buddy.mp = 100000
	await get_tree().process_frame
	var stats := {"over_budget": 0, "over_cap": 0, "foreign": 0, "roots": {}, "live": 0, "layers": 0}
	Engine.time_scale = 3.0
	buddy._cast(skill)
	await _watch(field, id, 2, float(skill.hit_delay) + 1.2, stats)
	Engine.time_scale = 1.0
	check(not stats.roots.is_empty(), "%s draws the signature" % tag)
	check(stats.foreign == 0, "%s: no shared art under it (%d)" % [tag, stats.foreign])
	check(int(stats.live) <= 4 and int(stats.layers) <= 20, "%s stays light (%d roots, %d layers at once)" % [tag, stats.live, stats.layers])
	Engine.time_scale = 3.0
	await get_tree().create_timer(3.2).timeout
	Engine.time_scale = 1.0
	check(_left(field, id) == 0, "%s roots are freed after the cast" % tag)
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame
	check(VfxBudget.counters() == base, "%s the budget returns to its baseline %s -> %s" % [tag, base, VfxBudget.counters()])


## The hero dies in the wind-up ([param early]) or just after the release: the set piece
## clears at once (StarSkillArt.CLOSE) instead of playing on over nobody's fight.
func _death(cls: StringName, skill: Dictionary, early: bool) -> void:
	var id := String(skill.id)
	var tag := "%s dies %s" % [id, "in the wind-up" if early else "after the release"]
	await get_tree().process_frame
	var base := VfxBudget.counters()
	var parts := _field(cls)
	var field: Node3D = parts[0]
	var hero: Hero = parts[1]
	await get_tree().process_frame
	hero._cast(skill)
	var delay := float(skill.hit_delay) * (1.0 - hero._haste())
	await get_tree().create_timer(delay * 0.4 if early else delay + 0.12).timeout
	var drawn := 0
	for node in field.get_children():
		if node is StarSkillArt and String(node.name).contains(id):
			drawn += 1
	check(drawn > 0, "%s: drawn before the death" % tag)
	hero._die()
	await get_tree().create_timer(0.45).timeout
	var left := 0
	for node in field.get_children():
		if node is StarSkillArt and String(node.name).contains(id) and not node.is_queued_for_deletion():
			left += 1
			printerr("  still standing: ", node.name)
	check(left == 0, "%s: the set piece clears at once (%d left)" % [tag, left])
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame
	check(VfxBudget.counters() == base, "%s the budget returns to its baseline" % tag)
