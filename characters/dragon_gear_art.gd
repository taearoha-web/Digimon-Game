class_name DragonGearArt
extends RefCounted
## The look of the Dragon God weapons (DragonGearData), one per class: the class's own
## weapon (StarGearArt's grandest silhouette) re-cut in dragon jade and gold, with a whole
## dragon coiled round it from the grip to the head: a banded jade body with a gold
## belly, a ridge of glowing spines, a tail fin, and a horned head with a mane, whiskers
## and eyes in the class's own glow (SetGearData.PALETTES), looking along the weapon.
## Built once per look into StarGearArt's two vertex-colour surfaces; the glow surface
## wears dragon_glow.gdshader (a pulse of light running up the weapon over TIME: the
## animated inner glow, no script). breath() adds the dragon's breath in the hand: one
## small shader shell (dragon_breath.gdshader, blended, never brighter than its colour),
## no lights and no particles, left out in a crowd's light dress and on the lowest
## quality. Weapons keep WeaponKit's grip origin and +Y axis.

const GLOW_SHADER := preload("res://shaders/dragon_glow.gdshader")
const BREATH_SHADER := preload("res://shaders/dragon_breath.gdshader")
const HELD := ["sword", "spear", "bow", "staff", "wand", "lantern", "greatshield", "shield", "dagger", "scepter", "lute", "book", "tome", "wraps"]

