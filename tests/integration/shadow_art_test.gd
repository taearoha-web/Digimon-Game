extends Node3D
## The class signatures of the Archer, the Assassin and the Dark Lord
## (ClassSignature over SignatureKit): every skill of the three lines and their
## star skills builds its class layers at high quality, fewer under memory
## pressure and at low quality (the core still draws), and 150 casts leave no
## node growth behind (drivers, sheets and emitters go back to their pools).
## godot --headless --path . res://tests/integration/shadow_art_test.tscn
const CLASSES := [&"archer", &"assassin", &"darklord"]
var failures: Array[String] = []
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func _cast(field: Node3D, skill: Dictionary) -> void:
	var origin := Vector3.ZERO
	var center := Vector3(5, 0, 0)
	if skill.has("star"):
		ClassSignature.anticipate(field, skill, origin, center, 0.6)
		for index in 2:
			ClassSignature.star_beat(field, skill, center, index, origin)
		ClassSignature.flight(field, skill, origin + Vector3.UP, center + Vector3.UP, 0.3)
		return
	ClassSignature.anticipate(field, skill, origin, center, 0.4)
	ClassSignature.play(field, skill, center, origin, 0.3 if String(skill.get("special", "")) == "rain" else 0.0)
	ClassSignature.flight(field, skill, origin + Vector3.UP, center + Vector3.UP, 0.3)
	ClassSignature.contact(field, skill, center + Vector3.UP, true)
	ClassSignature._last_contact.clear()
	ClassSignature._chain.clear()


## Layers one skill builds at the given quality / memory pressure.
func _layers(skill: Dictionary, quality: int, pressure: int) -> int:
	GameSettings.quality = quality
	MemoryGuard.pressure = pressure
	var field := Node3D.new()
	add_child(field)
	var before := SignatureKit.layers_built
	_cast(field, skill)
	var built := SignatureKit.layers_built - before
	field.free()
	VfxBudget._decorations = 0
	VfxBudget._particles = 0
	return built


func _ready() -> void:
	GameSettings.load_settings()
	SignatureKit.warm()
	var totals := {}
	for cls in CLASSES:
		var high_sum := 0
		var mid_sum := 0
		var core_sum := 0
		var low_sum := 0
		var skills := ClassData.pool(cls)
		check(skills.size() >= 29, "%s has its skills and star skills (%d)" % [cls, skills.size()])
		for skill in skills:
			check(ClassSignature.handles(skill), "%s %s is a signature skill" % [cls, skill.id])
			# A god skill with its own signature art (GodSkillArt.owns) draws every beat itself.
			if GodSkillArt.owns(skill):
				check(_layers(skill, 2, 0) == 0, "%s %s: the class layers stay out of its own god art" % [cls, skill.id])
				continue
			var high := _layers(skill, 2, 0)
			var mid := _layers(skill, 2, 1)
			var core := _layers(skill, 2, 2)
			var low := _layers(skill, 0, 0)
			check(high >= 4, "%s %s builds its class layers at high quality (%d)" % [cls, skill.id, high])
			check(mid <= high and core <= mid, "%s %s sheds layers under memory pressure (%d > %d > %d)" % [cls, skill.id, high, mid, core])
			check(low <= high and low > 0, "%s %s keeps only its core at low quality (%d of %d)" % [cls, skill.id, low, high])
			high_sum += high
			mid_sum += mid
			core_sum += core
			low_sum += low
		check(mid_sum < high_sum and core_sum < mid_sum, "%s: pressure 1 and 2 build fewer layers (%d, %d, %d)" % [cls, high_sum, mid_sum, core_sum])
		check(low_sum * 2 < high_sum, "%s: low quality builds well under half (%d of %d)" % [cls, low_sum, high_sum])
		totals[cls] = high_sum
	MemoryGuard.pressure = 0
	GameSettings.quality = 2
	# Families: nobody else's skills draw these layers.
	check(not ClassSignature.handles(ClassData.find_skill(&"mage", "fire_ball")) and not ClassSignature.handles({}), "other classes are left alone")
	# 150 casts in one field: no node growth, budgets returned.
	var field := Node3D.new()
	add_child(field)
	var all: Array = []
	for cls in CLASSES:
		all.append_array(ClassData.pool(cls))
	for i in 40:
		_cast(field, all[i % all.size()])
		await get_tree().create_timer(0.03).timeout
	await get_tree().create_timer(3.0).timeout
	var nodes_warm := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var children_warm := field.get_child_count()
	for i in 150:
		_cast(field, all[(i * 7) % all.size()])
		await get_tree().create_timer(0.03).timeout
	await get_tree().create_timer(3.0).timeout
	var nodes_after := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	print("nodes warm %d after 150 casts %d, field children %d -> %d, pooled %d" % [nodes_warm, nodes_after, children_warm, field.get_child_count(), SignatureKit.pooled()])
	check(nodes_after - nodes_warm <= 40, "150 casts do not grow the scene (%d -> %d nodes)" % [nodes_warm, nodes_after])
	check(field.get_child_count() <= children_warm + 2, "finished casts leave the field (%d -> %d children)" % [children_warm, field.get_child_count()])
	var counters := VfxBudget.counters()
	check(int(counters.decorations) <= 2 and int(counters.particles) <= 20, "the budgets are given back (%s)" % [counters])
	# A cancelled wind-up (new skill generation) is dropped at once.
	SignatureKit.release_pool()
	await get_tree().process_frame
	check(SignatureKit.pooled() == 0, "the pools empty on release (zone change)")
	field.queue_free()
	print("SHADOW ART: %d checks, %d failures, layers %s" % [checks, failures.size(), totals])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)
