class_name BuffArt
extends RefCounted
## Authored lasting silhouettes: shape, palette, count, orbit and height.
## One cached mesh / one draw per skill; no full-screen sphere, lights or particles.
const RECIPES := {
	"royal_vanguard": ["banners","ffd477","fff5cf",4,1.1,1.4,0.0],
	"sylph_step": ["sylph","81efca","e9ffff",3,1.1,0.5,0.2],
	"aegis_formation": ["phalanx","9acfff","eef6ff",4,1.1,1.1,0.0],
	"seraph_aegis": ["seraph","ffe2a0","ffffff",4,1.2,1.5,0.0],
	"sacred_sanctuary": ["chapel","ffd7a0","fffcea",4,1.1,0.6,0.0],
	"spirit_court": ["court","b69be9","ffe3bc",4,1.1,1.0,0.12],
	"eternal_aegis": ["rampart","5fb4ff","f0f8ff",8,1.15,1.0,0.0],
	"concentration": ["blade", "ffad56", "fff1b0", 3, 0.83, 0.65, 0.14],
	"swift_axe": ["blade", "6ae8bd", "fff0b0", 2, 1.04, 0.42, 0.8],
	"berserker": ["flame", "ff504a", "ffbd60", 5, 0.85, 0.6, -0.24],
	"holy_valor": ["shield", "f6c85f", "fff4cc", 3, 1.02, 1.15, 0.12],
	"drastic_spirit": ["wing", "ffde9b", "fffbed", 4, 1.08, 1.3, -0.12],
	"godly_shield": ["shield", "fff4dc", "d9b56f", 5, 1.17, 1.3, 0.08],
	"triumph_of_valhalla": ["crown", "ffd05e", "fff8cf", 6, 1.0, 1.8, 0.2],
	"scout_hawk": ["wing", "e9ae60", "ffefc0", 2, 1.0, 1.75, 0.3],
	"dionic_sight": ["eye", "ffdd62", "fff8d6", 3, 0.95, 1.6, 0.14],
	"spirit_of_wind": ["wing", "74e3bc", "e8fff3", 3, 1.08, 0.62, 0.7],
	"zenith": ["rune", "749fe9", "d9eeff", 3, 1.02, 1.3, 0.18],
	"enchant_weapon": ["blade", "ff9567", "ffedd6", 4, 0.9, 0.9, 0.3],
	"energy_shield": ["hex", "59cdef", "dcfaff", 6, 1.12, 1.32, -0.12],
	"silraphim": ["wing", "e5a4ec", "fff0ff", 6, 1.12, 1.2, 0.18],
	"vague": ["rune", "a290e9", "e6dfff", 2, 1.1, 1.4, -0.35],
	"magic_overdrive": ["rune", "e07fe8", "ffccee", 5, 1.03, 0.9, 0.5],
	"holy_reflection": ["mirror", "f5db8a", "ffffff", 3, 1.04, 1.3, -0.16],
	"virtual_life": ["cross", "f4d779", "f6fff0", 3, 0.98, 1.1, 0.14],
	"resurrection": ["wing", "a8eed1", "fffae0", 2, 1.16, 1.4, -0.1],
	"regeneration_field": ["petal", "5bddaa", "e5ffdd", 5, 1.02, 0.45, 0.2],
	"blessing_aura": ["cross", "ffcc72", "fff2cd", 4, 1.08, 1.5, 0.13],
	"prayer": ["cross", "c5f0db", "fffbed", 2, 0.94, 1.7, -0.12],
	"miracle": ["crown", "ffe4a1", "fffdf4", 8, 1.18, 1.6, -0.18],
	"forest_blessing": ["grove", "48c995", "ffe6a0", 4, 1.38, 2.65, 0.035],
	"regrowth": ["leaf", "61d89b", "e2ffbd", 4, 0.85, 0.4, -0.28],
	"beast_rage": ["claw", "ffab52", "ffe1a2", 3, 1.0, 0.8, 0.3],
	"life_bloom": ["petal", "efb4ce", "a7e6ac", 6, 1.08, 0.65, -0.17],
	"spirit_link": ["rune", "8ce3c7", "fff0bc", 4, 1.05, 1.4, -0.2],
	"gaia_blessing": ["leaf", "b6dc87", "fff0b0", 6, 1.18, 1.2, 0.12],
	"focus": ["eye", "e9bd67", "fff2c4", 2, 0.86, 1.25, -0.14],
	"wind_stance": ["blade", "72dec3", "ebfff7", 3, 1.03, 0.42, 0.6],
	"iron_resolve": ["shield", "9aaec9", "edf5ff", 4, 0.99, 1.1, -0.1],
	"lancer_rush": ["blade", "ff9c68", "ffe2ae", 5, 1.08, 0.66, 0.45],
	"dragon_stance": ["hex", "efa257", "ffdc92", 4, 1.12, 1.0, 0.16],
	"valkyrie_blessing": ["wing", "f2d5a0", "e9f4ff", 5, 1.1, 1.55, 0.0],
	"brace": ["shield", "9fc4e8", "eef6ff", 2, 0.92, 0.9, 0.0],
	"iron_wall": ["rampart", "a8c8e8", "f2f8ff", 8, 1.08, 0.55, -0.06],
	"thorn_guard": ["thorns", "e8925a", "ffe2c0", 6, 1.0, 0.9, -0.3],
	"guardian_oath": ["cross", "fff0b0", "ffffff", 5, 1.0, 1.25, 0.1],
	"unbreakable": ["citadel", "ffd27a", "fff6d8", 8, 1.14, 0.6, -0.08],
	"aegis_of_ages": ["aegis", "e4f1ff", "ffffff", 7, 1.2, 1.45, 0.05],
	"sanctuary_wall": ["crown", "ffe9a0", "fffbe8", 5, 1.12, 1.35, 0.1],
}
static var _meshes: Dictionary = {}
static var _names: Dictionary = {}
static var _grove_leaf: ArrayMesh

