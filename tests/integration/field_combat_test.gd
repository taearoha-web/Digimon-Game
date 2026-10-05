extends Node
## Real-time field combat in the real starter zone: area skills hit several
## monsters, monsters fight back, a fainted partner is replaced, and a wiped
## party wakes up at the Recovery Terminal. Runs headless:
##   godot --headless --path . res://tests/integration/field_combat_test.tscn
## Exit code 0 = pass.

const TEST_DIR := "user://test_saves_field_combat"
const STEP_TIMEOUT := 30.0

var _failures: Array[String] = []
var _completed := false
var _toasts: Array[String] = []


func _ready() -> void:
	if not has_meta("driver"):
		var driver := Node.new()
		driver.set_script(get_script())
		driver.set_meta("driver", true)
		get_parent().remove_child.call_deferred(self)
		get_tree().root.add_child.call_deferred(driver)
		return
	await get_tree().process_frame
	TestCase.use_locale("en")
	SaveManager.save_dir = TEST_DIR
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	EventBus.toast_requested.connect(func(text: String, _kind: StringName): _toasts.append(text))
	await _run()
	if not _completed:
		_failures.append("test aborted before finishing (see errors above)")
	for slot in range(0, SaveManager.SLOT_COUNT + 1):
		SaveManager.delete_slot(slot)
	print("")
	if _failures.is_empty():
		print("FIELD COMBAT TEST: PASS")
	else:
		print("FIELD COMBAT TEST: FAIL (%d)" % _failures.size())
		for f in _failures:
			print("  - ", f)
	get_tree().quit(_failures.size())


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		print("  FAIL ", message)
		_failures.append(message)


func _run() -> void:
	var draft := NewGameDraft.new()
	draft.player_name = "Field"
	draft.appearance = CharacterAppearance.create_default(&"male")
	draft.starter_species_id = &"agumon"
	GameState.start_new_game(draft)
	GameData.recruitment_config.min_chance = 0.0 # keep the party exactly as scripted
	GameData.recruitment_config.max_chance = 0.0
	var lead := GameState.roster.get_lead()
	lead.level = 12
	lead.learn_skill(&"whirlwind")
	lead.learn_skill(&"claw_swipe")
	lead.learn_skill(&"inferno_burst")
	lead.auto_equip_skills()
	lead.full_restore()
	var buddy := DigimonInstance.create(&"gabumon", 8, RandomNumberGenerator.new())
	GameState.roster.add_digimon(buddy)

	SceneManager.goto_map(&"starter_zone", &"start", {"intro": true})
	await _wait_transition()
	var world := get_tree().current_scene as WorldMap
	_check(world != null and world.combat != null, "world has a FieldCombat")
	if world == null or world.combat == null:
		return
	await _seconds(1.0)
	var combat := world.combat
	await _clear_ambient(world)
	var meadow := world.get_node("Waypoints/wild_meadow") as Node3D
	_teleport(world, meadow.global_position + Vector3(-4, 0, 5))
	await _seconds(1.0)

	print("== Area skills hit a whole pack")
	var pack := _spawn_pack(world, meadow.global_position, [&"palmon", &"palmon", &"palmon"], 3, false)
	await _seconds(0.5)
	var blast := _find_skill(combat, SkillData.Shape.BLAST)
	_check(blast != null, "partner has a blast skill equipped (%s)" % [combat.get_skills().map(func(k): return k.id)])
	var hp_before := pack.map(func(w: WildDigimon): return w.instance.current_hp)
	combat.set_target(pack[1])
	_check(combat.use_skill(blast) == &"", "blast skill starts")
	await _seconds(2.5)
	var hurt := 0
	for i in pack.size():
		if is_instance_valid(pack[i]) and pack[i].instance.current_hp < hp_before[i]:
			hurt += 1
		elif not is_instance_valid(pack[i]) or pack[i].is_dead():
			hurt += 1
	_check(hurt >= 2, "blast on the middle monster also hit its neighbours (%d of 3)" % hurt)
	_check(combat.cooldown_left(blast) > 0.0, "blast is on cooldown")
	_check(combat.can_use(blast) != &"", "blast cannot be spammed")

	var burst := _find_skill(combat, SkillData.Shape.BURST)
	_check(burst != null, "partner has a burst skill equipped")
	if burst:
		await _clear_ambient(world)
		await _seconds(0.3)
		var alive := _spawn_pack(world, meadow.global_position, [&"goburimon", &"goburimon", &"goburimon"], 8, false)
		await _seconds(0.3)
		var before := alive.map(func(w: WildDigimon): return w.instance.current_hp)
		combat._cooldowns.clear()
		combat._gcd = 0.0
		combat.set_target(alive[0])
		_check(combat.use_skill(burst) == &"", "burst skill starts")
		await _seconds(3.0)
		var burst_hits := 0
		for i in alive.size():
			if not is_instance_valid(alive[i]) or alive[i].is_dead() or alive[i].instance.current_hp < before[i]:
				burst_hits += 1
		_check(burst_hits >= 2, "burst hit everything around the partner (%d of %d)" % [burst_hits, alive.size()])
	await _clear_ambient(world)

	print("== Monsters fight back")
	lead.full_restore()
	var attacker := _spawn_pack(world, meadow.global_position, [&"kunemon"], 6, true)[0]
	attacker.global_position = world.partner.global_position + Vector3(1.2, 0.3, 0)
	attacker.provoke()
	await _dismiss_popups(world)
	var hp_start := lead.current_hp
	var waited := 0.0
	while lead.current_hp >= hp_start and waited < 15.0: # attacks can miss: allow several swings
		await _seconds(0.5)
		waited += 0.5
	_check(lead.current_hp < hp_start, "the monster hurt the partner (%d -> %d HP)" % [hp_start, lead.current_hp])
	_check(world.partner.is_inside_tree(), "partner still on the field")
	# Kill it for the next section.
	combat.set_target(attacker)
	var fought := 0.0
	while is_instance_valid(attacker) and not attacker.is_dead() and fought < 40.0:
		for skill in combat.get_skills():
			if skill.target == SkillData.Target.ENEMY and combat.can_use(skill) == &"":
				combat.use_skill(skill)
				break
		await _seconds(0.3)
		fought += 0.3
	_check(not is_instance_valid(attacker) or attacker.is_dead(), "partner beat the attacker (%.1fs)" % fought)
	await _clear_ambient(world)

	print("== Fainted partner is replaced")
	lead.full_restore()
	_toasts.clear()
	var killer := _spawn_pack(world, meadow.global_position, [&"goburimon"], 20, true)[0]
	killer.global_position = world.partner.global_position + Vector3(1.2, 0.3, 0)
	lead.current_hp = 1
	killer.provoke()
	await _seconds(6.0)
	_check(lead.is_fainted() or GameState.roster.get_lead() != lead, "partner fainted")
	_check(GameState.roster.get_lead() == buddy, "the next party member stepped in (lead: %s)" % GameState.roster.get_lead().get_display_name())
	_check(_toasts.any(func(t): return "fainted" in t), "faint announced")
	await _seconds(0.5)
	_check(world.partner != null and world.partner.instance == buddy, "partner node follows the new lead")
	await _clear_ambient(world)

	print("== Wiped party wakes at the Recovery Terminal")
	_toasts.clear()
	buddy.current_hp = 1
	lead.current_hp = 0
	var reaper := _spawn_pack(world, meadow.global_position, [&"goburimon"], 20, true)[0]
	reaper.global_position = world.partner.global_position + Vector3(1.2, 0.3, 0)
	reaper.provoke()
	await _wait_for_wipe(world)
	_check(GameState.roster.get_lead().current_hp > 1 and not GameState.roster.is_party_defeated(), "party healed at the terminal")
	_check(not GameState.roster.is_party_defeated(), "no one is left fainted")
	_completed = true


