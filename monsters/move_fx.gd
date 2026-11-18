class_name MoveFx
extends RefCounted
## Art of the star / lotus monster moves (MonsterMove): the red warnings in their
## real shapes (circle, cone, lane, ring), the projectiles and the impacts in each
## region's palette. Phone-safe: no lights, no GPU particles; every mesh and
## material is built once and shared (nodes scale / tint per instance through
## MultiMesh colours); decorations ask VfxBudget first. The warnings, the
## projectiles and the hazards are the move itself and are always drawn.

static var _meshes: Dictionary = {}
static var _mats: Dictionary = {}

const WARN_EDGE := Color(1.0, 0.23, 0.23, 0.92)
const WARN_FILL := Color(1.0, 0.16, 0.16, 0.36)
const WARN_BASE := Color(1.0, 0.16, 0.16, 0.13)


# ---------------------------------------------------------------------------
# Shared resources
# ---------------------------------------------------------------------------

## Cached unshaded material. [param tex]: a VfxArt texture kind; [param vcol]: tinted
## per instance (MultiMesh colours); [param bill]: faces the camera.
static func mat(color: Color, additive := false, tex := "", vcol := false, bill := false) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s|%s" % [color.to_html(true), additive, tex, vcol, bill]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	m.disable_fog = true
	if tex != "":
		m.albedo_texture = VfxArt.texture(tex)
	if vcol:
		m.vertex_color_use_as_albedo = true
	if bill:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	if _mats.size() >= 96:
		_mats.erase(_mats.keys()[0])
	_mats[key] = MaterialKeeper.keep(m)
	return m


static func _cached(key: String, build: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = build.call()
	return _meshes[key]


## Flat disc of radius 1 on the ground.
static func disc() -> Mesh:
	return _cached("disc", func(): return _fan(-PI, PI, 0.0, 40))


## Annulus between [param inner] and 1 (an outline when inner is near 1).
static func annulus(inner: float) -> Mesh:
	var q := clampi(roundi(inner * 40.0), 0, 39)
	return _cached("ann%d" % q, func(): return _fan(-PI, PI, float(q) / 40.0, 40))


## Sector of radius 1 along +Z, half-angle [param half] (radians, whole degrees).
static func sector(half: float) -> Mesh:
	var deg := clampi(roundi(rad_to_deg(half)), 1, 179)
	return _cached("sec%d" % deg, func(): return _fan(-deg_to_rad(deg), deg_to_rad(deg), 0.0, maxi(6, deg / 4)))


## The outline of that sector: its arc and its two straight sides.
static func sector_edge(half: float) -> Mesh:
	var deg := clampi(roundi(rad_to_deg(half)), 1, 179)
	return _cached("sece%d" % deg, func():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var a0 := -deg_to_rad(deg)
		var a1 := deg_to_rad(deg)
		var n := maxi(6, deg / 4)
		for i in n:
			var u := lerpf(a0, a1, float(i) / n)
			var v := lerpf(a0, a1, float(i + 1) / n)
			_quad(st, Vector3(sin(u), 0, cos(u)) * 0.95, Vector3(sin(u), 0, cos(u)), Vector3(sin(v), 0, cos(v)), Vector3(sin(v), 0, cos(v)) * 0.95)
		for a in [a0, a1]:
			var d := Vector3(sin(a), 0, cos(a))
			var s := Vector3(d.z, 0, -d.x) * 0.025
			_quad(st, -s, s, d + s, d - s)
		return st.commit())


## Unit lane: x -0.5..0.5, z 0..1 (scaled to width / length, grows from its start).
static func rect() -> Mesh:
	return _cached("rect", func():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_quad(st, Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 0, 1), Vector3(-0.5, 0, 1))
		return st.commit())


static func card() -> Mesh:
	return _cached("card", func():
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		return q)


static func _fan(a0: float, a1: float, inner: float, n: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var u := lerpf(a0, a1, float(i) / n)
		var v := lerpf(a0, a1, float(i + 1) / n)
		var pu := Vector3(sin(u), 0, cos(u))
		var pv := Vector3(sin(v), 0, cos(v))
		if inner <= 0.0:
			st.add_vertex(Vector3.ZERO)
			st.add_vertex(pu)
			st.add_vertex(pv)
		else:
			_quad(st, pu * inner, pu, pv, pv * inner)
	return st.commit()


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)


