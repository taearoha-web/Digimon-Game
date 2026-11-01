extends Node3D
## Mounts (สัตว์ขี่): crafted from their own material (dropped per kill in every
## hunting field) plus chaos jewels and levelled to Lv.5 in the menu tab, one picked as
## active, saved ({id: level}, old lists of ids migrate to Lv.1) and repaired with the
## profile. The active mount's HP / ATK / DEF / crit count in the hero's stats ridden or
## not. Riding adds the mount's speed; the hero fights from the saddle (attacks, skills,
## auto hunting and hits keep it riding, weapon in hand, legs held seated by SaddlePose).
## Death or a no-riding zone (guild war, ranked pvp, tower, arena) puts it back on foot.
## The HUD's "ขี่" button only shows while a mount is owned.
## godot --headless --path . res://tests/integration/mount_test.tscn
var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func settle() -> void:
	for i in 3:
		await get_tree().process_frame


func _ready() -> void:
	await get_tree().process_frame
	InputSetup.ensure_defaults()
	Game.set_process(false)
	GameSettings.load_settings()
	Game.new_profile(&"warrior", "Mount QA", FaceKit.default_look())
	Game.profile.level = 60
	Game.profile.hp = 99999
	_data()
	_drops()
	_craft()
	_stats()
	_save()
	await _riding()
	await _menu()
	print("MOUNT: %d checks, %d failures" % [checks, failures])
	if failures == 0:
		print("PASS")
	get_tree().quit(1 if failures > 0 else 0)


func give(id: String, count: int) -> void:
	Game.add_item(ItemData.jewel(id, count))


## Takes every jewel of `id` out of the bag.
func clear(id: String) -> void:
	var have := Game.jewel_count(id)
	if have > 0:
		Game._spend_jewels(id, have)


const MATS := {"thunder_wolf": "wolf_fang", "glow_stag": "stag_antler", "griffin": "griffin_plume", "fire_drake": "drake_scale"}
const DROPS := {"thunder_wolf": 0.01, "glow_stag": 0.0075, "griffin": 0.005, "fire_drake": 0.001}
const CHAOS := {"thunder_wolf": 5, "glow_stag": 8, "griffin": 10, "fire_drake": 15}


