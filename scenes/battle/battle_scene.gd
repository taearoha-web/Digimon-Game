class_name BattleScene
extends Node3D
## Presentation + integration for a battle.
##
## * BattleController decides everything (rules, turn order, damage).
## * This scene plays the returned events with animations / VFX / UI and,
##   at the end, applies rewards to GameState and returns to the world.

const PLAYER_POS := Vector3(-1.6, 0, 0.9)
const ENEMY_POS := Vector3(1.7, 0, -1.1)
## The Tamer stands behind-left of the partner, out of the camera's line.
const TAMER_POS := Vector3(-3.3, 0, -0.6)
const CAMERA_DEFAULT_POS := Vector3(-4.2, 2.5, 4.9)
const CAMERA_DEFAULT_LOOK := Vector3(0.3, 0.8, -0.3)

var controller: BattleController
var request: BattleRequest
var ui: BattleUI
var popups: PopupQueue
var camera: Camera3D
var player_visual: DigimonVisual
var enemy_visual: DigimonVisual
var tamer: ChibiAvatar
var fast_mode := false

var _vfx_root: Node3D
var _camera_tween: Tween
var _finished := false


func _ready() -> void:
	var params := SceneManager.take_params()
	request = params.get("request", GameState.pending_battle) as BattleRequest
	GameState.pending_battle = null
	if not GameState.is_game_active:
		_start_debug_game()
	if request == null:
		request = BattleRequest.wild(&"kunemon", 3)
	_build_arena()
	_vfx_root = Node3D.new()
	_vfx_root.name = "VFX"
	add_child(_vfx_root)

	var party := GameState.roster.get_party()
	var enemy_instance := DigimonInstance.create(request.enemy_species_id, request.enemy_level)
	controller = BattleController.new()
	controller.setup(party, enemy_instance, request, GameState.inventory)
	controller.completed_quests = QuestManager.count_completed()

	player_visual = _spawn_visual(controller.player.instance.species_id, PLAYER_POS, ENEMY_POS)
	enemy_visual = _spawn_visual(request.enemy_species_id, ENEMY_POS, PLAYER_POS)
	tamer = ChibiAvatar.new()
	add_child(tamer)
	tamer.apply_appearance(GameState.profile.appearance)
	tamer.position = TAMER_POS
	tamer.rotation.y = _yaw_towards(TAMER_POS, ENEMY_POS)
	tamer.play_animation(&"battle_idle")

	ui = BattleUI.new()
	add_child(ui)
	ui.setup(controller)
	ui.command_chosen.connect(_on_command)
	ui.switch_chosen.connect(_on_forced_switch)
	popups = PopupQueue.new()
	add_child(popups)

	AudioManager.play_music(request.music_id, 0.6)
	_run_intro()


func _run_intro() -> void:
	camera.position = ENEMY_POS + Vector3(1.8, 1.6, 3.2)
	camera.look_at(ENEMY_POS + Vector3(0, 0.8, 0))
	enemy_visual.play_once(&"skill", &"idle")
	var enemy_species := GameData.get_species(request.enemy_species_id)
	AudioManager.play_sfx(StringName(enemy_species.sounds.get("cry", "cry_enemy")) if enemy_species else &"cry_enemy")
	await get_tree().create_timer(0.4).timeout
	await _move_camera(CAMERA_DEFAULT_POS, CAMERA_DEFAULT_LOOK, 1.1)
	await _play_events(controller.start())
	_prompt()


func _prompt() -> void:
	if _finished:
		return
	match controller.phase:
		BattleController.Phase.AWAITING_COMMAND:
			ui.refresh_all()
			ui.show_main_menu()
		BattleController.Phase.AWAITING_SWITCH:
			ui.show_forced_switch()
		BattleController.Phase.FINISHED:
			_finish()


func _on_command(command: Dictionary) -> void:
	var events := controller.submit(command)
	await _play_events(events)
	_prompt()


func _on_forced_switch(index: int) -> void:
	var events := controller.submit_switch(index)
	await _play_events(events)
	_prompt()


# ---------------------------------------------------------------------------
# Event playback
# ---------------------------------------------------------------------------

func _play_events(events: Array[Dictionary]) -> void:
	for event in events:
		await _play_event(event)


