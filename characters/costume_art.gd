class_name CostumeArt
extends RefCounted
## The reward-shop costumes' own pieces (RewardShop.COSTUMES), built in code from
## primitives, sweeps and sheets: every costume dyes the outfit (HeroVisual) and adds
## layers on several bones, so it still reads on a hero in the 250-star set with big
## wings and an aura:
##   kitsune    nine fluffy fox tails fanned behind the hips (cream tips, swaying), big
##              fox ears with cream insides, a fur ruff round the neck, foxfire wisps
##   celestial  small white feathered wings (left off under gear wings), a starlit
##              shoulder capelet with a gold star clasp, a bright halo, twinkling stars
##   royal      a red velvet cape with ermine trim (a short ermine mantle under gear
##              wings), gold clasps and chain, a jewelled crown, gold fringed epaulettes
##   shadow     a demon tail with a glowing spade tip, big curled horns, purple smoke
##   seafoam    a fin crest and ear fins, scallop-shell pauldrons with pearls, bubbles
##   sakura     a blossoming sakura branch hair ornament with tassels, an obi with a big
##              bow and ribbon tails at the back, falling petals
##   midnight   a starry night cape (a capelet under gear wings) with a high collar,
##              crescent horns, a gold crescent moon pin, a few faint stars
##
## Everything is authored in the chibi's model space (x side, y up 0..1, z front) and
## HeroVisual mounts each part on its bone with the bone's rest undone. One mesh per
## bone, at most four surfaces (solid, sheet, sheet2, glow), cached for every wearer;
## the costume shaders (shaders/costume*.gdshader) sway tails, ribbons and capes from
## the vertex data alone, so nothing runs per frame in script. The motes (motes()) are
## one mesh of camera-facing quads moved by their shader: left off at the lowest
## quality, under strict memory pressure and on the cheaply dressed players around
## (HeroVisual.decor_light). No lights, no particles, no shadow casting.

const SOLID := preload("res://shaders/costume_solid.gdshader")
const SHEET := preload("res://shaders/costume_sheet.gdshader")
const OUTLINE := preload("res://shaders/costume_outline.gdshader")
const MOTE := preload("res://shaders/costume_mote.gdshader")
const LAYERS: Array[String] = ["solid", "sheet", "sheet2", "glow"]
## The body's outline width in model units (HeroVisual: 0.012 x its gear scale).
const OUTLINE_WIDTH := 0.0045
const CACHE_LIMIT := 96
## Generous bounds: the sway moves tips and hems past their rest places.
const BOUNDS := AABB(Vector3(-0.9, -0.3, -0.9), Vector3(1.8, 1.9, 1.8))

## The bones each costume dresses and the part built on each.
const PARTS := {
	"kitsune": [["Head", "head"], ["Chest", "ruff"], ["Hips", "tails"]],
	"celestial": [["Head", "head"], ["Chest", "back"]],
	"royal": [["Head", "head"], ["Chest", "back"], ["LeftUpperArm", "arm_l"], ["RightUpperArm", "arm_r"]],
	"shadow": [["Head", "head"], ["Hips", "tail"]],
	"seafoam": [["Head", "head"], ["Chest", "back"], ["LeftUpperArm", "arm_l"], ["RightUpperArm", "arm_r"]],
	"sakura": [["Head", "head"], ["Hips", "obi"]],
	"midnight": [["Head", "head"], ["Chest", "back"]],
}
## Each layer's look: sway (tip offset in model units), speed and lag down the piece,
## glow share, and for the cloth sheets the pattern, trim and lining (costume.gdshaderinc).
const STYLE := {
	"kitsune": {"solid": {"sway": Vector3(0.03, 0.012, 0.022), "speed": 1.35, "lag": 2.4}},
	"celestial": {"solid": {"sway": Vector3(0.0, 0.012, -0.018), "speed": 1.1, "lag": 1.0, "glow": 0.03},
		"sheet": {"pattern": 2.0, "trim": Color("ffd56a"), "trim_width": 0.06, "lining": Color("cfd6ff"), "speck": Color("ffe28a"), "glow": 0.08, "sway": Vector3(0.004, 0.0, -0.01), "speed": 1.3}},
	"royal": {"solid": {"sway": Vector3(0.006, 0.0, 0.008), "speed": 2.0, "lag": 1.0, "glow": 0.05},
		"sheet": {"pattern": 3.0, "trim": Color("fbf8f2"), "trim_width": 0.075, "ermine": 1.0, "lining": Color("8a1428"), "sway": Vector3(0.008, 0.0, -0.028), "speed": 1.2, "lag": 2.6},
		"sheet2": {"pattern": 0.0, "trim": Color("fbf8f2"), "trim_width": 2.0, "ermine": 1.0, "lining": Color("f2ead8")}},
	"shadow": {"solid": {"sway": Vector3(0.045, 0.02, 0.018), "speed": 1.05, "lag": 2.8}},
	"seafoam": {"solid": {"glow": 0.1},
		"sheet": {"sway": Vector3(0.006, 0.006, -0.012), "speed": 1.7, "lag": 1.5, "glow": 0.06, "lining": Color("a6ecf6"), "trim": Color("f2feff"), "trim_width": 0.06}},
	"sakura": {"solid": {"sway": Vector3(0.014, 0.0, -0.014), "speed": 1.5, "lag": 2.0},
		"sheet": {"sway": Vector3(0.02, 0.0, -0.03), "speed": 1.4, "lag": 2.2, "trim": Color("ffd24a"), "trim_width": 0.07, "lining": Color("ffd0e2")}},
	"midnight": {"solid": {"glow": 0.06},
		"sheet": {"pattern": 1.0, "trim": Color("c9d4ff"), "trim_width": 0.03, "lining": Color("3a2a6a"), "speck": Color("eaf0ff"), "sway": Vector3(0.01, 0.0, -0.03), "speed": 1.15, "lag": 2.6},
		"sheet2": {"pattern": 1.0, "trim": Color("c9d4ff"), "trim_width": 0.12, "lining": Color("2a1f55"), "speck": Color("eaf0ff")}},
}
## The drifting motes: how many, the quad shape (costume_mote.gdshader), colour, size in
## metres, the ring they keep (model units) and how they move.
const MOTES := {
	"kitsune": {"n": 3, "shape": 0.0, "color": Color("8fd8ff"), "size": 0.24, "r": [0.4, 0.47], "y": [0.5, 0.82], "orbit": 0.75, "bob": 0.05, "additive": 1.0},
	"celestial": {"n": 6, "shape": 1.0, "color": Color("fff0b0"), "size": 0.2, "r": [0.36, 0.5], "y": [0.2, 1.08], "orbit": 0.3, "bob": 0.03, "twinkle": 1.0, "additive": 1.0},
	"sakura": {"n": 9, "shape": 2.0, "color": Color("ffaacd"), "size": 0.1, "r": [0.28, 0.55], "y_lo": -0.02, "y_hi": 1.15, "rise": -0.075, "orbit": 0.15, "drift": 0.06, "spin": 1.3, "additive": 0.0},
	"shadow": {"n": 7, "shape": 4.0, "color": Color(0.55, 0.16, 0.85, 0.9), "size": 0.42, "r": [0.16, 0.3], "y_lo": 0.0, "y_hi": 0.34, "rise": 0.17, "orbit": 0.35, "drift": 0.03, "additive": 0.35},
	"seafoam": {"n": 6, "shape": 3.0, "color": Color("d4fbff"), "size": 0.13, "r": [0.32, 0.48], "y_lo": 0.05, "y_hi": 1.1, "rise": 0.1, "orbit": 0.25, "drift": 0.05, "additive": 0.5},
	"midnight": {"n": 4, "shape": 1.0, "color": Color("bcd0ff"), "size": 0.12, "r": [0.4, 0.5], "y": [0.45, 1.1], "orbit": 0.2, "twinkle": 1.0, "additive": 1.0},
}

