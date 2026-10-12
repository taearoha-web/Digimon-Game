extends Node3D
## Repeated casts must finish naturally, without deleting their scene to hide leaks.
var failures: Array[String] = []
var snapshots: Array[Dictionary] = []
var casts := 0
var field: Node3D
var caster: Node3D

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func _ready() -> void:
	GameSettings.load_settings()
	GameSettings.quality = 2
	field = Node3D.new()
	add_child(field)
	caster = Node3D.new()
	field.add_child(caster)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(13, 17, 17)
	camera.look_at(Vector3(0, 2, 0))
	VfxArt.warm_up()
	VfxKit.warm_shaders(field, Vector3.ZERO)
	Engine.time_scale = 12.0
	await get_tree().create_timer(10.0).timeout
	var skills: Array[Dictionary] = []
	for family in [&"vagabond", &"warrior", &"archer", &"mage", &"priest", &"summoner", &"lancer"]:
		for skill in ClassData.pool(family):
			skills.append(skill)
	for cycle in 4:
		for start in range(0, skills.size(), 6):
			for i in range(start, mini(start + 6, skills.size())):
				var skill := skills[i]
				SkillShow.anticipate(field, skill, Vector3.ZERO, float(skill.hit_delay))
				SkillShow.play(field, skill, Vector3(3, 0, 0), Vector3.ZERO)
				match String(skill.id):
					"armageddon": ArmageddonSequence.launch(field, caster, Vector3.ZERO, float(skill.radius), float(skill.mult), _meteor_hit)
					"thunder_storm": ThunderStormSequence.launch(field, caster, Vector3.ZERO, float(skill.radius), _targets, _single_hit)
					"judgment_ray": JudgmentRaySequence.launch(field, caster, caster, 1.05, _single_hit)
				BattleVfx.play_impact(field, skill.vfx, Vector3(3, 1, 0))
				SkillTableau.contact(field, skill, Vector3(3, 0, 0))
				casts += 1
			await get_tree().create_timer(10.0).timeout
			await get_tree().process_frame
			check(field.get_child_count() == 1, "temporary effects left after batch %d cycle %d: %d" % [start, cycle, field.get_child_count() - 1])
			check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "effect reservations remain after expiry")
		var sample := {"cycle": cycle, "casts": casts,
			"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
			"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
			"static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
			"video_bytes": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))}
		snapshots.append(sample)
		print("SESSION MEMORY: ", JSON.stringify(sample))
	check(int(snapshots.back().resources) <= int(snapshots[0].resources) + 8, "resources grow after catalogue warmup")
	check(int(snapshots.back().objects) <= int(snapshots[0].objects) + 16, "objects grow after catalogue warmup")
	check(int(snapshots.back().orphans) == int(snapshots[0].orphans), "orphan nodes grow during repeated casts")
	Engine.time_scale = 1.0
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var report := FileAccess.open(args[0], FileAccess.WRITE)
		report.store_string(JSON.stringify({"casts": casts, "snapshots": snapshots, "failures": failures}, "\t"))
	print("SESSION MEMORY: %s | %d casts; %d failures" % ["PASS" if failures.is_empty() else "FAIL", casts, failures.size()])
	get_tree().quit(failures.size())

func _targets() -> Array:
	return []

func _single_hit(_victim: Node) -> void:
	pass

func _meteor_hit(_index: int, _at: Vector3, _radius: float, _mult: float) -> void:
	pass