# ---------------------------------------------------------------------------

## Level-up / evolution popups pause the game: close them like a player would.
func _dismiss_popups(world: WorldMap) -> void:
	var elapsed := 0.0
	while is_instance_valid(world.popups) and world.popups.is_busy() and elapsed < STEP_TIMEOUT:
		for node in world.popups.find_children("*", "Button", true, false):
			var b := node as Button
			if b.is_visible_in_tree() and not b.disabled and b.text in ["OK", "Later", "Continue"]:
				b.pressed.emit()
				break
		await get_tree().create_timer(0.15).timeout
		elapsed += 0.15


func _spawn_pack(world: WorldMap, center: Vector3, species: Array, level: int, aggressive: bool) -> Array[WildDigimon]:
	var pack: Array[WildDigimon] = []
	for i in species.size():
		var wild := WildDigimon.new()
		wild.setup(species[i], level, center, Vector3(6, 0, 6), world.player)
		wild.encounters_enabled = aggressive
		world.add_child(wild)
		var spot := center + Vector3(-1.0 + i * 1.1, 0, 0.4)
		wild.global_position = Vector3(spot.x, world.get_ground_height(spot.x, spot.z) + 0.3, spot.z)
		wild.set_physics_process(aggressive) # a still pack makes the area checks deterministic
		pack.append(wild)
	return pack


func _find_skill(combat: FieldCombat, shape: int) -> SkillData:
	for skill in combat.get_skills():
		if skill.target == SkillData.Target.ENEMY and skill.shape == shape:
			return skill
	return null


func _clear_ambient(world: WorldMap) -> void:
	await _dismiss_popups(world)
	for node in world.find_children("*", "EncounterSpawner", true, false):
		(node as EncounterSpawner).set_encounters_enabled(false)
		node.set_process(false)
	for node in get_tree().get_nodes_in_group("wild_digimon"):
		node.queue_free()
	world.combat.set_target(null)
	world.combat._pending.clear()
	world.partner.disengage()


func _wait_for_wipe(world: WorldMap) -> void:
	var elapsed := 0.0
	var left_map := false
	while elapsed < 25.0:
		if SceneManager.is_transitioning:
			left_map = true
		if left_map and not SceneManager.is_transitioning:
			break
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	await _wait_transition()
	_check(left_map, "wipe sent the player to the respawn map")
	_check(_toasts.any(func(t): return "Recovery Terminal" in t), "told the player where they are going")


func _teleport(world: WorldMap, pos: Vector3) -> void:
	world.player.global_position = Vector3(pos.x, world.get_ground_height(pos.x, pos.z) + 0.3, pos.z)
	world.player.velocity = Vector3.ZERO
	world.camera_rig.snap_to_target()
	world.partner.teleport_near_target()


func _wait_transition() -> void:
	await get_tree().process_frame
	var elapsed := 0.0
	while SceneManager.is_transitioning and elapsed < STEP_TIMEOUT:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	for i in 5:
		await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout
