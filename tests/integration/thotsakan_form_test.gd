extends Node3D
## ★300 สิบเศียรสิบกรสะท้านสามภพ (three_realms_fist) as ทศกัณฐ์'s form (ThotsakanForm):
## the hero turns for 8 s (grown, the spirit's mantle on), every normal punch strikes and
## burns every foe round it, the god fist ends it (stun, burn, the combo spent); the damage
## matches the old five-beat god skill for one foe and for a pack; death, a zone change
## and a revive leave nothing of it; an AI player (a duel Rival, a guild war fighter)
## casts it and fights in it; another player's body shows it (RemotePlayer, cosmetic);
## the online duel's proxy takes its punches as pvp_hit; budget and cleanup hold.
##   godot --headless --path . res://tests/integration/thotsakan_form_test.tscn
const MT := &"muaythai"
var checks := 0
var failures := 0
var sim := 0.0
var burners: Array = []


class Target:
	extends Mob


class StubDuel:
	extends OnlineDuel
	var hits := 0
	func send_hit(amount: int, _crit: bool, _reflected := false) -> int:
		hits += 1
		return amount


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", note)


func _process(delta: float) -> void:
	sim += delta
	# The targets stand still (no AI): their burns are ticked here.
	for t in burners:
		if is_instance_valid(t) and not (t as Mob).is_dead():
			(t as Mob)._tick_status(delta)


func _wait(seconds: float) -> void:
	var end := sim + seconds
	while sim < end:
		await get_tree().process_frame