static var _meshes := {}
static var _materials := {}


static func release_cache() -> void:
	_meshes.clear()
	_materials.clear()


## [[bone, part], ...] of costume id ([] for none).
static func parts(id: String) -> Array:
	return PARTS.get(id, [])


## The mesh node of one part (model-space authored; null when the part is empty, such
## as the celestial wings' place under gear wings). winged: gear wings or a cape are
## worn in the wing slot. outlined: the cartoon outline pass on the solid pieces.
static func piece(id: String, part: String, winged: bool, outlined: bool) -> MeshInstance3D:
	var mesh := mesh_of(id, part, winged)
	if mesh == null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = "Costume_" + part
	mi.mesh = mesh
	var layers: Array = mesh.get_meta("layers", [])
	for i in mesh.get_surface_count():
		mi.set_surface_override_material(i, _material(id, String(layers[i]), outlined))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = BOUNDS
	mi.set_meta("no_outline", true)
	mi.set_meta("no_shadow_lod", true)
	mi.set_meta("costume_part", part)
	return mi


## The cached mesh of one part (null when empty).
static func mesh_of(id: String, part: String, winged: bool) -> ArrayMesh:
	var key := "%s|%s|%d" % [id, part, int(winged)]
	if _meshes.has(key):
		return _meshes[key]
	var b := _builder()
	match id:
		"kitsune": _kitsune(b, part)
		"celestial": _celestial(b, part, winged)
		"royal": _royal(b, part, winged)
		"shadow": _shadow(b, part)
		"seafoam": _seafoam(b, part)
		"sakura": _sakura(b, part)
		"midnight": _midnight(b, part, winged)
	var mesh := _commit(b)
	if _meshes.size() >= CACHE_LIMIT:
		_meshes.erase(_meshes.keys()[0])
	_meshes[key] = mesh
	return mesh


## How many motes costume id shows now (0 at the lowest quality or under strict
## memory pressure; fewer at medium quality or while memory is tight).
static func mote_count(id: String) -> int:
	if not MOTES.has(id) or GameSettings.quality <= 0 or MemoryGuard.pressure >= 2:
		return 0
	return VfxBudget.count(int(MOTES[id].n))


## The costume's drifting motes as one mesh node in model space (null for none).
static func motes(id: String) -> MeshInstance3D:
	var n := mote_count(id)
	if n <= 0:
		return null
	var spec: Dictionary = MOTES[id]
	var key := "motes|%s|%d" % [id, n]
	if not _meshes.has(key):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("costume_motes_" + id)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var r: Array = spec.r
		var ys: Array = spec.get("y", [spec.get("y_lo", 0.0), spec.get("y_hi", 1.0)])
		var corners := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for k in n:
			var a := TAU * (float(k) + rng.randf_range(-0.25, 0.25)) / float(n)
			var rad := rng.randf_range(float(r[0]), float(r[1]))
			var home := Vector3(cos(a) * rad, rng.randf_range(float(ys[0]), float(ys[1])), sin(a) * rad)
			var phase := (float(k) + rng.randf()) / float(n)
			var size := float(spec.size) * rng.randf_range(0.8, 1.15)
			for c in corners:
				st.set_color(spec.color)
				st.set_uv(c)
				st.set_uv2(Vector2(phase, size))
				st.set_normal(Vector3.BACK)
				st.add_vertex(home)
			var i := k * 4
			for j in [0, 1, 2, 0, 2, 3]:
				st.add_index(i + j)
		_meshes[key] = st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "CostumeMotes"
	mi.mesh = _meshes[key]
	mi.material_override = _mote_material(id)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = BOUNDS
	mi.set_meta("no_outline", true)
	mi.set_meta("no_shadow_lod", true)
	mi.set_meta("costume_motes", true)
	return mi


# --- Materials ------------------------------------------------------------------------

static func _material(id: String, layer: String, outlined: bool) -> ShaderMaterial:
	var key := "%s|%s|%d" % [id, layer, int(outlined and layer == "solid")]
	if _materials.has(key):
		return _materials[key]
	var style: Dictionary = (STYLE.get(id, {}) as Dictionary).get(layer if layer != "glow" else "solid", {})
	var mat := ShaderMaterial.new()
	mat.shader = SOLID if layer == "solid" or layer == "glow" else SHEET
	_sway_params(mat, style)
	mat.set_shader_parameter("glow", 1.1 if layer == "glow" else float(style.get("glow", 0.0)))
	if layer == "sheet" or layer == "sheet2":
		mat.set_shader_parameter("pattern", float(style.get("pattern", 0.0)))
		mat.set_shader_parameter("trim_color", style.get("trim", Color.WHITE))
		mat.set_shader_parameter("trim_width", float(style.get("trim_width", 0.0)))
		mat.set_shader_parameter("ermine", float(style.get("ermine", 0.0)))
		mat.set_shader_parameter("lining_color", style.get("lining", Color(0.2, 0.1, 0.15)))
		mat.set_shader_parameter("speck_color", style.get("speck", Color.WHITE))
	if outlined and layer == "solid":
		var line := ShaderMaterial.new()
		line.shader = OUTLINE
		_sway_params(line, style)
		line.set_shader_parameter("width", OUTLINE_WIDTH)
		mat.next_pass = line
	_materials[key] = mat
	return mat


static func _sway_params(mat: ShaderMaterial, style: Dictionary) -> void:
	mat.set_shader_parameter("sway_amp", style.get("sway", Vector3.ZERO))
	mat.set_shader_parameter("sway_speed", float(style.get("speed", 1.6)))
	mat.set_shader_parameter("sway_lag", float(style.get("lag", 2.0)))


static func _mote_material(id: String) -> ShaderMaterial:
	var key := "motes|" + id
	if _materials.has(key):
		return _materials[key]
	var spec: Dictionary = MOTES[id]
	var mat := ShaderMaterial.new()
	mat.shader = MOTE
	for p in ["orbit", "rise", "y_lo", "y_hi", "bob", "drift", "twinkle", "spin", "shape", "additive"]:
		if spec.has(p):
			mat.set_shader_parameter(p, float(spec[p]))
	if not spec.has("rise"):
		mat.set_shader_parameter("rise", 0.0)
	_materials[key] = mat
	return mat


# --- Building ---------------------------------------------------------------------------

static func _builder() -> Dictionary:
	var b := {}
	for layer in LAYERS:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		b[layer] = st
		b[layer + "_n"] = 0
	return b


