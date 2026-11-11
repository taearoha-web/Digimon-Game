extends Node3D
## The arcane classes' star signatures (Summoner, Dark Lord, Bard; 50..200 stars,
## combat/star_art via StarSignature): every skill casts on a real field at high and low
## quality and under memory pressure without script errors, its own signature owns the
## show (no generic class layers under it), every root keeps the layer cap and the
## budget, the contacts are the plan's own (art never changes a hit), the summons' legend
## skills and Poseidon's farewell are drawn by the same hand, and nothing is left behind.
var checks := 0
var failures := 0
const CLASSES := [&"summoner", &"darklord", &"bard"]

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
	Game.new_profile(cls, "Arcane Star QA")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.paragon = {"level": 200, "points": 200, "spent": 0, "exp": 0, "alloc": {}}
	Game.profile.look = {"gender": 0}
	Game.profile.party = []
	Game.profile.equip = {}
	for slot in ItemData.EQUIP_SLOTS:
		Game.profile.equip[slot] = StarWingData.item(String(cls), Game.rng) if slot == "wings" else StarProgression.item(cls, 200, slot, Game.rng)
	Game.profile.hp = 100000
	Game.profile.mp = 100000
	# The Dark Lord's raven would add its own strikes to the counted contacts.
	if Game.profile.get("flags") is Dictionary:
		Game.profile.flags["raven_attack"] = 0


func skills() -> Array:
	var out: Array = []
	for cls in CLASSES:
		var pool := StarSkillData.pool(cls)
		for i in 4:
			out.append([cls, ClassData.find_skill(cls, String(pool[i].id))])
	return out


