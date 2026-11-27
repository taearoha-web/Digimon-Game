extends RefCounted
## Muaythai Ascension buff (★500): สัจจะวงประเจียดเทวา, the fighter's sacred vow. Cosmetic only.
## The Muay Thai class has no support star art to play under the Ascension's crown
## (AscendSkillArt.BUFF_BASE), so this script draws the whole vow itself, painted, not
## additive (MuayPaint, the class's own shader: a cel ramp with a dark outline), so its
## flame orange, deep red and gold keep their hue on a bright sand field:
##   wind-up  a ยันต์ seal of dark line work on a red-brown wash burns itself into the
##            ground; a horseshoe of กนก flames (open towards the camera, the fighter stays
##            in view) blazes up round the fighter on its rim; two ประเจียด ribbons of red
##            cloth hemmed in gold whirl up round the body; the มงคล headband, a twisted
##            red-and-gold cord crowned with sacred fire, descends over the head (the
##            Ascension's crown of the class)
##   release  a กนก flame aureole (ประภามณฑล) opens behind the fighter, a wall of flame
##            leaps round the seal's rim, a shock ring of embers rolls out and sparks rise;
##            two great ประเจียด rings trailing their tails spin out round the legs
## Every mesh is built once from the Muay Thai art's own pieces (MuayThaiArt.mesh: kanok,
## yant, headband) and shared by every cast; every piece is one StarSkillArt layer (the
## root's 2/4/6 cap and the VFX budget apply). The wind-up's core sits in a stage root
## (M.stage, bound to the cast), the release's rings in an extra root (GodSkillArt.extra_roots).
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const PAINT := preload("res://shaders/muay_paint.gdshader")
const ID := "sacred_ring_vow"
## [primary, accent, shade]: the ink's body, highlight and outline.
const FLAME := [Color("ff6a10"), Color("ffd23c"), Color("4a0c04")]
const EMBER := [Color("d8301a"), Color("ffa62c"), Color("380604")]
const GOLD := [Color("f0a010"), Color("fff0a0"), Color("5a2404")]
const CLOTH := [Color("d4241a"), Color("ffd048"), Color("3a0604")]
const SEAL := [Color("e8561a"), Color("ffc83a"), Color("3a1004")]
## The flames' ring (m) and the headband's rest height over the feet.
const RING := 2.7
const HEAD := 2.65


## Vertex soup gathered from several MuayThaiArt pieces into ONE painted mesh. COLOR.b picks
## the piece's ramp (MuayPaint: 0 the layer's palette, 0.5 its second, 1 its third).
class Build:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()

	func put(arrays: Array, xf: Transform3D, ramp := 0.0) -> void:
		var pv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var pn = arrays[Mesh.ARRAY_NORMAL]
		var pc = arrays[Mesh.ARRAY_COLOR]
		var idx = arrays[Mesh.ARRAY_INDEX]
		var order: PackedInt32Array = idx if idx is PackedInt32Array and not (idx as PackedInt32Array).is_empty() else PackedInt32Array(range(pv.size()))
		var nb := xf.basis.inverse().transposed()
		for i in order:
			v.append(xf * pv[i])
			n.append((nb * (pn[i] as Vector3)).normalized() if pn is PackedVector3Array and not (pn as PackedVector3Array).is_empty() else Vector3.UP)
			var col: Color = pc[i] if pc is PackedColorArray and not (pc as PackedColorArray).is_empty() else Color(0.5, 1.0, 0.0)
			c.append(Color(col.r, col.g, ramp, 1.0))

	func put_kind(kind: String, xf: Transform3D, ramp := 0.0) -> void:
		put(MuayThaiArt.mesh(kind).surface_get_arrays(0), xf, ramp)

	func put_st(st: SurfaceTool, xf := Transform3D.IDENTITY, ramp := 0.0) -> void:
		put(st.commit_to_arrays(), xf, ramp)

	func mesh() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_COLOR] = c
		var out := ArrayMesh.new()
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return out