func _data() -> void:
	check(MountData.ORDER.size() == 4, "four mounts")
	var last_hp := 0.0
	var last_speed := 0.0
	var last_chaos := 0
	for id in MountData.ORDER:
		var info := MountData.info(id)
		check(not info.has("price"), "%s has no gold price" % id)
		check(float(info.speed) > last_speed and float(info.speed) <= 0.5, "%s rides faster than the one before, at most +50%%" % id)
		last_speed = float(info.speed)
		check(info.color is Color and String(info.name) != "", "%s has a name and a card colour" % id)
		check(MountData.mat_of(id) == MATS[id] and MountData.mount_of_mat(MATS[id]) == id, "%s's material is %s" % [id, MATS[id]])
		check(is_equal_approx(float(info.drop), DROPS[id]), "%s material drops at %.2f%%" % [id, DROPS[id] * 100.0])
		check(int(info.chaos) == CHAOS[id] and int(info.chaos) > last_chaos, "%s costs %d chaos per level" % [id, CHAOS[id]])
		last_chaos = int(info.chaos)
		for n in range(1, MountData.MAX_LEVEL + 1):
			var cost := MountData.cost(id, n)
			check(int(cost.mat) == n and int(cost.chaos) == CHAOS[id] * n, "%s Lv.%d costs %d materials + %d chaos (%s)" % [id, n, n, CHAOS[id] * n, str(cost)])
		check(MountData.cost(id, 0).is_empty() and MountData.cost(id, MountData.MAX_LEVEL + 1).is_empty(), "%s has no step below 1 or past Lv.5" % id)
		var top := MountData.bonus(id, MountData.MAX_LEVEL)
		check(float(top.hp) > last_hp, "%s gives more HP at Lv.5 than the one before" % id)
		last_hp = float(top.hp)
		check(MountData.bonus(id, 0).is_empty(), "an uncrafted %s gives nothing" % id)
		var item := ItemData.jewel(MATS[id])
		check(ItemData.is_stackable(item) and ItemData.JEWELS.has(MATS[id]), "%s is a stackable jewel item" % MATS[id])
		check(ItemData.name_of(item) != "" and ItemLook.icon(item) != null, "%s has a name and an icon" % MATS[id])
		check(Game._valid_item(item), "%s is a valid save item" % MATS[id])
	for n in range(1, 6):
		check(is_equal_approx(float(MountData.bonus("thunder_wolf", n).hp), 0.01 * n), "wolf Lv.%d HP +%d%%" % [n, n])
	check(MountData.bonus("thunder_wolf", 3).keys() == ["hp"], "the wolf gives HP only")
	check(is_equal_approx(float(MountData.bonus("glow_stag", 5).def), 0.05) and is_equal_approx(float(MountData.bonus("glow_stag", 5).hp), 0.10), "stag Lv.5: HP +10%, DEF +5%")
	check(is_equal_approx(float(MountData.bonus("griffin", 5).atk), 0.05) and is_equal_approx(float(MountData.bonus("griffin", 5).hp), 0.15), "griffin Lv.5: HP +15%, ATK +5%")
	var drake := MountData.bonus("fire_drake", 5)
	check(is_equal_approx(float(drake.hp), 0.25) and is_equal_approx(float(drake.atk), 0.10) and is_equal_approx(float(drake.crit), 0.05), "drake Lv.5: HP +25%, ATK +10%, crit +5%")
	for n in range(1, 6):
		check(is_equal_approx(MountData.speed_bonus("thunder_wolf"), 0.30), "the wolf rides +30% at every level")
	for zone_id in [&"guildwar", &"pvp", &"tower", &"arena"]:
		check(not MountData.zone_allows(ZoneData.get_zone(zone_id)), "no riding in %s" % zone_id)
	for zone_id in [&"town", &"meadow"]:
		var zone := ZoneData.get_zone(zone_id)
		if not zone.is_empty():
			check(MountData.zone_allows(zone), "riding allowed in %s" % zone_id)


## The per-kill drop roll every hunting field makes (Zone._drop_jewels).
func _drops() -> void:
	var roll := RandomNumberGenerator.new()
	roll.seed = 4242
	var kills := 400_000
	var got := {}
	for i in kills:
		for item in Zone.mount_mat_drops(0.0, roll):
			check(String(item.kind) == "jewel" and int(item.count) == 1, "a material drop is one jewel item")
			got[item.id] = int(got.get(item.id, 0)) + 1
	for id in MountData.ORDER:
		var expect: float = float(kills) * float(DROPS[id])
		var n := int(got.get(MATS[id], 0))
		check(absf(float(n) - expect) < expect * 0.15, "%s drops about %.0f in %d kills (%d)" % [MATS[id], expect, kills, n])
	var lucky := 0
	roll.seed = 4242
	for i in 100_000:
		for item in Zone.mount_mat_drops(1.0, roll):
			if item.id == "wolf_fang":
				lucky += 1
	check(absf(float(lucky) - 2000.0) < 300.0, "fortune raises the drops like the jewels (+100%%: %d fangs in 100K)" % lucky)
	var src := FileAccess.get_file_as_string("res://world/zone.gd")
	var body := src.substr(src.find("func _drop_jewels"), 1800)
	check(body.contains("mount_mat_drops(") and body.contains("Game.say("), "the jewel drop path rolls the materials and toasts them")