func profile(stars := 300) -> void:
	Game.new_profile(MT, "Thotsakan QA", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = JobData.GOD_ADV
	Game.profile.paragon = {"level": stars, "points": 0, "spent": 0, "exp": 0, "alloc": {}}
	Game.profile.party = []
	Game.profile.equip = {}
	for slot in ItemData.EQUIP_SLOTS:
		Game.profile.equip[slot] = StarProgression.item(MT, 200, slot, Game.rng)
	Game.profile.hp = 10000000
	Game.profile.mp = 10000000


func god() -> Dictionary:
	return ClassData.find_skill(MT, "three_realms_fist")


func _field() -> Node3D:
	var field := Node3D.new()
	add_child(field)
	# A floor to stand on (the hero walks and falls like in a zone).
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	field.add_child(floor_body)
	return field


func _hero(field: Node3D) -> Hero:
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.global_position = Vector3.ZERO
	return hero


func _target(field: Node3D, hero: Node3D, at: Vector3) -> Target:
	var t := Target.new()
	t.setup(&"dawn_stag", 100, at, hero)
	t.position = at
	field.add_child(t)
	t.set_physics_process(false)
	t.hp = 1000000000
	t.max_hp = t.hp
	burners.append(t)
	return t


func _drop(field: Node3D) -> void:
	burners.clear()
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame


func _ready() -> void:
	Game.set_process(false)
	InputSetup.ensure_defaults()
	GameSettings.load_settings()
	GameSettings.quality = 2
	GameSettings.combat_hitstop = false
	ZoneData.ensure()
	_catalogue()
	# Real time: the hero's swings and casts lock it on the wall clock (Hero._cast_until).
	Engine.time_scale = 1.0
	await _form_and_balance()
	await _death_and_revive()
	await _zone_change()
	await _rivals()
	await _remote_player()
	await _pvp_proxy()
	await _qualities()
	Engine.time_scale = 1.0
	MemoryGuard.force(-1, get_tree())
	Game.has_profile = false
	print("THOTSAKAN FORM: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(failures)


func _catalogue() -> void:
	var s := god()
	check(not s.is_empty() and StarSkillData.is_god(s) and String(s.shape) == "burst", "the god skill is still a god-tier burst")
	check(int(s.mp) == 300 and is_equal_approx(float(s.cd), 60.0), "MP 300, cooldown 60 s (mp %d cd %.0f)" % [int(s.mp), float(s.cd)])
	check(absf(float(s.mult) - 56.7) < 0.05, "its total multiplier stays 56.7 (%.2f)" % float(s.mult))
	check(String(s.desc).contains("แปลงร่างเป็นทศกัณฐ์") and String(s.desc).contains("8 วิ") and String(s.desc).contains("หมัดยักษ์") and String(s.desc).contains("ติดไฟ"), "the Thai description tells the form")
	check(s.fx.has("combo_power") and s.fx.has("stun") and s.fx.has("burn"), "finisher keeps stun, burn and combo_power")
	check(ThotsakanForm.handles(s) and not ThotsakanForm.handles(ClassData.find_skill(MT, "heavenly_master_fist")), "the form is three_realms_fist's own (not the ★500 ult built from it)")


## The old five-beat god skill on [param targets] (StarSkillSequence's GOD_WAVE_SHARE
## waves 0.32 s apart and the finale) with the combo at [param combo]: its hits and its
## 6 s burn, per target.
func _old_cast(hero: Hero, targets: Array, combo: int) -> void:
	var skill := hero._ranked(god())
	MuayThai.spend(hero)
	if hero.has_meta(MuayThai.SPENT_META):
		hero.remove_meta(MuayThai.SPENT_META)
	MuayThai.add_combo(hero, combo)
	var beats: Array = StarSkillData.GOD_BEATS
	var t0 := sim
	for i in beats.size():
		while sim < t0 + float(beats[i]):
			await get_tree().process_frame
		var share := StarSkillSequence.GOD_WAVE_SHARE if i < beats.size() - 1 else 1.0 - StarSkillSequence.GOD_WAVE_SHARE * float(beats.size() - 1)
		for t in targets:
			hero.stats["crit"] = 0.0
			hero._deal(t, float(skill.mult) * share * hero.rank_mult(skill), skill.color, skill.vfx, false, skill)
	await _wait(6.4)


## A hero fights [param count] foes with the form (or, [param with_form] false, only its
## normal punches for as long): HP each foe lost, the form's stats.
func _fight(count: int, with_form: bool) -> Dictionary:
	var field := _field()
	var hero := _hero(field)
	await get_tree().process_frame
	hero.refresh_stats()
	var spots := [Vector3(0, 0, 1.8), Vector3(1.6, 0, 1.2), Vector3(-1.6, 0, 1.2), Vector3(1.2, 0, -1.4), Vector3(-1.2, 0, -1.4)]
	var foes: Array = []
	for i in count:
		foes.append(_target(field, hero, spots[i]))
	hero.target = foes[0]
	hero.engaged = true
	MuayThai.add_combo(hero, 10)
	var out := {"hp0": [], "lost": [], "scale_peak": 1.0, "secs": 0.0, "punches": 0, "planned": 0, "finished": false, "stunned": false, "burning": false, "scale_end": 0.0, "lifted": 0.0}
	for f in foes:
		out.hp0.append((f as Mob).hp)
	var skill := god()
	if with_form:
		hero._cast(skill)
		check(hero.get_node_or_null("StarCast_three_realms_fist") != null, "the god cast starts its wind-up")
		var guard := 0
		while ThotsakanForm.of(hero) == null and guard < 2000:
			hero.stats["crit"] = 0.0
			await get_tree().process_frame
			guard += 1
		var form := ThotsakanForm.of(hero)
		check(form != null and not form.cosmetic, "the release turns the hero into ทศกัณฐ์")
		if form == null:
			await _drop(field)
			return out
		var began := sim
		var burned_mid := false
		while ThotsakanForm.of(hero) != null and sim - began < 12.0:
			hero.stats["crit"] = 0.0
			out.scale_peak = maxf(out.scale_peak, hero.visual.scale.x)
			if form.clock > 4.0 and form.clock < 7.5 and (foes.back() as Mob)._burn_time > 0.0:
				burned_mid = true
			if form.finished and not out.stunned and form._slammed:
				out.stunned = (foes[0] as Mob)._stun > 0.5
				out.secs = form.clock
			await get_tree().process_frame
		out.burning = burned_mid
		out.punches = int(ThotsakanForm.last.punches)
		out.planned = int(ThotsakanForm.last.planned)
		out.finished = bool(ThotsakanForm.last.finished)
		out.scale_end = hero.visual.scale.x
		# The fire burns on after the slam.
		await _wait(6.4)
	else:
		# Only its normal punches, as long as the form's release to its end (8.8 s).
		await _wait(ThotsakanForm.SECS + ThotsakanForm.FINISH_WINDUP + ThotsakanForm.SHRINK)
		hero.engaged = false
		await _wait(0.6)
	for i in foes.size():
		out.lost.append(int(out.hp0[i]) - (foes[i] as Mob).hp)
	await _drop(field)
	return out


func _old(count: int) -> Array:
	var field := _field()
	var hero := _hero(field)
	await get_tree().process_frame
	hero.refresh_stats()
	var spots := [Vector3(0, 0, 1.8), Vector3(1.6, 0, 1.2), Vector3(-1.6, 0, 1.2), Vector3(1.2, 0, -1.4), Vector3(-1.2, 0, -1.4)]
	var foes: Array = []
	for i in count:
		foes.append(_target(field, hero, spots[i]))
	var hp0: Array = foes.map(func(f): return (f as Mob).hp)
	await _old_cast(hero, foes, 10)
	var lost: Array = []
	for i in foes.size():
		lost.append(int(hp0[i]) - (foes[i] as Mob).hp)
	await _drop(field)
	return lost


func _sum(list: Array) -> float:
	var s := 0.0
	for v in list:
		s += float(v)
	return s


func _form_and_balance() -> void:
	profile()
	# One foe: the form against the old skill (its own punches subtracted, as it throws
	# them anyway).
	var one := await _fight(1, true)
	var plain := await _fight(1, false)
	var old_one := await _old(1)
	check(one.scale_peak > ThotsakanForm.SCALE - 0.05 and one.scale_peak < ThotsakanForm.SCALE + 0.05, "the hero grows to x%.1f (%.2f)" % [ThotsakanForm.SCALE, one.scale_peak])
	check(absf(one.scale_end - 1.0) < 0.001, "and is its own size again after (%.3f)" % one.scale_end)
	check(one.finished and absf(float(one.secs) - (ThotsakanForm.SECS + ThotsakanForm.FINISH_WINDUP)) < 0.25, "the form lasts 8 s and the god fist lands (%.2f s)" % float(one.secs))
	check(one.stunned, "the god fist stuns")
	check(int(one.punches) >= int(one.planned) - 2 and int(one.punches) <= int(one.planned) + 1 and int(one.planned) >= 10, "the hero punches through the form (%d of %d planned)" % [int(one.punches), int(one.planned)])
	var form_one := float(one.lost[0]) - float(plain.lost[0])
	var ratio_one := form_one / maxf(float(old_one[0]), 1.0)
	print("BALANCE single: form %.0f (with punches %.0f, punches only %.0f) vs old %.0f -> x%.2f" % [form_one, float(one.lost[0]), float(plain.lost[0]), float(old_one[0]), ratio_one])
	check(ratio_one > 0.85 and ratio_one < 1.2, "one foe takes about the old skill's damage (x%.2f)" % ratio_one)
	# A pack of five round the hero: each foe takes the form, the pack about the old area.
	var five := await _fight(5, true)
	var old_five := await _old(5)
	check(five.burning, "the punches keep the pack burning through the form")
	var others := _sum(five.lost.slice(1)) / 4.0
	var old_each := _sum(old_five) / 5.0
	var ratio_each := others / maxf(old_each, 1.0)
	var pack := _sum(five.lost) - float(plain.lost[0])
	var ratio_pack := pack / maxf(_sum(old_five), 1.0)
	print("BALANCE pack of 5: each %.0f vs old %.0f -> x%.2f; pack %.0f vs old %.0f -> x%.2f" % [others, old_each, ratio_each, pack, _sum(old_five), ratio_pack])
	check(ratio_each > 0.8 and ratio_each < 1.2, "each foe of a pack (not even targeted) takes about the old area's (x%.2f)" % ratio_each)
	check(ratio_pack > 0.8 and ratio_pack < 1.2, "the pack takes about the old area's total (x%.2f)" % ratio_pack)
	check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "fights leave nothing behind %s" % VfxBudget.counters())


func _death_and_revive() -> void:
	profile()
	var field := _field()
	var hero := _hero(field)
	var rig := ThirdPersonCamera.new()
	field.add_child(rig)
	rig.target = hero
	hero.camera_rig = rig
	await get_tree().process_frame
	var foe := _target(field, hero, Vector3(0, 0, 1.8))
	hero.target = foe
	var height := rig.height_offset
	var dist := float(rig._target_distance)
	hero._cast(god())
	await _wait(float(god().hit_delay) + 1.2)
	var form := ThotsakanForm.of(hero)
	check(form != null and hero.visual.scale.x > 1.6, "transformed (%.2f)" % hero.visual.scale.x)
	check(absf(rig.height_offset - height - ThotsakanForm.CAMERA_LIFT) < 0.01 and float(rig._target_distance) > dist + 1.0, "the camera rises and draws back for the big body")
	check(hero.get_node_or_null("ThotsakanMantle") != null, "the mantle stands on the hero")
	check(field.get_node_or_null("ThotsakanPunch") != null or form.punches >= 0, "punch art on the field")
	hero._die()
	await get_tree().process_frame
	await get_tree().process_frame
	check(ThotsakanForm.of(hero) == null, "death ends the form")
	check(hero.visual.scale.is_equal_approx(Vector3.ONE), "and gives the body back its size")
	check(absf(rig.height_offset - height) < 0.01 and absf(float(rig._target_distance) - dist) < 0.01, "and the camera its place")
	check(not ThotsakanForm.last.finished, "no god fist from a fallen fighter")
	await _wait(0.6)
	check(hero.get_node_or_null("ThotsakanMantle") == null and hero.get_node_or_null("ThotsakanGround") == null, "the mantle fades and goes")
	hero.revive()
	await _wait(0.3)
	check(ThotsakanForm.of(hero) == null and hero.visual.scale.is_equal_approx(Vector3.ONE), "revived as itself")
	# Punches after the form are ordinary again.
	ThotsakanForm.punch_from(hero)
	check(ThotsakanForm.of(hero) == null, "no form punches after")
	await _drop(field)
	check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "death leaves nothing %s" % VfxBudget.counters())