## How the dragon lies on each kind (held units, before the kind's scale): the line its
## body follows ("path"), the coil's half-widths across and in depth ("rx", "rz"), its
## turns, the body's thickness, where the head sits, which way it looks ("nose") and
## which way its crown faces ("crown"), the head's size, and the breath shell's
## [centre of its foot, its size].
const LAYOUT := {
	"sword": {"path": [Vector3(0, 0.36, 0), Vector3(0, 1.62, 0)], "rx": 0.33, "rz": 0.15, "turns": 2.5, "thick": 0.07,
		"head": Vector3(0.1, 1.84, 0.13), "nose": Vector3(-0.25, 1, 0.1), "crown": Vector3(0, 0, 1), "size": 0.5, "breath": [Vector3(0, 0.1, 0), Vector3(0.62, 2.3, 0.45)]},
	"dagger": {"path": [Vector3(0, 0.26, 0), Vector3(0, 0.84, 0)], "rx": 0.24, "rz": 0.13, "turns": 1.5, "thick": 0.06,
		"head": Vector3(0.08, 0.99, 0.12), "nose": Vector3(-0.25, 1, 0.1), "crown": Vector3(0, 0, 1), "size": 0.38, "breath": [Vector3(0, 0.05, 0), Vector3(0.5, 1.3, 0.4)]},
	"spear": {"path": [Vector3(0, 0.2, 0), Vector3(0, 1.12, 0)], "rx": 0.13, "rz": 0.13, "turns": 3.0, "thick": 0.055,
		"head": Vector3(0.06, 1.3, 0.14), "nose": Vector3(-0.2, 1, 0.15), "crown": Vector3(0, 0, 1), "size": 0.38, "breath": [Vector3(0, 0.75, 0), Vector3(0.6, 1.45, 0.5)]},
	"staff": {"path": [Vector3(0, 0.3, 0), Vector3(0, 1.5, 0)], "rx": 0.16, "rz": 0.16, "turns": 3.5, "thick": 0.065,
		"head": Vector3(0.06, 1.7, 0.2), "nose": Vector3(-0.15, 1, 0.1), "crown": Vector3(0, 0, 1), "size": 0.44, "breath": [Vector3(0, 1.2, 0), Vector3(1.0, 1.5, 0.7)]},
	"wand": {"path": [Vector3(0, -0.02, 0), Vector3(0, 0.5, 0)], "rx": 0.12, "rz": 0.12, "turns": 2.0, "thick": 0.045,
		"head": Vector3(0.04, 0.6, 0.14), "nose": Vector3(-0.15, 1, 0.15), "crown": Vector3(0, 0, 1), "size": 0.3, "breath": [Vector3(0, 0.3, 0), Vector3(0.66, 0.95, 0.5)]},
	"scepter": {"path": [Vector3(0, 0.0, 0), Vector3(0, 0.58, 0)], "rx": 0.125, "rz": 0.125, "turns": 2.0, "thick": 0.048,
		"head": Vector3(0.04, 0.68, 0.17), "nose": Vector3(-0.15, 1, 0.15), "crown": Vector3(0, 0, 1), "size": 0.32, "breath": [Vector3(0, 0.35, 0), Vector3(0.7, 1.0, 0.55)]},
	"lantern": {"path": [Vector3(0, 0.2, 0), Vector3(0, 1.02, 0)], "rx": 0.14, "rz": 0.14, "turns": 3.0, "thick": 0.055,
		"head": Vector3(0.1, 1.2, 0.12), "nose": Vector3(-0.5, 0.8, 0.1), "crown": Vector3(0, 0.3, 1), "size": 0.38, "breath": [Vector3(-0.6, 0.25, 0), Vector3(0.62, 1.2, 0.62)]},
	"bow": {"path": [Vector3(0.08, -1.36, 0), Vector3(-0.22, -1.15, 0), Vector3(-0.45, -0.8, 0), Vector3(-0.27, -0.38, 0), Vector3(-0.03, -0.17, 0), Vector3(-0.03, 0.17, 0),
			Vector3(-0.27, 0.38, 0), Vector3(-0.45, 0.8, 0), Vector3(-0.22, 1.15, 0), Vector3(0.05, 1.38, 0)], "rx": 0.085, "rz": 0.085, "turns": 5.0, "thick": 0.045,
		"head": Vector3(0.14, 1.5, 0.02), "nose": Vector3(0.6, 0.8, 0), "crown": Vector3(0, 0, 1), "size": 0.36, "skip": [0.42, 0.58], "breath": [Vector3(-0.2, -0.75, 0), Vector3(0.6, 1.5, 0.4)]},
	"greatshield": {"ring": [Vector3(0, 0.1, 0.33), 0.47], "rx": 0.035, "rz": 0.03, "turns": 6.0, "thick": 0.078,
		"head": Vector3(0.1, 0.63, 0.42), "nose": Vector3(1, -0.2, 0.1), "crown": Vector3(0, 0.25, 1), "size": 0.42, "breath": [Vector3(0, -0.75, 0.3), Vector3(1.5, 1.8, 0.4)]},
	"shield": {"ring": [Vector3(0, 0.1, 0.33), 0.47], "rx": 0.035, "rz": 0.03, "turns": 6.0, "thick": 0.078,
		"head": Vector3(0.1, 0.63, 0.42), "nose": Vector3(1, -0.2, 0.1), "crown": Vector3(0, 0.25, 1), "size": 0.42, "breath": [Vector3(0, -0.75, 0.3), Vector3(1.5, 1.8, 0.4)]},
	"book": {"ring": [Vector3(0, 0.08, 0.13), 0.2], "rx": 0.016, "rz": 0.012, "turns": 5.0, "thick": 0.03,
		"head": Vector3(0.04, 0.3, 0.17), "nose": Vector3(1, -0.2, 0.1), "crown": Vector3(0, 0.25, 1), "size": 0.2, "breath": [Vector3(0, -0.35, 0.1), Vector3(0.7, 0.85, 0.3)]},
	"tome": {"ring": [Vector3(0, 0.08, 0.13), 0.2], "rx": 0.016, "rz": 0.012, "turns": 5.0, "thick": 0.03,
		"head": Vector3(0.04, 0.3, 0.17), "nose": Vector3(1, -0.2, 0.1), "crown": Vector3(0, 0.25, 1), "size": 0.2, "breath": [Vector3(0, -0.35, 0.1), Vector3(0.7, 0.85, 0.3)]},
	# The Muay Thai fighter's knuckle dusters (HandWraps' grip space: the hand along X,
	# forearm to -X, back of the hand +Z): the dragon coils from the wrist round the hand
	# and rears its head over the knuckle bar, looking where the punch goes; its breath
	# wraps the fist.
	"wraps": {"path": [Vector3(-0.165, -0.016, 0.03), Vector3(-0.03, -0.016, 0.03)], "rx": 0.088, "rz": 0.066, "turns": 1.5, "thick": 0.014,
		"head": Vector3(0.0, -0.016, 0.08), "nose": Vector3(1, 0, 0.25), "crown": Vector3(0, 0, 1), "size": 0.06, "breath": [Vector3(-0.07, -0.17, 0.03), Vector3(0.32, 0.34, 0.3)]},
	"lute": {"path": [Vector3(-0.02, -0.56, 0.03), Vector3(0.14, -0.5, 0.03), Vector3(0.205, -0.33, 0.03), Vector3(0.11, -0.17, 0.03), Vector3(0.036, -0.1, 0.0),
			Vector3(0.03, 0.1, -0.03), Vector3(0.0, 0.3, -0.045), Vector3(0, 0.4, -0.085)], "rx": 0.01, "rz": 0.012, "turns": 3.0, "thick": 0.03,
		"head": Vector3(0, 0.47, -0.1), "nose": Vector3(0, 1, 0.35), "crown": Vector3(0, -0.3, 1), "size": 0.16, "breath": [Vector3(0, -0.6, 0), Vector3(0.52, 1.1, 0.3)]},
}

