extends Node
## Every zone's sky and air (Scenery.environment + SkyArt) at quality 0, 1 and 2:
##   - a valid WorldEnvironment with a procedural sky (what DayNight grades), a sun, the
##     soft filmic tone curve with a modest exposure (skills must not turn white again)
##   - no expensive passes anywhere (SDFGI, SSIL, SSAO, SSR, volumetric fog)
##   - quality 0 and the safe picture: the plain procedural sky, no cover, shafts or
##     cloud shadows, no colour grade
##   - quality 1+: at most the one shared, VRAM-compressed sky texture, under the size cap
##   - shafts and cloud shadows stay a few draws, hide under memory pressure, and the
##     cloud cover is dropped at strict pressure and comes back after
##   godot --headless --path . res://tests/integration/sky_budget_test.tscn
var failures: Array[String] = []
var checks := 0
## Shafts per zone at most (one MultiMesh, but every card is a full-height fill).
const MAX_RAYS := 8


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func _zone_ids() -> Array[StringName]:
	ZoneData.ensure()
	var ids: Array[StringName] = []
	for id in ZoneData.ZONES:
		ids.append(StringName(id))
	ids.append(RaidData.ID)
	return ids


## The environment a zone builds (Zone._build_field / _build_town; the arenas pass their
## own colours, the look here is the zone data's).
func _build(id: StringName) -> Node3D:
	var data := ZoneData.get_zone(id)
	var holder := Node3D.new()
	add_child(holder)
	var sky: Color = data.get("sky", Color("a7cddd"))
	var look := {"theme": StringName(data.get("theme", &"meadow")), "sun_size": float(data.get("sun_size", 1.0)), "moon": bool(data.get("moon", false))}
	if data.has("sky_palette"):
		look["palette"] = data.sky_palette
	Scenery.environment(holder, sky, data.get("fog", sky.lerp(Color.WHITE, 0.35)), data.get("ambient", Color(0.9, 0.95, 1.0)),
			data.get("sun", Color(1.0, 0.96, 0.88)), look)
	SkyArt.dress(holder, id, StringName(data.get("theme", &"")), 60.0)
	return holder


func _env_of(holder: Node3D) -> WorldEnvironment:
	for child in holder.get_children():
		if child is WorldEnvironment:
			return child
	return null


func _extras(holder: Node3D) -> Array[Node]:
	var out: Array[Node] = []
	for child in holder.get_children():
		if child.is_in_group(SkyArt.EXTRA_GROUP):
			out.append(child)
	return out


func _zones_at(quality: int) -> void:
	GameSettings.quality = quality
	var covers := {}
	for id in _zone_ids():
		var data := ZoneData.get_zone(id)
		var theme := StringName(data.get("theme", &""))
		check(SkyArt.MOODS.has(id) or SkyArt.MOODS.has(theme), "%s has a sky mood" % id)
		var holder := _build(id)
		var world_env := _env_of(holder)
		check(world_env != null and world_env.environment != null, "q%d %s: a WorldEnvironment" % [quality, id])
		if world_env == null or world_env.environment == null:
			holder.free()
			continue
		var env := world_env.environment
		var sky_mat := env.sky.sky_material as ProceduralSkyMaterial if env.sky else null
		check(env.background_mode == Environment.BG_SKY and sky_mat != null, "q%d %s: a procedural sky (DayNight grades it)" % [quality, id])
		var sun: DirectionalLight3D = null
		for child in holder.get_children():
			if child is DirectionalLight3D and child.is_in_group("sun"):
				sun = child
		check(sun != null and sun.light_energy > 0.0, "q%d %s: a sun" % [quality, id])
		check(env.tonemap_mode == Environment.TONE_MAPPER_FILMIC and env.tonemap_exposure >= 0.9 and env.tonemap_exposure <= 1.2 and env.tonemap_white >= 2.0,
				"q%d %s: soft filmic curve, modest exposure (%.2f, white %.1f)" % [quality, id, env.tonemap_exposure, env.tonemap_white])
		check(not env.sdfgi_enabled and not env.ssil_enabled and not env.ssao_enabled and not env.ssr_enabled and not env.volumetric_fog_enabled,
				"q%d %s: no SDFGI / SSIL / SSAO / SSR / volumetric fog" % [quality, id])
		check(env.fog_enabled, "q%d %s: distance fog for depth" % [quality, id])
		var extras := _extras(holder)
		if sky_mat:
			var cover := sky_mat.sky_cover
			if quality == 0:
				check(cover == null, "q0 %s: plain procedural sky (no cover texture)" % id)
			if cover:
				covers[cover.get_instance_id()] = cover
				check(cover.get_width() <= SkyArt.MAX_SKY_TEXTURE.x and cover.get_height() <= SkyArt.MAX_SKY_TEXTURE.y,
						"q%d %s: sky texture under the cap (%dx%d)" % [quality, id, cover.get_width(), cover.get_height()])
			elif quality >= 1 and (SkyArt.mood(id, theme).clouds as Color).a > 0.0:
				check(false, "q%d %s: the painted cloud cover is on" % [quality, id])
		check(not env.adjustment_enabled or (quality >= 2 and MemoryGuard.glow_allowed()), "q%d %s: the colour grade only with the post pass at high quality" % [quality, id])
		if quality == 0:
			check(extras.is_empty(), "q0 %s: no shafts or cloud shadows (%d)" % [id, extras.size()])
		for node in extras:
			if node is MultiMeshInstance3D:
				var count := (node as MultiMeshInstance3D).multimesh.instance_count
				check(count <= MAX_RAYS, "q%d %s: a few light shafts (%d)" % [quality, id, count])
			if quality < 2:
				check(not String(node.name).begins_with("CloudShadows"), "q%d %s: cloud shadows only at high quality" % [quality, id])
		check(extras.size() <= 2, "q%d %s: at most two atmosphere draws (%d)" % [quality, id, extras.size()])
		holder.free()
	check(covers.size() <= 1, "q%d: one sky texture shared by every zone (%d)" % [quality, covers.size()])