static func profile(buff: Dictionary) -> Dictionary:
	var id := String(buff.get("skill_id", buff.get("id", "")))
	if not RECIPES.has(id):
		if _names.is_empty():
			for family in ClassData.IDS:
				for skill in ClassData.pool(family):
					_names[String(skill.name)] = String(skill.id)
		id = _names.get(String(buff.get("name", "")), id)
	var r: Array = RECIPES.get(id, ["rune", "b6c9ff", "eef5ff", 3, 1.0, 1.0, 0.2])
	return {"id": id, "shape": r[0], "primary": Color(r[1]), "accent": Color(r[2]),
		"count": r[3], "radius": r[4], "height": r[5], "spin": r[6]}

static func warm_geometry() -> void:
	for id in RECIPES:
		mesh_for(profile({"skill_id": id}))

static func mesh_for(look: Dictionary) -> ArrayMesh:
	var id: String = look.id
	if _meshes.has(id):
		return _meshes[id]
	var star_shapes := {"royal_vanguard":"banners","sylph_step":"sylph","aegis_formation":"phalanx","seraph_aegis":"seraph","sacred_sanctuary":"chapel","spirit_court":"court"}
	if star_shapes.has(id):
		var build := SurfaceTool.new()
		build.begin(Mesh.PRIMITIVE_TRIANGLES)
		_append_tinted(build,StarGeometry.mesh(star_shapes[id]),Transform3D(Basis.from_scale(Vector3.ONE*0.72),Vector3(0,0.3,0)),0.3)
		build.generate_normals()
		_meshes[id]=build.commit()
		return _meshes[id]
	var martial_shapes := {"godly_shield":"shield", "triumph_of_valhalla":"crest", "spirit_of_wind":"wind_aura", "valkyrie_blessing":"valkyrie"}
	if martial_shapes.has(id):
		var build := SurfaceTool.new()
		build.begin(Mesh.PRIMITIVE_TRIANGLES)
		var at := Vector3.ZERO
		var size := Vector3.ONE
		if id=="godly_shield":
			at=Vector3(0,1.1,0.45); size=Vector3.ONE*0.65
		elif id=="triumph_of_valhalla":
			at=Vector3(0,2.1,0); size=Vector3.ONE*0.6
		_append_tinted(build,MartialGeometry.mesh(martial_shapes[id]),Transform3D(Basis.from_scale(size),at),0.4)
		build.generate_normals()
		_meshes[id]=build.commit()
		return _meshes[id]
	var elite_shapes := {"godly_shield":"bastion", "triumph_of_valhalla":"banners", "spirit_of_wind":"helix", "magic_overdrive":"astrolabe", "prayer":"lotus", "miracle":"cathedral", "gaia_blessing":"branches", "valkyrie_blessing":"wings", "eternal_aegis":"rampart", "aegis_of_ages":"aegis", "sanctuary_wall":"cathedral"}
	if elite_shapes.has(id):
		var build := SurfaceTool.new()
		build.begin(Mesh.PRIMITIVE_TRIANGLES)
		var size := Vector3(1.1, 1.9, 1.1)
		var at := Vector3.ZERO
		if id == "valkyrie_blessing":
			size = Vector3.ONE * 0.85
			at = Vector3(0, 1.2, -0.25)
		elif id == "magic_overdrive":
			at.y = 1.1
		elif id == "prayer":
			size.y = 0.45
		elif id == "eternal_aegis":
			# The star shield wall: a wide rampart of great shields around the whole party.
			size = Vector3(1.3, 1.05, 1.3)
		elif id == "aegis_of_ages":
			size = Vector3.ONE * 1.45
			at.y = 0.05
		elif id == "sanctuary_wall":
			size = Vector3(1.35, 1.5, 1.35)
		_append_tinted(build, EliteSkillArt.geometry(elite_shapes[id]), Transform3D(Basis.from_scale(size), at), 0.3)
		build.generate_normals()
		_meshes[id] = build.commit()
		return _meshes[id]
	if look.shape == "grove":
		var grove := _grove_mesh()
		_meshes[id] = grove
		return grove
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := int(look.count)
	var radius := float(look.radius)
	# Interrupted ground filigree retains an open centre and a quiet outer edge.
	for i in n:
		var angle := TAU * float(i) / n
		_arc(st, radius, 0.06, angle, angle + TAU / n * 0.62, 0.017)
		var pos := Vector3(sin(angle) * radius, float(look.height), cos(angle) * radius)
		var basis := Basis(Vector3.UP, angle)
		match String(look.shape):
			"shield":
				_append(st, SkillTableau.shield_mesh(), basis, pos, Vector3(0.38, 0.6, 0.36))
				_append(st, SpellSpectacle._crystal_mesh(), basis, pos + basis.z * 0.10, Vector3(0.07, 0.29, 0.04))
			"hex", "mirror":
				var sides := 6 if look.shape == "hex" else 4
				for j in sides:
					var a := TAU * float(j) / sides
					var b := TAU * float(j + 1) / sides
					var p1 := pos + basis * Vector3(cos(a) * 0.43, sin(a) * 0.58, 0)
					var p2 := pos + basis * Vector3(cos(b) * 0.43, sin(b) * 0.58, 0)
					_bar(st, p1, p2, 0.035)
				_append(st, SpellSpectacle._crystal_mesh(), basis, pos, Vector3(0.10, 0.2, 0.06))
			"leaf", "petal":
				var tilted := basis.rotated(basis.z, 0.5 if look.shape == "leaf" else -0.45)
				_append(st, SkillCraft.petal_mesh(), tilted, pos, Vector3(1.15, 0.85, 0.8))
				_bar(st, pos + tilted.y * 0.12, pos + tilted.y * 0.66, 0.024)
			"wing":
				_append(st, SpellSpectacle._wing_mesh(), basis, pos, Vector3(0.55, 0.46, 0.23))
			"cross":
				_bar(st, pos - Vector3.UP * 0.35, pos + Vector3.UP * 0.35, 0.065)
				_bar(st, pos + Vector3.UP * 0.1 - basis.x * 0.22, pos + Vector3.UP * 0.1 + basis.x * 0.22, 0.055)
			"eye":
				for side in [-1.0, 1.0]:
					_bar(st, pos - basis.x * 0.36, pos + Vector3.UP * 0.19 * side, 0.022)
					_bar(st, pos + Vector3.UP * 0.19 * side, pos + basis.x * 0.36, 0.022)
				_append(st, SpellSpectacle._crystal_mesh(), basis, pos, Vector3(0.08, 0.17, 0.08))
			"claw":
				for j in 3:
					_append(st, SpellSpectacle._crystal_mesh(), basis.rotated(basis.z, -0.3), pos + basis.x * (j - 1) * 0.16, Vector3(0.055, 0.44 - abs(j - 1) * 0.1, 0.04))
			"rampart", "citadel":
				# A wall of great shields edge to edge, crenellated; the citadel adds spires and a crown arc.
				_append(st, EliteSkillArt.geometry("greatshield"), basis, pos, Vector3(0.36, 0.42, 0.3))
				_arc(st, radius, float(look.height) + 0.44, angle - TAU / n * 0.48, angle + TAU / n * 0.48, 0.03)
				if look.shape == "citadel":
					_append(st, SpellSpectacle._crystal_mesh(), basis, pos + Vector3.UP * 0.62, Vector3(0.07, 0.22, 0.07))
					_arc(st, radius * 0.72, float(look.height) + 0.98, angle, angle + TAU / n * 0.9, 0.022)
			"thorns":
				# A shield bristling with three spikes pointing out at whoever strikes it.
				_append(st, SkillTableau.shield_mesh(), basis, pos, Vector3(0.34, 0.52, 0.3))
				for j in 3:
					_append(st, SpellSpectacle._crystal_mesh(), basis.rotated(basis.x, PI * 0.5), pos + basis.z * 0.12 + basis.x * (j - 1) * 0.17 + Vector3.UP * 0.12 * (j % 2), Vector3(0.05, 0.32, 0.05))
			"crown":
				_append(st, SkillTableau.shield_mesh(), basis, pos, Vector3(0.18, 0.38, 0.18))
				_arc(st, radius, float(look.height) - 0.25, angle, angle + TAU / n * 0.94, 0.024)
			_:
				var tilted := basis.rotated(basis.z, 0.25 if look.shape == "flame" else -0.16)
				_append(st, SpellSpectacle._crystal_mesh(), tilted, pos, Vector3(0.17 if look.shape == "rune" else 0.08, 0.48, 0.09))
				if look.shape == "blade":
					_bar(st, pos - Vector3.UP * 0.18 - basis.x * 0.16, pos - Vector3.UP * 0.18 + basis.x * 0.16, 0.035)
				else:
					_append(st, SpellSpectacle._crystal_mesh(), tilted, pos + basis.x * 0.22, Vector3(0.06, 0.22, 0.06))
	st.generate_normals()
	var result := st.commit()
	_meshes[id] = result
	return result