static func _mi(parent: Node3D, mesh: Mesh, material: Material, pos := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.scale = scale
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------------------
# Warnings
# ---------------------------------------------------------------------------

## A warning drawn in the part's real shape; MonsterMove calls show(t) as it fills.
class Warn:
	extends Node3D
	var part: Dictionary
	var fill: MeshInstance3D
	var closing: MeshInstance3D
	var guide: MeshInstance3D

	func show_progress(t: float) -> void:
		t = clampf(t, 0.0, 1.0)
		var e := 0.12 + 0.88 * t
		match String(part.shape):
			"circle":
				fill.scale = Vector3.ONE * float(part.r) * e
			"cone":
				fill.scale = Vector3.ONE * float(part.r) * e
			"line":
				fill.scale = Vector3(float(part.w), 1, float(part.len) * e)
			"ring":
				# The inner edge closes in from the outer one as the blow nears.
				closing.scale = Vector3.ONE * lerpf(float(part.r), float(part.r_in), t)
		if guide != null:
			guide.scale.x = 0.08 + 0.25 * t


static func telegraph(parent: Node3D, part: Dictionary) -> Warn:
	var w := Warn.new()
	w.name = "Warn_" + String(part.shape)
	w.part = part
	parent.add_child(w)
	w.global_position = (part.pos as Vector3) + Vector3(0, 0.05, 0)
	var dir: Vector3 = part.dir
	w.rotation.y = atan2(dir.x, dir.z)
	var edge := mat(WARN_EDGE)
	var fill := mat(WARN_FILL)
	var base := mat(WARN_BASE)
	var r := float(part.r)
	match String(part.shape):
		"circle":
			_mi(w, disc(), base, Vector3.ZERO, Vector3.ONE * r)
			w.fill = _mi(w, disc(), fill, Vector3(0, 0.004, 0), Vector3.ONE * r * 0.12)
			_mi(w, annulus(1.0 - 0.13 / maxf(r, 0.5)), edge, Vector3(0, 0.008, 0), Vector3.ONE * r)
		"ring":
			var inner := float(part.r_in) / r
			_mi(w, annulus(inner), base, Vector3.ZERO, Vector3.ONE * r)
			_mi(w, annulus(1.0 - 0.13 / r), edge, Vector3(0, 0.008, 0), Vector3.ONE * r)
			_mi(w, annulus(1.0 - 0.13 / float(part.r_in)), edge, Vector3(0, 0.008, 0), Vector3.ONE * float(part.r_in))
			w.closing = _mi(w, annulus(0.93), fill, Vector3(0, 0.006, 0), Vector3.ONE * r)
		"cone":
			_mi(w, sector(float(part.half)), base, Vector3.ZERO, Vector3.ONE * r)
			w.fill = _mi(w, sector(float(part.half)), fill, Vector3(0, 0.004, 0), Vector3.ONE * r * 0.12)
			_mi(w, sector_edge(float(part.half)), edge, Vector3(0, 0.008, 0), Vector3.ONE * r)
		"line":
			var length := float(part.len)
			var width := float(part.w)
			_mi(w, rect(), base, Vector3.ZERO, Vector3(width, 1, length))
			w.fill = _mi(w, rect(), fill, Vector3(0, 0.004, 0), Vector3(width, 1, length * 0.12))
			for s in [-0.5, 0.5]:
				_mi(w, rect(), edge, Vector3(width * s, 0.008, 0), Vector3(0.13, 1, length))
			_mi(w, rect(), edge, Vector3(0, 0.008, length - 0.13), Vector3(width, 1, 0.13))
			if String(part.fx) == "beam":
				# The petal beam's thin guide line brightens before it fires.
				w.guide = _mi(w, rect(), mat(Color(1.0, 0.75, 0.9, 0.85), true), Vector3(0, 0.012, 0), Vector3(0.08, 1, length))
	w.show_progress(0.0)
	return w


# ---------------------------------------------------------------------------
# Timed pieces and card bursts
# ---------------------------------------------------------------------------

## A piece that grows / shrinks from [member s0] to [member s1] and frees itself.
class Timed:
	extends Node3D
	var life := 0.4
	var age := 0.0
	var s0 := Vector3.ONE
	var s1 := Vector3.ONE
	var rise := 0.0

	func _process(delta: float) -> void:
		age += delta
		var t := clampf(age / life, 0.0, 1.0)
		scale = s0.lerp(s1, 1.0 - pow(1.0 - t, 2.0))
		position.y += rise * delta
		if t >= 1.0:
			queue_free()


static func timed(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, yaw: float, s0: Vector3, s1: Vector3, life: float, essential := false) -> Timed:
	if not essential and not VfxBudget.can_decorate():
		return null
	var t := Timed.new()
	t.life = life
	t.s0 = s0
	t.s1 = s1
	t.scale = s0
	parent.add_child(t)
	t.global_position = pos
	t.rotation.y = yaw
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t.add_child(mi)
	VfxBudget.track_decoration(t)
	return t


## Painted cards (petals, snow, feathers, stars...) in one MultiMesh draw: they fly
## out from [member origin], fall or drift, face the camera and fade through
## their instance colours.
class Cards:
	extends MultiMeshInstance3D
	var vel: Array[Vector3] = []
	var start: Array[Vector3] = []
	var cols: Array[Color] = []
	var spin: Array[float] = []
	var size := 0.4
	var life := 0.8
	var age := 0.0
	var gravity := -3.0

	func _process(delta: float) -> void:
		age += delta
		var t := clampf(age / life, 0.0, 1.0)
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		var face := cam.global_basis if cam != null else Basis.IDENTITY
		for i in vel.size():
			var p := start[i] + vel[i] * age + Vector3(0, 0.5 * gravity * age * age, 0)
			var b := (face * Basis(Vector3.FORWARD, spin[i] * age + float(i))).scaled(Vector3.ONE * size * (1.0 - 0.4 * t))
			multimesh.set_instance_transform(i, Transform3D(b, p))
			var c := cols[i]
			c.a = c.a * (1.0 - t * t)
			multimesh.set_instance_color(i, c)
		if t >= 1.0:
			queue_free()


## [param mode]: "burst" (out and up), "stream" (along [param dir]), "rise" (drift up),
## "implode" (pulled into the centre), "ring" (out flat from a circle of [param spread]).
static func cards(parent: Node3D, pos: Vector3, tex: String, colors: Array, n: int, mode := "burst", spread := 1.0, speed := 3.0, life := 0.8, dir := Vector3.FORWARD, size := 0.6) -> void:
	if not VfxBudget.can_decorate() or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var count := VfxBudget.count(n, 3)
	var c := Cards.new()
	c.name = "MoveCards"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = card()
	mm.instance_count = count
	c.multimesh = mm
	c.material_override = mat(Color.WHITE, false, tex, true)
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.life = life
	c.size = size
	parent.add_child(c)
	c.global_position = Vector3.ZERO
	for i in count:
		var a := TAU * float(i) / float(count) + randf() * 0.6
		var out := Vector3(cos(a), 0, sin(a))
		var p := pos + Vector3(0, 0.3, 0)
		var v := Vector3.ZERO
		match mode:
			"burst":
				p += out * spread * randf() * 0.5
				v = out * speed * randf_range(0.5, 1.0) + Vector3(0, speed * randf_range(0.6, 1.2), 0)
			"stream":
				var side := Vector3(-dir.z, 0, dir.x)
				p += side * randf_range(-spread, spread) * 0.5
				v = dir * speed * randf_range(0.7, 1.3) + side * randf_range(-0.6, 0.6) + Vector3(0, randf_range(0.4, 1.6), 0)
			"rise":
				p += out * spread * sqrt(randf())
				v = Vector3(0, speed * randf_range(0.4, 1.0), 0) + out * 0.3
			"implode":
				p += out * spread + Vector3(0, randf_range(0.2, 1.4), 0)
				v = -out * spread / life * randf_range(0.8, 1.0)
			"ring":
				p += out * spread
				v = out * speed * randf_range(0.7, 1.1) + Vector3(0, randf_range(0.3, 1.2), 0)
		c.start.append(p)
		c.vel.append(v)
		c.spin.append(randf_range(-6.0, 6.0))
		var col: Color = colors[i % colors.size()]
		col.a = maxf(col.a, 0.9)
		c.cols.append(col)
	c.gravity = -3.0 if mode in ["burst", "stream", "ring"] else 0.0
	c._process(0.0)
	VfxBudget.track_decoration(c)


static func _disc_flash(parent: Node3D, pos: Vector3, r: float, color: Color, life := 0.35, shrink := false) -> void:
	var s0 := Vector3.ONE * r * (1.0 if shrink else 0.35)
	var s1 := Vector3.ONE * r * (0.05 if shrink else 1.05)
	timed(parent, disc(), mat(color), pos + Vector3(0, 0.09, 0), 0.0, s0, s1, life)


# ---------------------------------------------------------------------------
# Projectiles
# ---------------------------------------------------------------------------

## A projectile's body (pollen ball, ice lance, dead-moon orb); MonsterMove flies it.
static func shot_body(parent: Node3D, kind: String, style: String) -> Node3D:
	var pal: Array = StarMoves.palette(style)
	var holder := Node3D.new()
	holder.name = "MoveShot_" + kind
	parent.add_child(holder)
	match kind:
		"ice":
			var lance := _mi(holder, MeshKit.prism(), mat(Color("dff8ff", 0.95)), Vector3.ZERO, Vector3(0.28, 1.3, 0.28))
			lance.rotation.x = PI * 0.5
			_mi(holder, MeshKit.sphere_low(), mat(Color(pal[0], 0.5), true), Vector3(0, 0, -0.3), Vector3(0.5, 0.5, 0.9))
		"void":
			_mi(holder, MeshKit.sphere_low(), mat(Color("1b0f30")), Vector3.ZERO, Vector3.ONE * 0.62)
			_mi(holder, MeshKit.torus(), mat(Color(pal[1], 0.9)), Vector3.ZERO, Vector3(0.72, 0.06, 0.72))
		_:
			_mi(holder, MeshKit.sphere_low(), mat(Color("ffe27a", 0.95)), Vector3.ZERO, Vector3.ONE * 0.45)
	if VfxBudget.can_decorate():
		var halo_color: Color = {"ice": Color(pal[0], 0.55), "void": Color(pal[0], 0.7)}.get(kind, Color(pal[1], 0.6))
		var halo := _mi(holder, card(), mat(halo_color, true, "flare", false, true), Vector3.ZERO, Vector3.ONE * 1.5)
		VfxBudget.track_decoration(halo)
	return holder


# ---------------------------------------------------------------------------
# Hazards and impacts
# ---------------------------------------------------------------------------

## The lingering area of a part (pollen cloud, frost patch, jade fire): its own
## shape in the region's colour, for as long as it hurts.
static func hazard(parent: Node3D, part: Dictionary, style: String, life: float) -> void:
	var pal: Array = StarMoves.palette(style)
	var color: Color = {"pollen": Color(pal[1], 0.34), "ice": Color("c8f4ff", 0.38), "jade_trail": Color(pal[1], 0.36)}.get(String(part.fx), Color(pal[0], 0.32))
	var dir: Vector3 = part.dir
	var yaw := atan2(dir.x, dir.z)
	var pos := (part.pos as Vector3) + Vector3(0, 0.07, 0)
	var shape := String(part.shape)
	var mesh: Mesh = rect() if shape == "line" else disc()
	var s := Vector3(float(part.w), 1, float(part.len)) if shape == "line" else Vector3.ONE * float(part.r)
	var t := timed(parent, mesh, mat(color), pos, yaw, s, s * Vector3(0.9, 1, 0.97), life, true)
	if t != null:
		t.name = "MoveHazard"
	var mid := StarMoves.center(part)
	match String(part.fx):
		"pollen":
			cards(parent, mid, "flare", [Color(pal[1], 0.8), Color("fff3b0", 0.7)], 10, "rise", float(part.r), 0.7, life)
		"ice":
			cards(parent, mid, "snow", [Color("e9fbff", 0.9), Color(pal[0], 0.8)], 8, "rise", float(part.r), 0.4, life)
		"jade_trail":
			for k in 3:
				cards(parent, (part.pos as Vector3) + dir * float(part.len) * (0.2 + 0.3 * k), "flame", [Color(pal[1], 0.85), Color("c9fff0", 0.7)], 5, "rise", 0.9, 1.4, minf(life, 1.2))


static func impact(parent: Node3D, part: Dictionary, style: String, tint: Color) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var pal: Array = StarMoves.palette(style)
	var main: Color = pal[0]
	var accent: Color = pal[1]
	var deep: Color = pal[2]
	var pos: Vector3 = part.pos
	var mid := StarMoves.center(part)
	var dir: Vector3 = part.dir
	var yaw := atan2(dir.x, dir.z)
	var r := float(part.r)
	match String(part.fx):
		"pounce", "pounce_big":
			var big := String(part.fx) == "pounce_big"
			match style:
				"crystal":
					VfxKit.spikes(parent, pos, r * 0.75, main, 7 if big else 5, 2.0 if big else 1.4, 0.12)
					cards(parent, pos, "snow", [accent, main], 12 if big else 8, "burst", r, 3.0)
					if big:
						VfxKit.shockwave(parent, pos + Vector3(0, 0.1, 0), main, r)
				"eclipse":
					VfxKit.slash_arc(parent, pos + Vector3(0, 0.9, 0), yaw + 0.8, main, 1.8, 0.5)
					VfxKit.slash_arc(parent, pos + Vector3(0, 0.9, 0), yaw - 0.8, accent, 1.8, -0.5)
					cards(parent, pos, "star", [main, accent], 8, "burst", r, 2.6)
				_:
					VfxKit.impact_ring(parent, pos + Vector3(0, 0.1, 0), main, r * 0.8, 0.35)
					cards(parent, pos, "petal", [main, accent, Color("fff0f5")], 12, "burst", r, 3.2)
		"headbutt":
			cards(parent, pos + dir * float(part.len) * 0.6, "leaf", [deep, accent], 12, "stream", float(part.w), 4.0, 0.7, dir)
			VfxKit.impact_ring(parent, pos + dir * float(part.len) * 0.75 + Vector3(0, 0.6, 0), accent, 1.4, 0.3)
		"charge":
			timed(parent, rect(), mat(Color(main, 0.55)), pos + Vector3(0, 0.1, 0), yaw, Vector3(float(part.w) * 0.9, 1, float(part.len)), Vector3(0.05, 1, float(part.len)), 0.4)
			var tex: String = {"dawn": "petal", "crystal": "snow", "sky": "leaf"}.get(style, "spark")
			cards(parent, mid, tex, [main, accent], 14, "stream", float(part.len) * 0.4, 3.5, 0.8, dir)
			if style == "crystal":
				VfxKit.spikes(parent, mid, 1.6, main, 4, 1.2, 0.2)
		"charge_burst":
			match style:
				"dawn":
					VfxKit.spikes(parent, pos, r * 0.8, Color("8a6a44"), 6, 2.0, 0.15)
					cards(parent, pos, "petal", [main, deep], 12, "burst", r, 3.4)
				"crystal":
					VfxKit.spikes(parent, pos, r * 0.8, main, 7, 2.2, 0.12)
					VfxKit.shockwave(parent, pos + Vector3(0, 0.1, 0), main, r)
				_:
					VfxKit.lightning(parent, pos + Vector3(0.4, 9.0, 0.3), pos, main)
					VfxKit.shockwave(parent, pos + Vector3(0, 0.1, 0), main, r)
					cards(parent, pos, "leaf", [main, accent], 10, "burst", r, 3.4)
		"pollen", "pollen_bloom":
			VfxKit.impact_ring(parent, pos + Vector3(0, 0.15, 0), accent, r * 0.8, 0.35)
			cards(parent, pos, "petal" if String(part.fx) == "pollen_bloom" else "flare", [accent, Color("fff3b0"), main], 10, "burst", r, 2.4)
		"ice":
			VfxKit.spikes(parent, pos, r * 0.7, main, 6, 1.7, 0.1)
			_disc_flash(parent, pos, r, Color(accent, 0.6))
			cards(parent, pos, "snow", [accent, main], 10, "burst", r, 3.0)
		"gust":
			timed(parent, sector(float(part.half)), mat(Color(accent, 0.35)), pos + Vector3(0, 0.12, 0), yaw, Vector3.ONE * r * 0.3, Vector3.ONE * r, 0.45)
			cards(parent, pos + dir * 1.2, "leaf", [main, accent, deep], 16, "stream", 2.0, r * 1.2, 0.75, dir, 0.45)
		"cleave":
			VfxKit.slash_arc(parent, pos + dir * 1.3 + Vector3(0, 1.0, 0), yaw, tint.lerp(main, 0.5), r * 0.9)
			var tex: String = {"crystal": "snow", "sky": "leaf", "eclipse": "star"}.get(style, "petal")
			cards(parent, mid, tex, [main, accent], 9, "burst", r * 0.8, 2.6)
		"rend":
			timed(parent, rect(), mat(Color(main, 0.6)), pos + Vector3(0, 0.1, 0), yaw, Vector3(float(part.w), 1, float(part.len)), Vector3(0.05, 1, float(part.len)), 0.45)
			for k in 3:
				VfxKit.pillar(parent, pos + dir * float(part.len) * (0.2 + 0.32 * k), deep if style == "eclipse" else main, 5.0, 0.9, 0.4, accent)
		"void":
			_disc_flash(parent, pos, r * 1.2, Color(deep, 0.85), 0.42, true)
			cards(parent, pos, "star", [main, accent], 10, "implode", r * 1.3, 0.0, 0.4)
			VfxKit.pillar(parent, pos, deep, 6.0, r * 0.5, 0.4, main)
		"void_ring":
			VfxKit.shockwave(parent, pos + Vector3(0, 0.1, 0), main, r)
			cards(parent, pos, "star", [accent, main], 12, "ring", float(part.r_in), 3.0, 0.6)
		"beam":
			var beam := timed(parent, MeshKit.box(), mat(Color(main, 0.7)), pos + Vector3(0, 1.0, 0) + dir * float(part.len) * 0.5, yaw, Vector3(float(part.w) * 0.55, 0.55, float(part.len)), Vector3(0.05, 0.05, float(part.len)), 0.4, true)
			if beam != null:
				beam.name = "MoveBeam"
			cards(parent, mid, "petal", [main, accent, Color("fff4fb")], 14, "stream", float(part.len) * 0.5, 2.0, 0.8, dir)
		"slam":
			DivineImpact.emit_at(parent, pos, r)
			VfxKit.shockwave(parent, pos + Vector3(0, 0.1, 0), deep, r)
		"slam_ring":
			VfxKit.shockwave(parent, pos + Vector3(0, 0.1, 0), accent, r)
			cards(parent, pos, "petal", [main, accent], 14, "ring", float(part.r_in), 3.5, 0.7)
		"jade_trail":
			timed(parent, rect(), mat(Color(accent, 0.6)), pos + Vector3(0, 0.1, 0), yaw, Vector3(float(part.w), 1, float(part.len)), Vector3(0.1, 1, float(part.len)), 0.4)
			cards(parent, mid, "leaf", [accent, Color("e8fff6")], 12, "stream", float(part.len) * 0.4, 3.0, 0.7, dir)
		"leap":
			VfxKit.impact_ring(parent, pos + Vector3(0, 0.15, 0), deep, r, 0.35)
			cards(parent, pos, "petal", [deep, main, accent], 12, "burst", r, 3.4)
		"ripple":
			VfxKit.shockwave(parent, pos + Vector3(0, 0.1, 0), accent, r)
			VfxKit.impact_ring(parent, pos + Vector3(0, 0.1, 0), Color("bff6ff"), float(part.r_in) * 1.3, 0.5)
		"palm":
			_disc_flash(parent, pos, r, Color(accent, 0.65), 0.3)
			VfxKit.impact_ring(parent, pos + Vector3(0, 0.9, 0), accent, r * 0.9, 0.3)
			cards(parent, pos, "petal", [accent, main], 6, "burst", r, 2.2, 0.6)
		_:
			VfxKit.impact_ring(parent, pos + Vector3(0, 0.1, 0), main, maxf(r, 1.5) * 0.8, 0.35)