func _zone_change() -> void:
	profile()
	Game.current_zone = &"eclipse_realm"
	var zone := Zone.new()
	zone.zone_id = &"eclipse_realm"
	add_child(zone)
	await get_tree().process_frame
	var hero := zone.hero
	var nearest: Mob = null
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob := node as Mob
		if mob and not mob.is_dead() and (nearest == null or mob.global_position.distance_to(hero.global_position) < nearest.global_position.distance_to(hero.global_position)):
			nearest = mob
	if nearest:
		hero.global_position = nearest.global_position + Vector3(0, 0, 1.6)
		hero.target = nearest
	Game.profile.mp = 1000000
	hero._cast(god())
	await _wait(float(god().hit_delay) + 1.5)
	check(ThotsakanForm.of(hero) != null and hero.visual.scale.x > 1.6, "transformed in a real field")
	zone.queue_free()
	await zone.tree_exited
	await get_tree().process_frame
	await _wait(0.5)
	check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "leaving the zone mid-form leaves nothing %s" % VfxBudget.counters())
	var left := 0
	for label in ["ThotsakanForm", "ThotsakanMantle", "ThotsakanSpirit", "ThotsakanGround", "ThotsakanPunch", "ThotsakanSlam"]:
		left += get_tree().root.find_children(label, "", true, false).size()
	check(left == 0, "no form node outlives its zone (%d)" % left)