static func _st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## A กนก flame (MuayThaiArt "kanok": XY, base at the origin, 1 tall) standing at [param at]
## facing +Z, [param w] wide and [param h] tall.
static func _upright(w: float, h: float, at: Vector3, lean := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.BACK, lean) * Basis.from_scale(Vector3(w, h, 1.0)), at)


## A กนก flame lying in a plane (its tip along [param out], its face along [param face]).
static func _laid(out: Vector3, face: Vector3, w: float, h: float, at: Vector3) -> Transform3D:
	var side := out.cross(face).normalized()
	return Transform3D(Basis(side * w, out.normalized() * h, face.normalized()), at)


## The seal under the feet (XZ, radius 1): a red-brown wash that darkens the field, the
## Muay Thai ยันต์ in the middle, a dark-and-gold border and a crown of กนก flames laid
## flat round it, pointing out.
static func _seal() -> ArrayMesh:
	if M.has("vow_seal"):
		return M.get_mesh("vow_seal")
	var b := Build.new()
	var st := _st()
	BardSkillArt._ground_ring(st, 0.0, 0.9, -0.004, MuayThaiArt._c(0.16, 0.5), MuayThaiArt._c(0.12, 0.42), 56)
	BardSkillArt._ground_ring(st, 0.9, 1.08, -0.004, MuayThaiArt._c(0.12, 0.42), MuayThaiArt._c(0.1, 0.0), 56)
	b.put_st(st)
	# The flames of the border (behind the rings), every other one gold.
	for k in 16:
		var a := TAU * (float(k) + 0.5) / 16.0
		var out := Vector3(sin(a), 0, cos(a))
		var tall := 0.17 if k % 2 == 0 else 0.12
		b.put_kind("kanok", _laid(out, Vector3.UP, tall * 0.9, tall, out * 0.975 + Vector3.UP * 0.001), 0.5 if k % 2 == 0 else 1.0)
	st = _st()
	BardSkillArt._ground_ring(st, 0.945, 1.0, 0.002, MuayThaiArt._c(0.0), MuayThaiArt._c(0.0), 72)
	BardSkillArt._ground_ring(st, 0.957, 0.988, 0.003, MuayThaiArt._c(0.9), MuayThaiArt._c(0.9), 72)
	BardSkillArt._ground_ring(st, 0.9, 0.925, 0.002, MuayThaiArt._c(0.0), MuayThaiArt._c(0.0), 72)
	for k in 32:
		var a := TAU * float(k) / 32.0
		BardSkillArt._ground_star(st, Vector3(sin(a), 0.004, cos(a)) * 0.912, 0.03 if k % 4 == 0 else 0.018, 0.012, MuayThaiArt._c(1.0), 4, a)
	b.put_st(st)
	b.put_kind("yant", Transform3D(Basis().scaled(Vector3.ONE * 0.86), Vector3.UP * 0.005))
	return M.keep("vow_seal", b.mesh())


## The pyre: a horseshoe of tall กนก flames on a ring of RING metres, open at +Z (the
## camera's side), gold tongues between them; back to front, as a painted mesh draws.
static func _pyre() -> ArrayMesh:
	if M.has("vow_pyre"):
		return M.get_mesh("vow_pyre")
	var b := Build.new()
	var flames: Array = []
	var n := 9
	for k in n:
		var a := lerpf(0.82, TAU - 0.82, float(k) / float(n - 1))
		var back := 0.5 - 0.5 * cos(a)
		var h := lerpf(1.35, 2.3, back) * (1.0 if k % 2 == 0 else 0.88)
		flames.append([Vector3(sin(a), 0, cos(a)) * RING, h * 0.62, h, 0.0 if k % 2 == 0 else 0.5, 0.06 * sin(a)])
		if k < n - 1:
			var m := a + (TAU - 1.64) / float(n - 1) * 0.5
			flames.append([Vector3(sin(m), 0, cos(m)) * (RING - 0.18), 0.5, lerpf(0.75, 1.15, 0.5 - 0.5 * cos(m)), 1.0, -0.1 * sin(m)])
	flames.sort_custom(func(p, q): return (p[0] as Vector3).z < (q[0] as Vector3).z)
	for f in flames:
		b.put_kind("kanok", _upright(f[1], f[2], f[0], f[4]), f[3])
	return M.keep("vow_pyre", b.mesh())