func _pressure() -> void:
	GameSettings.quality = 2
	var holder := _build(&"lotus_sanctum")
	var meadow := _build(&"meadow")
	var world_env := _env_of(holder)
	var sky_mat := world_env.environment.sky.sky_material as ProceduralSkyMaterial
	var extras := _extras(holder) + _extras(meadow)
	check(extras.size() >= 2, "lotus shafts and meadow cloud shadows at high quality (%d)" % extras.size())
	check(sky_mat.sky_cover != null, "the lotus sanctum wears its cloud cover")
	MemoryGuard.force(1, get_tree())
	var shown := 0
	for node in extras:
		shown += 1 if (node as Node3D).visible else 0
	check(shown == 0, "trimmed pressure hides the shafts and cloud shadows (%d shown)" % shown)
	check(sky_mat.sky_cover != null, "trimmed pressure keeps the cloud cover")
	check(not world_env.environment.adjustment_enabled, "no colour grade without the post pass")
	MemoryGuard.force(2, get_tree())
	check(sky_mat.sky_cover == null, "strict pressure drops the cloud cover")
	MemoryGuard.force(-1, get_tree())
	check(sky_mat.sky_cover != null, "the cloud cover comes back")
	var ray_node: Node3D = null
	for node in extras:
		if node is MultiMeshInstance3D:
			ray_node = node
	check(ray_node != null and ray_node.visible, "the shafts come back")
	holder.free()
	meadow.free()
	# The safe picture keeps the plain sky.
	GameSettings.safe_picture = true
	var safe := _build(&"meadow")
	var safe_mat := _env_of(safe).environment.sky.sky_material as ProceduralSkyMaterial
	check(safe_mat.sky_cover == null and _extras(safe).is_empty(), "the safe picture draws the plain sky")
	safe.free()
	GameSettings.safe_picture = false


func _texture_import() -> void:
	var cfg := ConfigFile.new()
	check(cfg.load(SkyArt.CLOUD_TEXTURE + ".import") == OK, "the cloud texture's import settings exist")
	check(int(cfg.get_value("params", "compress/mode", -1)) == 2, "the cloud texture is VRAM-compressed (%s)" % cfg.get_value("params", "compress/mode", -1))
	check(not bool(cfg.get_value("params", "mipmaps/generate", true)), "the cloud texture carries no mipmaps")


func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	var saved := GameSettings.quality
	_texture_import()
	for q in [0, 1, 2]:
		_zones_at(q)
	_pressure()
	GameSettings.quality = saved
	print("")
	if failures.is_empty():
		print("SKY BUDGET TEST: PASS (%d checks)" % checks)
	else:
		print("SKY BUDGET TEST: FAIL (%d of %d)" % [failures.size(), checks])
		for f in failures:
			print("  - ", f)
	get_tree().quit(failures.size())
