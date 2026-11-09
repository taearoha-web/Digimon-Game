class_name SurfaceKit
extends RefCounted
## The textured look of the world's surfaces: ground, paths, paving, walls, roofs, wood,
## castle stone and rocks. One shared Texture2DArray of toon detail layers
## (assets/textures/surfaces/surface_detail.jpg, Poly Haven CC0, see SOURCE.json there)
## multiplies the painted colours of a few SHARED materials (shaders/surface_detail.gdshaderinc).
##
## Phone budget: the array is VRAM-compressed (S3TC on desktop browsers, ETC2 on phones),
## LAYER_SIZE px a layer with mipmaps, about 1.4 MB of video memory in all. On low quality
## (and while an iPhone is under memory pressure) no texture is bound and the shaders skip
## the sampling: the materials fall back to their painted, texture-free look.
##
## Kinds for vertex-coloured batches (JapanKit.Batch): the kind rides in the vertex
## colour's alpha (1 - kind / KIND_STEPS), which the opaque materials never use otherwise.

const TEXTURE_PATH := "res://assets/textures/surfaces/surface_detail.jpg"
## Side of a layer in pixels (the import keeps it; tests/integration/surface_kit_test checks it).
const LAYER_SIZE := 512
const LAYERS := 8
## Layers (same order as tools/make_surface_textures.py and the shader constants).
const GRASS := 0
const DIRT := 1
const SAND := 2
const COBBLE := 3
const STONE_WALL := 4
const ROOF := 5
const WOOD := 6
const ROCK := 7
## Vertex-colour kinds for batched buildings (0: painted only).
const KIND_NONE := 0
const KIND_WOOD := 1
const KIND_PLASTER := 2
const KIND_STONE := 3
const KIND_ROOF := 4
const KIND_MASONRY := 5
## Natural ground forms (ridges, banks, river stones): rock grain on the slopes, earth on top.
const KIND_EARTH := 6
const KIND_STEPS := 16.0

static var _texture: TextureLayered
## Every shared material handed out so far (weak), so a quality change reaches them.
static var _materials: Array[WeakRef] = []
static var _shaders: Dictionary = {}


## Whether the detail textures are on: medium and high quality, not under memory pressure.
static func enabled() -> bool:
	return GameSettings.quality > 0 and MemoryGuard.pressure < 2


## The shared array, loaded on first use while enabled (null otherwise).
static func texture() -> TextureLayered:
	if not enabled():
		return null
	if _texture == null:
		_texture = load(TEXTURE_PATH) as TextureLayered
	return _texture


## Binds the shared texture and amount to [param mat] and remembers it for refresh().
static func prepare(mat: ShaderMaterial) -> ShaderMaterial:
	_bind(mat)
	for ref in _materials:
		if ref.get_ref() == mat:
			return mat
	_materials.append(weakref(mat))
	return mat


static func _bind(mat: ShaderMaterial) -> void:
	var tex := texture()
	mat.set_shader_parameter("surface_detail", tex)
	mat.set_shader_parameter("surface_amount", 1.0 if tex != null else 0.0)


## Brings every shared material up to the current quality (called as a zone is built).
## Going to low quality drops the texture, so its video memory is freed.
static func refresh() -> void:
	var on := enabled()
	var live: Array[WeakRef] = []
	for ref in _materials:
		var mat := ref.get_ref() as ShaderMaterial
		if mat != null:
			_bind(mat)
			live.append(ref)
	_materials = live
	if not on:
		_texture = null


## A cached shader by path (the surface shaders are shared by every material).
static func shader(path: String) -> Shader:
	if not _shaders.has(path):
		_shaders[path] = load(path)
	return _shaders[path]


## A shared, vertex-coloured toon material that textures by the kind in the vertex alpha
## (JapanKit buildings, the castle). `srgb`: the vertex colours are sRGB (as BaseMaterial3D's
## vertex_color_is_srgb). One material per flag combination for the whole game.
static var _vertex_mats: Dictionary = {}


static func vertex_material(srgb := true, double_sided := true, default_kind := KIND_NONE, soft := false) -> ShaderMaterial:
	var key := "%s|%s|%d|%s" % [srgb, double_sided, default_kind, soft]
	if not _vertex_mats.has(key):
		var mat := ShaderMaterial.new()
		var path := "res://shaders/toon_surface.gdshader" if double_sided else "res://shaders/toon_surface_cull.gdshader"
		if soft:
			path = "res://shaders/toon_surface_soft.gdshader"
		mat.shader = shader(path)
		mat.set_shader_parameter("srgb_colors", srgb)
		mat.set_shader_parameter("default_kind", default_kind)
		_vertex_mats[key] = prepare(mat)
	return _vertex_mats[key]


## The kind for a building colour: explicit palette colours first, then by hue/saturation
## (dark wood browns, white plaster, grey stone, slate-blue roof tiles).
static func kind_for(color: Color) -> int:
	var s := color.s
	var v := color.v
	var h := color.h
	if v < 0.2:
		return KIND_NONE
	if s < 0.12 and v > 0.85:
		return KIND_PLASTER
	if h > 0.5 and h < 0.72 and s >= 0.12 and s < 0.4 and v < 0.48:
		return KIND_ROOF
	if s < 0.2 and v >= 0.35:
		return KIND_STONE
	if h > 0.02 and h < 0.13 and s > 0.28 and s < 0.8 and v < 0.78:
		return KIND_WOOD
	return KIND_NONE


## The vertex colour with the kind in its alpha.
static func tag(color: Color, kind: int) -> Color:
	return Color(color.r, color.g, color.b, 1.0 - float(kind) / KIND_STEPS)


## Approximate video memory of the bound texture in bytes (0 when off): 4 bits a texel
## (BC1 / ETC2 RGB) plus a third for the mipmaps.
static func vram_bytes() -> int:
	if _texture == null:
		return 0
	return int(float(LAYER_SIZE * LAYER_SIZE * LAYERS) * 0.5 * 4.0 / 3.0)