static func _append(st: SurfaceTool, mesh: Mesh, basis: Basis, pos: Vector3, size: Vector3) -> void:
	st.append_from(mesh, 0, Transform3D(basis * Basis.from_scale(size), pos))

static func _bar(st: SurfaceTool, a: Vector3, b: Vector3, width: float) -> void:
	var axis := (b - a).normalized()
	var across := axis.cross(Vector3.FORWARD).normalized()
	if across.length_squared() < 0.1:
		across = Vector3.RIGHT
	var basis := Basis(across, axis, across.cross(axis))
	_append(st, MeshKit.box(), basis, (a + b) * 0.5, Vector3(width, a.distance_to(b), width))

static func _arc(st: SurfaceTool, r: float, y: float, start: float, end: float, width: float) -> void:
	for j in 12:
		var a := lerpf(start, end, float(j) / 12.0)
		var b := lerpf(start, end, float(j + 1) / 12.0)
		var p := Vector3(sin(a), 0, cos(a))
		var q := Vector3(sin(b), 0, cos(b))
		var up := Vector3(0, y, 0)
		SpellSpectacle._tri(st, p * r + up, q * r + up, q * (r + width) + up)
		SpellSpectacle._tri(st, p * r + up, q * (r + width) + up, p * (r + width) + up)