func _craft() -> void:
	check(Game.owned_mounts().is_empty() and Game.active_mount() == "", "a new hero owns no mount")
	check(Game.mount_level("thunder_wolf") == 0 and Game.profile.mounts is Dictionary, "levels start at 0, saved as a dictionary")
	clear("chaos")
	var gold := int(Game.profile.gold)
	check(Game.craft_mount("thunder_wolf") != "", "no materials: the wolf can't be crafted")
	give("wolf_fang", 1)
	give("chaos", 4)
	check(Game.mount_step_problem("thunder_wolf") != "" and Game.craft_mount("thunder_wolf") != "", "4 chaos is short of 5")
	check(Game.mount_mats("thunder_wolf") == 1 and Game.jewel_count("chaos") == 4, "a refused craft spends nothing")
	give("chaos", 1)
	check(Game.mount_step_problem("thunder_wolf") == "", "1 fang + 5 chaos is enough")
	check(Game.craft_mount("thunder_wolf") == "", "wolf crafted")
	check(Game.mount_level("thunder_wolf") == 1 and Game.owns_mount("thunder_wolf"), "the wolf is Lv.1")
	check(Game.mount_mats("thunder_wolf") == 0 and Game.jewel_count("chaos") == 0, "crafting used the fang and 5 chaos")
	check(int(Game.profile.gold) == gold, "crafting costs no gold")
	check(Game.active_mount() == "thunder_wolf", "the first mount crafted becomes active")
	# Lv.2-5: n fangs and 5n chaos each, always succeeds.
	for n in range(2, 6):
		give("wolf_fang", n - 1)
		give("chaos", 5 * n)
		check(Game.craft_mount("thunder_wolf") != "", "Lv.%d refused with %d fangs" % [n, n - 1])
		give("wolf_fang", 1)
		give("chaos", 7)
		check(Game.craft_mount("thunder_wolf") == "" and Game.mount_level("thunder_wolf") == n, "wolf up to Lv.%d" % n)
		check(Game.mount_mats("thunder_wolf") == 0 and Game.jewel_count("chaos") == 7, "Lv.%d took %d fangs and %d chaos" % [n, n, 5 * n])
		clear("chaos")
	give("wolf_fang", 10)
	give("chaos", 100)
	check(Game.mount_step_problem("thunder_wolf") != "" and Game.craft_mount("thunder_wolf") != "", "Lv.5 is the top")
	check(Game.mount_level("thunder_wolf") == 5 and Game.mount_mats("thunder_wolf") == 10, "nothing spent at Lv.5")
	clear("wolf_fang")
	clear("chaos")
	give("stag_antler", 1)
	give("chaos", 8)
	check(Game.craft_mount("glow_stag") == "" and Game.mount_level("glow_stag") == 1, "stag crafted with 1 antler + 8 chaos")
	check(Game.active_mount() == "thunder_wolf", "crafting a second mount keeps the active one")
	check(Game.owned_mounts() == ["thunder_wolf", "glow_stag"], "owned mounts in menu order (%s)" % str(Game.owned_mounts()))
	check(Game.craft_mount("no_such_mount") != "", "unknown id refused")
	check(not Game.select_mount("griffin"), "can't pick a mount not owned")
	check(Game.select_mount("glow_stag") and Game.active_mount() == "glow_stag", "picked the stag")
	Game.select_mount("thunder_wolf")