## The มงคล headband of sacred fire (XZ hoop, radius 1): the twisted red-and-gold cord with
## its tail, and seven กนก flames standing on it, facing +Z (the layer faces the camera).
static func _mongkol() -> ArrayMesh:
	if M.has("vow_mongkol"):
		return M.get_mesh("vow_mongkol")
	var b := Build.new()
	var back: Array = []
	var front: Array = []
	for k in 7:
		var a := TAU * float(k) / 7.0 + PI
		var at := Vector3(sin(a), 0.04, cos(a))
		var h := 0.95 if k == 0 else (0.62 if k % 2 == 0 else 0.5)
		(back if at.z < 0.0 else front).append([at, h])
	back.sort_custom(func(p, q): return (p[0] as Vector3).z < (q[0] as Vector3).z)
	front.sort_custom(func(p, q): return (p[0] as Vector3).z < (q[0] as Vector3).z)
	for f in back:
		b.put_kind("kanok", _upright(f[1] * 0.62, f[1], f[0]), 0.5)
	b.put_kind("headband", Transform3D.IDENTITY)
	for f in front:
		b.put_kind("kanok", _upright(f[1] * 0.62, f[1], f[0]), 0.5)
	return M.keep("vow_mongkol", b.mesh())


## Two ประเจียด ribbons of red cloth hemmed in gold, whirling up round the body in a
## helix (dark outline, cloth, gold hem), fading at both ends; back segments first.
static func _ribbons() -> ArrayMesh:
	if M.has("vow_ribbons"):
		return M.get_mesh("vow_ribbons")
	var segs: Array = []
	var steps := 30
	for r in 2:
		var phase := TAU * float(r) / 2.0
		var prev := Vector3.ZERO
		for k in steps + 1:
			var s := float(k) / float(steps)
			var ang := phase + s * TAU * 0.95
			var rad := lerpf(1.75, 1.25, s)
			var p := Vector3(sin(ang) * rad, 0.25 + 2.75 * s, cos(ang) * rad)
			if k > 0:
				var s0 := float(k - 1) / float(steps)
				segs.append([prev, p, lerpf(0.24, 0.08, s0), lerpf(0.24, 0.08, s), minf(s0 * 6.0, 1.0) * minf((1.0 - s0) * 3.0, 1.0), minf(s * 6.0, 1.0) * minf((1.0 - s) * 3.0, 1.0)])
			prev = p
	segs.sort_custom(func(p, q): return ((p[0] as Vector3) + (p[1] as Vector3)).z < ((q[0] as Vector3) + (q[1] as Vector3)).z)
	var st := _st()
	for g in segs:
		var p0: Vector3 = g[0]
		var p1: Vector3 = g[1]
		var out := Vector3(p0.x + p1.x, 0, p0.z + p1.z).normalized()
		SculptureArt._strip(st, p0, p1, g[2] + 0.07, out, MuayThaiArt._c(0.0, g[4]), MuayThaiArt._c(0.0, g[5]), g[3] + 0.07)
		SculptureArt._strip(st, p0 + out * 0.004, p1 + out * 0.004, g[2], out, MuayThaiArt._c(0.5, g[4]), MuayThaiArt._c(0.46, g[5]), g[3])
		var up0: float = g[2] * 0.36
		var up1: float = g[3] * 0.36
		SculptureArt._strip(st, p0 + out * 0.008 + Vector3.UP * up0, p1 + out * 0.008 + Vector3.UP * up1, 0.035, out, MuayThaiArt._c(0.95, g[4]), MuayThaiArt._c(0.95, g[5]), 0.03)
	var b := Build.new()
	b.put_st(st)
	return M.keep("vow_ribbons", b.mesh())