static var _glow_materials := {}
static var _breath_material: ShaderMaterial
static var _breath_mesh: ArrayMesh


## The weapon palette of [param cls]: dragon jade and gold for every class, the class's
## own set colours in the cloth, the eyes and the pearl.
static func palette(cls: String) -> Dictionary:
	var own := SetGearData.palette(cls)
	return {"metal": DragonGearData.GOLD, "edge": Color("a6f7dc"), "cloth": (own.cloth as Color).lerp(DragonGearData.JADE_DEEP, 0.35),
		"gem": DragonGearData.GLOW, "dark": DragonGearData.JADE_DEEP, "glow": DragonGearData.GLOW, "eye": own.glow, "pearl": own.gem}


static func _bits(look: String) -> Array[String]:
	var bits := look.split("_")
	var kind := String(bits[1]) if bits.size() >= 3 else "sword"
	var cls := String(bits[2]) if bits.size() >= 3 else "warrior"
	return [kind if LAYOUT.has(kind) else "sword", cls if SetGearData.THEMES.has(cls) else "warrior"]


## "dragon_<kind>_<class>": a held weapon or off-hand (shield, book, tome, dagger).
static func build(look: String) -> Node3D:
	# The Muay Thai fighter's knuckle dusters are drawn by HandWraps for every other look
	# kind; the dragon's are built here, as a dragon weapon (_wraps).
	if HandWraps.is_look(look) and not look.begins_with("dragon_"):
		return HandWraps.build(look)
	var bits := _bits(look)
	var kind := bits[0]
	var cls := bits[1]
	var key := "dragon_%s_%s" % [kind, cls]
	var root := Node3D.new()
	root.name = look
	if not StarGearArt._cache.has(key):
		var b := StarGearArt._builder()
		var p := palette(cls)
		match kind:
			"sword": StarGearArt._sword(b, p, 3)
			"spear": StarGearArt._spear(b, p, 3)
			"bow": StarGearArt._bow(b, p, 3)
			"staff": StarGearArt._staff(b, p, 2)
			"wand": StarGearArt._wand(b, p, 3)
			"lantern": StarGearArt._lantern(b, p, 2)
			"greatshield", "shield": StarGearArt._shield(b, p, 3)
			"dagger": StarGearArt._dagger(b, p, 3)
			"scepter": StarGearArt._scepter(b, p, 3)
			"lute": StarGearArt._lute(b, p, 2)
			"book", "tome": StarGearArt._book(b, p, 3)
			"wraps": _wraps(b, p)
		_dragon(b, p, kind)
		_extras(b, p, kind)
		StarGearArt._store(key, b)
	StarGearArt._attach(root, key)
	# The glow surface (the second one) runs the dragon's pulse of light.
	var art := root.get_child(0) as MeshInstance3D
	if art.mesh.get_surface_count() > 1:
		art.set_surface_override_material(1, glow_material())
	# The same held sizes as the star and set pieces.
	if kind == "greatshield": root.scale = Vector3.ONE * 1.55
	if kind == "dagger": root.scale = Vector3.ONE * 0.62
	if kind == "lute": root.scale = Vector3.ONE * float(WeaponKit.MODELS.lute.scale) / 1.5
	root.set_meta("star_gear", true)
	root.set_meta("dragon_gear", true)
	root.set_meta("weapon_kind", kind)
	return root