func _stats() -> void:
	var p: Dictionary = Game.profile.duplicate(true)
	p["mount"] = ""
	var base := HeroStats.compute(p)
	var cases := [["thunder_wolf", 5, {"hp": 0.05}], ["glow_stag", 1, {"hp": 0.02, "def": 0.01}],
		["griffin", 3, {"hp": 0.09, "atk": 0.03}], ["fire_drake", 2, {"hp": 0.10, "atk": 0.04, "crit": 0.02}]]
	for c in cases:
		var q: Dictionary = p.duplicate(true)
		q["mounts"] = {c[0]: c[1]}
		q["mount"] = c[0]
		var s := HeroStats.compute(q)
		var b: Dictionary = c[2]
		check(absi(int(s.max_hp) - int(float(base.max_hp) * (1.0 + float(b.hp)))) <= 1, "%s Lv.%d: HP %d -> %d" % [c[0], c[1], int(base.max_hp), int(s.max_hp)])
		check(is_equal_approx(float(s.atk), float(base.atk) * (1.0 + float(b.get("atk", 0.0)))), "%s Lv.%d: ATK x%.2f" % [c[0], c[1], 1.0 + float(b.get("atk", 0.0))])
		check(is_equal_approx(float(s.def), float(base.def) * (1.0 + float(b.get("def", 0.0)))), "%s Lv.%d: DEF x%.2f" % [c[0], c[1], 1.0 + float(b.get("def", 0.0))])
		check(is_equal_approx(float(s.crit), minf(float(base.crit) + float(b.get("crit", 0.0)), HeroStats.MAX_CRIT)), "%s Lv.%d: crit +%.2f" % [c[0], c[1], float(b.get("crit", 0.0))])
		check(is_equal_approx(float(s.speed), float(base.speed)), "%s: no speed on foot" % c[0])
	var q2: Dictionary = p.duplicate(true)
	q2["mounts"] = {"griffin": 3}
	q2["mount"] = ""
	check(int(HeroStats.compute(q2).max_hp) == int(base.max_hp), "an owned but inactive mount adds nothing")
	# The live hero: the active wolf Lv.5 counts in Game.stats_now.
	var with_wolf := int(Game.stats_now().max_hp)
	Game.profile["mount"] = ""
	var none := int(Game.stats_now().max_hp)
	Game.profile["mount"] = "thunder_wolf"
	check(absi(with_wolf - int(float(none) * 1.05)) <= 1, "the hero's max HP has the wolf's +5%% (%d -> %d)" % [none, with_wolf])
	Game.select_mount("glow_stag")
	check(int(Game.stats_now().max_hp) < with_wolf, "switching to the Lv.1 stag changes the bonus")
	Game.select_mount("thunder_wolf")


func _save() -> void:
	var saved: Dictionary = Game.profile.duplicate(true)
	check(Game._valid_profile(saved.duplicate(true)), "a profile with mount levels is a valid save")
	var parsed: Variant = JSON.parse_string(JSON.stringify(saved))
	check(parsed is Dictionary and Game._valid_profile((parsed as Dictionary).duplicate(true)), "the JSON round trip is a valid save")
	if parsed is Dictionary:
		var back := Game._repair(parsed)
		check(back.mounts == {"thunder_wolf": 5, "glow_stag": 1} and back.mounts.thunder_wolf is int and back.mount == "thunder_wolf", "levels survive the round trip (%s)" % str(back.mounts))
	for bad_value in ["thunder_wolf", 5, {"thunder_wolf": 6}, {"thunder_wolf": -1}, {"thunder_wolf": "1"}, {"thunder_wolf": 1.5}, [3]]:
		var bad: Dictionary = saved.duplicate(true)
		bad["mounts"] = bad_value
		check(not Game._valid_profile(bad), "mounts = %s is refused" % str(bad_value))
	var bad: Dictionary = saved.duplicate(true)
	bad["mount"] = 5
	check(not Game._valid_profile(bad), "mount must be a string")
	# Saves from before mount levels: a list of owned ids becomes level 1 each.
	var old: Dictionary = saved.duplicate(true)
	old["mounts"] = ["thunder_wolf", "dragon_from_the_future", "thunder_wolf", "griffin"]
	old["mount"] = "griffin"
	check(Game._valid_profile(old.duplicate(true)), "an old list of owned mounts still loads")
	var migrated := Game._repair(old)
	check(migrated.mounts == {"thunder_wolf": 1, "griffin": 1}, "owned ids migrate to Lv.1, unknown and doubled dropped (%s)" % str(migrated.mounts))
	check(migrated.mount == "griffin", "the active mount survives the migration")
	var odd: Dictionary = saved.duplicate(true)
	odd["mounts"] = {"thunder_wolf": 3, "glow_stag": 0, "dragon_from_the_future": 2}
	odd["mount"] = "glow_stag"
	var fixed := Game._repair(odd)
	check(fixed.mounts == {"thunder_wolf": 3}, "repair drops unknown and level-0 mounts (%s)" % str(fixed.mounts))
	check(fixed.mount == "", "repair clears an active mount that isn't owned")
	var older: Dictionary = saved.duplicate(true)
	older.erase("mounts")
	older.erase("mount")
	check(Game._valid_profile(older.duplicate(true)), "an old save without mounts still loads")
	var older_fixed := Game._repair(older)
	check(older_fixed.mounts == {} and older_fixed.mount == "", "an old save gets no mounts")
	var with_mats: Dictionary = saved.duplicate(true)
	with_mats["inv"] = [ItemData.jewel("drake_scale", 3), ItemData.jewel("wolf_fang", 1)]
	check(Game._valid_profile(with_mats), "materials in the bag are a valid save")