static func _commit(b: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var layers: Array = []
	for layer in LAYERS:
		if int(b[layer + "_n"]) > 0:
			var st: SurfaceTool = b[layer]
			st.commit(mesh)
			layers.append(layer)
	if layers.is_empty():
		return null
	mesh.set_meta("layers", layers)
	# How many tubes went in (tails, horns, cords): the tests count the nine tails by it.
	mesh.set_meta("sweeps", int(b.get("sweeps", 0)))
	return mesh


## One triangle, wound so its front faces where the vertex normals point.
static func _tri(b: Dictionary, layer: String, p: Array, n: Array, c: Array, uv: Array, fr: Array) -> void:
	var g: Vector3 = (p[1] - p[0]).cross(p[2] - p[0])
	if g.length_squared() < 1e-16:
		return
	var order := [0, 1, 2]
	# Godot's front faces wind clockwise: their cross product points away from the normal.
	if g.dot(n[0] + n[1] + n[2]) > 0.0:
		order = [0, 2, 1]
	var st: SurfaceTool = b[layer]
	for i in order:
		st.set_color(c[i])
		st.set_normal(n[i])
		st.set_uv(uv[i])
		st.set_uv2(fr[i])
		st.add_vertex(p[i])
	b[layer + "_n"] = int(b[layer + "_n"]) + 3


## A primitive (MeshKit) placed by pos / size / rot (degrees) or by `basis`; free is
## its sway data (Vector2) or a Callable(point) -> Vector2.
static func _prim(b: Dictionary, layer: String, mesh: Mesh, color: Color, pos: Vector3, size: Vector3, rot := Vector3.ZERO, free: Variant = Vector2.ZERO, basis_override: Variant = null) -> void:
	var basis: Basis = (basis_override as Basis) * Basis.from_scale(size) if basis_override is Basis else Basis.from_euler(rot * PI / 180.0) * Basis.from_scale(size)
	var xform := Transform3D(basis, pos)
	var nb := basis.inverse().transposed()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var count := idx.size() if not idx.is_empty() else verts.size()
	for t in range(0, count - 2, 3):
		var p := []
		var n := []
		var fr := []
		for j in 3:
			var k := idx[t + j] if not idx.is_empty() else t + j
			var at := xform * verts[k]
			p.append(at)
			n.append((nb * norms[k]).normalized())
			fr.append((free as Callable).call(at) if free is Callable else free)
		_tri(b, layer, p, n, [color, color, color], [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], fr)


## A grid of rows x cols vertices (row-major) made into quads.
static func _grid(b: Dictionary, layer: String, rows: int, cols: int, P: Array, N: Array, C: Array, U: Array, F: Array) -> void:
	for r in rows - 1:
		for c in cols - 1:
			var i := r * cols + c
			for tri in [[i, i + cols, i + 1], [i + 1, i + cols, i + cols + 1]]:
				_tri(b, layer, [P[tri[0]], P[tri[1]], P[tri[2]]], [N[tri[0]], N[tri[1]], N[tri[2]]],
					[C[tri[0]], C[tri[1]], C[tri[2]]], [U[tri[0]], U[tri[1]], U[tri[2]]], [F[tri[0]], F[tri[1]], F[tri[2]]])


## A parametric sheet: pos(u, v) for u, v in 0..1, its colour(u, v), its sway data
## free(u, v) and `out` (Callable(point) -> Vector3), the side its front faces.
static func _surface(b: Dictionary, layer: String, rows: int, cols: int, pos: Callable, color: Callable, free: Callable, out: Callable) -> void:
	var P := []
	var N := []
	var C := []
	var U := []
	var F := []
	var e := 0.002
	for r in rows:
		var v := float(r) / float(rows - 1)
		for c in cols:
			var u := float(c) / float(cols - 1)
			var p: Vector3 = pos.call(u, v)
			var du: Vector3 = pos.call(minf(u + e, 1.0), v) - pos.call(maxf(u - e, 0.0), v)
			var dv: Vector3 = pos.call(u, minf(v + e, 1.0)) - pos.call(u, maxf(v - e, 0.0))
			var n := du.cross(dv)
			n = n.normalized() if n.length_squared() > 1e-14 else (out.call(p) as Vector3).normalized()
			if n.dot(out.call(p)) < 0.0:
				n = -n
			P.append(p)
			N.append(n)
			C.append(color.call(u, v))
			U.append(Vector2(u, v))
			F.append(free.call(u, v))
	_grid(b, layer, rows, cols, P, N, C, U, F)


## A tube along `pts` (sides around), radius(t), colour(t), sway data free(t) and an
## optional ridge(angle, t) multiplier for tufts; the first ring is closed with a cap.
static func _sweep(b: Dictionary, layer: String, pts: Array, sides: int, radius: Callable, color: Callable, free: Callable, ridge := Callable()) -> void:
	var rows := pts.size()
	var tangent := []
	for i in rows:
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var z: Vector3 = pts[mini(i + 1, rows - 1)]
		tangent.append((z - a).normalized())
	var t0: Vector3 = tangent[0]
	var side := t0.cross(Vector3.UP if absf(t0.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()
	var P := []
	var N := []
	var C := []
	var U := []
	var F := []
	var cols := sides + 1
	for i in rows:
		var tg: Vector3 = tangent[i]
		# Parallel transport keeps the rings from twisting along the curve.
		side = (side - tg * side.dot(tg)).normalized()
		var up := tg.cross(side).normalized()
		var t := float(i) / float(rows - 1)
		var r: float = radius.call(t)
		var col: Color = color.call(t)
		var fr: Vector2 = free.call(t)
		for k in cols:
			var a := TAU * float(k % sides) / float(sides)
			var dir := side * cos(a) + up * sin(a)
			var m: float = ridge.call(a, t) if ridge.is_valid() else 1.0
			P.append((pts[i] as Vector3) + dir * r * m)
			N.append(dir)
			C.append(col)
			U.append(Vector2(float(k) / float(sides), t))
			F.append(fr)
	_grid(b, layer, rows, cols, P, N, C, U, F)
	b["sweeps"] = int(b.get("sweeps", 0)) + 1
	# The root cap.
	var c0: Vector3 = pts[0]
	var back: Vector3 = -(tangent[0] as Vector3)
	for k in sides:
		_tri(b, layer, [c0, P[k], P[k + 1]], [back, back, back], [C[0], C[0], C[0]], [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], [F[0], F[0], F[0]])


## A bevelled flat shape: the polygon `pts` (x, y; star-shaped about its middle) in
## the plane of `xf` (its z the thickness axis), rim colour(s) at the points and
## `middle` at the raised ridge. free: Vector2 or Callable(point) -> Vector2.
static func _flat(b: Dictionary, layer: String, pts: Array, xf: Transform3D, thick: float, middle: Color, rim: Variant, free: Variant = Vector2.ZERO) -> void:
	var mid := Vector2.ZERO
	for q in pts:
		mid += q
	mid /= float(pts.size())
	for face in [1.0, -1.0]:
		var peak := xf * Vector3(mid.x, mid.y, face * thick)
		for i in pts.size():
			var qa: Vector2 = pts[i]
			var qb: Vector2 = pts[(i + 1) % pts.size()]
			var pa := xf * Vector3(qa.x, qa.y, 0)
			var pb := xf * Vector3(qb.x, qb.y, 0)
			var n := (pa - peak).cross(pb - peak).normalized()
			var facing := (xf.basis * Vector3(0, 0, face)).normalized()
			if n.dot(facing) < 0.0:
				n = -n
			var ca: Color = (rim as Array)[i] if rim is Array else rim
			var cb: Color = (rim as Array)[(i + 1) % pts.size()] if rim is Array else rim
			var fp: Vector2 = (free as Callable).call(peak) if free is Callable else free
			var fa: Vector2 = (free as Callable).call(pa) if free is Callable else free
			var fb: Vector2 = (free as Callable).call(pb) if free is Callable else free
			_tri(b, layer, [peak, pa, pb], [n, n, n], [middle, ca, cb], [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], [fp, fa, fb])


## A small low sphere for gems, pearls, beads and bells (48 triangles).
static var _dot_mesh: SphereMesh


static func _dot() -> Mesh:
	if _dot_mesh == null:
		_dot_mesh = SphereMesh.new()
		_dot_mesh.radius = 0.5
		_dot_mesh.height = 1.0
		_dot_mesh.radial_segments = 8
		_dot_mesh.rings = 4
	return _dot_mesh


static func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: int) -> Array:
	var out := []
	for i in n:
		var t := float(i) / float(n - 1)
		var s := 1.0 - t
		out.append(p0 * s * s * s + p1 * 3.0 * s * s * t + p2 * 3.0 * s * t * t + p3 * t * t * t)
	return out


## Points through every control point (Catmull-Rom), `per` samples a span.
static func _spline(ctrl: Array, per: int) -> Array:
	var out := []
	for i in ctrl.size() - 1:
		var p0: Vector3 = ctrl[maxi(i - 1, 0)]
		var p1: Vector3 = ctrl[i]
		var p2: Vector3 = ctrl[i + 1]
		var p3: Vector3 = ctrl[mini(i + 2, ctrl.size() - 1)]
		for s in per:
			var t := float(s) / float(per)
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	out.append(ctrl[ctrl.size() - 1])
	return out


## A basis turning +Y onto dir.
static func _along(dir: Vector3) -> Basis:
	var d := dir.normalized()
	if d.dot(Vector3.UP) < -0.999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, d))