## The glow surface's material: the pulse stands still on the lowest quality.
static func glow_material() -> ShaderMaterial:
	var still := GameSettings.quality == 0
	if not _glow_materials.has(still):
		var mat := ShaderMaterial.new()
		mat.shader = GLOW_SHADER
		mat.set_shader_parameter("motion", 0.0 if still else 1.0)
		MaterialKeeper.keep(mat)
		_glow_materials[still] = mat
	return _glow_materials[still]


## Whether the breath shows: the hero's own full dress above the lowest quality, with
## memory to spare (the rules of the set aura's motes and the legend wings' sparkles).
static func breath_allowed(light := false) -> bool:
	return not light and GameSettings.quality > 0 and MemoryGuard.pressure < 2


## The dragon's breath round a held weapon [param item] (built by build): one shader
## shell, null when not allowed.
static func breath(item: Node3D, light := false) -> MeshInstance3D:
	if not breath_allowed(light) or not item.has_meta("weapon_kind"):
		return null
	var spec: Array = LAYOUT[String(item.get_meta("weapon_kind"))].breath
	var shell := MeshInstance3D.new()
	shell.name = "DragonBreath"
	shell.mesh = _breath_shell()
	shell.position = spec[0]
	shell.scale = spec[1]
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.set_meta("no_outline", true)
	if _breath_material == null:
		_breath_material = ShaderMaterial.new()
		_breath_material.shader = BREATH_SHADER
		_breath_material.render_priority = 1
		MaterialKeeper.keep(_breath_material)
	shell.material_override = _breath_material
	item.add_child(shell)
	return shell


## A unit shell: radius 0.5, y 0..1, UV (around, along), open at both ends.
static func _breath_shell() -> ArrayMesh:
	if _breath_mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var sides := 12
		var rings := 5
		for r in rings + 1:
			var v := float(r) / float(rings)
			var wide := 0.5 * (0.55 + 0.45 * sin(PI * minf(v * 1.15, 1.0)))
			for s in sides + 1:
				var a := TAU * float(s) / float(sides)
				st.set_uv(Vector2(float(s) / float(sides), v))
				st.set_normal(Vector3(cos(a), 0, sin(a)))
				st.add_vertex(Vector3(cos(a) * wide, v, sin(a) * wide))
		for r in rings:
			for s in sides:
				var i := r * (sides + 1) + s
				for k in [i, i + sides + 1, i + 1, i + 1, i + sides + 1, i + sides + 2]:
					st.add_index(k)
		_breath_mesh = st.commit()
	return _breath_mesh


## Triangles of a built weapon (the budget the tests hold it to).
static func triangles(root: Node3D) -> int:
	var total := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null:
			total += LegendWingMesh.triangles(mesh)
	return total


## The inventory icon model of a dragon look (ItemLook.build_icon_node).
static func build_icon_node(look: String) -> Node3D:
	var bits := look.split("_")
	if bits.size() >= 3 and bits[1] == "wings":
		return DragonWingArt.build_icon_node(String(bits[2]))
	var kind := _bits(look)[0]
	var root := Node3D.new()
	root.add_child(build(look))
	root.rotation_degrees.z = -27.0 if kind not in ["bow", "shield", "greatshield", "book", "tome"] else -12.0
	if kind == HandWraps.KIND:
		root.rotation_degrees = HandWraps.ICON_ROTATION
	return root