func _riding() -> void:
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	await settle()
	var walk := hero.move_speed()
	var hp_on_foot := int(hero.stats.max_hp)
	check(hero.can_ride_here(), "the open field allows riding")
	check(hero.toggle_ride() and hero.is_riding(), "the ride button mounts the wolf")
	check(is_equal_approx(hero.move_speed(), walk * (1.0 + MountData.speed_bonus("thunder_wolf"))), "riding adds the wolf's +30%% (%.2f -> %.2f)" % [walk, hero.move_speed()])
	check(not hero.visual.held_stowed and hero.visual.seated, "the rider sits with the weapon in hand")
	check(int(hero.stats.max_hp) == hp_on_foot, "the mount's HP counts the same ridden or not")
	var held_shown := 0
	for n in hero.visual._skeleton.get_children():
		if n.has_meta(&"held") and (n as Node3D).visible:
			held_shown += 1
	check(held_shown > 0, "the weapon is drawn while riding (%d)" % held_shown)
	hero._ride_step(4.0)
	check(hero.visual.current == Hero.RIDE_UPPER and hero.visual.seated, "the rider sits in its ready stance (%s)" % hero.visual.current)
	check(hero.visual.anim.has_animation(Hero.RIDE_CLIP), "the riding clip exists on the hero model")
	await _saddle(hero)
	Game.select_mount("glow_stag")
	check(hero.mount != null and hero.mount.id == "glow_stag", "picking another mount swaps the ridden body")
	check(is_equal_approx(hero.move_speed(), walk * 1.35), "the stag's +35%")
	check(not hero.toggle_ride() and not hero.is_riding(), "the ride button again gets off")
	check(is_equal_approx(hero.move_speed(), walk), "on foot the speed is back")
	check(not hero.visual.held_stowed and not hero.visual.seated, "on foot the weapon is still in hand, standing")
	check(hero.visual.position.x == 0.0 and hero.visual.position.z == 0.0, "the rider's seat offset is gone on foot")
	# The hero fights from the saddle: nothing that fights puts it on foot.
	var mob := _dummy(field, hero)
	check(hero.ride() and hero.is_riding(), "back in the saddle")
	hero.tap_attack()
	check(hero.is_riding() and hero.engaged, "attacking keeps the hero riding")
	hero._basic_attack()
	check(hero.is_riding() and hero.visual.current != Hero.RIDE_UPPER, "a swing plays from the saddle (%s)" % hero.visual.current)
	hero.tap_target(mob)
	check(hero.is_riding() and hero.target == mob, "tapping a target keeps the hero riding")
	hero.cooldowns.clear()
	hero._cast_until = 0
	Game.profile.mp = 99999
	Game.fill_loadout()
	var slot := -1
	var skills: Array = Game.class_data().skills
	for i in skills.size():
		if skills[i] is Dictionary and not (skills[i] as Dictionary).is_empty() and Game.skill_unlocked(skills[i]):
			slot = i
			break
	check(slot >= 0, "the warrior has a skill on the bar")
	if slot >= 0:
		var why := hero.use_skill(slot)
		check(why == "" and hero.is_riding(), "a skill is pressed from the saddle (%s)" % why)
		hero._cast_until = 0
		hero._cast(skills[slot])
		check(hero.is_riding() and hero.visual.seated and hero.visual.current != Hero.RIDE_UPPER, "the skill plays from the saddle (%s)" % hero.visual.current)
	hero._pending = {}
	hero.visual.release()
	# A hit, landed or dodged, never knocks the rider off: try both ways.
	var dodge := float(hero.stats.dodge)
	hero.stats.dodge = 0.0
	var hp := int(Game.profile.hp)
	hero._invulnerable_until = 0
	hero.take_damage(50.0)
	check(hero.is_riding() and int(Game.profile.hp) < hp, "a landed hit keeps the hero riding (%d -> %d)" % [hp, int(Game.profile.hp)])
	hero.stats.dodge = 1.0
	hero._invulnerable_until = 0
	hero.take_damage(50.0)
	check(hero.is_riding(), "a dodged hit keeps the hero riding")
	hero.stats.dodge = dodge
	hero.set_auto(true)
	check(hero.is_riding() and hero.auto, "auto hunting keeps the hero riding")
	hero.ride()
	check(hero.auto, "getting on again doesn't stop auto hunting")
	hero.set_auto(false)
	hero.engaged = false
	hero.set_target(null)
	mob.queue_free()
	# Death puts the hero down.
	hero._die()
	check(not hero.is_riding() and not hero.visual.seated, "dying dismounts")
	check(not hero.ride(true), "no riding while dead")
	hero._dead = false
	Game.profile.hp = 99999
	hero.visual.release()
	# No-riding zones: can't get on, and riding into one puts the hero down.
	for zone_id in [&"guildwar", &"pvp", &"tower", &"arena"]:
		hero.field = field
		hero.ride()
		check(hero.is_riding(), "riding before %s" % zone_id)
		var zone := Zone.new()
		zone.data = ZoneData.get_zone(zone_id)
		hero.field = zone
		check(not hero.can_ride_here(), "%s forbids riding" % zone_id)
		hero.set_physics_process(true)
		await get_tree().physics_frame
		await get_tree().physics_frame
		hero.set_physics_process(false)
		check(not hero.is_riding(), "entering %s dismounts" % zone_id)
		check(not hero.ride(true), "can't mount in %s" % zone_id)
		hero.field = field
		zone.free()
	# The HUD button: hidden without a mount, "ขี่" / "ลง" with one.
	var hud := HUD.new()
	add_child(hud)
	hud.set_process(false)
	hud.hero = hero
	hud._update_mount_row()
	check(hud.mount_chip_text() == "ขี่", "HUD shows ขี่ with a mount (%s)" % hud.mount_chip_text())
	hud.tap_mount()
	check(hero.is_riding() and hud.mount_chip_text() == "ลง", "tapping ขี่ rides, the chip says ลง")
	hud.tap_mount()
	check(not hero.is_riding() and hud.mount_chip_text() == "ขี่", "tapping ลง gets off")
	var keep: Dictionary = Game.profile.duplicate(true)
	Game.profile["mounts"] = {}
	Game.profile["mount"] = ""
	hud._update_mount_row()
	check(hud.mount_chip_text() == "" and not hud._mount_row.visible, "HUD button hidden without a mount")
	Game.profile["mounts"] = keep.mounts
	Game.profile["mount"] = keep.mount
	hud.queue_free()
	field.queue_free()
	await settle()