## A transform whose x / y span the plane (x_axis, y_axis) at `at`, z its normal.
static func _plane(at: Vector3, x_axis: Vector3, y_axis: Vector3, scale := 1.0) -> Transform3D:
	var x := x_axis.normalized()
	var z := x.cross(y_axis).normalized()
	var y := z.cross(x).normalized()
	return Transform3D(Basis(x * scale, y * scale, z * scale), at)


## Sway data that grows with the distance from `root` over `length`.
static func _hang(root: Vector3, length: float, phase: float) -> Callable:
	return func(p: Vector3) -> Vector2: return Vector2(clampf(p.distance_to(root) / length, 0.0, 1.0), phase)


## Sway data that grows downwards from height `top` over `length`.
static func _drop(top: float, length: float, phase: float) -> Callable:
	return func(p: Vector3) -> Vector2: return Vector2(clampf((top - p.y) / length, 0.0, 1.0), phase)


static func _ellipse(rx: float, ry: float, n := 10, notch := 0.0) -> Array:
	var out := []
	for i in n:
		var a := TAU * float(i) / float(n)
		var r := 1.0 - notch * pow(maxf(0.0, cos(a - PI * 0.5)), 12.0)
		out.append(Vector2(cos(a) * rx * r, sin(a) * ry * r))
	return out


static func _star(outer: float, inner: float, points := 5, turn := 0.0) -> Array:
	var out := []
	for i in points * 2:
		var a := turn + PI * 0.5 + PI * float(i) / float(points)
		var r := outer if i % 2 == 0 else inner
		out.append(Vector2(cos(a) * r, sin(a) * r))
	return out


## A feather / leaf: pointed at the tip, rounder at the base, `length` along +y.
static func _leaf(length: float, width: float) -> Array:
	return [Vector2(0, 0), Vector2(width * 0.45, length * 0.18), Vector2(width * 0.5, length * 0.45), Vector2(width * 0.34, length * 0.75),
		Vector2(0, length), Vector2(-width * 0.34, length * 0.75), Vector2(-width * 0.5, length * 0.45), Vector2(-width * 0.45, length * 0.18)]


static func _crescent(r: float, thin := 0.55, n := 12) -> Array:
	# Outer arc then the inner arc back, offset to cut the moon.
	var out := []
	for i in n + 1:
		var a := lerpf(-PI * 0.78, PI * 0.78, float(i) / float(n))
		out.append(Vector2(cos(a + PI * 0.5) * -r, sin(a + PI * 0.5) * r).rotated(PI * 0.5))
	for i in range(n, -1, -1):
		var a := lerpf(-PI * 0.62, PI * 0.62, float(i) / float(n))
		out.append(Vector2(cos(a + PI * 0.5) * -r * thin + r * (1.0 - thin) * 0.9, sin(a + PI * 0.5) * r * 0.86).rotated(PI * 0.5))
	return out


# --- Kitsune (จิ้งจอกเก้าหาง) ------------------------------------------------------------

const FOX := Color("f47a26")
const FOX_DEEP := Color("d85a16")
const FOX_LIGHT := Color("ff9d4a")
const FOX_CREAM := Color("fff3e2")
const FOX_TIP := Color("4a2414")


static func _kitsune(b: Dictionary, part: String) -> void:
	match part:
		"head":
			for side in [-1.0, 1.0]:
				var base := Vector3(side * 0.142, 0.915, -0.005)
				var tilt := Basis(Vector3.FORWARD, side * deg_to_rad(20.0)) * Basis(Vector3.UP, side * deg_to_rad(-14.0)) * Basis(Vector3.RIGHT, deg_to_rad(-8.0))
				var outer := [Vector2(-0.07, 0), Vector2(-0.058, 0.08), Vector2(-0.03, 0.16), Vector2(0, 0.205), Vector2(0.03, 0.16), Vector2(0.058, 0.08), Vector2(0.07, 0)]
				var rims := []
				for q in outer:
					rims.append(FOX_TIP if q.y > 0.15 else (FOX_DEEP if q.y < 0.01 else FOX))
				_flat(b, "solid", outer, Transform3D(tilt, base), 0.026, FOX_LIGHT, rims)
				var inner := []
				for q in outer:
					inner.append(Vector2(q.x * 0.6, q.y * 0.7 + 0.012))
				_flat(b, "solid", inner, Transform3D(tilt, base + tilt * Vector3(0, 0, 0.018)), 0.01, FOX_CREAM, Color("ffd2b8"))
				# A tuft of cream fur at the ear's root.
				_prim(b, "solid", MeshKit.cone(), FOX_CREAM, base + tilt * Vector3(side * 0.02, 0.02, 0.03), Vector3(0.05, 0.07, 0.03), Vector3.ZERO, Vector2.ZERO, tilt * Basis(Vector3.FORWARD, side * 0.5))
		"ruff":
			var n := 18
			for k in n:
				var a := TAU * float(k) / float(n)
				var ring := Vector3(sin(a) * 0.118, 0.585, 0.035 + cos(a) * 0.104)
				var out := Vector3(sin(a), -0.55, cos(a) * 0.9)
				var col := FOX_CREAM if k % 2 == 0 else Color("ffe6c8")
				_prim(b, "solid", MeshKit.cone(), col, ring + out.normalized() * 0.03, Vector3(0.062, 0.085, 0.045), Vector3.ZERO, Vector2.ZERO, _along(out) * Basis(Vector3.UP, a))
			_prim(b, "solid", MeshKit.torus(), FOX_CREAM, Vector3(0, 0.592, 0.035), Vector3(0.27, 0.32, 0.245))
			# A red tassel cord with a little gold bell at the throat.
			_prim(b, "solid", MeshKit.torus(), Color("d8243a"), Vector3(0, 0.565, 0.04), Vector3(0.26, 0.12, 0.24), Vector3(8, 0, 0))
			_prim(b, "solid", _dot(), Color("ffd24a"), Vector3(0, 0.535, 0.158), Vector3.ONE * 0.034)
		"tails":
			var root := Vector3(0, 0.305, -0.055)
			for k in 9:
				var s := (float(k) - 4.0) / 4.0
				var th := s * deg_to_rad(88.0)
				var length := 0.47 - 0.07 * absf(s)
				var outward := Vector3(sin(th), cos(th), 0)
				var p0 := root + Vector3(s * 0.025, -0.01 * absf(s), 0)
				# Every other tail sits further back, so the fan layers instead of fusing.
				var depth := -0.19 - 0.05 * (1.0 - absf(s)) - (0.07 if k % 2 == 1 else 0.0)
				var curl := Vector3(-sin(th) * 0.09, 0.03 - 0.04 * absf(s), depth + 0.07)
				var pts := _bezier(p0, p0 + Vector3(s * 0.03, -0.06, -0.13), p0 + outward * length * 0.66 + Vector3(0, 0, depth),
					p0 + outward * length + curl, 13)
				var fat := 0.058 - 0.008 * absf(s)
				var phase := float(k) * 0.71
				_sweep(b, "solid", pts, 10,
					func(t: float) -> float: return maxf(0.016, fat * pow(maxf(sin(PI * pow(t, 0.72)), 0.0), 0.62)),
					func(t: float) -> Color:
						var c := FOX_DEEP.lerp(FOX, smoothstep(0.0, 0.25, t)).lerp(FOX_LIGHT, smoothstep(0.35, 0.62, t) * 0.6)
						return c.lerp(FOX_CREAM, smoothstep(0.66, 0.8, t)),
					func(t: float) -> Vector2: return Vector2(t, phase),
					func(a: float, t: float) -> float: return 1.0 + 0.16 * cos(5.0 * a + t * 9.0 + phase) * smoothstep(0.12, 0.4, t))