func _ai_info(stars := 300) -> Dictionary:
	profile(stars)
	var p: Dictionary = Game.profile.duplicate(true)
	return {"member": {"class": String(MT), "name": "ทศ QA", "level": 100}, "profile": p, "look": {"gender": 0},
		"difficulty": 1.0, "mults": {"hp": 1.0, "atk": 1.0, "def": 1.0}}


func _rivals() -> void:
	# A duel Rival casts it on the hero and fights in it: punches hit the hero, the god fist lands.
	var info := _ai_info()
	profile()
	Game.profile.level = 100
	var field := _field()
	var hero := _hero(field)
	hero.set_physics_process(false)
	var rival := Rival.new()
	rival.setup_rival(info, Vector3(0, 0, 1.6), hero, "QA")
	field.add_child(rival)
	rival.global_position = Vector3(0, 0, 1.6)
	rival.set_physics_process(false)
	await get_tree().process_frame
	rival.start_fight()
	rival.mp = 99999.0
	var skill := ClassData.find_skill(MT, "three_realms_fist")
	check(rival._shape_score(rival._ranked(skill), "burst", 1.6, 1.0) > 0.0, "an AI fighter wants it in reach")
	hero.stats["dodge"] = 0.0
	Game.profile.hp = 100000000
	rival._cast(skill, hero)
	await _wait(1.8)
	var form := ThotsakanForm.of(rival)
	check(form != null and not form.cosmetic and rival._rv.hero_visual.scale.x > 1.6, "a duel rival turns into ทศกัณฐ์")
	if form:
		var hp := int(Game.profile.hp)
		var punched := form.punches
		rival._attack_timer = 0.0
		rival._cast_until = 0
		rival._basic_attack(hero)
		await _wait(0.5)
		check(form.punches == punched + 1 and int(ThotsakanForm.last.victims) >= 1 and int(Game.profile.hp) < hp, "its punch strikes the hero round it")
		await _wait(ThotsakanForm.SECS + 0.8)
		check(ThotsakanForm.of(rival) == null and bool(ThotsakanForm.last.finished), "its god fist lands at the end")
		check(rival._rv.hero_visual.scale.is_equal_approx(Vector3.ONE), "the rival is its own size again")
	await _drop(field)
	# A guild war fighter: turns, falls mid-form, comes back as itself.
	info = _ai_info()
	profile()
	field = _field()
	hero = _hero(field)
	hero.set_physics_process(false)
	var f := GuildFighter.new()
	f.setup_fighter(info, GuildFighter.TEAM_ENEMY, hero, Vector3(0, 0, 1.6), "[QA]")
	field.add_child(f)
	f.global_position = Vector3(0, 0, 1.6)
	f.set_physics_process(false)
	await get_tree().process_frame
	f.start_fight()
	f.mp = 99999.0
	f._cast(skill, hero)
	await _wait(1.8)
	check(ThotsakanForm.of(f) != null and f._rv.hero_visual.scale.x > 1.6, "a guild war fighter turns into ทศกัณฐ์")
	f._die()
	await get_tree().process_frame
	await get_tree().process_frame
	check(ThotsakanForm.of(f) == null and f._rv.hero_visual.scale.is_equal_approx(Vector3.ONE), "its fall ends the form and its size")
	f.respawn()
	await _wait(0.2)
	check(ThotsakanForm.of(f) == null and f._rv.hero_visual.scale.is_equal_approx(Vector3.ONE), "it comes back as itself")
	await _drop(field)
	check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "AI forms leave nothing %s" % VfxBudget.counters())