func _play_event(e: Dictionary) -> void:
	match str(e.get("type", "")):
		"message":
			await ui.show_message(str(e.text))
		"skill":
			await _play_skill(e)
		"damage":
			await _play_damage(e)
		"miss":
			var target := _visual_for(int(e.side))
			BattleVfx.floating_text(_vfx_root, target.global_position + Vector3(0, target.model_height + 0.3, 0), "MISS", UIPalette.TEXT_DIM, 0.8)
			AudioManager.play_sfx(&"miss")
			await ui.show_message(str(e.text))
		"heal":
			var v := _visual_for(int(e.side))
			BattleVfx.sparkles(_vfx_root, v.global_position + Vector3(0, 0.6, 0), Color(0.4, 1.0, 0.55))
			BattleVfx.floating_text(_vfx_root, v.global_position + Vector3(0, v.model_height + 0.3, 0), "+%d" % int(e.amount), UIPalette.SUCCESS)
			AudioManager.play_sfx(&"heal")
			ui.animate_hp(int(e.side), int(e.hp), int(e.max_hp))
			await _wait(0.35)
		"sp":
			ui.set_sp(int(e.side), int(e.sp), int(e.max_sp))
		"stat":
			var v := _visual_for(int(e.side))
			var up := int(e.delta) > 0
			if int(e.delta) != 0:
				BattleVfx.stat_arrows(_vfx_root, v.global_position, up)
				AudioManager.play_sfx(&"buff" if up else &"debuff")
			await _wait(0.25)
		"status":
			var v := _visual_for(int(e.side))
			BattleVfx.cloud(_vfx_root, v.global_position + Vector3(0, 0.6, 0), StatusEffects.get_color(e.status_id))
			ui.set_status(int(e.side), e.status_id)
			AudioManager.play_sfx(&"debuff")
		"status_clear":
			ui.set_status(int(e.side), &"")
		"defend":
			var v := _visual_for(int(e.side))
			BattleVfx.ring(_vfx_root, v.global_position + Vector3(0, 0.6, 0), UIPalette.CYAN, 1.8)
			AudioManager.play_sfx(&"defend")
			await ui.show_message(str(e.text))
		"item":
			tamer.play_once(&"interact", &"battle_idle")
			AudioManager.play_sfx(&"item_use")
			await ui.show_message(str(e.text))
		"switch":
			await _play_switch(e)
		"faint":
			var v := _visual_for(int(e.side))
			AudioManager.play_sfx(&"faint")
			v.play_once(&"defeat", &"")
			if int(e.side) == BattleCombatant.PLAYER_SIDE:
				tamer.play_once(&"hurt", &"battle_idle")
			await ui.show_message(str(e.text))
		"escape":
			if e.get("success", false):
				AudioManager.play_sfx(&"escape")
				var tween := create_tween().set_parallel(true)
				tween.tween_property(player_visual, "position", player_visual.position + Vector3(-4, 0, 4), 0.6)
				tween.tween_property(tamer, "position", tamer.position + Vector3(-4, 0, 4), 0.6)
				tamer.play_animation(&"run")
				player_visual.play_animation(&"run")
			await ui.show_message(str(e.text))
		"befriend":
			await _play_befriend(e)
		"victory":
			AudioManager.play_music(&"victory", 0.3)
			player_visual.play_animation(&"victory")
			tamer.play_animation(&"victory")
			await _move_camera(PLAYER_POS + Vector3(0.8, 1.5, 3.4), PLAYER_POS + Vector3(-0.6, 0.8, -0.4), 0.8)
		"defeat":
			AudioManager.play_music(&"defeat", 0.3)
			tamer.play_animation(&"hurt")
		"party_update":
			ui.refresh_all()
		"need_switch", "invalid":
			pass
		_:
			if e.has("text"):
				await ui.show_message(str(e.text))