## Four living arches: intertwined gold vines, broad emerald leaves and little
## blossom crowns. All parts are baked into ONE mesh with per-part colour masks.
static func _grove_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color(0.35, 1, 0))
	for ring in 2:
		for i in 8:
			var a := TAU * float(i) / 8.0
			_arc(st, 1.36 + ring * 0.16, 0.055 + ring * 0.01, a, a + 0.55, 0.018 if ring == 0 else 0.01)
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		var radial := Vector3(sin(a), 0, cos(a))
		var side := Vector3(cos(a), 0, -sin(a))
		var basis := Basis(Vector3.UP, a)
		for strand in 2:
			var points := PackedVector3Array()
			for j in 13:
				var t := float(j) / 12.0
				var r := 1.36 + sin(t * PI) * 0.2 - pow(t, 4.0) * 0.23
				points.append(radial * r + side * sin(t * TAU + strand * PI) * 0.105 + Vector3.UP * (0.08 + t * 2.60))
			_append_tinted(st, SpellSpectacle._tube_mesh(points, 0.030 if strand == 0 else 0.017), Transform3D.IDENTITY, 0.62 if strand == 0 else 0.9)
		for leaf in 4:
			var t := 0.24 + leaf * 0.17
			var sign := -1.0 if leaf % 2 == 0 else 1.0
			var pos := radial * (1.36 + sin(t * PI) * 0.18) + Vector3.UP * (0.08 + t * 2.60)
			var leaf_basis := basis.rotated(radial, sign * 0.76)
			var scale := Vector3(0.94, 0.74 if leaf < 2 else 0.52, 0.65)
			_append_tinted(st, _grove_leaf_mesh(), Transform3D(leaf_basis * Basis.from_scale(scale), pos), 0.06 + leaf * 0.06)
			var vein := PackedVector3Array([pos + leaf_basis.y * 0.04, pos + leaf_basis.y * 0.32 + leaf_basis.z * 0.05, pos + leaf_basis.y * scale.y * 0.85 + leaf_basis.z * 0.10])
			_append_tinted(st, SpellSpectacle._tube_mesh(vein, 0.012), Transform3D.IDENTITY, 0.82)
		# Five petals bloom out from the tip, framing the head without a filled dome.
		var bud := radial * 1.13 + Vector3.UP * 2.69
		for petal in 5:
			var flower_basis := basis.rotated(radial, TAU * float(petal) / 5.0)
			_append_tinted(st, _grove_leaf_mesh(), Transform3D(flower_basis * Basis.from_scale(Vector3(0.64, 0.31, 0.55)), bud), 0.92)
		_append_tinted(st, SpellSpectacle._crystal_mesh(), Transform3D(basis * Basis.from_scale(Vector3(0.10, 0.14, 0.10)), bud + radial * 0.10), 0.66)
		# Ground rosettes make the protection readable from the high gameplay camera.
		for leaf in 3:
			var root_basis := basis.rotated(radial, (leaf - 1) * 0.75).rotated(side, 0.70)
			_append_tinted(st, _grove_leaf_mesh(), Transform3D(root_basis * Basis.from_scale(Vector3(0.8, 0.52, 0.6)), radial * 1.42 + Vector3.UP * 0.07), 0.2)
	for i in 8:
		var a := TAU * (float(i) + 0.18) / 8.0
		var at := Vector3(sin(a) * 1.3, 0.7 + float(i % 3) * 0.56, cos(a) * 1.3)
		_append_tinted(st, SpellSpectacle._crystal_mesh(), Transform3D(Basis.from_scale(Vector3(0.035, 0.065, 0.035)), at), 0.95, 1.0)
	st.generate_normals()
	return st.commit()