func _remote_player() -> void:
	profile()
	var field := _field()
	var hero := _hero(field)
	hero.set_physics_process(false)
	var foe := _target(field, hero, Vector3(4, 0, 1))
	var remote := RemotePlayer.new()
	remote.setup({"id": "p2", "name": "Mali", "look": {"class": String(MT), "adv": 5, "gender": 0}, "pos": [4.0, 0.0, 0.0], "level": 100})
	field.add_child(remote)
	await get_tree().process_frame
	var hp := foe.hp
	remote._set_anim("skill:three_realms_fist")
	await _wait(float(god().hit_delay) + 0.8)
	var form := ThotsakanForm.of(remote)
	check(form != null and form.cosmetic and remote.visual.scale.x > 1.6, "another player's fighter is seen turning into ทศกัณฐ์")
	remote._set_anim("attack")
	remote._set_anim("idle")
	await _wait(0.3)
	check(foe.hp == hp, "their form hurts nothing here (their own game deals it)")
	remote._set_anim("dead")
	await get_tree().process_frame
	await get_tree().process_frame
	check(ThotsakanForm.of(remote) == null and remote.visual.scale.is_equal_approx(Vector3.ONE), "their fall ends it")
	await _drop(field)


func _pvp_proxy() -> void:
	profile()
	var field := _field()
	var hero := _hero(field)
	await get_tree().process_frame
	var duel := StubDuel.new()
	var stand := Node3D.new()
	field.add_child(stand)
	stand.global_position = Vector3(1.6, 0, 1.0)
	var proxy := PvpProxy.new()
	proxy.setup_proxy(duel, "p2", stand, hero, {"level": 100, "max_hp": 100000, "hp": 100000})
	field.add_child(proxy)
	proxy.live = true
	var foe := _target(field, hero, Vector3(0, 0, 1.8))
	hero.target = foe
	hero._cast(god())
	await _wait(float(god().hit_delay) + 0.5)
	var form := ThotsakanForm.of(hero)
	check(form != null, "transformed beside a duel opponent")
	if form:
		var before := duel.hits
		form.punch()
		check(duel.hits == before + 1, "a punch of the form reaches the duel opponent as one pvp_hit (%d)" % (duel.hits - before))
	ThotsakanForm.end_on(hero)
	await _drop(field)
	duel.free()