# --- Emitters ------------------------------------------------------------------

## A four-sided spike from [param base] along [param dir].
static func _spike(b: Dictionary, base: Vector3, dir: Vector3, length: float, width: float, color: Color, glow := false) -> void:
	var layer := "glow" if glow else "solid"
	var st: SurfaceTool = b[layer]
	var axis := dir.normalized()
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var other := axis.cross(side)
	var tip := base + axis * length
	var corners := [base + side * width * 0.5, base + other * width * 0.5, base - side * width * 0.5, base - other * width * 0.5]
	for i in 4:
		var a: Vector3 = corners[i]
		var c: Vector3 = corners[(i + 1) % 4]
		var normal := (c - a).cross(tip - a).normalized()
		var shade := color.lightened(0.12) if i % 2 == 0 else color.darkened(0.1)
		for vertex in [a, c, tip]:
			st.set_color(shade)
			st.set_normal(normal)
			st.add_vertex(vertex)
	b[layer + "_count"] += 12


## A ball or a box of one colour placed by a full transform.
static func _put(b: Dictionary, mesh: Mesh, color: Color, xform: Transform3D, glow := false) -> void:
	var layer := "glow" if glow else "solid"
	var st: SurfaceTool = b[layer]
	var normals := xform.basis.inverse().transposed()
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normal: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var count := indices.size() if not indices.is_empty() else vertices.size()
	for i in count:
		var idx := indices[i] if not indices.is_empty() else i
		st.set_color(color)
		st.set_normal((normals * normal[idx]).normalized())
		st.add_vertex(xform * vertices[idx])
	b[layer + "_count"] += count