## The flame aureole (ประภามณฑล, XY facing +Z, radius about 1.15): กนก flames radiating
## from an outlined gold ring, a tall flame at the crown; the middle stays open.
static func _aureole() -> ArrayMesh:
	if M.has("vow_aureole"):
		return M.get_mesh("vow_aureole")
	var b := Build.new()
	var count := 18
	for k in count:
		var a := TAU * float(k) / float(count)
		var out := Vector3(sin(a), cos(a), 0)
		var long := k % 2 == 0
		var h := (0.82 if k == 0 else 0.56) if long else 0.36
		b.put_kind("kanok", _laid(out, Vector3.BACK, h * 0.62, h, out * 0.56 + Vector3.BACK * (0.0 if long else 0.004)), 0.0 if long else 1.0)
	var st := _st()
	MuayThaiArt._xy_ring(st, 0.5, 0.62, MuayThaiArt._c(0.0), MuayThaiArt._c(0.0), 64, 0.008)
	MuayThaiArt._xy_ring(st, 0.525, 0.595, MuayThaiArt._c(0.92), MuayThaiArt._c(0.75), 64, 0.011)
	MuayThaiArt._xy_ring(st, 0.42, 0.45, MuayThaiArt._c(0.0, 0.8), MuayThaiArt._c(0.0, 0.8), 64, 0.008)
	b.put_st(st, Transform3D.IDENTITY, 1.0)
	return M.keep("vow_aureole", b.mesh())


## One painted layer: [param c] the main ramp, [param ramps] the second and third.
static func _paint(art: StarSkillArt, mesh: Mesh, label: String, c: Array, at: Vector3, size: Vector3, seconds: float, style := {}, angles := Vector3.ZERO, glow := false, opacity := 0.95, ramps := []) -> void:
	if art == null or mesh == null:
		return
	var n := art.layers.size()
	var opts := {"initial": 1.0, "grow_time": 0.01, "fade_in": 0.04, "decay": 0.85}
	opts.merge(style, true)
	art.add_mesh(mesh, label, K.WHITE, at, size, angles, seconds, opts)
	if art.layers.size() == n:
		return
	var node: MeshInstance3D = art.layers[n].node
	var mat := ShaderMaterial.new()
	mat.shader = PAINT
	mat.set_shader_parameter("primary", c[0])
	mat.set_shader_parameter("accent", c[1])
	mat.set_shader_parameter("shade", c[2])
	mat.set_shader_parameter("opacity", opacity)
	mat.set_shader_parameter("glow", 1.0 if glow else 0.0)
	MuayThaiArt._ramps(mat, ramps)
	mat.render_priority = int(style.get("priority", 0))
	node.material_override = mat


## Embers thrown up (one BITS layer): mostly matter, a little light, so they keep their
## orange on a bright field.
static func _embers(art: StarSkillArt, key: String, count: int, r0: float, r1: float, out: float, up: float, delay: float, seconds: float, seed_value: int) -> void:
	K.put(art, K.BITS, K.burst(key, "ember", count, r0, r1, out, up, [FLAME[0], EMBER[0], GOLD[0], FLAME[1]], 0.15, 0.1, seed_value, 0.2, 1.6), key, Vector3.ZERO, Vector3.ONE, seconds, {"life": seconds * 0.85, "gravity": -1.6, "drag": 1.4, "piece": 0.15, "add": 0.3, "shrink": 0.3, "spin": 5.0}, {"delay": delay, "decay": 0.8})