func _ready() -> void:
	Game.set_process(false)
	InputSetup.ensure_defaults()
	GameSettings.load_settings()
	GameSettings.quality = 2
	ZoneData.ensure()
	_hooks()
	for mode in [[2, 0], [0, 0], [1, 2]]:
		GameSettings.quality = int(mode[0])
		MemoryGuard.force(int(mode[1]), get_tree())
		for entry in skills():
			await _cast(entry[0], entry[1], int(mode[0]), int(mode[1]))
	MemoryGuard.force(-1, get_tree())
	GameSettings.quality = 2
	await _legend_moves()
	Game.has_profile = false
	print("STAR ART ARCANE: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(failures)


## Each of the twelve skills has its own signature script and owns its show.
func _hooks() -> void:
	check(StarSignature.script_for("_kit_star") == null, "a kit is never a skill's own art")
	check(StarSignature.script_for("nope_not_a_skill") == null, "no script, no signature")
	for entry in skills():
		var skill: Dictionary = entry[1]
		var id := String(skill.get("id", ""))
		check(not skill.is_empty() and skill.has("star"), "%s is a star skill of %s" % [id, entry[0]])
		var own := StarSignature.script_for(id)
		check(own != null and own.has_method("telegraph") and own.has_method("strike"), "%s has its own signature art" % id)
		check(StarSignature.owns(skill) and GodSkillArt.owns(skill), "%s owns its show" % id)
	var god: Dictionary = StarSkillData.pool(&"darklord")[4]
	check(not StarSignature.owns(god), "the god skill keeps its own god art")
	check(planned(ClassData.find_skill(&"darklord", "raven_sovereign")) == 6, "the raven's six contacts")
	check(planned(ClassData.find_skill(&"bard", "cosmic_encore")) == 5, "the encore's five waves")


## How many contacts the cast's own plan (StarSkillSequence) lands.
func planned(skill: Dictionary) -> int:
	var seq := StarSkillSequence.new()
	seq.skill = skill
	seq._plan()
	var n := 0
	for event in seq.events:
		if event.has("count") and not bool(event.get("launch", false)):
			n += 1
	seq.free()
	return n


func _field(cls: StringName) -> Array:
	profile(cls)
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	var target := Target.new()
	target.setup(&"dawn_stag", 100, Vector3(0, 0, 4), hero)
	target.position = Vector3(0, 0, 4)
	field.add_child(target)
	target.set_physics_process(false)
	target.hp = 100000000
	target.max_hp = target.hp
	hero.target = target
	return [field, hero, target]


func _cast(cls: StringName, skill: Dictionary, quality: int, pressure: int) -> void:
	var id := String(skill.id)
	var tag := "%s q%d p%d" % [id, quality, pressure]
	await get_tree().process_frame
	var base := VfxBudget.counters()
	var parts := _field(cls)
	var field: Node3D = parts[0]
	var hero: Hero = parts[1]
	var target: Target = parts[2]
	await get_tree().process_frame
	var snapshot: Dictionary = skill.duplicate(true)
	hero._cast(skill)
	var seq := hero.get_node_or_null("StarCast_" + id) as StarSkillSequence
	check(seq != null, "%s casts" % tag)
	if seq == null:
		field.queue_free()
		await field.tree_exited
		return
	var beats := planned(skill)
	var own_roots := 0
	var class_layers := 0
	var over_cap := 0
	var over_budget := 0
	var frames := 0
	Engine.time_scale = 3.0
	while is_instance_valid(seq) and not seq.is_queued_for_deletion() and frames < 3000:
		await get_tree().process_frame
		frames += 1
		if int(VfxBudget.counters().decorations) > VfxBudget.decoration_limit() + VfxBudget.hero_decoration_room():
			over_budget += 1
		for node in field.get_children():
			if node is StarSkillArt:
				var root := node as StarSkillArt
				if root.layers.size() > [2, 4, 6][quality]:
					over_cap += 1
				if String(root.name).contains(id) and not root.layers.is_empty():
					own_roots += 1
			# The generic class art (Lord / Bard / Caster sculptures) stays out of an owned show.
			if node is SculptureArt and String(node.name).contains(id):
				class_layers += 1
	Engine.time_scale = 1.0
	check(frames < 3000, "%s cast ends" % tag)
	check(own_roots > 0, "%s draws its own signature roots" % tag)
	check(class_layers == 0, "%s: no generic class art under its own signature (%d)" % [tag, class_layers])
	check(over_cap == 0, "%s every root within the layer cap" % tag)
	check(over_budget == 0, "%s decorations stay within the budget" % tag)
	# (A summon's creature fights on its own: only the attacks' contacts are the plan's.)
	if String(skill.shape) != "summon":
		var attack := String(skill.shape) != "self"
		check(target.contacts == (beats if attack else 0), "%s contacts as planned (%d of %d)" % [tag, target.contacts, beats])
	check(skill == snapshot, "%s art leaves the combat data untouched" % tag)
	if String(skill.shape) == "summon":
		var summons := field.get_children().filter(func(n): return n is Summon)
		check(summons.size() == 1, "%s its creature is called" % tag)
	# The aftermath plays out, then every root of the cast is gone.
	Engine.time_scale = 3.0
	await get_tree().create_timer(3.0 * 3.0).timeout
	Engine.time_scale = 1.0
	var left := 0
	for node in field.get_children():
		if node is StarSkillArt and String(node.name).contains(id):
			left += 1
			printerr("  left: ", node.name, " age ", (node as StarSkillArt).age, " life ", (node as StarSkillArt).lifetime)
	check(left == 0, "%s roots are freed after the cast (%d left)" % [tag, left])
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame
	check(VfxBudget.counters() == base, "%s the budget returns to its baseline %s -> %s" % [tag, base, VfxBudget.counters()])


## The Wind Monkey King's and Poseidon's own skills and Poseidon's farewell wave.
func _legend_moves() -> void:
	for id in ["moonwolf_pact", "eclipse_sovereign"]:
		for quality in [2, 0]:
			GameSettings.quality = quality
			await get_tree().process_frame
			var base := VfxBudget.counters()
			var parts := _field(&"summoner")
			var field: Node3D = parts[0]
			var hero: Hero = parts[1]
			var target: Target = parts[2]
			await get_tree().process_frame
			var skill := ClassData.find_skill(&"summoner", id)
			hero._summon(skill, 1.0)
			var king: Summon = null
			for node in field.get_children():
				if node is Summon: king = node
			check(king != null, "%s q%d creature called" % [id, quality])
			if king == null:
				field.queue_free()
				await field.tree_exited
				continue
			king.set_process(false)
			for move in LegendMoves.moves(king._kind_id):
				var before := field.get_child_count()
				LegendMoves.windup_vfx(field, String(move.style), target.global_position, 5.0, float(move.impact), king)
				LegendMoves.impact_vfx(field, String(move.style), target.global_position, 5.0)
				var drawn := 0
				for node in field.get_children():
					if node is StarSkillArt and String(node.name).contains(id) and not (node as StarSkillArt).layers.is_empty():
						drawn += 1
				check(drawn >= 2 and field.get_child_count() > before, "%s q%d %s: wind-up and landing drawn by the signature" % [id, quality, move.style])
			if id == "eclipse_sovereign":
				king._star_wave(3.0, 7.5, 2)
				var wave := false
				for node in field.get_children():
					if node is StarSkillArt and String(node.name).begins_with("StarContact_" + id) and not (node as StarSkillArt).layers.is_empty():
						wave = true
				check(wave, "q%d Poseidon's farewell wave drawn by the signature" % quality)
			Engine.time_scale = 3.0
			await get_tree().create_timer(3.0 * 3.0).timeout
			Engine.time_scale = 1.0
			var left := 0
			for node in field.get_children():
				if node is StarSkillArt and String(node.name).contains(id):
					left += 1
			check(left == 0, "%s q%d legend move roots freed (%d left)" % [id, quality, left])
			field.queue_free()
			await field.tree_exited
			await get_tree().process_frame
			check(VfxBudget.counters() == base, "%s q%d legend moves: the budget returns to its baseline" % [id, quality])
	GameSettings.quality = 2