# --- Celestial (เทวดาแสงดาว) ---------------------------------------------------------------

const HOLY_GOLD := Color("ffd56a")
const HOLY_WHITE := Color("fbfaff")


static func _celestial(b: Dictionary, part: String, winged: bool) -> void:
	match part:
		"head":
			# The halo: a bright ring with six little stars, floating over the crown.
			var at := Vector3(0, 1.12, -0.05)
			var tilt := Basis(Vector3.RIGHT, deg_to_rad(-14.0))
			_prim(b, "glow", MeshKit.torus(), Color("ffc83a"), at, Vector3(0.4, 0.3, 0.4), Vector3.ZERO, Vector2.ZERO, tilt)
			_prim(b, "glow", MeshKit.torus(), Color("fff4c8"), at + Vector3(0, 0.006, 0), Vector3(0.37, 0.1, 0.37), Vector3.ZERO, Vector2.ZERO, tilt)
			for k in 8:
				var a := TAU * float(k) / 8.0
				var p := at + tilt * Vector3(cos(a) * 0.2, 0, sin(a) * 0.2)
				_flat(b, "glow", _star(0.045 if k % 2 == 0 else 0.03, 0.014, 4), Transform3D(Basis.IDENTITY, p + Vector3(0, 0.01, 0)), 0.008, Color.WHITE, Color("ffe07a"))
			# Little wings at the temples.
			for side in [-1.0, 1.0]:
				var root := Vector3(side * 0.235, 0.82, -0.04)
				for k in 3:
					var dir := Vector3(side * 0.55, 1.0 - 0.3 * k, -0.45).normalized()
					var xf := Transform3D(_along(dir) * Basis(Vector3.UP, side * 1.2), root)
					_flat(b, "solid", _leaf(0.14 - 0.028 * k, 0.05), xf, 0.007, HOLY_WHITE, [HOLY_WHITE, HOLY_WHITE, Color("eef0ff"), Color("ffeab0"), HOLY_GOLD, Color("ffeab0"), Color("eef0ff"), HOLY_WHITE])
		"back":
			_capelet(b, "sheet", 0.62, 0.17, 1.4, 0.115, 0.215, Color("f4f2ff"), Color("dcdcff"), 5.0, 0.1)
			# A gold star clasp at the throat.
			_flat(b, "glow", _star(0.042, 0.018, 5), Transform3D(Basis.IDENTITY, Vector3(0, 0.575, 0.128)), 0.012, Color("fff6c8"), HOLY_GOLD)
			if not winged:
				for side in [-1.0, 1.0]:
					_feather_wing(b, side)


## One small feathered wing on the back (side -1 / 1): long flight feathers fanned out
## and up, a row of shorter coverts over them.
static func _feather_wing(b: Dictionary, side: float) -> void:
	var root := Vector3(side * 0.045, 0.555, -0.085)
	var across := Vector3(side, 0.0, -0.32).normalized()
	var up := Vector3(0, 1, -0.22).normalized()
	var rows := [[7, 1.0, 0.0, Color("e4e7ff")], [5, 0.62, -0.012, Color("f4f2ff")]]
	for row in rows:
		var count: int = row[0]
		for k in count:
			var f := float(k) / float(count - 1)
			var ang := deg_to_rad(lerpf(78.0, -22.0, f))
			var dir := (across * cos(ang) + up * sin(ang)).normalized()
			var length: float = (0.16 + 0.12 * sin(PI * clampf(f * 1.1, 0.0, 1.0))) * float(row[1])
			var at := root + dir * 0.02 + across.cross(up) * float(row[2]) * side
			var xf := _plane(at, dir.cross(across.cross(up)), dir)
			var tipc := Color("ffe6a0") if row[1] > 0.9 else Color("e8eaff")
			var col: Color = row[3]
			_flat(b, "solid", _leaf(length, 0.05), xf, 0.008, col, [col, HOLY_WHITE, HOLY_WHITE, HOLY_WHITE.lerp(tipc, 0.5), tipc, HOLY_WHITE.lerp(tipc, 0.5), HOLY_WHITE, HOLY_WHITE], _hang(root, 0.3, 0.0))


# --- Royal (ราชันทองคำ) --------------------------------------------------------------------

const GOLD := Color("ffcc3a")
const GOLD_DEEP := Color("d9961c")
const VELVET := Color("b3102e")
const VELVET_DEEP := Color("6a0a1c")


static func _royal(b: Dictionary, part: String, winged: bool) -> void:
	match part:
		"head":
			var c := Vector3(0, 0.962, -0.005)
			var tilt := Basis(Vector3.RIGHT, deg_to_rad(-9.0))
			var ring := func(p: Vector3) -> Vector3: return c + tilt * p
			# Velvet cap inside, then the band, its points and pearls, gems and the orb.
			_prim(b, "solid", MeshKit.hemisphere(), VELVET, ring.call(Vector3(0, 0.03, 0)), Vector3(0.235, 0.2, 0.225), Vector3.ZERO, Vector2.ZERO, tilt)
			_prim(b, "solid", MeshKit.cylinder(), GOLD, ring.call(Vector3(0, 0.02, 0)), Vector3(0.262, 0.05, 0.25), Vector3.ZERO, Vector2.ZERO, tilt)
			_prim(b, "solid", MeshKit.torus(), GOLD_DEEP, ring.call(Vector3(0, -0.004, 0)), Vector3(0.28, 0.2, 0.268), Vector3.ZERO, Vector2.ZERO, tilt)
			_prim(b, "solid", MeshKit.torus(), GOLD_DEEP, ring.call(Vector3(0, 0.046, 0)), Vector3(0.276, 0.16, 0.264), Vector3.ZERO, Vector2.ZERO, tilt)
			var gems := [Color("ff2a4a"), Color("3a7bff"), Color("22d07a"), Color("ff2a4a"), Color("b35cff"), Color("22d07a"), Color("3a7bff"), Color("ff2a4a")]
			for k in 8:
				var a := TAU * float(k) / 8.0
				var dir := Vector3(sin(a), 0, cos(a))
				var tall := k % 2 == 0
				var h := 0.1 if tall else 0.062
				var base: Vector3 = ring.call(dir * 0.128 + Vector3(0, 0.04, 0))
				_prim(b, "solid", MeshKit.cone(), GOLD, base + tilt * Vector3(0, h * 0.5, 0), Vector3(0.05, h, 0.026), Vector3.ZERO, Vector2.ZERO, tilt * Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, deg_to_rad(10.0)))
				_prim(b, "glow", _dot(), Color("fff8e8") if tall else GOLD, base + tilt * (Vector3(0, h + 0.008, 0) + dir * 0.012), Vector3.ONE * (0.026 if tall else 0.018))
				_prim(b, "glow", _dot(), gems[k], ring.call(dir * 0.137 + Vector3(0, 0.02, 0)), Vector3(0.03, 0.03, 0.016), Vector3.ZERO, Vector2.ZERO, Basis(Vector3.UP, a))
			_prim(b, "solid", _dot(), GOLD, ring.call(Vector3(0, 0.125, 0)), Vector3.ONE * 0.05)
			_prim(b, "solid", MeshKit.box(), GOLD, ring.call(Vector3(0, 0.168, 0)), Vector3(0.012, 0.05, 0.012), Vector3.ZERO, Vector2.ZERO, tilt)
			_prim(b, "solid", MeshKit.box(), GOLD, ring.call(Vector3(0, 0.172, 0)), Vector3(0.036, 0.012, 0.012), Vector3.ZERO, Vector2.ZERO, tilt)
		"back":
			# The ermine mantle over the shoulders.
			_capelet(b, "sheet2", 0.63, 0.11, 1.62, 0.108, 0.198, Color.WHITE, Color.WHITE, 0.0, 0.0)
			if not winged:
				_long_cape(b, "sheet", 0.6, 0.5, 0.3, 0.54, VELVET, VELVET_DEEP, 0.0)
			# Gold clasps joined by a chain across the chest.
			for side in [-1.0, 1.0]:
				var at := Vector3(side * 0.092, 0.56, 0.112)
				_prim(b, "solid", MeshKit.cylinder(), GOLD, at, Vector3(0.05, 0.014, 0.05), Vector3(78, 0, 0))
				_prim(b, "glow", _dot(), Color("ff2a4a"), at + Vector3(0, 0.002, 0.01), Vector3(0.026, 0.026, 0.014))
			var chain := _bezier(Vector3(-0.09, 0.556, 0.118), Vector3(-0.04, 0.53, 0.14), Vector3(0.04, 0.53, 0.14), Vector3(0.09, 0.556, 0.118), 8)
			_sweep(b, "solid", chain, 5, func(_t: float) -> float: return 0.0055, func(_t: float) -> Color: return GOLD, func(_t: float) -> Vector2: return Vector2.ZERO)
		"arm_l", "arm_r":
			var side := 1.0 if part == "arm_l" else -1.0
			var at := Vector3(side * 0.158, 0.598, 0.022)
			var turn := Basis(Vector3.FORWARD, side * deg_to_rad(24.0))
			_prim(b, "solid", MeshKit.cylinder(), GOLD, at, Vector3(0.118, 0.024, 0.108), Vector3.ZERO, Vector2.ZERO, turn)
			_prim(b, "solid", MeshKit.torus(), GOLD_DEEP, at, Vector3(0.124, 0.22, 0.114), Vector3.ZERO, Vector2.ZERO, turn)
			_prim(b, "solid", MeshKit.hemisphere(), VELVET, at + turn * Vector3(0, 0.012, 0), Vector3(0.07, 0.05, 0.064), Vector3.ZERO, Vector2.ZERO, turn)
			_prim(b, "glow", _dot(), Color("fff6d8"), at + turn * Vector3(0, 0.03, 0), Vector3.ONE * 0.02)
			# The fringe of gold bullion round the outer edge.
			for k in 9:
				var a := lerpf(-1.45, 1.45, float(k) / 8.0)
				var rim := at + turn * Vector3(side * cos(a) * 0.056, -0.004, sin(a) * 0.052)
				_prim(b, "solid", MeshKit.box(), Color("ffd75a"), rim + Vector3(side * 0.008, -0.024, 0), Vector3(0.01, 0.05, 0.01), Vector3(0, 0, side * 14.0), _drop(rim.y, 0.06, float(k) * 0.5))