static func _at(frame: Transform3D, pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> Transform3D:
	return frame * Transform3D(Basis.from_euler(rot * PI / 180.0) * Basis.from_scale(size), pos)


## The point at [param u] (0-1) along a polyline, by length.
static func _along(points: Array, u: float) -> Vector3:
	var total := 0.0
	for i in points.size() - 1:
		total += (points[i + 1] as Vector3).distance_to(points[i])
	var want := clampf(u, 0.0, 1.0) * total
	for i in points.size() - 1:
		var step := (points[i + 1] as Vector3).distance_to(points[i])
		if want <= step or i == points.size() - 2:
			return (points[i] as Vector3).lerp(points[i + 1], clampf(want / maxf(step, 0.0001), 0.0, 1.0))
		want -= step
	return points[points.size() - 1]


## A smoothed copy of a polyline (so a bent path coils without corners).
static func _smooth(points: Array, steps := 40) -> Array:
	var out: Array = []
	for k in steps + 1:
		var u := float(k) / float(steps)
		var span := 0.06
		out.append((_along(points, u - span) + _along(points, u) * 2.0 + _along(points, u + span)) * 0.25)
	return out


# --- The dragon ------------------------------------------------------------------

## The line the coil's centre follows for a layout.
static func _centre(spec: Dictionary) -> Array:
	if spec.has("ring"):
		var c: Vector3 = spec.ring[0]
		var r: float = spec.ring[1]
		var out: Array = []
		# From the tail (just right of the top) all the way round to the head at the top.
		for k in 41:
			var a := deg_to_rad(28.0 + 322.0 * float(k) / 40.0)
			out.append(c + Vector3(sin(a) * r, cos(a) * r, 0))
		return out
	var path: Array = spec.path
	return _smooth(path) if path.size() > 2 else path


static func _dragon(b: Dictionary, p: Dictionary, kind: String) -> void:
	var spec: Dictionary = LAYOUT[kind]
	var centre := _centre(spec)
	var turns: float = spec.turns
	var thick: float = spec.thick
	var rings := int(ceil(turns * 12.0)) + 6
	var skip: Array = spec.get("skip", [])
	var sides := 6
	var prev: Array = []
	var prev_ok := false
	var last_pos := Vector3.ZERO
	var length := 0.0
	for i in centre.size() - 1:
		length += (centre[i + 1] as Vector3).distance_to(centre[i])
	for k in rings + 1:
		var u := float(k) / float(rings)
		var c := _along(centre, u)
		var ahead := _along(centre, minf(u + 0.02, 1.0)) - _along(centre, maxf(u - 0.02, 0.0))
		var tangent := ahead.normalized()
		var across := tangent.cross(Vector3.BACK).normalized()
		var depth := across.cross(tangent).normalized()
		var angle := TAU * turns * u
		# The coil opens a little toward the head and closes onto the weapon at the tail.
		var swell := lerpf(0.75, 1.0, smoothstep(0.0, 0.25, u))
		var out_dir := across * cos(angle) * float(spec.rx) + depth * sin(angle) * float(spec.rz)
		var pos := c + out_dir * swell
		var flow := (tangent * length + (-across * sin(angle) * float(spec.rx) + depth * cos(angle) * float(spec.rz)) * TAU * turns).normalized()
		var outward := out_dir.normalized() if out_dir.length() > 0.001 else depth
		outward = (outward - flow * outward.dot(flow)).normalized()
		var side := flow.cross(outward).normalized()
		# A whip of a tail, a full body, a slimmer neck.
		var girth := thick * lerpf(0.18, 1.0, smoothstep(0.0, 0.3, u)) * lerpf(1.0, 0.8, smoothstep(0.85, 1.0, u))
		var ring: Array = []
		for s in sides:
			var a := TAU * float(s) / float(sides)
			var dir := outward * cos(a) + side * sin(a)
			ring.append([pos + dir * girth * (1.0 if s != 0 else 1.12), dir])
		var open := skip.size() == 2 and u > float(skip[0]) and u < float(skip[1])
		if prev_ok and not open:
			var st: SurfaceTool = b["solid"]
			for s in sides:
				var s2 := (s + 1) % sides
				# Back scales in two jades by band, the belly (toward the weapon) in pale gold.
				var belly := s == 2 or s == 3
				var color: Color = DragonGearData.GOLD_LIGHT if belly else (DragonGearData.JADE if k % 2 == 0 else DragonGearData.JADE.darkened(0.22))
				if s == 0 or s == sides - 1:
					color = color.lightened(0.16)
				var quad := [prev[s], ring[s], ring[s2], prev[s2]]
				for idx in [0, 1, 2, 0, 2, 3]:
					st.set_color(color)
					st.set_normal(quad[idx][1])
					st.add_vertex(quad[idx][0])
			b["solid_count"] += sides * 6
			# The ridge of spines, alight, every other band.
			if k % 2 == 0 and u > 0.12 and u < 0.97:
				_spike(b, pos + outward * girth * 0.8 - flow * girth * 0.4, outward - flow * 0.55, girth * 1.5, girth * 0.7, p.glow, true)
		prev = ring
		prev_ok = not open
		last_pos = pos
	# The tail fin: three flames of light fanning off the tip.
	var tail := _along(centre, 0.0) + ((_along(centre, 0.0) - _along(centre, 0.05)).normalized().cross(Vector3.BACK)).normalized() * float(spec.rx) * 0.75
	var back := (_along(centre, 0.0) - _along(centre, 0.06)).normalized()
	for k in 3:
		var fan := back.rotated(Vector3.BACK, (float(k) - 1.0) * 0.55)
		_spike(b, tail, fan, thick * (2.6 if k == 1 else 1.9), thick * 0.9, p.glow if k == 1 else DragonGearData.JADE_LIGHT, true)
	# The neck reaches from the last coil to the head.
	var head_at: Vector3 = spec.head
	var nose: Vector3 = (spec.nose as Vector3).normalized()
	var neck: Array[Vector3] = [last_pos, last_pos.lerp(head_at, 0.5) + (spec.crown as Vector3).normalized() * thick * 0.6, head_at - nose * float(spec.size) * 0.3]
	StarGearArt._part(b, WeaponKit.tube(neck, Vector3.BACK, thick * 0.78, 6), DragonGearData.JADE, Vector3.ZERO, Vector3.ONE)
	_head(b, p, head_at, nose, spec.crown, float(spec.size))


## The dragon's head at [param at], looking along [param nose], its crown toward
## [param crown]: skull, snout, an open gold jaw with fangs, brows, two pairs of swept
## horns, a mane and whiskers of light, and eyes in the class's glow.
static func _head(b: Dictionary, p: Dictionary, at: Vector3, nose: Vector3, crown: Vector3, s: float) -> void:
	var y := nose.normalized()
	var x := y.cross(crown.normalized()).normalized()
	var z := x.cross(y).normalized()
	var frame := Transform3D(Basis(x, y, z) * Basis.from_scale(Vector3.ONE * s), at)
	var jade: Color = DragonGearData.JADE
	var gold: Color = DragonGearData.GOLD
	_put(b, MeshKit.sphere_low(), jade, _at(frame, Vector3(0, 0, 0), Vector3(0.9, 0.86, 0.74)))
	# A long wedge of a snout over an open gold jaw, a tongue of fire between them.
	_spike(b, frame * Vector3(0, 0.12, 0.06), frame.basis * Vector3(0, 1, -0.06), s * 0.9, s * 0.74, jade.lightened(0.3))
	_spike(b, frame * Vector3(0, 0.1, 0.27), frame.basis * Vector3(0, 1, -0.2), s * 0.8, s * 0.2, gold)
	_spike(b, frame * Vector3(0, 0.1, -0.24), frame.basis * Vector3(0, 1, -0.42), s * 0.8, s * 0.46, DragonGearData.GOLD_LIGHT)
	_spike(b, frame * Vector3(0, 0.2, -0.12), frame.basis * Vector3(0, 1, -0.24), s * 0.66, s * 0.2, Color("ff6a4a"), true)
	_spike(b, frame * Vector3(0, -0.05, 0.36), frame.basis * Vector3(0, -0.35, 1), s * 0.34, s * 0.2, gold)
	for side in [-1.0, 1.0]:
		_spike(b, frame * Vector3(side * 0.2, 0.55, -0.06), frame.basis * Vector3(0, 0.1, -1), s * 0.22, s * 0.1, Color("fffbe8"))
		# Eyes alight in the class's colour.
		_put(b, MeshKit.sphere_low(), p.eye, _at(frame, Vector3(side * 0.3, 0.16, 0.24), Vector3(0.17, 0.26, 0.17)), true)
		# Great horns swept back, a smaller pair below.
		_spike(b, frame * Vector3(side * 0.24, -0.1, 0.3), frame.basis * Vector3(side * 0.42, -0.8, 0.55), s * 1.25, s * 0.24, gold)
		_spike(b, frame * Vector3(side * 0.38, -0.12, 0.02), frame.basis * Vector3(side * 0.85, -0.6, 0.0), s * 0.7, s * 0.2, DragonGearData.GOLD_LIGHT)
		# Fin ears and whiskers of light.
		_spike(b, frame * Vector3(side * 0.4, 0.05, -0.12), frame.basis * Vector3(side * 0.8, -0.5, -0.35), s * 0.6, s * 0.2, DragonGearData.JADE_LIGHT, true)
		var whisker: Array[Vector3] = [frame * Vector3(side * 0.2, 0.7, 0.0), frame * Vector3(side * 0.5, 0.86, 0.1), frame * Vector3(side * 0.72, 0.6, 0.18), frame * Vector3(side * 0.8, 0.22, 0.14)]
		StarGearArt._part(b, WeaponKit.tube(whisker, frame.basis.z.normalized(), s * 0.035, 4), p.glow, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, true)
	# The mane streams off the back of the skull.
	for k in 4:
		_spike(b, frame * Vector3(0, -0.2 - 0.14 * k, 0.3 - 0.07 * k), frame.basis * Vector3(0, -0.75, 0.6), s * (0.62 - 0.07 * k), s * 0.2, p.glow, true)


## The dragon knuckle dusters under the dragon (HandWraps' pieces and layout, at the
## top grade): dragon gold with jade-bound grip and trims, a dragon claw of pale gold
## over every knuckle, the stones and the mantra band in the class's own glow (the fire
## of อัคนี), and the dragon pearl at the bar's lower end.
static func _wraps(b: Dictionary, p: Dictionary) -> void:
	var roles := {"metal": DragonGearData.GOLD, "accent": DragonGearData.JADE_DEEP, "gem": p.eye, "glow": p.glow}
	for part in HandWraps.pieces(3, false):
		_put(b, part[0], roles[part[1]], part[2], part[1] in ["gem", "glow"])
	var face := HandWraps.KNUCKLES
	for k in 4:
		_spike(b, Vector3(face.x + 0.012, HandWraps.ring_y(k), face.z + 0.016), Vector3(1, 0, -0.2), 0.028, 0.014, DragonGearData.GOLD_LIGHT)
	_pearl(b, p, Vector3(face.x + 0.004, HandWraps.ring_y(0) - HandWraps.RING_STEP * 0.75, face.z), 0.016)


## What only this weapon has besides the dragon: the dragon pearl in the class's gem
## colour (in the staffs' rings, on the pommels, over the shield's and the book's
## face) and a hot edge of light down the blades.
static func _extras(b: Dictionary, p: Dictionary, kind: String) -> void:
	match kind:
		"sword":
			for side in [-1.0, 1.0]:
				StarGearArt._line(b, [Vector3(side * 0.21, 0.5, 0.05), Vector3(side * 0.15, 1.9, 0.04), Vector3(0, 2.42, 0.03)], 0.014, p.glow, true)
			_pearl(b, p, Vector3(0, -0.27, 0), 0.2)
		"dagger":
			_pearl(b, p, Vector3(0, -0.25, 0), 0.16)
			StarGearArt._line(b, [Vector3(0, 0.9, 0.05), Vector3(0, 1.36, 0.02)], 0.014, p.glow, true)
		"spear":
			for side in [-1.0, 1.0]:
				StarGearArt._line(b, [Vector3(side * 0.1, 1.5, 0.03), Vector3(0, 2.06, 0.02)], 0.012, p.glow, true)
			_pearl(b, p, Vector3(0, -0.7, 0), 0.15)
		"staff":
			_pearl(b, p, Vector3(0, 2.05, 0), 0.4)
		"wand":
			_pearl(b, p, Vector3(0, 0.79, 0.08), 0.17)
		"scepter":
			_pearl(b, p, Vector3(0, 0.86, 0), 0.31)
		"lantern":
			_pearl(b, p, Vector3(-0.6, 0.85, 0), 0.3)
		"bow":
			_pearl(b, p, Vector3(-0.42, 0, 0.02), 0.2)
		"greatshield", "shield":
			_pearl(b, p, Vector3(0, 0.1, 0.4), 0.3)
		"book", "tome":
			_pearl(b, p, Vector3(0, 0.08, 0.17), 0.13)
		"lute":
			_pearl(b, p, Vector3(0, -0.3, 0.036), 0.06)


## The dragon pearl: a ball of the class's gem colour in a thin gold claw ring.
static func _pearl(b: Dictionary, p: Dictionary, at: Vector3, size: float) -> void:
	StarGearArt._part(b, MeshKit.sphere_low(), p.pearl, at, Vector3.ONE * size, Vector3.ZERO, true)
	StarGearArt._part(b, MeshKit.sphere_low(), Color("ffffff"), at + Vector3(-size * 0.14, size * 0.16, size * 0.3), Vector3.ONE * size * 0.3, Vector3.ZERO, true)
	for k in 3:
		var a := TAU * float(k) / 3.0 + 0.5
		_spike(b, at + Vector3(sin(a) * size * 0.62, -size * 0.3, cos(a) * size * 0.3), Vector3(-sin(a) * 0.5, 1, -cos(a) * 0.2), size * 0.7, size * 0.2, DragonGearData.GOLD)