func _play_skill(e: Dictionary) -> void:
	var side := int(e.side)
	var user := _visual_for(side)
	var target := _visual_for(int(e.get("target_side", 1 - side)))
	var skill := GameData.get_skill(StringName(e.skill_id))
	var self_target := skill != null and skill.target == SkillData.Target.SELF
	if side == BattleCombatant.PLAYER_SIDE:
		tamer.play_once(&"attack", &"battle_idle")
	ui.set_prompt(str(e.text))
	AudioManager.play_ui(&"skill_start")
	var anim: StringName = skill.animation if skill else &"attack"
	if self_target:
		user.play_once(&"skill", &"idle")
		BattleVfx.play_impact(_vfx_root, skill.vfx if skill else &"aura", user.global_position + Vector3(0, 0.6, 0))
		await _wait(0.6)
		return
	if skill and skill.projectile:
		user.play_once(&"skill", &"idle")
		await _wait(0.3)
		AudioManager.play_sfx(skill.sfx)
		await BattleVfx.projectile(_vfx_root, skill.vfx, user.global_position + Vector3(0, 0.8, 0) + (target.global_position - user.global_position).normalized() * 0.6,
			target.global_position + Vector3(0, 0.7, 0))
	else:
		# Physical: dash towards the target, strike, come back.
		user.play_once(anim, &"idle")
		var start := user.position
		var dash := start.lerp(target.position, 0.62)
		var tween := create_tween()
		tween.tween_property(user, "position", dash, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tween.finished
		if skill:
			AudioManager.play_sfx(skill.sfx)
		var back := create_tween()
		back.tween_interval(0.12)
		back.tween_property(user, "position", start, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_damage(e: Dictionary) -> void:
	var side := int(e.side)
	var target := _visual_for(side)
	var skill := GameData.get_skill(StringName(e.get("skill_id", "")))
	var vfx_id: StringName = skill.vfx if skill else &"impact"
	if e.get("status_tick", false):
		vfx_id = &"poison"
	BattleVfx.play_impact(_vfx_root, vfx_id, target.global_position + Vector3(0, 0.7, 0), 1.3 if e.get("critical", false) else 1.0)
	target.flash(Color(1, 1, 1))
	target.play_once(&"hurt", &"idle")
	if side == BattleCombatant.PLAYER_SIDE:
		tamer.play_once(&"hurt", &"battle_idle")
	var mult := float(e.get("type_multiplier", 1.0))
	var color := UIPalette.GOLD if e.get("critical", false) else (UIPalette.ORANGE if mult >= 1.2 else Color.WHITE)
	BattleVfx.floating_text(_vfx_root, target.global_position + Vector3(0, target.model_height + 0.3, 0), str(int(e.amount)), color,
		1.3 if e.get("critical", false) else 1.0)
	AudioManager.play_sfx(&"crit" if e.get("critical", false) else (&"hit_special" if int(e.get("category", 0)) == SkillData.Category.SPECIAL else &"hit_physical"))
	_shake(0.18 if e.get("critical", false) else 0.08)
	ui.animate_hp(side, int(e.hp), int(e.max_hp))
	await _wait(0.5)


func _play_switch(e: Dictionary) -> void:
	var old := player_visual
	AudioManager.play_sfx(&"switch")
	var shrink := create_tween()
	shrink.tween_property(old, "scale", Vector3.ONE * 0.01, 0.2)
	await shrink.finished
	old.queue_free()
	player_visual = _spawn_visual(controller.player.instance.species_id, PLAYER_POS, ENEMY_POS)
	player_visual.scale = Vector3.ONE * 0.01
	var grow := create_tween()
	grow.tween_property(player_visual, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	BattleVfx.ring(_vfx_root, PLAYER_POS + Vector3(0, 0.2, 0), UIPalette.CYAN, 2.0)
	ui.refresh_all()
	await ui.show_message(str(e.text))


func _play_befriend(e: Dictionary) -> void:
	var target := enemy_visual
	tamer.play_once(&"interact", &"battle_idle")
	await ui.show_message(str(e.text), 0.2)
	for i in 3:
		BattleVfx.floating_text(_vfx_root, target.global_position + Vector3(randf_range(-0.4, 0.4), target.model_height + 0.2, 0), "♥", UIPalette.PINK, 0.8)
		AudioManager.play_ui(&"heart")
		await _wait(0.25)
	if e.get("success", false):
		BattleVfx.sparkles(_vfx_root, target.global_position + Vector3(0, 0.6, 0), UIPalette.PINK)
		target.play_once(&"victory", &"idle")
		AudioManager.play_sfx(&"recruit")
	else:
		target.play_once(&"hurt", &"idle")


# ---------------------------------------------------------------------------
# End of battle
# ---------------------------------------------------------------------------

func _finish() -> void:
	if _finished:
		return
	_finished = true
	ui.hide_menus()
	var outcome := controller.outcome
	GameState.last_battle_summary = {"outcome": outcome}
	match outcome:
		BattleController.Outcome.VICTORY:
			await _handle_victory()
		BattleController.Outcome.RECRUITED:
			await _handle_recruited()
		BattleController.Outcome.ESCAPED:
			await _wait(0.4)
		BattleController.Outcome.DEFEAT:
			await _handle_defeat()
	# Restore SP (HP persists between battles; heal at terminals / with items).
	for inst in GameState.roster.get_party():
		inst.current_sp = inst.get_max_sp()
		inst.clamp_vitals()
	GameState.roster.notify_changed()
	await _return_to_world()


func _handle_victory() -> void:
	var summary := BattleRewards.apply_victory(controller)
	EventBus.battle_won.emit(request.enemy_species_id, request.enemy_level)
	for item_id in summary.drops.keys():
		GameState.inventory.add_item(StringName(item_id), int(summary.drops[item_id]))
	var level_up_entries: Array = []
	for entry in summary.exp_entries:
		if not entry.level_ups.is_empty():
			level_up_entries.append({"instance": entry.instance, "ups": entry.level_ups})
			EventBus.digimon_leveled_up.emit(entry.instance, entry.instance.level)
	await BattleResults.show_victory(ui, "Victory!", summary)
	popups.show_level_ups(level_up_entries)
	await popups.wait_until_idle()
	var recruit: DigimonInstance = summary.recruit
	if recruit:
		var accepted := await BattleResults.ask_recruit(ui, recruit)
		if accepted:
			_add_recruit(recruit)


func _handle_recruited() -> void:
	var summary := BattleRewards.apply_recruited(controller)
	var level_up_entries: Array = []
	for entry in summary.exp_entries:
		if not entry.level_ups.is_empty():
			level_up_entries.append({"instance": entry.instance, "ups": entry.level_ups})
			EventBus.digimon_leveled_up.emit(entry.instance, entry.instance.level)
	var recruit: DigimonInstance = summary.recruit
	await BattleResults.ask_recruit(ui, recruit, true)
	_add_recruit(recruit)
	if not summary.exp_entries.is_empty():
		await BattleResults.show_victory(ui, "New Friend!", summary)
	popups.show_level_ups(level_up_entries)
	await popups.wait_until_idle()


func _add_recruit(recruit: DigimonInstance) -> void:
	var placed := GameState.roster.add_digimon(recruit)
	if placed == &"full":
		EventBus.toast("Your Collection is full.", &"warning")
		return
	EventBus.digimon_recruited.emit(recruit)
	EventBus.toast("%s joined your %s!" % [recruit.get_display_name(), "party" if placed == &"party" else "Collection"], &"success")
	SaveManager.autosave("digimon recruited", true)


func _handle_defeat() -> void:
	await ui.show_message("You hurry back to the Recovery Terminal…", 1.0)
	GameState.roster.heal_all()
	GameState.world.has_position = false
	GameState.world.current_map_id = GameState.world.respawn_map_id
	GameState.world.spawn_id = GameState.world.respawn_spawn_id


func _return_to_world() -> void:
	var map_id := request.return_map_id if GameState.world.has_position else GameState.world.current_map_id
	SceneManager.goto_map(map_id, GameState.world.spawn_id, {"from_battle": true})


# ---------------------------------------------------------------------------
# Scene building / helpers
# ---------------------------------------------------------------------------

func _build_arena() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/digital_sky.gdshader")
	sky_mat.set_shader_parameter("top_color", Color(0.22, 0.28, 0.72))
	sky_mat.set_shader_parameter("horizon_color", Color(0.95, 0.72, 0.85))
	sky_mat.set_shader_parameter("bottom_color", Color(0.3, 0.3, 0.6))
	sky_mat.set_shader_parameter("grid_strength", 0.3)
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.76, 1.0)
	env.ambient_light_energy = 0.36
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_hdr_threshold = 1.5
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.set_script(load("res://systems/world/quality_light.gd"))
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_energy = 0.7
	sun.light_color = Color(1.0, 0.95, 0.92)
	add_child(sun)

	camera = Camera3D.new()
	camera.fov = 50
	camera.current = true
	add_child(camera)

	# Arena platform with a glowing digital grid.
	var platform := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 7.5
	disc.bottom_radius = 8.0
	disc.height = 0.6
	disc.radial_segments = 48
	platform.mesh = disc
	var grid := ShaderMaterial.new()
	grid.shader = load("res://shaders/grid_floor.gdshader")
	grid.set_shader_parameter("cells", 14.0)
	platform.material_override = grid
	platform.position = Vector3(0, -0.3, 0)
	add_child(platform)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 7.5
	torus.outer_radius = 7.8
	torus.rings = 64
	rim.mesh = torus
	rim.material_override = MeshKit.toon(UIPalette.CYAN, {"emission": 1.4})
	add_child(rim)
	for pos in [PLAYER_POS, ENEMY_POS]:
		var pad := MeshInstance3D.new()
		var pad_mesh := CylinderMesh.new()
		pad_mesh.top_radius = 1.2
		pad_mesh.bottom_radius = 1.2
		pad_mesh.height = 0.06
		pad_mesh.radial_segments = 6
		pad.mesh = pad_mesh
		pad.material_override = MeshKit.toon(Color(0.3, 0.9, 1.0, 0.5), {"unshaded": true, "alpha": 0.5})
		pad.position = pos + Vector3(0, 0.03, 0)
		add_child(pad)
	# Surroundings: data pillars, floating cubes and distant hills.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 10:
		var ang := i * TAU / 10.0
		var dist := rng.randf_range(12.0, 18.0)
		var pillar := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.5
		pm.bottom_radius = 0.7
		pm.height = rng.randf_range(6.0, 12.0)
		pm.radial_segments = 6
		pm.cap_top = false
		pm.cap_bottom = false
		pillar.mesh = pm
		var pmat := ShaderMaterial.new()
		pmat.shader = load("res://shaders/data_pillar.gdshader")
		pillar.material_override = pmat
		pillar.position = Vector3(cos(ang) * dist, pm.height * 0.5 - 0.5, sin(ang) * dist)
		add_child(pillar)
	for i in 14:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(35.0, 60.0)
		var hill := MeshInstance3D.new()
		hill.mesh = MeshKit.sphere_low()
		var s := rng.randf_range(10.0, 22.0)
		hill.scale = Vector3(s * 1.6, s * 0.7, s * 1.6)
		hill.position = Vector3(cos(ang) * dist, -2.0, sin(ang) * dist)
		hill.material_override = MeshKit.toon(Color(0.38, 0.62, 0.62).lerp(Color(0.45, 0.4, 0.75), rng.randf()))
		add_child(hill)
	for i in 16:
		var cube := MeshInstance3D.new()
		cube.mesh = MeshKit.box()
		cube.material_override = MeshKit.toon([UIPalette.CYAN, UIPalette.ORANGE, UIPalette.PURPLE][i % 3], {"emission": 1.3})
		cube.scale = Vector3.ONE * rng.randf_range(0.2, 0.5)
		var ang := rng.randf() * TAU
		cube.position = Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(9.0, 14.0) + Vector3(0, rng.randf_range(1.5, 5.0), 0)
		cube.rotation = Vector3(rng.randf(), rng.randf(), rng.randf())
		add_child(cube)
		var bob := create_tween().set_loops()
		bob.tween_property(cube, "position:y", cube.position.y + 0.4, rng.randf_range(1.2, 2.0)).set_trans(Tween.TRANS_SINE)
		bob.tween_property(cube, "position:y", cube.position.y, rng.randf_range(1.2, 2.0)).set_trans(Tween.TRANS_SINE)


func _spawn_visual(species_id: StringName, pos: Vector3, look_target: Vector3) -> DigimonVisual:
	var v := DigimonVisual.new()
	add_child(v)
	v.set_species(species_id)
	v.position = pos
	v.rotation.y = _yaw_towards(pos, look_target)
	return v


func _visual_for(side: int) -> DigimonVisual:
	return player_visual if side == BattleCombatant.PLAYER_SIDE else enemy_visual


static func _yaw_towards(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(d.x, d.z)


func _move_camera(pos: Vector3, look: Vector3, duration: float) -> void:
	if _camera_tween:
		_camera_tween.kill()
	var start_pos := camera.position
	var start_look := camera.position + (-camera.global_transform.basis.z) * 5.0
	_camera_tween = create_tween()
	_camera_tween.tween_method(func(t: float):
		camera.position = start_pos.lerp(pos, t)
		camera.look_at(start_look.lerp(look, t)), 0.0, 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await _camera_tween.finished


func _shake(strength: float) -> void:
	var base := camera.position
	var tween := create_tween()
	for i in 4:
		tween.tween_property(camera, "position", base + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * strength, 0.03)
	tween.tween_property(camera, "position", base, 0.04)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds * (0.5 if fast_mode else 1.0)).timeout


func _start_debug_game() -> void:
	var draft := NewGameDraft.new()
	draft.player_name = "Tester"
	draft.starter_species_id = &"agumon"
	GameState.start_new_game(draft)