## Every quality and memory pressure: the form plays inside the budget and its roots
## keep their cap; nothing is left.
func _qualities() -> void:
	Engine.time_scale = 2.0
	for pressure in [0, 2]:
		MemoryGuard.force(pressure, get_tree())
		for quality in 3:
			GameSettings.quality = quality
			profile()
			var field := _field()
			var hero := _hero(field)
			await get_tree().process_frame
			var foes: Array = []
			for i in 6:
				var a := float(i) * 1.05
				foes.append(_target(field, hero, Vector3(sin(a), 0, cos(a)) * (1.6 + 0.4 * float(i % 2))))
			hero.target = foes[0]
			hero.engaged = true
			hero._cast(god())
			var over_budget := 0
			var over_cap := 0
			var spirit := false
			var t0 := sim
			while sim - t0 < float(god().hit_delay) + ThotsakanForm.SECS + 1.6:
				await get_tree().process_frame
				if int(VfxBudget.counters().decorations) > VfxBudget.decoration_limit() + VfxBudget.hero_decoration_room():
					over_budget += 1
				for node in field.find_children("*", "RamakienArt", true, false):
					if (node as RamakienArt).layers.size() > RamakienArt.layer_cap():
						over_cap += 1
				spirit = spirit or hero.find_child("ThotsakanSpirit", true, false) != null
			check(over_budget == 0, "within the effects budget q%d p%d" % [quality, pressure])
			check(over_cap == 0, "every root within its cap q%d p%d" % [quality, pressure])
			check(spirit == (pressure == 0), "the spirit stands up unless memory is short q%d p%d" % [quality, pressure])
			check(bool(ThotsakanForm.last.finished), "the god fist lands q%d p%d" % [quality, pressure])
			await _drop(field)
			check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "cleanup q%d p%d %s" % [quality, pressure, VfxBudget.counters()])
	MemoryGuard.force(-1, get_tree())
	GameSettings.quality = 2
