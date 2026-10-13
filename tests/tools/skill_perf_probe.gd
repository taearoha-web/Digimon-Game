extends Node3D
## Frame cost of real Hero casts on a crowded field: a Lv.100 hero casts its
## skills back to back (cooldowns reset) into a pack of dummies for a few
## seconds, with ClassFlourish on and then off. Prints per-frame CPU time
## (mean / p95 / max), frames over 33 ms, and node / object counts.
##   godot --headless --path . res://tests/tools/skill_perf_probe.tscn -- [class] [ids,comma,separated]
class Dummy extends Mob:
	func knock_back(_from: Vector3, _strength := 2.5) -> void:
		pass

var frame_us: Array[int] = []
var _last := 0
var _recording := false
var peak_nodes := 0
var peak_objects := 0


func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	GameSettings.quality = 1
	GameSettings.combat_hitstop = false
	var args := OS.get_cmdline_user_args()
	var cls := StringName(args[0]) if args.size() > 0 else &"lancer"
	var ids: Array = Array(args[1].split(",")) if args.size() > 1 else ["dragon_tooth", "vanguard_strike", "sky_pierce", "dragon_lance", "gungnir", "ragnarok_lance"]
	for flourish in [true, false]:
		ClassFlourish.enabled = flourish
		await _run(cls, ids, flourish)
	get_tree().quit()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _recording and _last > 0:
		frame_us.append(now - _last)
		peak_nodes = maxi(peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		peak_objects = maxi(peak_objects, int(Performance.get_monitor(Performance.OBJECT_COUNT)))
	_last = now


func _run(cls: StringName, ids: Array, flourish: bool) -> void:
	Game.new_profile(cls, "Perf")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.hp = 10000000
	Game.profile.mp = 10000000
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	var mobs: Array[Mob] = []
	for i in 14:
		var mob := Dummy.new()
		mob.setup(&"forest_orc", 100, Vector3.ZERO, hero)
		field.add_child(mob)
		mob.position = Vector3(1.5 + float(i % 7) * 1.6, 0, -1.5 + float(i / 7) * 3.0)
		mob.hp = 1000000000
		mob.max_hp = 1000000000
		mob.set_physics_process(false)
		mobs.append(mob)
	hero.target = mobs[0]
	hero.set_facing(PI * 0.5)
	await get_tree().create_timer(0.3).timeout
	var skills: Array[Dictionary] = []
	for id in ids:
		var skill := ClassData.find_skill(cls, String(id))
		if not skill.is_empty():
			Game.profile.skills[String(id)] = 5
			skills.append(skill)
	frame_us.clear()
	peak_nodes = 0
	peak_objects = 0
	_last = 0
	_recording = true
	var start := Time.get_ticks_msec()
	var i := 0
	while i < 24:
		hero.cooldowns.clear()
		hero._cast_until = 0
		Game.profile.mp = 10000000
		var before := frame_us.size()
		hero._cast(skills[i % skills.size()])
		await get_tree().create_timer(0.9).timeout
		var worst := 0
		for k in range(before, frame_us.size()):
			worst = maxi(worst, frame_us[k])
		if worst > 33000:
			print("  spike %.1fms after cast #%d %s" % [worst / 1000.0, i, skills[i % skills.size()].id])
		i += 1
	_recording = false
	var sorted := frame_us.duplicate()
	sorted.sort()
	var total := 0
	var over := 0
	for us in sorted:
		total += us
		if us > 33000:
			over += 1
	print("PERF flourish=%s casts=%d frames=%d mean=%.2fms p95=%.2fms max=%.2fms over33=%d peak_nodes=%d peak_objects=%d vfx=%s" % [flourish, i, sorted.size(),
		float(total) / maxf(1.0, sorted.size()) / 1000.0, float(sorted[int(sorted.size() * 0.95)]) / 1000.0, float(sorted[-1]) / 1000.0, over,
		peak_nodes, peak_objects, VfxBudget.counters()])
	field.queue_free()
	await field.tree_exited
	await get_tree().create_timer(2.0).timeout
