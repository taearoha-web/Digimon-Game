extends Node3D
## Catalogue coverage, strict elemental decoration limits, scene-exit cleanup,
## and construction of every real Zone branch. Use an isolated XDG_DATA_HOME.
## godot --headless --path . res://tests/integration/art_direction_test.tscn
## Optional -- skills|elements|zones limits the audit; zones accepts quality 0..2.

var failures: Array[String] = []
var checks := 0
var skills_audited := 0
var zones_audited := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func _ready() -> void:
	await get_tree().process_frame
	GameSettings.load_settings()
	var old_quality := GameSettings.quality
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if not args.is_empty() else "all"
	if mode in ["all", "skills"]:
		_skill_coverage()
	if mode in ["all", "elements"]:
		await _element_limits()
		await _interrupted_flights()
	if mode in ["all", "zones"]:
		GameSettings.quality = clampi(int(args[1]), 0, 2) if args.size() > 1 else 2
		await _zone_coverage()
	check(mode in ["all", "skills", "elements", "zones"], "known test selection")
	GameSettings.quality = old_quality
	_stop_audio()
	# Audio stop and renderer RID retirement are deferred by their servers.
	# Let those queues drain before the test closes the engine; quitting on the
	# same frame falsely reports the last music playbacks as leaked resources.
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
	await get_tree().create_timer(0.12, true, false, true).timeout
	print("ART DIRECTION: %s | %d checks, %d skills, %d zones, %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks, skills_audited, zones_audited, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)


func _skill_coverage() -> void:
	var families: Array[StringName] = [&"vagabond"]
	families.append_array(ClassData.IDS)
	var seen := {}
	for family in families:
		var pool := ClassData.pool(family)
		check(not pool.is_empty(), "nonempty family: " + String(family))
		for skill in pool:
			var id := String(skill.id)
			check(not seen.has(id), "unique active skill id: " + id)
			seen[id] = true
			var before: Dictionary = skill.duplicate(true)
			var art := SkillShow.profile_for(skill)
			check(bool(art.get("mapped", false)) and String(art.family) == String(family), "correct family: " + id)
			check(bool(art.get("art_mapped", false)), "explicit art design: " + id)
			check(not String(art.get("recipe", "")).is_empty(), "art silhouette: " + id)
			check(not String(art.get("palette", "")).is_empty(), "art palette: " + id)
			check(float(art.get("tempo", 0.0)) > 0.0, "positive presentation lifetime: " + id)
			for color_key in ["primary", "accent", "shade"]:
				var color: Color = art.get(color_key, Color(0, 0, 0, 0))
				check(is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and color.a > 0.0, "finite visible %s: %s" % [color_key, id])
			check(skill == before, "art lookup leaves gameplay data intact: " + id)
			skills_audited += 1
		print("ART FAMILY: %s = %d active skills" % [family, pool.size()])
	check(not bool(SkillShow.profile_for({"id": "__unknown_art_audit__", "shape": "self"}).get("art_mapped", true)), "unknown future skill reports missing art coverage")


func _element_limits() -> void:
	for quality in 3:
		GameSettings.quality = quality
		var saturated := Node3D.new()
		add_child(saturated)
		for i in VfxBudget.decoration_limit():
			var reservation := Node3D.new()
			saturated.add_child(reservation)
			VfxBudget.track_decoration(reservation)
		var before := saturated.get_child_count()
		# These entry points are purely decorative, unlike projectile carriers.
		# Checking actual nodes catches a false pass from untracked geometry.
		_emit_elements(saturated)
		check(saturated.get_child_count() == before, "no untracked elemental geometry after saturation q%d" % quality)
		check(int(VfxBudget.counters().decorations) == VfxBudget.decoration_limit(), "strict elemental reservation ceiling q%d" % quality)
		saturated.queue_free()
		await saturated.tree_exited
		check(_empty_budget(), "saturated scene releases reservations q%d" % quality)
		var effects := Node3D.new()
		add_child(effects)
		for i in 8:
			_emit_elements(effects)
		check(effects.get_child_count() > 0, "unsaturated elements create visible geometry q%d" % quality)
		check(int(VfxBudget.counters().decorations) <= VfxBudget.decoration_limit(), "overlapping element fields stay bounded q%d" % quality)
		await get_tree().create_timer(0.25).timeout
		check(int(VfxBudget.counters().decorations) <= VfxBudget.decoration_limit(), "delayed element geometry stays bounded q%d" % quality)
		effects.queue_free()
		await effects.tree_exited
		check(_empty_budget(), "interrupted elements release reservations q%d" % quality)
		await get_tree().create_timer(0.2).timeout
		check(_empty_budget(), "delayed callbacks do not resurrect reservations q%d" % quality)


func _emit_elements(parent: Node3D) -> void:
	ElementFx.fire_field(parent, Vector3.ZERO, 5.0, 5)
	ElementFx.ice_field(parent, Vector3.RIGHT * 3.0, 5.0, 5)
	ElementFx.vine_field(parent, Vector3.LEFT * 3.0, 5.0, 5)
	for kind in ["tree", "spores", "sprouts"]:
		ElementFx.plant_field(parent, Vector3.FORWARD * 3.0, 5.0, kind, 5)
	ElementFx.flame_hit(parent, Vector3.UP)
	ElementFx.ice_hit(parent, Vector3.UP)
	ElementFx.vine_bind(parent, Vector3.ZERO)
	ElementFx.flame_puff(parent, Vector3.UP)
	ElementFx.shatter(parent, Vector3.UP, 1.0)


func _interrupted_flights() -> void:
	# A zone can unload while arrows/spells are still travelling. An await on
	# a killed Tween can retain its function's local meshes and materials even
	# though reservation counters and all scene nodes have been released.
	var effects := Node3D.new()
	add_child(effects)
	for variant in ["orb", "flame", "shard", "leaf", "spark"]:
		VfxKit.projectile(effects, Color("c8ddff"), Vector3.UP, Vector3(8, 1, 0), 4.0, 0.5, variant)
	VfxKit.arrow(effects, Color("bbe9cc"), Vector3.UP, Vector3(8, 1, 0), 4.0)
	var resources := _flight_resource_refs(effects)
	check(not resources.is_empty(), "flight cleanup probe observes actual transient resources")
	effects.queue_free()
	await effects.tree_exited
	await get_tree().process_frame
	await get_tree().process_frame
	var retained := 0
	for reference in resources:
		if reference.get_ref() != null:
			retained += 1
	check(retained == 0, "interrupted flights release temporary meshes and materials (%d retained)" % retained)
	check(_empty_budget(), "interrupted flights release particle and light reservations")
	var completed := Node3D.new()
	add_child(completed)
	VfxKit.projectile(completed, Color("b9cfff"), Vector3.UP, Vector3(4, 1, 0), 0.08)
	VfxKit.arrow(completed, Color("bbe9cc"), Vector3.UP, Vector3(4, 1, 0), 0.08)
	var carriers: Array[WeakRef] = []
	for node in completed.get_children():
		carriers.append(weakref(node))
	await get_tree().create_timer(0.18).timeout
	for carrier in carriers:
		check(carrier.get_ref() == null, "normal flight retires its completed carrier")
	check(completed.get_child_count() > 0, "normal flight still presents an arrival effect")
	completed.queue_free()
	await completed.tree_exited
	check(_empty_budget(), "completed flights release their arrival reservations on exit")


func _flight_resource_refs(parent: Node3D) -> Array[WeakRef]:
	var result: Array[WeakRef] = []
	for child in parent.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		# Glow/spark quads and their materials are per-flight resources. Shared
		# sphere, crystal, arrow and texture caches deliberately survive casts.
		if mesh.mesh is QuadMesh:
			result.append(weakref(mesh.mesh))
		if mesh.material_override:
			result.append(weakref(mesh.material_override))
	return result


func _zone_coverage() -> void:
	Game.set_process(false)
	Game.new_profile(&"mage", "Art audit")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.fill_loadout()
	var stats := Game.stats_now()
	Game.profile.hp = stats.max_hp
	Game.profile.mp = stats.max_mp
	for id in ZoneData.ZONES:
		Game.current_zone = id
		Game.profile["spawn_override"] = ""
		var source: Dictionary = ZoneData.ZONES[id].duplicate(true)
		var zone := Zone.new()
		zone.zone_id = id
		add_child(zone)
		zone.process_mode = Node.PROCESS_MODE_DISABLED
		check(zone.hero != null and zone.camera_rig != null, "stage retains player and camera: " + String(id))
		check(zone.data == ZoneData.get_zone(id), "stage keeps correct gameplay data: " + String(id))
		check(ZoneData.ZONES[id] == source, "stage art leaves source data intact: " + String(id))
		var meshes := 0
		var has_region_art := false
		var has_stage_art := false
		for node in zone.find_children("*", "Node3D", true, false):
			has_region_art = has_region_art or node.has_meta("art_theme")
			has_stage_art = has_stage_art or String(node.get_meta("stage", "")) == String(id)
			if node is MeshInstance3D or node is MultiMeshInstance3D:
				meshes += 1
				check((node as Node3D).transform.is_finite(), "finite geometry transform in " + String(id))
			if id == &"pvp" and node is MeshInstance3D:
				var material: Material = (node as MeshInstance3D).material_override
				if material is ShaderMaterial and (material as ShaderMaterial).shader:
					has_stage_art = has_stage_art or (material as ShaderMaterial).shader.resource_path.ends_with("special_stage_floor.gdshader")
		check(meshes > 0, "stage builds visible geometry: " + String(id))
		if id in [&"tower", &"arena", &"pvp"]:
			check(has_stage_art, "special combat stage receives authored art: " + String(id))
		else:
			check(has_region_art, "region receives authored landscape art: " + String(id))
		zones_audited += 1
		print("ART ZONE: %s, q%d, %d mesh nodes" % [id, GameSettings.quality, meshes])
		if DisplayServer.get_name() != "headless":
			# In graphical runs, finish one real frame before retiring the sky
			# and environment. This also exercises the stage's render resources.
			await RenderingServer.frame_post_draw
		zone.queue_free()
		await zone.tree_exited
		await get_tree().process_frame
		check(_empty_budget(), "stage unload releases temporary art: " + String(id))


func _empty_budget() -> bool:
	return VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}


func _stop_audio() -> void:
	AudioManager.stop_music(0.0)
	AudioManager.play_ambient(&"")
	for player in AudioManager.get_children():
		if player is AudioStreamPlayer:
			player.stop()
			player.stream = null