static func _append_tinted(st: SurfaceTool, mesh: Mesh, transform: Transform3D, gold: float, mote := 0.0) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	st.set_color(Color(gold, 1, mote))
	for i in (indices.size() if not indices.is_empty() else vertices.size()):
		var v := vertices[indices[i] if not indices.is_empty() else i]
		st.set_uv(Vector2(v.x, v.y))
		st.add_vertex(transform * v)


static func _grove_leaf_mesh() -> ArrayMesh:
	if _grove_leaf != null:
		return _grove_leaf
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 10:
		var t := float(i) / 10.0
		var u := float(i + 1) / 10.0
		var width_t := sin(t * PI) * 0.40
		var width_u := sin(u * PI) * 0.40
		var spine_t := Vector3(0, t, sin(t * PI) * 0.12 + t * t * 0.15)
		var spine_u := Vector3(0, u, sin(u * PI) * 0.12 + u * u * 0.15)
		for side in [-1.0, 1.0]:
			var edge_t := Vector3(side * width_t, t, t * t * 0.15)
			var edge_u := Vector3(side * width_u, u, u * u * 0.15)
			SpellSpectacle._tri(st, spine_t, edge_t, spine_u)
			SpellSpectacle._tri(st, edge_t, edge_u, spine_u)
	st.generate_normals()
	_grove_leaf = st.commit()
	return _grove_leaf