## A short shoulder capelet: an arc round the back and sides, from height `top` down
## `length`, `spread` radians either side of the spine, radius r0 at the neck to r1 at
## the hem, hem points (count, depth) cut into it.
static func _capelet(b: Dictionary, layer: String, top: float, length: float, spread: float, r0: float, r1: float, col: Color, hem: Color, points: float, depth: float) -> void:
	_surface(b, layer, 9, 25,
		func(u: float, v: float) -> Vector3:
			var phi := (u * 2.0 - 1.0) * spread
			var cut := 1.0 + depth * absf(sin(u * PI * points)) if points > 0.0 else 1.0
			var vv := v * cut
			var rad := lerpf(r0, r1, pow(vv, 0.85))
			return Vector3(sin(phi) * rad * 1.08, top - vv * length, 0.035 - cos(phi) * rad),
		func(_u: float, v: float) -> Color: return col.lerp(hem, v),
		func(_u: float, v: float) -> Vector2: return Vector2(v * 0.6, 0.0),
		func(p: Vector3) -> Vector3: return Vector3(p.x, 0.2, p.z - 0.035))


## A long cape hanging from the shoulders: top height, length, width at the top and
## the hem, cloth colour into its hem colour, hem points (0 straight).
static func _long_cape(b: Dictionary, layer: String, top: float, length: float, w0: float, w1: float, col: Color, hem: Color, points: float) -> void:
	_surface(b, layer, 18, 15,
		func(u: float, v: float) -> Vector3:
			var s := u * 2.0 - 1.0
			var cut := 1.0 - 0.1 * absf(sin(u * PI * points)) if points > 0.0 else 1.0 + 0.04 * (1.0 - s * s)
			var vv := v * cut
			var half := lerpf(w0, w1, pow(vv, 0.8)) * 0.5
			var hug := 1.0 - smoothstep(0.0, 0.45, vv)
			var pleat := sin((u * 5.0) * TAU) * 0.012 * smoothstep(0.1, 1.0, vv)
			return Vector3(s * half, top - vv * length, -0.078 + s * s * 0.07 * hug - vv * 0.1 - pleat),
		func(_u: float, v: float) -> Color: return col.lerp(hem, smoothstep(0.1, 1.0, v)),
		func(_u: float, v: float) -> Vector2: return Vector2(pow(v, 1.2), 0.0),
		func(p: Vector3) -> Vector3: return Vector3(p.x * 0.3, 0.0, -1.0))


# --- Shadow (เงาอสูร) ------------------------------------------------------------------------

const DEMON := Color("341446")
const DEMON_MID := Color("6a2a8c")
const DEMON_GLOW := Color("d455ff")


static func _shadow(b: Dictionary, part: String) -> void:
	match part:
		"head":
			for side in [-1.0, 1.0]:
				# Ram-like: out to the side, back, then curling up and forward.
				var ctrl := [Vector3(side * 0.11, 0.925, 0.005), Vector3(side * 0.2, 0.975, -0.04), Vector3(side * 0.29, 1.0, -0.1),
					Vector3(side * 0.35, 1.07, -0.14), Vector3(side * 0.35, 1.17, -0.1), Vector3(side * 0.31, 1.22, -0.02)]
				_sweep(b, "solid", _spline(ctrl, 4), 9,
					func(t: float) -> float: return 0.046 * pow(1.0 - t, 0.75) + 0.003,
					func(t: float) -> Color: return DEMON.lerp(DEMON_MID, smoothstep(0.15, 0.7, t)).darkened(0.35 * smoothstep(0.3, 0.0, absf(fmod(t * 9.0, 1.0) - 0.5)) * (1.0 - t)).lerp(DEMON_GLOW, smoothstep(0.8, 1.0, t)),
					func(_t: float) -> Vector2: return Vector2.ZERO,
					func(_a: float, t: float) -> float: return 1.0 + 0.1 * smoothstep(0.55, 0.0, absf(fmod(t * 9.0, 1.0) - 0.5)) * (1.0 - t))
			# A violet gem on the brow.
			_flat(b, "glow", [Vector2(0, 0.03), Vector2(0.018, 0), Vector2(0, -0.022), Vector2(-0.018, 0)], Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-20.0)), Vector3(0, 0.875, 0.21)), 0.008, Color("ffd0ff"), DEMON_GLOW)
		"tail":
			var ctrl := [Vector3(0, 0.3, -0.06), Vector3(0.01, 0.23, -0.16), Vector3(0.06, 0.19, -0.27), Vector3(0.13, 0.24, -0.35),
				Vector3(0.17, 0.36, -0.37), Vector3(0.15, 0.47, -0.33)]
			var pts := _spline(ctrl, 4)
			_sweep(b, "solid", pts, 8,
				func(t: float) -> float: return lerpf(0.024, 0.011, t),
				func(t: float) -> Color: return DEMON.lerp(DEMON_MID, 0.5 + 0.5 * sin(t * 30.0) * smoothstep(0.2, 0.5, t)),
				func(t: float) -> Vector2: return Vector2(t, 0.0))
			var tip: Vector3 = pts[pts.size() - 1]
			var dir := (tip - (pts[pts.size() - 3] as Vector3)).normalized()
			var spade := [Vector2(0, 0.12), Vector2(0.03, 0.075), Vector2(0.062, 0.035), Vector2(0.058, 0.0), Vector2(0.025, -0.008), Vector2(0.012, 0.012),
				Vector2(0, -0.02), Vector2(-0.012, 0.012), Vector2(-0.025, -0.008), Vector2(-0.058, 0.0), Vector2(-0.062, 0.035), Vector2(-0.03, 0.075)]
			var xf := _plane(tip - dir * 0.01, Vector3.RIGHT.cross(dir), dir)
			_flat(b, "solid", spade, xf, 0.012, DEMON_MID, DEMON, Vector2(1.0, 0.0))
			var glow := []
			for q in spade:
				glow.append(q * 1.12 + Vector2(0, -0.004))
			_flat(b, "glow", glow, Transform3D(xf.basis, xf.origin), 0.004, DEMON_GLOW, Color("8a2ad0"), Vector2(1.0, 0.0))