## A harmless monster in front of the hero to aim at.
func _dummy(field: Node3D, hero: Hero) -> Mob:
	var at := hero.global_position + Vector3(0, 0, 2.0)
	var mob := Mob.new()
	mob.setup(&"forest_orc", 1, at, hero)
	field.add_child(mob)
	mob.set_physics_process(false)
	mob.global_position = at
	return mob


## While riding, a swing, a cast and a hit move the arms but keep the hips and legs
## in the seated clip's pose (SaddlePose); the clip itself and life on foot are untouched.
func _saddle(hero: Hero) -> void:
	var visual := hero.visual
	var skeleton := visual._skeleton
	var saddle := skeleton.get_node_or_null("SaddlePose") as SaddlePose
	check(saddle != null and saddle.active, "riding adds the SaddlePose modifier")
	if saddle == null:
		return
	var legs := skeleton.find_bone("LeftUpperLeg" if visual.chibi else "upperleg.l")
	var arm := skeleton.find_bone("RightUpperArm" if visual.chibi else "upperarm.r")
	var spine := skeleton.find_bone("Spine" if visual.chibi else "spine")
	check(legs >= 0 and legs in saddle.bones, "the legs are held seated")
	check(arm >= 0 and not (arm in saddle.bones) and spine >= 0 and not (spine in saddle.bones), "the spine and arms stay free")
	# Let the seated clip blend in. Godot 4.3 puts the animated pose back after
	# drawing: read the drawn pose in skeleton_updated.
	await get_tree().create_timer(0.5).timeout
	await skeleton.skeleton_updated
	var sit_leg := skeleton.get_bone_global_pose(legs)
	var sit_arm := skeleton.get_bone_global_pose(arm)
	var attack: Dictionary = Game.class_data().attack
	var clip: String = attack.anims[0]
	var length := visual.action(clip)
	var moved := 0.0
	var drift := 0.0
	var seat_gap := 0.0
	var held_leg: Variant = null
	var end := Time.get_ticks_msec() + int(length * 700.0)
	while Time.get_ticks_msec() < end:
		hero._ride_step(0.0)
		await skeleton.skeleton_updated
		var leg := skeleton.get_bone_global_pose(legs).origin
		if held_leg == null:
			held_leg = leg
		moved = maxf(moved, skeleton.get_bone_global_pose(arm).basis.get_rotation_quaternion().angle_to(sit_arm.basis.get_rotation_quaternion()))
		drift = maxf(drift, leg.distance_to(held_leg))
		seat_gap = maxf(seat_gap, leg.distance_to(sit_leg.origin))
	check(moved > 0.2, "the sword arm swings from the saddle (%.2f rad)" % moved)
	check(drift < 0.005, "the legs hold still through the swing (%.4f)" % drift)
	check(seat_gap < 0.08, "the legs keep the seated clip's pose (%.3f)" % seat_gap)
	check(not visual.held_stowed, "the weapon is in hand mid-swing")
	# Back to sitting once the swing ends.
	end = Time.get_ticks_msec() + int(length * 600.0) + 400
	while Time.get_ticks_msec() < end:
		hero._ride_step(0.0)
		await get_tree().process_frame
	check(visual.current == Hero.RIDE_UPPER, "the rider is back in its ready stance after the swing (%s)" % visual.current)