static func telegraph(art: StarSkillArt, _caster: Node3D, _skill: Dictionary, _point: Vector3, time: float) -> bool:
	var stay := time + 1.75
	var gap := K.facing(art)
	# The vow stands through the release: a root of its own (the wind-up's root ends with
	# the fighter's motion). Most telling first: the seal, the pyre, the crown, the cloth.
	var hold := M.stage(art, stay, "StarStage_" + ID)
	if hold == null:
		return false
	_paint(hold, _seal(), "VowSeal", SEAL, Vector3.UP * 0.05, Vector3.ONE * (RING + 0.75), stay, {"initial": 0.25, "grow_time": 0.3, "fade_in": 0.06, "spin": 0.3, "decay": 0.9}, Vector3.ZERO, false, 0.97, [FLAME, GOLD])
	_paint(hold, _pyre(), "VowPyre", FLAME, Vector3.ZERO, Vector3.ONE, stay, {"initial": 0.2, "grow_time": 0.42, "fade_in": 0.05, "decay": 0.88, "pulse": true}, Vector3(0, gap, 0), false, 0.97, [EMBER, GOLD])
	_paint(hold, _mongkol(), "VowMongkol", CLOTH, Vector3.UP * (HEAD + 1.1), Vector3.ONE * 0.62, stay, {"initial": 0.4, "grow_time": 0.3, "fade_in": 0.1, "decay": 0.9, "face_camera": true, "travel": Vector3.DOWN * 1.1, "accelerate": false}, Vector3.ZERO, false, 0.97, [FLAME])
	_paint(hold, _ribbons(), "VowRibbons", CLOTH, Vector3.ZERO, Vector3.ONE, time + 0.45, {"initial": 0.55, "grow_time": 0.35, "fade_in": 0.08, "spin": 2.8, "decay": 0.66, "travel": Vector3.UP * 0.6})
	hold._draw()
	# The first sparks rise off the pyre.
	_embers(art, "vow_motes", 24, 0.5, RING, 0.6, 2.4, 0.1, time + 0.3, 62)
	return true


static func strike(art: StarSkillArt, parent: Node3D, _skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	if index > 0:
		return true
	var behind := K.away(art)
	# The release: the flame aureole opens behind the fighter, the pyre leaps into a wall
	# of fire, a ring of embers rolls out over the field, sparks fly up.
	_paint(art, _aureole(), "VowAureole", FLAME, Vector3.UP * 1.55 + behind * 0.75, Vector3.ONE * 1.85, 1.7, {"initial": 0.2, "grow_time": 0.16, "fade_in": 0.03, "decay": 0.78, "face_camera": true, "pulse": true}, Vector3.ZERO, false, 0.97, [EMBER, GOLD])
	_paint(art, MuayThaiArt.mesh("fire_wall"), "VowFireWall", EMBER, Vector3.UP * 0.03, Vector3(RING, 1.7, RING), 1.0, {"initial": 0.55, "grow_time": 0.18, "fade_in": 0.03, "spin": 2.4, "decay": 0.55}, Vector3.ZERO, true, 0.9)
	K.put(art, K.FLAT, K.shock("vow_shock", M.a(EMBER[0], 1.0), 0.16), "VowShock", Vector3.UP * 0.08, Vector3.ONE * 6.2, 0.7, {"soft": 0.7, "hot": M.a(FLAME[1], 0.9), "core": 0.55, "add": 0.12}, {"initial": 0.1, "grow_time": 0.8, "fade_in": 0.02, "decay": 0.35})
	_embers(art, "vow_burst", 40, 0.6, RING + 0.3, 2.6, 5.5, 0.0, 1.5, 63)
	if GodSkillArt.extra_roots(1) < 1:
		return true
	# The vow binds: two great ประเจียด rings of red cloth bound in gold, trailing their
	# tails, spin out round the fighter's legs (never across the face).
	var bind := K.extra(parent, Vector3(point.x, 0, point.z), 1.6, "StarAscendPrajiad_" + ID, source, art)
	if bind:
		_paint(bind, MuayThaiArt.mesh("prajiad"), "VowPrajiadInner", CLOTH, Vector3.UP * 0.3, Vector3.ONE * 1.9, 1.2, {"initial": 0.35, "grow_time": 0.25, "fade_in": 0.04, "spin": 3.4, "travel": Vector3.UP * 0.45, "decay": 0.66}, Vector3(0.1, 0, 0.06))
		_paint(bind, MuayThaiArt.mesh("prajiad"), "VowPrajiadOuter", CLOTH, Vector3.UP * 0.2, Vector3.ONE * 2.5, 1.2, {"delay": 0.08, "initial": 0.3, "grow_time": 0.3, "fade_in": 0.04, "spin": -2.8, "travel": Vector3.UP * 0.3, "decay": 0.66}, Vector3(-0.08, 0, -0.07))
		bind._draw()
	return true