# --- Seafoam (คลื่นทะเล) -------------------------------------------------------------------

const SEA := Color("39b9d8")
const SEA_LIGHT := Color("c4f6ff")
const SHELL := Color("ffe2d2")
const CORAL := Color("ff9a86")


static func _seafoam(b: Dictionary, part: String) -> void:
	match part:
		"head":
			# The crest: a ribbed fin arching over the crown from brow to nape.
			_surface(b, "sheet", 6, 25,
				func(u: float, v: float) -> Vector3:
					var z := lerpf(0.13, -0.2, u)
					var base := 0.985 - pow(u - 0.42, 2.0) * 0.42
					var h := 0.14 * pow(maxf(sin(PI * u), 0.0), 0.7) * (0.82 + 0.18 * absf(sin(u * PI * 4.0)))
					return Vector3(0.0, base + v * h, z - v * 0.04 * u),
				func(u: float, v: float) -> Color: return SEA.lerp(SEA_LIGHT, v * 0.85).darkened(0.12 * smoothstep(0.15, 0.0, absf(fmod(u * 6.0, 1.0) - 0.5)) * v),
				func(_u: float, v: float) -> Vector2: return Vector2(v * 0.5, 0.0),
				func(p: Vector3) -> Vector3: return Vector3(1.0, 0.0, 0.0) if p.z > -1.0 else Vector3.RIGHT)
			for side in [-1.0, 1.0]:
				var root := Vector3(side * 0.252, 0.79, -0.02)
				_surface(b, "sheet", 7, 13,
					func(u: float, v: float) -> Vector3:
						var a := lerpf(deg_to_rad(-40.0), deg_to_rad(65.0), u)
						var r := v * 0.2 * (0.85 + 0.15 * absf(sin(u * PI * 3.0)))
						return root + Vector3(side * (0.03 * v + 0.012 * sin(u * PI * 7.0) * v), sin(a) * r, -cos(a) * r),
					func(u: float, v: float) -> Color: return SEA.darkened(0.15).lerp(SEA_LIGHT, v).darkened(0.1 * smoothstep(0.2, 0.0, absf(fmod(u * 6.0, 1.0) - 0.5))),
					func(_u: float, v: float) -> Vector2: return Vector2(v * 0.7, side),
					func(_p: Vector3) -> Vector3: return Vector3(side, 0, 0))
			# A coral starfish hairpin and a pearl.
			_flat(b, "solid", _star(0.045, 0.02, 5, 0.3), Transform3D(Basis(Vector3.UP, deg_to_rad(-30.0)) * Basis(Vector3.RIGHT, deg_to_rad(-35.0)), Vector3(-0.15, 0.94, 0.15)), 0.012, Color("ffc0a8"), CORAL)
			_prim(b, "glow", _dot(), Color("fffaf0"), Vector3(-0.15, 0.95, 0.165), Vector3.ONE * 0.022)
		"back":
			# A wave capelet: deep sea at the shoulders into a hem of foam crests.
			_capelet(b, "sheet", 0.62, 0.2, 1.45, 0.112, 0.228, Color("1f8fbf"), SEA_LIGHT, 7.0, 0.16)
			_prim(b, "glow", _dot(), Color("fffaf0"), Vector3(0, 0.572, 0.13), Vector3.ONE * 0.034)
			_flat(b, "solid", _star(0.03, 0.013, 5), Transform3D(Basis.IDENTITY, Vector3(0, 0.575, 0.122)), 0.008, Color("ffc0a8"), CORAL)
		"arm_l", "arm_r":
			var side := 1.0 if part == "arm_l" else -1.0
			var hinge := Vector3(side * 0.115, 0.645, 0.022)
			# A scallop shell: ribs fanning from the hinge over the shoulder, a frilled rim.
			_surface(b, "sheet", 8, 21,
				func(u: float, v: float) -> Vector3:
					var a := lerpf(-1.3, 1.3, u)
					var ribs := 0.01 * absf(sin(u * PI * 7.0)) * v
					var r := v * 0.13 * (1.0 + 0.06 * absf(sin(u * PI * 7.0)))
					var bulge := sin(v * PI * 0.75) * 0.04 + ribs
					return hinge + Vector3(side * (r * 0.95 + bulge * 0.6), 0.018 - r * 0.6 + bulge, sin(a) * r * 0.95),
				func(u: float, v: float) -> Color: return SHELL.lerp(CORAL, smoothstep(0.35, 1.0, v) * 0.75).darkened(0.12 * smoothstep(0.25, 0.0, absf(fmod(u * 7.0, 1.0) - 0.5)) * v),
				func(_u: float, _v: float) -> Vector2: return Vector2.ZERO,
				func(p: Vector3) -> Vector3: return Vector3(side * 0.6, 1.0, 0.0))
			_prim(b, "glow", _dot(), Color("fffaf0"), hinge + Vector3(side * 0.006, 0.016, 0), Vector3.ONE * 0.03)
			_prim(b, "glow", _dot(), SEA_LIGHT, hinge + Vector3(side * 0.07, -0.05, 0.05), Vector3.ONE * 0.018)


# --- Sakura (ซากุระบาน) -------------------------------------------------------------------

const PETAL := Color("ffb6d3")
const PETAL_EDGE := Color("ff86b6")
const PETAL_HEART := Color("fff2f7")
const BARK := Color("5b3a2a")
const OBI := Color("e23f78")
const OBI_LIGHT := Color("ff7fac")


## A five-petal blossom facing `normal` at `at`.
static func _blossom(b: Dictionary, at: Vector3, normal: Vector3, size: float, turn := 0.0) -> void:
	var n := normal.normalized()
	var x := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var y := n.cross(x).normalized()
	for k in 5:
		var a := turn + TAU * float(k) / 5.0
		var dir := x * cos(a) + y * sin(a)
		var xf := _plane(at + dir * size * 0.08 + n * 0.004 * float(k % 2), dir.cross(n), dir, size)
		_flat(b, "solid", _ellipse(0.42, 0.6, 10, 0.35).map(func(q: Vector2) -> Vector2: return q + Vector2(0, 0.55)), xf, 0.05, PETAL_HEART, PETAL_EDGE.lerp(PETAL, 0.4))
	_prim(b, "glow", _dot(), Color("ffd84a"), at + n * size * 0.06, Vector3.ONE * size * 0.38)