func _card(menu: GameMenu, id: String) -> Node:
	return menu._content.find_child("Mount_" + id, true, false)


func _menu() -> void:
	Game.profile["mounts"] = {}
	Game.profile["mount"] = ""
	for mat in MATS.values():
		clear(mat)
	clear("chaos")
	var menu := GameMenu.new()
	add_child(menu)
	var ids: Array = []
	for tab in GameMenu.TABS:
		ids.append(String(tab[0]))
	check(ids.has("mounts"), "the menu has a สัตว์ขี่ tab")
	menu.open_menu(&"mounts")
	await settle()
	for id in MountData.ORDER:
		var card := _card(menu, id)
		check(card != null, "card for %s" % id)
		if card == null:
			continue
		check(card.find_child("Buy", true, false) == null, "%s has no buy button" % id)
		check(card.find_child("Colour", true, false) is ColorRect and card.find_child("MatIcon", true, false) is TextureRect, "%s card has its colour and material icon" % id)
		var title := card.find_child("Title", true, false) as Label
		check(title != null and title.text.contains("Lv.0/5"), "%s shows Lv.0 (%s)" % [id, title.text if title else ""])
		var craft := card.find_child("Craft", true, false) as Button
		check(craft != null and craft.text == "สร้าง" and craft.disabled, "%s: สร้าง is off without materials" % id)
		var cost := card.find_child("Cost", true, false) as Label
		check(cost != null and cost.text.contains("0/1") and cost.text.contains("0/%d" % CHAOS[id]), "%s cost shows owned/needed (%s)" % [id, cost.text if cost else ""])
		check(card.find_child("Next", true, false) != null, "%s shows the next level's stats" % id)
		for label in card.find_children("*", "Label", true, false):
			check(not (label as Label).text.contains("เหรียญ"), "%s card shows no gold price" % id)
	give("wolf_fang", 1)
	give("chaos", 5)
	menu._rebuild()
	await settle()
	var wolf_craft := _card(menu, "thunder_wolf").find_child("Craft", true, false) as Button
	check(wolf_craft != null and not wolf_craft.disabled, "the wolf can be crafted with 1 fang + 5 chaos")
	wolf_craft.pressed.emit()
	await settle()
	check(Game.mount_level("thunder_wolf") == 1 and Game.active_mount() == "thunder_wolf", "menu craft makes the wolf Lv.1 and active")
	var wolf := _card(menu, "thunder_wolf")
	var up := wolf.find_child("Craft", true, false) as Button
	check(up != null and up.text == "อัปเลเวล" and up.disabled, "the wolf now offers อัปเลเวล, off while short")
	check((wolf.find_child("Title", true, false) as Label).text.contains("Lv.1/5"), "the card shows Lv.1")
	check((wolf.find_child("Now", true, false) as Label).text.contains("HP +1%"), "current stats: HP +1%")
	check((wolf.find_child("Next", true, false) as Label).text.contains("HP +2%"), "next stats: HP +2%")
	check(wolf.find_child("Select", true, false) == null, "the active wolf has no pick button")
	give("wolf_fang", 2)
	give("chaos", 10)
	menu._rebuild()
	await settle()
	up = _card(menu, "thunder_wolf").find_child("Craft", true, false) as Button
	check(not up.disabled, "2 fangs + 10 chaos open Lv.2")
	up.pressed.emit()
	await settle()
	check(Game.mount_level("thunder_wolf") == 2 and Game.mount_mats("thunder_wolf") == 0 and Game.jewel_count("chaos") == 0, "menu upgrade to Lv.2 spends 2 fangs + 10 chaos")
	Game.profile.mounts["thunder_wolf"] = 5
	give("stag_antler", 1)
	give("chaos", 8)
	Game.craft_mount("glow_stag")
	menu._rebuild()
	await settle()
	var maxed := _card(menu, "thunder_wolf").find_child("Craft", true, false) as Button
	check(maxed.text == "MAX" and maxed.disabled, "Lv.5 shows MAX, off")
	check(_card(menu, "thunder_wolf").find_child("Next", true, false) == null, "no next level past Lv.5")
	var pick := _card(menu, "glow_stag").find_child("Select", true, false) as Button
	check(pick != null, "an owned, inactive mount has ใช้ตัวนี้")
	if pick != null:
		pick.pressed.emit()
		await settle()
	check(Game.active_mount() == "glow_stag", "menu pick makes the stag active")
	menu.close_menu()
	menu.queue_free()
	await settle()
