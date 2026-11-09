extends Node3D
## The textured surfaces stay inside the phone budget: one VRAM-compressed detail array,
## LAYER_SIZE px a layer at most, shared by a handful of SHARED materials (never one per
## building or per instance), dropped entirely on low quality; and the earlier texture
## size caps (iPhone VRAM fix) are still in place.

var failures: Array[String] = []
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func _import(path: String) -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(path + ".import")
	return cfg


func _ready() -> void:
	await get_tree().process_frame
	GameSettings.load_settings()
	var saved_quality := GameSettings.quality
	var saved_pressure := MemoryGuard.pressure
	MemoryGuard.pressure = 0

	# The detail array: VRAM compressed for both web formats, mipmapped, 8 layers of 512 px.
	var cfg := _import(SurfaceKit.TEXTURE_PATH)
	check(String(cfg.get_value("remap", "importer", "")) == "2d_array_texture", "surface detail imports as one texture array")
	check(int(cfg.get_value("params", "compress/mode", -1)) == 2, "surface detail is VRAM compressed")
	check(bool(cfg.get_value("params", "mipmaps/generate", false)), "surface detail has mipmaps")
	check(int(cfg.get_value("params", "slices/vertical", 0)) == SurfaceKit.LAYERS, "surface detail holds every layer")
	var formats: Array = (cfg.get_value("remap", "metadata", {}) as Dictionary).get("imported_formats", [])
	check("s3tc_bptc" in formats and "etc2_astc" in formats, "surface detail is imported for desktop and phone browsers")
	var source := Image.load_from_file(ProjectSettings.globalize_path(SurfaceKit.TEXTURE_PATH))
	check(source != null and source.get_width() == SurfaceKit.LAYER_SIZE and source.get_height() == SurfaceKit.LAYER_SIZE * SurfaceKit.LAYERS,
		"surface detail is %d px a layer" % SurfaceKit.LAYER_SIZE)
	check(SurfaceKit.LAYER_SIZE <= 512, "surface detail layers stay at 512 px or less")
	# 4 bits a texel compressed, a third more for mipmaps; even unpacked to RGBA8 on a
	# browser without either format it stays well inside 16 MB.
	var compressed := SurfaceKit.LAYER_SIZE * SurfaceKit.LAYER_SIZE * SurfaceKit.LAYERS * 4 / 3 / 2
	check(compressed <= 2 * 1024 * 1024, "surface detail costs at most 2 MB of video memory (%d)" % compressed)
	check(compressed * 8 <= 16 * 1024 * 1024, "even unpacked, surface detail stays under 16 MB")

	# The earlier caps on character and monster textures are still there.
	var capped := 0
	for path in ["res://assets/models/monsters/big/Demon_Atlas_Monsters.png", "res://assets/models/characters/knight_texture.png",
			"res://assets/models/heroes/chibi_boy_chibi_fantasy_figure_3d_model_basecolor.jpg"]:
		var limit := int(_import(path).get_value("params", "process/size_limit", 0))
		if limit > 0 and limit <= 512:
			capped += 1
	check(capped == 3, "character and monster textures keep their size caps")

	# Low quality: nothing bound, nothing sampled.
	GameSettings.quality = 0
	SurfaceKit.refresh()
	var solid := JapanKit.solid_material()
	check(solid.get_shader_parameter("surface_detail") == null and float(solid.get_shader_parameter("surface_amount")) == 0.0, "low quality binds no surface texture")
	check(SurfaceKit.vram_bytes() == 0, "low quality holds no surface texture")

	# Medium / high: one texture shared by every surface material.
	GameSettings.quality = 2
	SurfaceKit.refresh()
	var tex := SurfaceKit.texture()
	check(tex != null, "the surface texture loads on high quality")
	if tex != null:
		check(tex.get_width() <= 512 and tex.get_height() <= 512 and tex.get_layers() == SurfaceKit.LAYERS, "loaded layers are 512 px at most")
	check(solid.get_shader_parameter("surface_detail") == tex and float(solid.get_shader_parameter("surface_amount")) == 1.0, "buildings take the shared texture")
	check(JapanKit.solid_material() == solid, "every building shares one solid material")
	check(RegionArt._earth_material() == RegionArt._earth_material(), "ridges, banks and river stones share one material")
	check(SurfaceKit.vertex_material(false, false, SurfaceKit.KIND_MASONRY) == SurfaceKit.vertex_material(false, false, SurfaceKit.KIND_MASONRY), "the castle's stone shares one material")
	check(RegionArt._earth_material().get_shader_parameter("surface_detail") == tex, "natural ground takes the same texture")

	# A batched building: one solid surface with the shared material, UV in metres, kinds by colour.
	var b := JapanKit.Batch.new()
	b.box(Vector3(0, 1, 0), Vector3(4, 2, 3), JapanKit.PLASTER)
	b.box(Vector3(0, 0.2, 0), Vector3(4.2, 0.4, 3.2), JapanKit.STONE)
	b.cyl(Vector3(2, 1, 1.5), 0.15, 2.0, JapanKit.WOOD)
	b.roof(Vector3(0, 2.6, 0), 5.0, 4.0, 1.2, JapanKit.TILE)
	var mesh := b.mesh()
	check(mesh.get_surface_count() == 1 and mesh.surface_get_material(0) == solid, "a building is one surface with the shared material")
	var arrays := mesh.surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	check(uvs.size() == (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), "every building vertex has a surface UV")
	var span := 0.0
	for uv in uvs:
		span = maxf(span, absf(uv.x))
	check(span > 1.5 and span < 3.0, "building UVs are in metres (%.2f)" % span)
	var kinds := {}
	for c in colors:
		kinds[int(roundf((1.0 - c.a) * SurfaceKit.KIND_STEPS))] = true
	check(kinds.has(SurfaceKit.KIND_PLASTER) and kinds.has(SurfaceKit.KIND_STONE) and kinds.has(SurfaceKit.KIND_WOOD) and kinds.has(SurfaceKit.KIND_ROOF),
		"plaster, stone, wood and roof tiles each get their texture")
	check(SurfaceKit.kind_for(SiegeArena.TILE) == SurfaceKit.KIND_ROOF and SurfaceKit.kind_for(SiegeArena.WOOD) == SurfaceKit.KIND_WOOD
		and SurfaceKit.kind_for(SiegeArena.PLASTER) == SurfaceKit.KIND_PLASTER and SurfaceKit.kind_for(SiegeArena.STONE_CORE) == SurfaceKit.KIND_STONE,
		"the castle's palette maps to its surfaces")
	check(SurfaceKit.kind_for(JapanKit.VERMILION) == SurfaceKit.KIND_NONE and SurfaceKit.kind_for(JapanKit.GOLD) == SurfaceKit.KIND_NONE,
		"lacquer and gold stay painted")

	# A field's ground: one material, prepared, the theme's layers.
	var holder := Node3D.new()
	add_child(holder)
	Scenery.ground(holder, 40.0, Color("6fae54"), Color("86c063"), 3, Color("cdb88a"), [], 3.0, [], &"desert")
	var ground := holder.get_node("Ground") as MeshInstance3D
	var gmat := ground.material_override as ShaderMaterial
	check(gmat.get_shader_parameter("surface_detail") == tex, "the field ground takes the shared texture")
	check(int(gmat.get_shader_parameter("ground_layer")) == SurfaceKit.SAND, "the desert floor is sand")
	holder.queue_free()

	# Back to low: the bound texture is released from every live material.
	GameSettings.quality = 0
	SurfaceKit.refresh()
	check(solid.get_shader_parameter("surface_detail") == null and RegionArt._earth_material().get_shader_parameter("surface_detail") == null,
		"going to low quality unbinds the texture everywhere")
	check(SurfaceKit._texture == null, "going to low quality drops the texture")

	GameSettings.quality = saved_quality
	MemoryGuard.pressure = saved_pressure
	SurfaceKit.refresh()
	print("SURFACE KIT: %s | %d checks, %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	get_tree().quit(failures.size())