static func _sakura(b: Dictionary, part: String) -> void:
	match part:
		"head":
			var ctrl := [Vector3(-0.1, 0.985, 0.1), Vector3(-0.19, 0.945, 0.03), Vector3(-0.255, 0.87, -0.05), Vector3(-0.27, 0.78, -0.11)]
			var twig := _spline(ctrl, 4)
			_sweep(b, "solid", twig, 6, func(t: float) -> float: return lerpf(0.013, 0.006, t), func(_t: float) -> Color: return BARK, func(_t: float) -> Vector2: return Vector2.ZERO)
			var spots := [[0.0, 0.066], [0.3, 0.08], [0.55, 0.072], [0.8, 0.064], [1.0, 0.05]]
			var centre := Vector3(0, 0.75, -0.02)
			for k in spots.size():
				var at: Vector3 = twig[int(round(float(spots[k][0]) * float(twig.size() - 1)))]
				var out := (at - centre).normalized()
				_blossom(b, at + out * 0.018, out + Vector3(0, 0.0, 0.35), float(spots[k][1]), float(k) * 0.9)
			for k in 2:
				var at: Vector3 = twig[4 + k * 5]
				var out := (at - centre).normalized()
				var xf := _plane(at + out * 0.01, out.cross(Vector3.UP), Vector3(0, -0.4, 1.0) if k == 0 else Vector3(0, 0.8, -0.6), 1.0)
				_flat(b, "solid", _leaf(0.06, 0.03), xf, 0.005, Color("9be27e"), Color("5aa84a"))
			# Two tassels of pink cord with a bead, hanging from the branch.
			for k in 2:
				var top: Vector3 = twig[twig.size() - 2 - k * 3] + Vector3(-0.012, -0.01, 0)
				var pts := _bezier(top, top + Vector3(-0.01, -0.05, 0), top + Vector3(-0.012, -0.1, 0.0), top + Vector3(-0.008, -0.15 + 0.03 * k, 0.0), 7)
				var phase := float(k) * 1.3
				_sweep(b, "solid", pts, 5, func(_t: float) -> float: return 0.0055, func(t: float) -> Color: return OBI_LIGHT.lerp(OBI, t),
					func(t: float) -> Vector2: return Vector2(t, phase))
				_prim(b, "solid", _dot(), Color("ffd24a"), pts[pts.size() - 1], Vector3.ONE * 0.022, Vector3.ZERO, Vector2(1.0, phase))
		"obi":
			# The obi round the waist, a gold cord, and the big bow at the back.
			_prim(b, "solid", MeshKit.cylinder(), OBI, Vector3(0, 0.392, 0.035), Vector3(0.292, 0.066, 0.268))
			_prim(b, "solid", MeshKit.torus(), Color("ffd24a"), Vector3(0, 0.392, 0.035), Vector3(0.302, 0.09, 0.278))
			_prim(b, "solid", MeshKit.torus(), PETAL_HEART, Vector3(0, 0.425, 0.035), Vector3(0.296, 0.06, 0.272))
			_prim(b, "solid", MeshKit.torus(), PETAL_HEART, Vector3(0, 0.359, 0.035), Vector3(0.296, 0.06, 0.272))
			var knot := Vector3(0, 0.4, -0.112)
			for side in [-1.0, 1.0]:
				var loop_at := knot + Vector3(side * 0.085, 0.03, -0.022)
				var turn := Basis(Vector3.FORWARD, side * deg_to_rad(-22.0))
				_prim(b, "solid", MeshKit.sphere_low(), OBI_LIGHT, loop_at, Vector3(0.15, 0.1, 0.05), Vector3.ZERO, Vector2.ZERO, turn)
				_prim(b, "solid", MeshKit.torus(), OBI, loop_at + Vector3(0, 0, -0.012), Vector3(0.15, 0.3, 0.1), Vector3.ZERO, Vector2.ZERO, turn * Basis(Vector3.RIGHT, PI * 0.5))
				# A ribbon tail hanging down from the knot.
				_surface(b, "sheet", 10, 4,
					func(u: float, v: float) -> Vector3:
						var w := lerpf(0.05, 0.064, v)
						var vcut := (1.0 - absf(u * 2.0 - 1.0)) * 0.035 * smoothstep(0.85, 1.0, v)
						return knot + Vector3(side * (0.018 + v * 0.05) + (u - 0.5) * w, -0.02 - v * 0.21 + vcut, -0.03 - v * 0.035),
					func(_u: float, v: float) -> Color: return OBI.lerp(OBI_LIGHT, v * 0.5),
					func(_u: float, v: float) -> Vector2: return Vector2(v, side * 0.8),
					func(_p: Vector3) -> Vector3: return Vector3(0, 0, -1))
			_prim(b, "solid", MeshKit.sphere_low(), OBI, knot + Vector3(0, 0.01, -0.03), Vector3(0.062, 0.07, 0.05))
			_prim(b, "glow", _dot(), Color("ffd24a"), knot + Vector3(0, 0.01, -0.056), Vector3(0.026, 0.026, 0.014))


# --- Midnight (ราตรีสีนิล) -------------------------------------------------------------------

const NIGHT := Color("1d2048")
const NIGHT_DEEP := Color("0b0c24")
const MOON := Color("ffe28a")
const SILVER := Color("c9d4ff")


static func _midnight(b: Dictionary, part: String, winged: bool) -> void:
	match part:
		"head":
			for side in [-1.0, 1.0]:
				# Slim crescents rising from the crown, their tips turned towards each other.
				var ctrl := [Vector3(side * 0.09, 0.935, 0.03), Vector3(side * 0.145, 1.0, 0.01), Vector3(side * 0.16, 1.075, -0.03),
					Vector3(side * 0.13, 1.135, -0.05), Vector3(side * 0.075, 1.16, -0.04)]
				_sweep(b, "solid", _spline(ctrl, 4), 8,
					func(t: float) -> float: return 0.032 * pow(1.0 - t, 0.85) + 0.003,
					func(t: float) -> Color: return Color("2a2e66").lerp(Color("aab6f2"), smoothstep(0.05, 0.55, t)).lerp(Color("f6f8ff"), smoothstep(0.65, 1.0, t)),
					func(_t: float) -> Vector2: return Vector2.ZERO)
				_flat(b, "glow", _star(0.022, 0.009, 4), Transform3D(Basis.IDENTITY, Vector3(side * 0.112, 0.94, 0.07)), 0.006, Color.WHITE, SILVER)
		"back":
			# A high collar behind the neck, then the night cape (a capelet under wings).
			_surface(b, "sheet2", 5, 17,
				func(u: float, v: float) -> Vector3:
					var phi := (u * 2.0 - 1.0) * 1.45
					var rad := lerpf(0.112, 0.17, v * v)
					var tooth := 0.02 * absf(sin(u * PI * 5.0)) * v
					return Vector3(sin(phi) * rad * 1.05, 0.585 + v * 0.13 + tooth, 0.035 - cos(phi) * rad),
				func(_u: float, v: float) -> Color: return NIGHT_DEEP.lerp(NIGHT, v),
				func(_u: float, _v: float) -> Vector2: return Vector2.ZERO,
				func(p: Vector3) -> Vector3: return Vector3(p.x, 0.0, p.z - 0.035))
			if winged:
				_capelet(b, "sheet", 0.615, 0.22, 1.35, 0.112, 0.22, NIGHT, NIGHT_DEEP, 4.0, 0.14)
			else:
				_long_cape(b, "sheet", 0.6, 0.52, 0.3, 0.58, NIGHT, NIGHT_DEEP, 3.0)
			_flat(b, "glow", _crescent(0.036), Transform3D(Basis(Vector3.FORWARD, deg_to_rad(-25.0)), Vector3(0.07, 0.545, 0.132)), 0.01, Color("fff4c8"), MOON)
			_flat(b, "glow", _star(0.018, 0.007, 4), Transform3D(Basis.IDENTITY, Vector3(0.105, 0.575, 0.128)), 0.005, Color.WHITE, MOON)
