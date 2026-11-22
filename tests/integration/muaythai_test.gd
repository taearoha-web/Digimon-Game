extends Node
## The Muay Thai fighter (นักมวยประเจียด, ClassData "muaythai"): its data across the
## tables a class needs, its 8 skill lines, the class mechanics (MuayThai: combo and its
## decay, hit-heal growing with the combo, the ultimates spending it, the kick and the
## throw), the orbiting mantra rings (MantraRings: 2 / 4 / 6 by level, one cheap node,
## hidden far away), the kick pushing a guild war leader off the altar (its capture
## pauses), the AI casting its lines, and a save / online look round trip.
##   godot --headless --path . res://tests/integration/muaythai_test.tscn
var failures := 0
var checks := 0
var main: Node
const MT := &"muaythai"


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _ready() -> void:
	InputSetup.ensure_defaults()
	WorldEvents.festival_enabled = false
	GameSettings.load_settings()
	_data()
	_lines()
	await _rings()
	await _robes()
	await _guild_war()
	await _field()
	_save_round_trip()
	print("muaythai_test: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------

func _data() -> void:
	check(ClassData.IDS.has(MT) and ClassData.IDS.size() == 11, "eleven playable classes, the Muay Thai fighter among them")
	var data := ClassData.get_class_data(MT)
	check(String(data.name) == "นักมวยประเจียด" and String(data.short) == "นักมวย", "its Thai name and short label")
	check(String(data.main) == "str" and String(data.sub) == "vit" and String(data.weapon_kind) == "wraps", "STR main, VIT second, hand wraps")
	check(not bool(data.attack.projectile) and String(data.attack.anims[0]) == "Unarmed_Melee_Attack_Punch_A", "a melee punch for its basic attack")
	for advance in 4:
		check(not JobData.step(MT, advance).is_empty() and String(JobData.step(MT, advance).name) != "", "advancement %d has a Thai name" % (advance + 1))
	check(ClassRoles.trait_of(MT).get("name", "") == "หมัดปลุกใจ", "its party role")
	check(StarSkillData.pool(MT).size() == 5 and StarSkillData.is_god(StarSkillData.pool(MT)[4]), "five star skills, the last a god skill")
	for star in StarSkillData.pool(MT):
		check(SkillIcons.for_skill(star) != null, "%s has its medallion" % star.id)
		check(StarSkillArt.handles(star), "%s has its star art colours" % star.id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for level in [5, 55, 95]:
		var w := ItemData.generate(level, MT, rng, 2, "weapon")
		check(String(w.base) == "wraps" and String(w.name).begins_with("สนับมือ") and ItemLook.look_of(w).begins_with("wraps_"), "a Lv.%d weapon is a pair of knuckle dusters (%s)" % [level, w.name])
	# Knuckle dusters (สนับมือ) everywhere: star, set, divine and dragon names; pieces
	# dropped as นวม show under the new name, the tier names mapped one to one.
	var star_names := StarGearData.catalogue().filter(func(i): return String(i.class) == "muaythai" and String(i.slot) == "weapon").map(func(i): return String(i.name))
	check(star_names.size() == 4 and star_names.all(func(n): return n.begins_with("สนับมือ")), "the star knuckle dusters' names (%s)" % [star_names])
	check(SetGearData.item_name("muaythai", "weapon").begins_with("สนับมือ") and DivineGearData.item_name("muaythai", "weapon").begins_with("สนับมือ")
		and DragonGearData.weapon_name("muaythai").begins_with("สนับมือ"), "the set, divine and dragon knuckle dusters' names")
	check(ItemData.name_of({"kind": "equip", "slot": "weapon", "base": "wraps", "name": "นวมผ้าดิบ ล้ำค่า", "plus": 2}) == "+2 สนับมือเหล็กดิบ ล้ำค่า"
		and ItemData.name_of({"kind": "equip", "slot": "weapon", "base": "wraps", "name": "นวมเทพมังกรอัคนี"}) == "สนับมือเทพมังกรอัคนี"
		and ItemData.name_of({"kind": "equip", "slot": "weapon", "base": "wraps", "name": "นวมมวยเทพอัคนี แห่งตำนาน"}) == "สนับมือมวยเทพอัคนี แห่งตำนาน",
		"old นวม pieces show as สนับมือ")
	check(ItemData.NAMES.wraps.all(func(n): return String(n).begins_with("สนับมือ")) and ItemData.RENAMED_WRAPS.size() == 10, "the ten tiers are knuckle dusters")
	check(ItemData.WING_INFO.has("muaythai") and StarWingData.INFO.has("muaythai"), "its wings and star wings")
	var star_weapons := StarGearData.catalogue().filter(func(i): return String(i.class) == "muaythai" and String(i.slot) == "weapon")
	check(star_weapons.size() == 4 and star_weapons.all(func(i): return String(i.base) == "wraps"), "four star knuckle dusters")
	check(SetGearData.THEMES.has("muaythai") and SetGearData.PALETTES.has("muaythai"), "its 250-star set")
	check(DivineGearData.THEMES.has("muaythai") and DragonGearData.SIGNATURE.has("muaythai"), "its divine and dragon gear")
	var divine := DivineGearData.item(MT, "weapon", rng)
	check(not divine.is_empty() and divine.stats.has("atk"), "the divine knuckle dusters hit with ATK")
	for look in ["wraps_0", "wraps_9", "star_wraps_200", "set_wraps_muaythai", "divine_wraps_muaythai_200", "dragon_wraps_muaythai"]:
		var node := WeaponKit.build(look) if not look.begins_with("star_") else StarGearArt.build(look)
		var meshes := node.find_children("*", "MeshInstance3D", true, false)
		var surfaces := (meshes[0] as MeshInstance3D).mesh.get_surface_count() if meshes.size() == 1 else 0
		check(meshes.size() == 1 and surfaces >= 2 and surfaces <= 5, "%s is one baked mesh of a few surfaces (%d meshes, %d surfaces)" % [look, meshes.size(), surfaces])
		node.free()
	check(ClassSelect.class_lines(MT).role.contains("หมัดปลุกใจ"), "the create screen tells its role")


func _lines() -> void:
	check(ClassData.has_lines(MT) and ClassData.line_ids(MT).size() == 8, "8 skill lines")
	var top := ClassData.kit(MT, 100, 5).filter(func(s): return not s.has("star")).map(func(s): return String(s.id))
	check(top == ["sun_fist", "thunder_elbow", "mantra_storm", "earth_kick", "fire_dragon_circle", "sacred_mongkhon", "iron_prajiad", "muay_king"], "the Lv.100 stages (%s)" % [top])
	for skill in ClassData.pool(MT):
		check(SkillIcons.for_skill(skill) != null, "%s has its medallion" % skill.id)
		check(bool(SkillChoreography.cue_for(skill).choreographed), "%s has a choreographed motion" % skill.id)
	check(ClassData.find_skill(MT, "push_kick").fx.has("kick") and ClassData.find_skill(MT, "body_throw").fx.has("stun"), "the kick and the throw")
	check(ClassData.find_skill(MT, "thousand_ring_fist").fx.has("combo_power") and ClassData.find_skill(MT, "muay_king").fx.has("combo_power"), "the ultimates grow with the combo")
	check(BuffBook.is_self_only(ClassData.find_skill(MT, "ring_guard").fx.buff) and float(ClassData.find_skill(MT, "iron_prajiad").fx.buff.reflect) > 0.0, "the ring guard is the fighter's own and reflects at its second stage")
	check(not BuffBook.reaches_party(ClassData.find_skill(MT, "sacred_mongkhon").fx.buff), "มงคลศักดิ์สิทธิ์ is the fighter's own (party-buff rule: only Priest, Bard, เบ่งเลือด reach the party)")
	# Passives: hit-heal and the combo window.
	var p := {"class": MT, "level": 100, "adv": 4, "skills": {"fighter_heart": 5, "muay_rhythm": 5}, "equip": {}, "attrs": {}}
	var bonus := HeroStats.passive_bonus(p)
	check(is_equal_approx(float(bonus.hit_heal), 0.025) and is_equal_approx(float(bonus.combo), 1.0), "ใจนักสู้ and จังหวะมวย at ★5 (+2.5%% hit-heal, +1 s combo)")


# ---------------------------------------------------------------------------
# The mantra rings
# ---------------------------------------------------------------------------

func _rings() -> void:
	check(MuayThai.ring_count(1) == 2 and MuayThai.ring_count(59) == 2 and MuayThai.ring_count(60) == 4 and MuayThai.ring_count(89) == 4 and MuayThai.ring_count(90) == 6 and MuayThai.ring_count(100) == 6, "2 rings, 4 from Lv.60, 6 from Lv.90")
	var holder := Node3D.new()
	add_child(holder)
	var visuals: Array[HeroVisual] = []
	for gender in 2:
		var v := HeroVisual.new()
		holder.add_child(v)
		v.setup(MT, "", true, {}, {"gender": gender, "body": 0})
		visuals.append(v)
	var other := HeroVisual.new()
	holder.add_child(other)
	other.setup(&"warrior", "", true, {}, {"gender": 0, "body": 0})
	await _frames(2)
	check(not is_instance_valid(other.rings), "another class has no rings")
	var a := visuals[0]
	check(is_instance_valid(a.rings) and a.rings.multimesh.instance_count == 2, "a new fighter wears 2 rings")
	for level in [60, 90, 30]:
		a.set_mantra_level(level)
		check(a.rings.multimesh.instance_count == MuayThai.ring_count(level), "Lv.%d: %d rings" % [level, MuayThai.ring_count(level)])
	a.set_mantra_level(90)
	# The budget: one node and one draw for all the rings, one mesh and one material shared
	# by every fighter, no shadow, no light, no particles.
	var nodes := a.rings.find_children("*", "", true, false).size()
	check(nodes == 0 and a.rings is MultiMeshInstance3D, "the rings are a single MultiMesh node (%d children)" % nodes)
	check(a.rings.multimesh.mesh == visuals[1].rings.multimesh.mesh and a.rings.multimesh.mesh.surface_get_material(0) == MantraRings.material(), "every fighter shares one ring mesh and one material")
	check(a.rings.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and (MantraRings.material() as StandardMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "unshaded, no shadow")
	check((a.rings.multimesh.mesh as TorusMesh).rings * (a.rings.multimesh.mesh as TorusMesh).ring_segments <= 64, "a low-poly band")
	check(a.find_children("*", "OmniLight3D", true, false).is_empty() and a.find_children("*", "GPUParticles3D", true, false).is_empty(), "no light or particles with the rings")
	var before := a.rings._time
	await _frames(4)
	check(a.rings._time > before, "the rings orbit")
	a.set_far(true)
	await _frames(2)
	check(not a.rings.visible, "far from the camera the rings are hidden")
	a.set_far(false)
	await _frames(2)
	check(a.rings.visible, "and shown again near")
	a.rings.lend(0.2)
	check(not a.rings.visible, "thrown rings leave the orbit")
	await _wait(0.35)
	check(a.rings.visible, "and come back")
	# The lowest quality moves them every other frame without the bob.
	var q := GameSettings.quality
	GameSettings.quality = 0
	var cheap := HeroVisual.new()
	holder.add_child(cheap)
	cheap.setup(MT, "", true, {}, {"gender": 0, "body": 1})
	check(cheap.rings._cheap, "the lowest quality runs the cheap orbit")
	GameSettings.quality = q
	# The knuckle dusters on both fists, on every body.
	for gender in 2:
		for body in ChibiBodies.count(gender):
			var v := HeroVisual.new()
			holder.add_child(v)
			v.setup(MT, "", true, {"weapon": ItemData.generate(95, MT, RandomNumberGenerator.new(), 2, "weapon")}, {"gender": gender, "body": body})
			var held := v._skeleton.find_children("Held_wraps_*", "BoneAttachment3D", false, false)
			check(held.size() == 2 and (held[0] as BoneAttachment3D).bone_name != (held[1] as BoneAttachment3D).bone_name, "body %d/%d wears knuckle dusters on both fists" % [gender, body])
			v.free()
	holder.queue_free()
	await _frames(2)


# ---------------------------------------------------------------------------
# The ring robes: a cape in the wing slot, never wings
# ---------------------------------------------------------------------------

## A cape shader parameter (0 when the layer leaves it at the shader's default).
func _param(sm: ShaderMaterial, key: String) -> float:
	var value: Variant = sm.get_shader_parameter(key)
	return 0.0 if value == null else float(value)


func _robes() -> void:
	check(CapeArt.wears_cape("muaythai") and CapeArt.wears_cape("darklord") and not CapeArt.wears_cape("lancer"), "the fighter and the Lord wear capes, the lancer wings")
	check(String(ItemData.WING_INFO.muaythai.name) == "ผ้าคลุมนักมวย" and StarWingData.item_name("muaythai") == "ผ้าคลุมมนตราดารา", "the robes' names")
	check(ItemData.name_of({"kind": "equip", "slot": "wings", "wing": "muaythai", "name": "ปีกเพลิงมนตราดารา แห่งเทพนิยาย", "plus": 3}) == "+3 ผ้าคลุมมนตราดารา แห่งเทพนิยาย"
		and ItemData.name_of({"kind": "equip", "slot": "wings", "wing": "muaythai", "name": "ปีกเพลิงประเจียด ล้ำค่า"}) == "ผ้าคลุมนักมวย ล้ำค่า", "pieces dropped as wings show their robe names")
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var holder := Node3D.new()
	add_child(holder)
	for star in [false, true]:
		var tier := "100★" if star else "Lv.100"
		var item := StarWingData.item("muaythai", rng, 4) if star else ItemData.wings(rng, "muaythai", 3)
		var v := HeroVisual.new()
		holder.add_child(v)
		v.setup(MT, "", true, {"wings": item}, {"gender": 0, "body": 0})
		await _frames(2)
		var robe := v.find_child("Wings_star_muaythai" if star else "Wings_muaythai", true, false) as CapeArt
		check(robe != null and robe.cls == "muaythai" and robe.star == star, "%s: the wing slot shows the robe" % tier)
		if robe == null:
			continue
		# Nothing of the old fire dragon pair, no feather capelet or collar of the Lord's.
		check(v.find_children("Wings_lancer*", "", true, false).is_empty() and robe.find_children("*", "Skeleton3D", true, false).is_empty(), "%s: no wing model under it" % tier)
		var mats := {}
		var layers := 0
		var tails: Array[MeshInstance3D] = []
		var tris := 0
		for mi in robe.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.material_override is ShaderMaterial and (m.material_override as ShaderMaterial).shader == CapeArt.SHADER:
				mats[m.material_override] = true
				layers += 1
				var sm := m.material_override as ShaderMaterial
				check(_param(sm, "boxer") == (2.0 if star else 1.0) and _param(sm, "kind") != 1.0 and _param(sm, "kind") != 2.0, "%s: %s is a boxer layer (no capelet, no collar)" % [tier, m.name])
				if _param(sm, "ribbon") > 0.5:
					tails.append(m)
				tris += m.mesh.surface_get_array_index_len(0) / 3
		# The four prajiad tails are one mesh: four grids told apart by their vertex colour.
		var tail_colors := {}
		if tails.size() == 1:
			for c in tails[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
				tail_colors[c] = true
		check(tails.size() == 1 and tail_colors.size() == 4, "%s: the four prajiad tails are one mesh (%d tagged tails)" % [tier, tail_colors.size()])
		check(mats.size() == (3 if star else 2) and layers == (3 if star else 2), "%s: robe, tails%s: %d layers on %d materials" % [tier, " and the mantra ring" if star else "", layers, mats.size()])
		check((robe.find_child("MantraRing", true, false) != null) == star, "%s: %s" % [tier, "the mantra ring floats behind" if star else "no mantra ring"])
		var meshes := robe.find_children("*", "MeshInstance3D", true, false).size()
		check(meshes <= 10 and tris < 4000, "%s: phone-sized (%d meshes, %d triangles)" % [tier, meshes, tris])
		check(robe.find_children("*", "Light3D", true, false).is_empty() and robe.find_children("*", "GPUParticles3D", true, false).is_empty() and robe.find_children("*", "CPUParticles3D", true, false).is_empty(), "%s: no lights or particles" % tier)
		v.set_wing_mode(HeroVisual.WING_FOLD, true)
		await _wait(0.5)
		check(robe.fold > 0.9, "%s: folding gathers the robe" % tier)
		v.set_wing_mode(HeroVisual.WING_FLY, true)
		await _wait(0.9)
		check(v.flying() and robe.fold < 0.1 and robe.billow > 0.4, "%s: flying streams it out (billow %.2f)" % [tier, robe.billow])
		v.free()
	# The Dragon God robe: the star robe in jade, no wings.
	var dragon := DragonWingArt.build("muaythai", true)
	var dragon_robe := dragon.find_child("DragonCape", true, false) as CapeArt
	check(dragon_robe != null and dragon_robe.cls == "muaythai" and dragon.find_child("WingR", true, false) == null, "the dragon robe has no wings")
	dragon.free()
	# Icons and the shop come from the same builders.
	for id in ["wings_muaythai", "star_wings_muaythai_100", "dragon_wings_muaythai"]:
		check(ItemLook.icon_for_id(id) != null, "%s has its icon" % id)
	# The Dark Lord's capes are untouched: three layers (cape, feather capelet, collar)
	# and the gem clasps, on the royal or galaxy style.
	for star in [false, true]:
		var cape := CapeArt.build(star) as CapeArt
		var kinds: Array[float] = []
		for mi in cape.find_children("*", "MeshInstance3D", true, false):
			var sm := (mi as MeshInstance3D).material_override as ShaderMaterial
			if sm == null or sm.shader != CapeArt.SHADER:
				continue
			kinds.append(_param(sm, "kind"))
			check(_param(sm, "boxer") == 0.0 and _param(sm, "style") == (1.0 if star else 0.0), "the Lord's %s cape layer keeps its style" % ("star" if star else "Lv.100"))
		check(cape.cls == "darklord" and String(cape.name) == ("Wings_star_darklord" if star else "Wings_darklord") and kinds == [0.0, 1.0, 2.0] and cape.find_child("Clasps", true, false).get_child_count() == 4, "the Lord's %s cape: cape, capelet, collar and clasps" % ("star" if star else "Lv.100"))
		cape.free()
	holder.queue_free()
	await _frames(2)


# ---------------------------------------------------------------------------
# Guild war: the kick and the throw push a leader off the altar
# ---------------------------------------------------------------------------

func _guild_war() -> void:
	Game.set_process(false)
	Game.new_profile(MT, "Muay GW")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	Game.profile.hp = Game.stats_now().max_hp
	Game.guildwar_party_chosen = false
	Game.current_zone = &"guildwar"
	Game.guildwar_save_checkpoint(7, GuildWarData.DURATION, false, [0, 0], 0, 0, 0, {"gates": [0, 0, 0, 0, 0], "owner": -1})
	Game.guildwar_resuming = true
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	add_child(zone)
	var m: GuildWarMatch = zone.gw_match
	check(m != null and GuildWarMatch.in_war(), "a guild war is on")
	if m == null:
		zone.queue_free()
		return
	if m.ally_leader == null:
		m.ally_leader = GuildWarMatch.pick_leader(m.allies)
		m.ally_leader.make_leader()
	m._timer = 0.05
	for i in 30:
		await _frames(1)
		if m.state == "fight":
			break
	check(m.state == "fight", "the war has begun")
	var hero: Hero = m.hero
	hero.set_physics_process(false)
	var lead: GuildFighter = m.enemy_leader
	check(lead != null, "the other guild has a leader")
	if lead == null:
		zone.queue_free()
		return
	# Everyone else stays out of it.
	for f in m.allies + m.enemies:
		if f != lead:
			f.global_position = GuildWarMatch.hero_camp() + Vector3(randf_range(-4, 4), 0.3, randf_range(-4, 4))
			f.set_physics_process(false)
	for kick_from in ["hero", "ai"]:
		lead.global_position = SiegeArena.ALTAR + Vector3(0.4, 0.3, 0.6)
		lead.velocity = Vector3.ZERO
		lead._stun = 0.0
		if not m.capture.is_empty():
			m._cancel_capture()
		m._start_capture(GuildFighter.TEAM_ENEMY, lead)
		await _frames(3)
		check(SiegeArena.on_altar(lead.global_position) and not bool(m.capture.get("paused", true)), "%s: the leader counts on the altar" % kick_from)
		var skill := ClassData.find_skill(MT, "push_kick")
		if kick_from == "hero":
			hero.global_position = SiegeArena.ALTAR + Vector3(0, 0.3, 2.5)
			MuayThai.skill_fx(hero, lead, skill.fx)
		else:
			# An AI Muay Thai fighter of our guild throws it (body_throw: the stun lasts).
			var ally: GuildFighter = m.allies[0]
			ally.member["class"] = "muaythai"
			ally.global_position = SiegeArena.ALTAR + Vector3(0, 0.3, 2.5)
			ally._hit(lead, 0.01, Color.WHITE, ClassData.find_skill(MT, "body_throw").fx)
		var paused := false
		for i in 90:
			await get_tree().physics_frame
			if bool(m.capture.get("paused", false)):
				paused = true
				break
		check(not SiegeArena.on_altar(lead.global_position), "%s: the kick put the leader off the yellow circle (%.1f m from its middle)" % [kick_from, Vector2(lead.global_position.x - SiegeArena.ALTAR.x, lead.global_position.z - SiegeArena.ALTAR.z).length()])
		check(paused, "%s: its capture count pauses" % kick_from)
	# A Muay Thai fighter in the war's AI values the kick on a leader on the altar.
	zone.queue_free()
	await _frames(3)
	Game.guildwar_resuming = false
	Game.set_process(true)


# ---------------------------------------------------------------------------
# The field: combo, hit-heal, finishers, kick, AI casts
# ---------------------------------------------------------------------------

func _field() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _wait(0.3)
	if main.title_screen:
		main.title_screen.queue_free()
		main.title_screen = null
	Game.new_profile(MT, "Muay QA", FaceKit.default_look())
	Game.profile.level = 30
	Game.profile.adv = 2
	WorldPresence.clock_offset = float(WorldPlayers.START_UNIX) + 40.0 * 86400.0 - WorldPlayers.now()
	main.hud.visible = true
	main._traveling = false
	await main.go(&"meadow", true)
	await _wait(0.5)
	var hero: Hero = main.zone.hero
	hero._invulnerable_until = 0
	hero.stats["dodge"] = 0.0
	hero.stats["crit"] = 0.0
	check(is_instance_valid(hero.visual.rings) and hero.visual.rings.multimesh.instance_count == 2, "the Lv.30 hero has 2 rings in the field")
	var mob: Mob = null
	for node in get_tree().get_nodes_in_group("mobs"):
		if node is Mob and not (node as Mob).is_boss and not (node as Mob).is_dead():
			mob = node
			break
	check(mob != null, "the meadow has monsters")
	if mob == null:
		return
	mob.max_hp = 100000000
	mob.hp = 100000000
	mob.set_physics_process(false)
	hero.global_position = mob.global_position + Vector3(0, 0, 1.5)
	# Combo: each hit adds one; it grows the damage.
	MuayThai.spend(hero)
	check(MuayThai.combo(hero) == 0 and is_equal_approx(MuayThai.damage_mult(hero), 1.0), "no combo at first")
	for i in 5:
		hero._deal_now(mob, 1.0, Color.WHITE, &"impact", true)
	check(MuayThai.combo(hero) == 5 and is_equal_approx(MuayThai.damage_mult(hero), 1.05), "five hits: combo 5, +5%% damage (%d)" % MuayThai.combo(hero))
	hero._deal_now(mob, 1.0, Color.WHITE, &"impact", true, ClassData.find_skill(MT, "jab_cross"))
	check(MuayThai.combo(hero) == 8, "หมัดตรง adds 2 more (%d)" % MuayThai.combo(hero))
	for i in 20:
		hero._deal_now(mob, 1.0, Color.WHITE, &"impact", true)
	check(MuayThai.combo(hero) == MuayThai.COMBO_MAX, "the combo stops at %d" % MuayThai.COMBO_MAX)
	# Hit-heal grows with the combo.
	var low := MuayThai.heal_share(hero)
	MuayThai.spend(hero)
	check(low > MuayThai.heal_share(hero) + 0.03, "a full combo heals more per hit (%.3f vs %.3f)" % [low, MuayThai.heal_share(hero)])
	Game.profile.hp = 100
	var hp0 := int(Game.profile.hp)
	for i in 6:
		hero._deal_now(mob, 3.0, Color.WHITE, &"impact", true)
	check(int(Game.profile.hp) > hp0, "hits heal the fighter (%d -> %d)" % [hp0, int(Game.profile.hp)])
	# The combo fades after the window.
	hero.set_meta(MuayThai.META, [10, Time.get_ticks_msec() - int(MuayThai.window(hero) * 1000.0) - 50])
	check(MuayThai.combo(hero) == 0, "the combo is gone after %.1f s without a hit" % MuayThai.window(hero))
	hero.set_meta(MuayThai.META, [10, Time.get_ticks_msec() - 1500])
	check(MuayThai.combo(hero) == 10, "but holds within it")
	# The finisher spends the combo for its power, for every target of the same cast.
	var fx := {"combo_power": 0.03}
	hero.set_meta(MuayThai.SPENT_META, [0, -100000])
	MuayThai.add_combo(hero, 0)
	var power := MuayThai.finisher(hero, fx)
	check(is_equal_approx(power, 1.3) and MuayThai.combo(hero) == 0, "the ultimate at combo 10 hits +30%% and spends it (%.2f)" % power)
	check(is_equal_approx(MuayThai.finisher(hero, fx), 1.3), "its other targets get the same power")
	# The rings cut damage taken.
	check(ClassRoles.guard(hero, 1000) == 960, "2 rings cut 4%% of damage taken (%d)" % ClassRoles.guard(hero, 1000))
	# The kick throws a monster back; the throw stuns.
	mob.set_physics_process(true)
	mob._stun = 0.0
	var start := mob.global_position
	hero._deal_now(mob, 0.5, Color.WHITE, &"impact", true, ClassData.find_skill(MT, "push_kick"))
	check(mob._stun > 0.3, "the kick holds it while it slides")
	for i in 60:
		await get_tree().physics_frame
	var moved := Vector2(mob.global_position.x - start.x, mob.global_position.z - start.z).length()
	check(moved > 2.5, "ถีบ throws the monster back (%.1f m)" % moved)
	mob._stun = 0.0
	hero._deal_now(mob, 0.5, Color.WHITE, &"impact", true, ClassData.find_skill(MT, "body_throw"))
	check(mob._stun >= 1.5, "จับทุ่ม stuns (%.1f s)" % mob._stun)
	mob.set_physics_process(false)
	# The ring guard buff.
	Game.profile.level = 70
	Game.profile.adv = 3
	hero.refresh_stats()
	check(hero.visual.rings.multimesh.instance_count == 4, "Lv.70: 4 rings")
	hero._apply_self_fx(ClassData.find_skill(MT, "iron_prajiad"))
	check(BuffBook.reflect(hero._buffs) >= 0.2, "ประเจียดเหล็ก reflects")
	hero._apply_self_fx(ClassData.find_skill(MT, "ram_muay"))
	check(MuayThai.buff_total(hero, "hit_heal") >= 0.05, "รำมวยบูชาครู raises the hit-heal")
	# An AI Muay Thai party member fights and casts its lines.
	await _ai_party(hero)
	# The online look: another player's game shows the class, its rings and its dusters.
	var look := PlayerLook.of_profile(Game.profile)
	var sent: Variant = JSON.parse_string(JSON.stringify(look))
	var remote := RemotePlayer.new()
	remote.setup({"id": "qa", "name": "Muay QA", "class": "muaythai", "level": 70, "look": sent})
	main.zone.add_child(remote)
	remote.apply_look(sent, 70, 0)
	await _frames(2)
	check(remote.visual.class_id == MT and is_instance_valid(remote.visual.rings) and remote.visual.rings.multimesh.instance_count == 4, "online: a Muay Thai player shows with 4 rings at Lv.70")
	check(remote.visual._skeleton.find_children("Held_wraps_*", "BoneAttachment3D", false, false).size() == 2, "online: and its knuckle dusters")
	remote.queue_free()
	main.queue_free()
	await _frames(3)


func _ai_party(hero: Hero) -> void:
	for i in Game.world_party.duplicate():
		Game.party_kick(i)
	var idx := -1
	var t := WorldPresence.clock()
	for i in WorldPlayers.size():
		if StringName(WorldPlayers.state(i, t)["class"]) == MT:
			idx = i
			break
	check(idx >= 0 and Game.party_invite(idx, true) == "", "a Muay Thai world player joins the party")
	await _wait(0.6)
	var member: Companion = null
	for c in main.zone.companions:
		if is_instance_valid(c) and StringName(c.member["class"]) == MT:
			member = c
	check(member != null, "it fights beside the hero")
	if member == null:
		return
	check(is_instance_valid(member.visual.rings) and member.visual.rings.multimesh.instance_count == MuayThai.ring_count(int(member.member.level)), "it wears its rings (Lv.%d)" % int(member.member.level))
	var mobs: Array = []
	for node in get_tree().get_nodes_in_group("mobs"):
		if node is Mob and not (node as Mob).is_dead() and not (node as Mob).is_boss:
			(node as Mob).max_hp = 100000000
			(node as Mob).hp = 100000000
			mobs.append(node)
	hero.global_position = (mobs[0] as Mob).global_position + Vector3(0, 0, 2.0)
	member.global_position = hero.global_position + Vector3(1.0, 0, 0)
	hero.set_target(mobs[0])
	var cast := {}
	for i in 24:
		await _wait(0.5)
		for id in member.cooldowns:
			if float(member.cooldowns[id]) > 0.0:
				cast[String(id)] = true
	var lines := cast.keys().filter(func(id): return ClassData.line_of(MT, String(id)) in ClassData.line_ids(MT))
	check(lines.size() >= 2, "the AI fighter casts its lines (%s)" % [cast.keys()])
	check(member.has_meta(MuayThai.META), "its hits build its combo")
	for i in Game.world_party.duplicate():
		Game.party_kick(i)


# ---------------------------------------------------------------------------
# Save round trip
# ---------------------------------------------------------------------------

func _save_round_trip() -> void:
	Game.new_profile(MT, "Muay Save", FaceKit.default_look())
	Game.profile.level = 64
	Game.profile.adv = 3
	Game.profile.skills["jab_cross"] = 4
	Game.fill_loadout()
	Game.slot = 3
	check(Game.save(), "the fighter saves")
	Game.profile["class"] = "warrior"
	Game.profile.level = 1
	Game.profile.skills.clear()
	check(Game.load_game(3), "and loads")
	check(Game.class_id() == MT and int(Game.profile.level) == 64 and int(Game.profile.skills.get("jab_cross", 0)) == 4, "its class, level and star ranks survive")
	var bar := Game.loadout_skills().filter(func(s): return not (s as Dictionary).is_empty()).map(func(s): return String(s.id))
	check(bar.has("flame_hook") and bar.has("ring_guard"), "its bar casts the Lv.64 stages (%s)" % [bar])
	check(String(Game.profile.equip.weapon.base) == "wraps", "its starter weapon is a pair of knuckle dusters")
