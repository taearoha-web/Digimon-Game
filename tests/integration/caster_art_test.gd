extends Node3D
## The caster classes' signature art (CasterArt for the Mage, Priest and Summoner,
## BardSkillArt for the Bard, both on NaturalArt): every skill builds its class layers
## at high quality, fewer under memory pressure and on low quality, the art never
## touches the skill's combat data, and 150 casts leave no nodes or reservations behind.

const FAMILIES := [&"mage", &"priest", &"summoner", &"bard"]
## These run their own sequences (and dedicated tests); SkillShow skips them.
const SEQUENCES := ["armageddon", "thunder_storm", "judgment_ray"]
var failures := 0
var checks := 0


func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", why)


func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	BardSkillArt.warm_geometry()
	check(CasterArt._meshes.size() == CasterArt.KINDS.split(" ").size(), "the shared caster geometry is finite and warm")
	var skills: Array[Dictionary] = []
	for family in FAMILIES:
		for skill in ClassData.pool(family):
			if not String(skill.id) in SEQUENCES:
				skills.append(skill)
	check(skills.size() >= 100, "all four classes' skills selected (%d)" % skills.size())
	# --- tiers -------------------------------------------------------------------
	GameSettings.quality = 2
	MemoryGuard.pressure = 0
	check(NaturalArt.depth() == NaturalArt.TIER_DEBRIS and NaturalArt.count(8) == 8, "high quality draws every tier")
	MemoryGuard.pressure = 1
	check(NaturalArt.depth() == NaturalArt.TIER_MID and NaturalArt.count(8) == 4, "pressure 1 drops debris and halves the counts")
	MemoryGuard.pressure = 2
	check(NaturalArt.depth() == NaturalArt.TIER_CORE and NaturalArt.count(8) == 1, "pressure 2 keeps the core only")
	MemoryGuard.pressure = 0
	GameSettings.quality = 0
	check(NaturalArt.depth() == NaturalArt.TIER_CORE, "low quality keeps the core only")
	# --- every skill builds its layers; fewer under pressure / low quality ----------
	var totals := {}
	for mode in [["high", 2, 0], ["pressure1", 2, 1], ["pressure2", 2, 2], ["low", 0, 0]]:
		GameSettings.quality = int(mode[1])
		MemoryGuard.pressure = int(mode[2])
		var total := 0
		for skill in skills:
			var snapshot: Dictionary = skill.duplicate(true)
			var layers := await _cast(skill)
			total += layers
			if mode[0] == "high":
				check(layers >= 3, "%s builds its class layers at high quality (%d)" % [skill.id, layers])
				totals[String(skill.id)] = layers
			else:
				check(layers >= 1, "%s keeps a core under %s" % [skill.id, mode[0]])
				check(layers <= int(totals[String(skill.id)]), "%s draws no more under %s (%d > %d)" % [skill.id, mode[0], layers, int(totals[String(skill.id)])])
			check(skill == snapshot, "the art leaves %s's combat data untouched" % skill.id)
		totals[mode[0]] = total
		print("CASTER ART %s: %d layers over %d skills" % [mode[0], total, skills.size()])
	check(int(totals.pressure1) < int(totals.high), "pressure 1 draws fewer layers in all")
	check(int(totals.pressure2) < int(totals.pressure1), "pressure 2 draws fewer still")
	check(int(totals.low) < int(totals.pressure1), "low quality draws the core only")
	MemoryGuard.pressure = 0
	GameSettings.quality = 2
	# --- 150 casts: no node growth, every reservation released ------------------------
	var baseline := -1
	for i in 150:
		var skill: Dictionary = skills[(i * 7) % skills.size()]
		await _cast(skill, true)
		if i == 29:
			await get_tree().process_frame
			baseline = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	await get_tree().process_frame
	var final_count := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	print("CASTER ART objects %d -> %d" % [baseline, final_count])
	check(final_count <= baseline + 12, "no node growth over 150 casts: %d -> %d" % [baseline, final_count])
	check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "all visual reservations released: %s" % VfxBudget.counters())
	check(CasterArt._meshes.size() == CasterArt.KINDS.split(" ").size(), "no geometry growth")
	# --- expiry: the roots free themselves --------------------------------------------
	var field := Node3D.new()
	add_child(field)
	CasterArt.play(field, ClassData.find_skill(&"mage", "fire_ball"), Vector3(0, 0, 4), Vector3.ZERO)
	var art := field.get_child(0) as CasterArt
	check(art != null, "a release builds one root")
	if art:
		art.set_process(false)
		art._process(6.0)
		check(art.is_queued_for_deletion(), "the root expires on its own clock")
	field.queue_free()
	await field.tree_exited
	print("CASTER ART TEST: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


## Casts the skill's art on a fresh field (wind-up, release, one contact; star skills:
## their wind-up and two beats) and returns the caster layers it built. With
## [param run] the art plays to its end before the field is freed.
func _cast(skill: Dictionary, run := false) -> int:
	var field := Node3D.new()
	add_child(field)
	SkillShow._recent_shows.clear()
	var visual: HeroVisual = null
	var target := Vector3(0, 0, 4)
	if skill.has("star"):
		CasterArt.star_telegraph(field, skill, Vector3.ZERO, target, 0.6)
		BardSkillArt.anticipate(field, skill, Vector3.ZERO, target, 0.6)
		for index in 2:
			CasterArt.star(field, skill, target, index, Vector3.ZERO)
			BardSkillArt.star(field, skill, target, index, Vector3.ZERO)
	else:
		BardSkillArt.anticipate(field, skill, Vector3.ZERO, target, 0.5, visual)
		BardSkillArt.play(field, skill, target, Vector3.ZERO, 0.0)
		BardSkillArt._last_contact.clear()
		CasterArt._last_contact.clear()
		BardSkillArt.contact(field, skill, target + Vector3.UP)
		if String(skill.get("shape", "")) == "summon":
			CasterArt.summon_arrival(field, skill, Vector3(1, 0, 1), 1.0)
	var layers := 0
	for node in field.get_children():
		if node is NaturalArt:
			layers += (node as NaturalArt).layers.size()
	if run:
		for node in field.get_children():
			if node is SculptureArt:
				(node as SculptureArt)._process(0.5)
	field.queue_free()
	await field.tree_exited
	return layers
