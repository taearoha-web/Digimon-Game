extends Node3D
## Skill feel (SkillFeel, SkillWeight, UltCutIn, the camera's feel_*): weights derived
## for every class's skills (ultimates heaviest), the cut-in on the hero's own 200 / 300
## star casts only (never for AI casters, off with its setting, no slow motion in a
## duel), the clock given back, hit-stop and shake scaled and capped, heavy hits throw
## normal monsters (bosses and rivals only stagger) and stay inside the field, element
## flashes and numbers, the combo total, and ground marks capped and dropped under
## memory pressure.
## godot --headless --path . res://tests/integration/skill_feel_test.tscn

var checks := 0
var failures := 0


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", note)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.set_process(false)
	InputSetup.ensure_defaults()
	GameSettings.load_settings()
	GameSettings.quality = 2
	GameSettings.combat_hitstop = true
	GameSettings.ult_cutin = true
	GameSettings.screen_shake = true
	ZoneData.ensure()
	_weights()
	_elements()
	_scaling()
	await _camera_caps()
	await _cut_in()
	await _reactions()
	await _marks()
	_numbers_and_combo()
	_settings_saved()
	MemoryGuard.force(-1, get_tree())
	Engine.time_scale = 1.0
	GameSettings.quality = 2
	Game.has_profile = false
	# Shared resources held in statics go before the engine checks for leaks at exit.
	SkillFeel._mark_shader = null
	SkillFeel._mark_mesh = null
	var layer := UltCutIn.active()
	if layer:
		layer.queue_free()
	await get_tree().process_frame
	print("SKILL FEEL: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(failures)


func _damaging(skill: Dictionary) -> bool:
	return not String(skill.shape) in ["self", "summon"]


## Every class: weights in 0..1, the god skill heaviest, the 200-star skills above every
## class skill, late skills heavier than early ones on average, light ones exist.
func _weights() -> void:
	var lights := 0
	for cls in ClassData.IDS:
		var pool := ClassData.pool(cls)
		var god: Dictionary = {}
		var best_class := 0.0
		var early: Array[float] = []
		var late: Array[float] = []
		var two_hundred: Array[float] = []
		for skill in pool:
			var w := SkillWeight.weight(skill)
			check(w >= 0.0 and w <= 1.0 and is_finite(w), "%s %s weight in range (%.2f)" % [cls, skill.id, w])
			if int(skill.get("star", 0)) >= 300:
				god = skill
			elif int(skill.get("star", 0)) == 200:
				two_hundred.append(w)
			elif not skill.has("star") and _damaging(skill):
				best_class = maxf(best_class, w)
				if int(skill.level) < 40:
					early.append(w)
				elif int(skill.level) >= 80:
					late.append(w)
				if SkillWeight.tier(w) == SkillWeight.LIGHT:
					lights += 1
		check(not god.is_empty() and SkillWeight.tier_of(god) == SkillWeight.ULTIMATE, "%s god skill is an ultimate" % cls)
		for skill in pool:
			check(SkillWeight.weight(skill) <= SkillWeight.weight(god), "%s: %s not heavier than the god skill" % [cls, skill.id])
		for w in two_hundred:
			check(w > best_class and SkillWeight.tier(w) == SkillWeight.ULTIMATE, "%s 200-star skill heavier than every class skill" % cls)
		check(not early.is_empty() and not late.is_empty() and _mean(late) > _mean(early) + 0.15, "%s late skills heavier than early ones (%.2f > %.2f)" % [cls, _mean(late), _mean(early)])
	check(lights > 10, "light skills exist (%d)" % lights)
	check(SkillWeight.weight(ClassData.find_skill(&"mage", "armageddon")) > SkillWeight.weight(ClassData.find_skill(&"mage", "fire_ball")), "override: Armageddon heavier than Fire Ball")
	check(SkillWeight.is_slam(ClassData.find_skill(&"defender", "ground_quake")), "ground slams are slams")
	check(SkillWeight.thai_name(StarSkillData.pool(&"warrior")[3]) == "ฝนดาบราชันสวรรค์", "a 200-star skill shows its Thai title")


func _mean(values: Array[float]) -> float:
	var sum := 0.0
	for v in values:
		sum += v
	return sum / maxf(1.0, float(values.size()))


func _elements() -> void:
	check(SkillWeight.element(ClassData.find_skill(&"mage", "fire_ball")) == "fire", "fire ball is fire")
	check(SkillWeight.element(ClassData.find_skill(&"mage", "ice_storm")) == "ice", "ice storm is ice")
	check(SkillWeight.element(ClassData.find_skill(&"mage", "dead_ray")) == "thunder", "dead ray is lightning")
	check(SkillWeight.element(StarSkillData.pool(&"assassin")[4]) == "dark", "the assassin's god skill is dark")
	check(SkillWeight.element(StarSkillData.pool(&"warrior")[4]) == "holy", "the warrior's god skill is holy")
	var fire := SkillWeight.flash_color("fire")
	var ice := SkillWeight.flash_color("ice")
	var dark := SkillWeight.flash_color("dark")
	var holy := SkillWeight.flash_color("holy")
	check(fire.r > fire.g and fire.g > fire.b, "fire flashes orange")
	check(ice.b > ice.r and ice.b > 0.8, "ice flashes blue")
	check(dark.b > dark.g and dark.r > dark.g, "dark flashes purple")
	check(holy.r > holy.b and holy.g > holy.b + 0.3, "holy flashes gold")
	check(SkillWeight.flash_color("phys") == Color.WHITE, "plain hits keep the white flash")


func _scaling() -> void:
	var stops: Array[float] = []
	var shakes: Array[float] = []
	for t in 4:
		stops.append(SkillFeel.stop_for(t))
		shakes.append(SkillFeel.shake_for(t))
	check(is_equal_approx(stops[0], 2.0 / 60.0) and is_equal_approx(stops[2], 8.0 / 60.0), "hit-stop light 2 frames, heavy 8 frames")
	check(stops[0] < stops[1] and stops[1] < stops[2] and stops[2] < stops[3], "hit-stop grows with weight")
	check(SkillFeel.stop_for(3, true) <= SkillWeight.stop_seconds(3) + 0.0001 and stops[3] <= 0.2, "hit-stop capped")
	check(shakes[0] <= shakes[1] and shakes[1] < shakes[2] and shakes[2] < shakes[3], "shake grows with weight")
	check(SkillFeel.shake_for(3, true) <= ThirdPersonCamera.FEEL_MAX_OFFSET, "shake capped")
	GameSettings.quality = 0
	check(SkillFeel.shake_for(1) == 0.0 and SkillFeel.shake_for(2) > 0.0, "low quality: only heavy hits shake")
	GameSettings.quality = 2


func _rig() -> Dictionary:
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	var cam := ThirdPersonCamera.new()
	cam.target = hero
	field.add_child(cam)
	hero.camera_rig = cam
	return {"field": field, "hero": hero, "camera": cam}


func _camera_caps() -> void:
	_profile(&"warrior", 300)
	var rig := _rig()
	var cam: ThirdPersonCamera = rig.camera
	await get_tree().process_frame
	cam.feel_windup(40.0, 0.2)
	cam.feel_shake(Vector3(1, 0, 0), 5.0, 0.3, 5.0)
	var worst := Vector2.ZERO
	var moved := false
	for i in 12:
		await get_tree().process_frame
		var off := cam.feel_offset()
		worst = Vector2(maxf(worst.x, absf(off.x)), maxf(worst.y, off.y))
		moved = moved or off.y > 0.001 or absf(off.x) > 0.01
	check(moved, "the camera shakes for a heavy hit")
	check(worst.x <= ThirdPersonCamera.FEEL_MAX_FOV + 0.001 and worst.y <= ThirdPersonCamera.FEEL_MAX_OFFSET + 0.001, "camera moves capped (%.2f deg, %.3f m)" % [worst.x, worst.y])
	cam.feel_punch(50.0)
	await get_tree().create_timer(1.6, true, false, true).timeout
	var rest := cam.feel_offset()
	check(is_zero_approx(rest.x) and is_zero_approx(rest.y), "the camera settles back to rest")
	GameSettings.screen_shake = false
	cam.feel_shake(Vector3(1, 0, 0), 0.1)
	cam.feel_punch(4.0)
	cam.feel_windup(4.0, 0.5)
	await get_tree().process_frame
	await get_tree().process_frame
	check(cam.feel_offset() == Vector2.ZERO, "\"สั่นจอ\" off: the camera never moves")
	GameSettings.screen_shake = true
	rig.field.queue_free()
	await rig.field.tree_exited


func _profile(cls: StringName, stars: int) -> void:
	Game.new_profile(cls, "Feel QA")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.paragon = {"level": stars, "points": stars, "spent": 0, "exp": 0, "alloc": {}}
	Game.profile.look = {"gender": 0}
	Game.profile.party = []
	Game.profile.hp = 100000
	Game.profile.mp = 100000
	if Game.profile.get("flags") is Dictionary:
		Game.profile.flags["raven_attack"] = 0


func _target(field: Node3D, hero: Hero, id: StringName, at: Vector3) -> Mob:
	var mob := Mob.new()
	mob.setup(id, 100, at, hero)
	field.add_child(mob)
	mob.position = at
	mob.hp = 100000000
	mob.max_hp = mob.hp
	return mob


func _cast(cls: StringName, star: int) -> Dictionary:
	_profile(cls, 300)
	var rig := _rig()
	var hero: Hero = rig.hero
	var mob := _target(rig.field, hero, &"pink_slime", Vector3(0, 0, 3))
	mob.set_physics_process(false)
	hero.target = mob
	var skill: Dictionary = {}
	for s in StarSkillData.pool(cls):
		if int(s.star) == star:
			skill = ClassData.find_skill(cls, String(s.id))
	rig["skill"] = skill
	rig["mob"] = mob
	return rig


func _cut_in() -> void:
	# Hit-stops of the casts' own hits would restore their own clocks over the checks here.
	GameSettings.combat_hitstop = false
	# The god skill (300 stars) and a 200-star skill of the hero: a banner and slow motion.
	for pair in [[&"mage", 300], [&"lancer", 200]]:
		var rig := await _cast(pair[0], pair[1])
		var before := UltCutIn.shown_count
		Engine.time_scale = 1.0
		rig.hero._cast(rig.skill)
		check(UltCutIn.shown_count == before + 1, "%s %d-star cast shows the cut-in" % pair)
		check(SkillWeight._has_thai(UltCutIn.last_name), "the cut-in name is Thai: " + UltCutIn.last_name)
		var layer := UltCutIn.active()
		# Its own clock (real time, hitch frames capped): into the held slow motion.
		for i in 300:
			if layer == null or layer._t >= 0.1:
				break
			await get_tree().process_frame
		check(layer != null and layer.visible, "the banner is on screen")
		check(Engine.time_scale < 0.8 and UltCutIn.slowing(), "time slows with the cut-in (%.2f)" % Engine.time_scale)
		await get_tree().create_timer(0.9, true, false, true).timeout
		check(is_equal_approx(Engine.time_scale, 1.0) and not UltCutIn.slowing(), "time runs normally again afterwards")
		check(layer != null and not layer.visible, "the banner is gone after ~0.75 s")
		rig.field.queue_free()
		await rig.field.tree_exited
	# Someone else changing the clock meanwhile (a test's fast clock): left alone.
	var fast := await _cast(&"mage", 300)
	fast.hero._cast(fast.skill)
	await get_tree().process_frame
	Engine.time_scale = 3.0
	await get_tree().create_timer(0.7, true, false, true).timeout
	check(is_equal_approx(Engine.time_scale, 3.0), "a clock changed by someone else is never overwritten")
	Engine.time_scale = 1.0
	UltCutIn.stop_now()
	fast.field.queue_free()
	await fast.field.tree_exited
	# The setting off: nothing.
	GameSettings.ult_cutin = false
	var off := await _cast(&"mage", 300)
	var count := UltCutIn.shown_count
	off.hero._cast(off.skill)
	await get_tree().process_frame
	check(UltCutIn.shown_count == count and is_equal_approx(Engine.time_scale, 1.0), "\"ฉากท่าไม้ตาย\" off: no cut-in, no slow motion")
	GameSettings.ult_cutin = true
	off.field.queue_free()
	await off.field.tree_exited
	# A duel: the banner (shorter), the clock untouched.
	var old_zone := Game.current_zone
	var duel := await _cast(&"mage", 300)
	Game.current_zone = &"pvp"
	count = UltCutIn.shown_count
	duel.hero._cast(duel.skill)
	await get_tree().process_frame
	check(UltCutIn.shown_count == count + 1 and is_equal_approx(Engine.time_scale, 1.0) and not UltCutIn.slowing(), "duel: banner without slow motion (%d %d %.2f %s)" % [UltCutIn.shown_count, count, Engine.time_scale, UltCutIn.slowing()])
	Game.current_zone = old_zone
	UltCutIn.stop_now()
	duel.field.queue_free()
	await duel.field.tree_exited
	# A class skill (not an ultimate) and an AI caster: no cut-in, no camera.
	var ai := await _cast(&"mage", 300)
	count = UltCutIn.shown_count
	var companion := Companion.new()
	companion.setup({"class": "mage", "name": "QA mage", "level": 100, "exp": 0, "gender": 0}, 0, ai.hero, ai.field)
	ai.field.add_child(companion)
	companion.position = Vector3(-2, 0, 0)
	companion.set_physics_process(false)
	companion.target = ai.mob
	companion.mp = 100000.0
	companion._cast(ClassData.find_skill(&"mage", "armageddon"))
	var still := true
	for i in 70:
		await get_tree().process_frame
		still = still and ai.camera.feel_offset() == Vector2.ZERO
	check(UltCutIn.shown_count == count and is_equal_approx(Engine.time_scale, 1.0), "an AI caster's big skill shows no cut-in")
	check(still, "an AI caster never moves the camera")
	ai.hero._cast(ClassData.find_skill(&"mage", "fire_bolt"))
	check(UltCutIn.shown_count == count, "a class skill shows no cut-in")
	ai.field.queue_free()
	await ai.field.tree_exited
	await get_tree().process_frame
	GameSettings.combat_hitstop = true


func _reactions() -> void:
	_profile(&"warrior", 300)
	var rig := _rig()
	var hero: Hero = rig.hero
	hero.field_radius = 40.0
	var slime := _target(rig.field, hero, &"pink_slime", Vector3(0, 0, 3))
	var boss := _target(rig.field, hero, &"mush_king", Vector3(6, 0, 3))
	boss.set_physics_process(false)
	await get_tree().physics_frame
	var heavy := ClassData.find_skill(&"warrior", "gladiator")
	check(SkillWeight.tier_of(heavy) == SkillWeight.HEAVY, "Gladiator is a heavy skill")
	var launched := SkillFeel.launches
	var dir := Vector3(0, 0, 1)
	SkillFeel.react(hero, slime, dir, SkillWeight.weight(heavy))
	check(SkillFeel.launches == launched + 1 and slime.velocity.dot(dir) > 3.0, "a heavy hit throws a normal monster along the hit (%.2f)" % slime.velocity.dot(dir))
	var peak := 0.0
	for i in 20:
		await get_tree().process_frame
		peak = maxf(peak, slime.visual.position.y)
	check(peak > 0.3, "the thrown monster flies a short arc (%.2f m)" % peak)
	await get_tree().create_timer(0.8).timeout
	check(is_zero_approx(slime.visual.position.y) and is_zero_approx(slime.visual.rotation.x), "and lands back on its feet")
	check(slime.global_position.z > 3.5 and slime.global_position.is_finite(), "its real position slid along the hit (%.2f)" % slime.global_position.z)
	var staggered := SkillFeel.staggers
	var boss_at := boss.global_position
	SkillFeel.react(hero, boss, dir, 1.0)
	check(SkillFeel.launches == launched + 1 and SkillFeel.staggers == staggered + 1 and boss.velocity.length() < 0.01, "a boss resists: a stagger only")
	await get_tree().create_timer(0.3).timeout
	check(boss.global_position.distance_to(boss_at) < 0.2 and is_zero_approx(boss.visual.position.y), "the boss holds its ground")
	var rival := Rival.new()
	var fighter := GuildFighter.new()
	check(SkillFeel.resists(rival) and SkillFeel.resists(fighter), "rivals and guild fighters resist")
	rival.free()
	fighter.free()
	# A star skill's waves before its last: a hop in place, no slide out of the next wave.
	var hopper := _target(rig.field, hero, &"pink_slime", Vector3(-6, 0, 3))
	hopper.set_physics_process(false)
	SkillFeel._hold = true
	var hops := SkillFeel.launches
	SkillFeel.react(hero, hopper, dir, 1.0)
	SkillFeel.beat_done()
	check(SkillFeel.launches == hops + 1 and hopper.velocity.length() < 0.01, "an early star wave only hops the monster in place")
		# Thrown toward the field's edge: the slide is cut so it stays inside.
	hero.field_radius = 10.0
	var edge := _target(rig.field, hero, &"pink_slime", Vector3(0, 0, 9.2))
	var speed := SkillFeel.launch_speed(hero, edge, Vector3(0, 0, 1), 1.0)
	check(9.2 + speed * speed / (2.0 * SkillFeel.SLIDE_DECEL) <= 10.0, "a throw at the edge stays inside the field (%.2f m/s)" % speed)
	check(SkillFeel.launch_speed(hero, edge, Vector3(0, 0, -1), 1.0) > 5.0, "a throw back inward keeps its full speed")
	# The real hit path: Hero._deal with a heavy skill throws, a light one does not.
	var light := ClassData.find_skill(&"warrior", "raving")
	launched = SkillFeel.launches
	var fresh := _target(rig.field, hero, &"pink_slime", Vector3(-4, 0, 2))
	hero._deal(fresh, 1.0, light.color, light.vfx, false, light)
	check(SkillFeel.launches == launched, "a light skill throws nothing")
	await get_tree().create_timer(0.3, true, false, true).timeout
	hero._deal(fresh, 1.0, heavy.color, heavy.vfx, false, heavy)
	check(SkillFeel.launches == launched + 1, "a heavy skill hit through Hero._deal throws")
	# Element flashes on the monster.
	for element in ["fire", "ice", "thunder", "dark", "holy"]:
		SkillFeel.flash(fresh, element)
		var mat: StandardMaterial3D = fresh.visual._flash_mat
		var c := SkillWeight.flash_color(element)
		check(mat != null and Color(mat.albedo_color.r, mat.albedo_color.g, mat.albedo_color.b).is_equal_approx(c), "%s flash colour on the monster" % element)
	rig.field.queue_free()
	await rig.field.tree_exited
	await get_tree().create_timer(0.3, true, false, true).timeout
	Engine.time_scale = 1.0


func _marks() -> void:
	_profile(&"mage", 300)
	var rig := _rig()
	var hub := SkillFeel.of(rig.hero)
	MemoryGuard.force(0, get_tree())
	GameSettings.quality = 2
	for i in 20:
		hub.place_mark(Vector3(i * 2.5, 0, 0), 3.0, ["fire", "ice", "holy", "earth"][i % 4])
	check(hub.marks_visible() == SkillFeel.MARK_CAP[2] and hub._marks.size() == SkillFeel.MARK_CAP[2], "ground marks pooled and capped (%d)" % hub.marks_visible())
	hub.place_mark(Vector3(0, 0, 50), 3.0, "fire")
	hub.place_mark(Vector3(0.2, 0, 50), 3.0, "fire")
	check(hub._marks.size() == SkillFeel.MARK_CAP[2], "the pool never grows past its cap")
	await get_tree().create_timer(0.1, true, false, true).timeout
	var mat := hub._marks[0].material_override as ShaderMaterial
	check(mat != null and float(mat.get_shader_parameter("fade")) > 0.0, "a mark fades in (%s)" % mat.get_shader_parameter("fade"))
	MemoryGuard.force(1, get_tree())
	await get_tree().create_timer(0.05, true, false, true).timeout
	check(hub.marks_visible() <= SkillFeel.MARK_CAP[2] / 2, "trimmed memory: half the marks (%d)" % hub.marks_visible())
	MemoryGuard.force(2, get_tree())
	await get_tree().create_timer(0.05, true, false, true).timeout
	check(hub.marks_visible() == 0, "strict memory: marks dropped first")
	await get_tree().create_timer(0.05, true, false, true).timeout
	check(hub._marks.is_empty(), "strict memory: the pool itself is freed")
	check(hub.place_mark(Vector3.ZERO, 3.0, "fire") == null, "no new marks under strict pressure")
	MemoryGuard.force(0, get_tree())
	GameSettings.quality = 0
	check(hub.place_mark(Vector3.ZERO, 3.0, "fire") == null, "low quality: no ground marks")
	GameSettings.quality = 2
	var mark := hub.place_mark(Vector3.ZERO, 3.0, "holy")
	check(mark != null and mark.visible, "a mark is laid again once memory is fine")
	hub._mark_age[hub._marks.find(mark)] = SkillFeel.MARK_LIFE - 0.01
	await get_tree().create_timer(0.1).timeout
	check(not mark.visible, "a mark is gone after its life (%.1f s)" % SkillFeel.MARK_LIFE)
	# A real blast lays one through Hero._blast_damage.
	var before := hub.marks_visible()
	# (A skill whose own signature art draws its scar, GodSkillArt.owns, lays none here.)
	var heavy := {}
	for skill in ClassData.pool(&"mage"):
		if String(skill.shape) == "blast" and not GodSkillArt.owns(skill) and SkillWeight.tier_of(skill) >= SkillWeight.MEDIUM:
			heavy = skill
	check(not heavy.is_empty(), "a heavy blast without its own signature art to test")
	rig.hero._blast_damage(heavy, Vector3(5, 0, 5), 5.0, 1.0)
	check(hub.marks_visible() == before + 1, "a heavy blast leaves a mark (%s)" % heavy.get("id", ""))
	var owned := ClassData.find_skill(&"mage", "ice_storm")
	if GodSkillArt.owns(owned):
		var marks := hub.marks_visible()
		rig.hero._blast_damage(owned, Vector3(-5, 0, 5), 5.0, 1.0)
		check(hub.marks_visible() == marks, "a blast with its own signature art leaves its own scar instead")
	rig.field.queue_free()
	await rig.field.tree_exited
	MemoryGuard.force(-1, get_tree())
	Engine.time_scale = 1.0


func _numbers_and_combo() -> void:
	var holder := Node3D.new()
	add_child(holder)
	BattleVfx.clock_override = 0.0
	var plain := BattleVfx.damage_number(holder, Vector3(0, 2, 0), "100", false)
	BattleVfx.number_tint = SkillWeight.flash_color("fire")
	var fire := BattleVfx.damage_number(holder, Vector3(10, 2, 0), "100", false)
	var fire_crit := BattleVfx.damage_number(holder, Vector3(20, 2, 0), "100!", false, 1.35)
	BattleVfx.number_tint = SkillWeight.flash_color("ice")
	var ice := BattleVfx.damage_number(holder, Vector3(30, 2, 0), "100", false)
	BattleVfx.number_tint = Color(0, 0, 0, 0)
	var crit := BattleVfx.damage_number(holder, Vector3(40, 2, 0), "100!", false, 1.35)
	check(plain.modulate.is_equal_approx(BattleVfx.DAMAGE_DEALT), "untinted numbers keep their colour")
	check(not fire.modulate.is_equal_approx(plain.modulate) and fire.modulate.r > fire.modulate.b, "fire numbers lean orange")
	check(ice.modulate.b > fire.modulate.b + 0.2, "ice numbers lean blue")
	check(crit.modulate.is_equal_approx(BattleVfx.CRIT_COLOR), "an untinted crit stays gold")
	check(fire_crit.pixel_size > fire.pixel_size * 1.4, "element crits are bigger")
	BattleVfx.clock_override = -1.0
	holder.queue_free()
	# The combo total: three hits and more of one skill.
	_profile(&"mage", 300)
	var rig := _rig()
	var hub := SkillFeel.of(rig.hero)
	var mob := _target(rig.field, rig.hero, &"pink_slime", Vector3(0, 0, 3))
	for i in 4:
		hub._count("chain_lightning", 1250, mob)
	var text := hub.close_combo()
	check(text == "รวม 4 ฮิต 5,000", "multi-hit total: " + text)
	hub._count("fire_bolt", 300, mob)
	check(hub.close_combo() == "", "a single hit shows no total")
	check(SkillFeel.group_digits(1234567) == "1,234,567", "digits grouped")
	rig.field.queue_free()


func _settings_saved() -> void:
	GameSettings.ult_cutin = false
	GameSettings.screen_shake = false
	GameSettings.save_settings()
	GameSettings.ult_cutin = true
	GameSettings.screen_shake = true
	GameSettings._loaded = false
	GameSettings.load_settings()
	check(not GameSettings.ult_cutin and not GameSettings.screen_shake, "both toggles are saved")
	GameSettings.ult_cutin = true
	GameSettings.screen_shake = true
	GameSettings.save_settings()
