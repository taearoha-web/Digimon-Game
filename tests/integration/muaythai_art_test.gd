extends Node3D
## The Muay Thai fighter's own skill art (MuayThaiArt): every one of its 22 skills gets
## its bespoke layered composition through the real hooks (SkillShow, SkillTableau),
## the compositions grow along each line (base < Lv.60 evolution < top stage), the
## layers stay inside the phone budget (layer_cap by quality and memory pressure,
## fewer tiers under pressure), the art never touches the skill's combat data, the
## mesh library is finite, and 150 casts leave no nodes or reservations behind.
##   godot --headless --path . res://tests/integration/muaythai_art_test.tscn

const MT := &"muaythai"
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
	GameSettings.quality = 2
	MemoryGuard.pressure = 0
	MuayThaiArt.warm_geometry()
	var kinds := MuayThaiArt.KINDS.split(" ").size()
	check(MuayThaiArt._meshes.size() == kinds, "the shared muay thai geometry is finite and warm (%d)" % MuayThaiArt._meshes.size())
	var skills: Array[Dictionary] = []
	for line in load("res://data/skill_lines/muaythai.gd").LINES:
		for id in line:
			var skill := ClassData.find_skill(MT, String(id))
			check(not skill.is_empty(), "%s exists" % id)
			if not skill.is_empty():
				skills.append(skill)
	check(skills.size() == 22, "all 22 active skills (%d)" % skills.size())
	for skill in skills:
		check(MuayThaiArt.owns(skill), "%s gets the fighter's own art" % skill.id)
		check(MuayThaiArt.TIER.has(String(skill.id)), "%s has a stage in its line's growth" % skill.id)
	check(not MuayThaiArt.handles(ClassData.find_skill(&"warrior", "raving")) and not MuayThaiArt.handles({}), "other classes keep their own art")
	# --- each skill: a bespoke composition through the real SkillShow hook ------------
	var drawn := {}
	for skill in skills:
		var snapshot: Dictionary = skill.duplicate(true)
		var field := await _field()
		MuayThaiArt.last = {"id": "", "asked": 0, "drawn": 0}
		SkillShow.play(field, skill, Vector3(0, 0, 3), Vector3.ZERO)
		var roots := _roots(field)
		check(roots.size() >= 1, "%s: SkillShow.play builds its MuayThaiArt composition" % skill.id)
		check(String(MuayThaiArt.last.id) == String(skill.id), "%s: its own arm of the compositions ran" % skill.id)
		var n := int(MuayThaiArt.last.drawn)
		drawn[String(skill.id)] = n
		check(n >= 4, "%s draws a layered composition at high quality (%d)" % [skill.id, n])
		check(n <= MuayThaiArt.layer_cap(), "%s keeps within the layer cap (%d > %d)" % [skill.id, n, MuayThaiArt.layer_cap()])
		check(_spectacle(field) == 0, "%s: the generic silhouette stays out of its show" % skill.id)
		check(skill == snapshot, "the art leaves %s's combat data untouched" % skill.id)
		await _free(field)
	# The compositions grow along each line: the top stage asks for more than the base.
	for line in load("res://data/skill_lines/muaythai.gd").LINES:
		var first := await _asked(ClassData.find_skill(MT, String(line[0])))
		var top := await _asked(ClassData.find_skill(MT, String(line[line.size() - 1])))
		check(top > first, "%s grows into %s (%d -> %d layers)" % [line[0], line[line.size() - 1], first, top])
	for id in ["sun_fist", "thunder_elbow", "mantra_storm", "earth_kick", "fire_dragon_circle", "sacred_mongkhon", "muay_king"]:
		check(int(drawn[id]) >= 12, "%s is a grand composition at high quality (%d)" % [id, int(drawn[id])])
	# --- wind-up and contact hooks ------------------------------------------------------
	var field := await _field()
	SkillShow.anticipate(field, ClassData.find_skill(MT, "muay_king"), Vector3.ZERO, 0.5, Vector3(0, 0, 5))
	var sky := 0
	for node in field.get_children():
		if node is MuayThaiArt and String(node.name).begins_with("MuayArt_Sky"):
			sky += 1
	check(_roots(field).size() >= 2 and sky == 1, "ราชันมวยไทย's rings and dragon fall from the sky in its wind-up")
	MuayThaiArt._last_contact.clear()
	SkillTableau.contact(field, ClassData.find_skill(MT, "flame_hook"), Vector3(0, 1, 3))
	var hit := false
	for node in field.get_children():
		if node is MuayThaiArt and String(node.name).begins_with("MuayArt_Hit"):
			hit = (node as MuayThaiArt).layers.size() >= 2
	check(hit, "a landed hit draws the fighter's punch ring, spark and fire")
	await _free(field)
	# --- the phone budget: fewer layers under pressure and on low quality --------------
	var totals := {}
	for mode in [["high", 2, 0], ["pressure1", 2, 1], ["pressure2", 2, 2], ["low", 0, 0]]:
		GameSettings.quality = int(mode[1])
		MemoryGuard.pressure = int(mode[2])
		var total := 0
		for skill in skills:
			var f := await _field()
			MuayThaiArt.play(f, skill, Vector3(0, 0, 3), Vector3.ZERO)
			var n := int(MuayThaiArt.last.drawn)
			total += n
			check(n >= 1, "%s keeps a core under %s" % [skill.id, mode[0]])
			check(n <= MuayThaiArt.layer_cap(), "%s within the %s cap (%d)" % [skill.id, mode[0], n])
			if mode[0] == "low" or mode[0] == "pressure2":
				check(n <= 8, "%s keeps to a phone's few layers under %s (%d)" % [skill.id, mode[0], n])
			await _free(f)
		totals[mode[0]] = total
		print("MUAY THAI ART %s: %d layers over %d skills" % [mode[0], total, skills.size()])
	check(int(totals.pressure1) < int(totals.high), "pressure 1 draws fewer layers in all")
	check(int(totals.pressure2) < int(totals.pressure1), "pressure 2 draws fewer still")
	check(int(totals.low) < int(totals.pressure1), "low quality draws the core only")
	MemoryGuard.pressure = 0
	GameSettings.quality = 2
	# --- 150 casts: no node growth, every reservation released ------------------------
	var baseline := -1
	for i in 150:
		var skill: Dictionary = skills[(i * 7) % skills.size()]
		var f := await _field()
		SkillShow.anticipate(f, skill, Vector3.ZERO, 0.5, Vector3(0, 0, 3))
		SkillShow.play(f, skill, Vector3(0, 0, 3), Vector3.ZERO)
		MuayThaiArt._last_contact.clear()
		MuayThaiArt.contact(f, skill, Vector3(0, 1, 3))
		for node in f.get_children():
			if node is SculptureArt:
				(node as SculptureArt)._process(0.5)
		await _free(f)
		if i == 29:
			await get_tree().process_frame
			baseline = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	await get_tree().process_frame
	var final_count := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	print("MUAY THAI ART objects %d -> %d" % [baseline, final_count])
	check(final_count <= baseline + 12, "no node growth over 150 casts: %d -> %d" % [baseline, final_count])
	await get_tree().process_frame
	check(int(VfxBudget.counters().decorations) == 0, "all decoration reservations released: %s" % VfxBudget.counters())
	check(MuayThaiArt._meshes.size() == kinds, "no geometry growth")
	# --- expiry: the roots free themselves --------------------------------------------
	var last_field := await _field()
	MuayThaiArt.play(last_field, ClassData.find_skill(MT, "muay_king"), Vector3(0, 0, 4), Vector3.ZERO)
	var art := _roots(last_field)[0] as MuayThaiArt if not _roots(last_field).is_empty() else null
	check(art != null, "a release builds one root")
	if art:
		art.set_process(false)
		art._process(6.0)
		check(art.is_queued_for_deletion(), "the root expires on its own clock")
	await _free(last_field)
	print("MUAY THAI ART TEST: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _field() -> Node3D:
	var field := Node3D.new()
	add_child(field)
	SkillShow._recent_shows.clear()
	SkillLayers.reset_crowd()
	await get_tree().process_frame
	return field


func _free(field: Node3D) -> void:
	field.queue_free()
	await field.tree_exited


func _roots(field: Node3D) -> Array:
	var out: Array = []
	for node in field.get_children():
		if node is MuayThaiArt:
			out.append(node)
	return out


## Anything on the field besides the fighter's own art (the generic silhouette and
## finish its show no longer draws; the shared particle stack lives in SkillLayerPool).
func _spectacle(field: Node3D) -> int:
	var n := 0
	for node in field.get_children():
		if not node is MuayThaiArt:
			print("  other art on the field: ", node.name)
			n += 1
	return n


## Layers a composition asks for (before the cap), at high quality.
func _asked(skill: Dictionary) -> int:
	var field := Node3D.new()
	add_child(field)
	SkillShow._recent_shows.clear()
	MuayThaiArt.play(field, skill, Vector3(0, 0, 3), Vector3.ZERO)
	var n := int(MuayThaiArt.last.asked)
	await _free(field)
	return n
