class_name DragonWingArt
extends Node3D
## The look of the 300★ Dragon God wings (DragonGearData.wings), built in code: a great
## pair of dragon wings, each a gold-boned arm (shoulder, elbow, wrist) plated with jade
## scales, four long bone fingers ending in claws, a thumb claw and an elbow spur, and a
## membrane stretched between the fingers and down to the hip with a scalloped trailing
## edge. The membrane wears the class's own colours (SetGearData.PALETTES: its cloth
## deepening toward the arm, its glow at the edge) and veins of light pulse out along it
## from the wrist; the class's sigil (SetGearArt._sigil: flames, gale leaves, thunder, a
## galaxy, dawn rays, a moon, ice, blood crescents or aurora ribbons) burns at each wrist.
## The Dark Lord, who wears a cape in the wing slot, gets the Dragon Emperor's cape
## instead: CapeArt's long cape and scale capelet re-cut in dragon jade over his abyss
## violet, with a small pair of these wings standing at the shoulders. The Muay Thai
## fighter, who wears a ring robe, gets its star robe (CapeArt, "muaythai") re-cut
## as the Dragon God's (cape shader boxer 3): jade dragon-scale satin, a gold dragon coiled
## round the mongkhon on the back, scale rims, embers, prajiad tails and mantra ring all
## alight in the fire of its dragon (อัคนี: the class set's glow), and two gold dragon
## heads clasping the robe at the shoulders where the prajiad tails are knotted (one
## baked mesh). No wings at all.
##
## One unshaded shader (dragon_wing.gdshader) draws membrane, bones, scales and claws
## from the mesh's UVs: no textures, no lights, no particles, nothing added over the
## picture (so the select stage's soften_glow has nothing to tone down). Each wing sways
## and its membrane flutters in the vertex stage; on the lowest quality and in a crowd's
## light dress the material holds still (motion 0). Two draw calls for the pair plus the
## two sigils.
##
## It answers to the wing clips (Idle, Flap, Glide, Fold, Unfold on an AnimationPlayer),
## so HeroVisual poses it like any pair: the clips drive [member beat], [member fold] and
## [member air], which place the wing nodes (and billow the Dark Lord's cape).
##
## Model space is the chibi's (x side, y up, z front) like the wing GLBs; everything is
## authored in metres at the hero's size under the Fit node, on the shoulder blades.

const SHADER := preload("res://shaders/dragon_wing.gdshader")
## The chibi's model space is this many times smaller than the hero in metres.
const FIT := 1.0 / 2.45
## The shoulder blades in model space.
const BACK := Vector3(0.0, 0.57, -0.09)
const PIVOT := Vector3(0.1, 0.06, -0.1)
## The Dark Lord's small pair: its size and where it stands on the cape's shoulders.
const SMALL := 0.5
## The great pair's size (the mesh is authored at 1).
const GREAT := 0.84
const SMALL_PIVOT := Vector3(0.16, 0.16, -0.12)
const ROW_MEMBRANE := 0
const ROW_BONE := 1
const ROW_SCALE := 2
const ROW_CLAW := 3
## The arm: shoulder, elbow, wrist; then the finger tips from the leading finger down,
## and the hip the last panel runs to.
const SHOULDER := Vector2(0.0, 0.0)
const ELBOW := Vector2(0.5, 0.46)
const WRIST := Vector2(0.92, 1.12)
const TIPS := [Vector2(1.78, 1.82), Vector2(2.42, 0.98), Vector2(2.26, 0.0), Vector2(1.66, -0.78)]
const HIP := Vector2(0.34, -0.8)
const REACH := 2.6
## Membrane grid of one panel: along the fingers and across.
const ALONG := 10
const ACROSS := 8

## Wing beat: 0 rests open, up to 1 raised, down to -1 lowered.
@export var beat := 0.0:
	set(value):
		beat = value
		_place()
## 0 spread, 1 folded down behind the back.
@export var fold := 0.0:
	set(value):
		fold = value
		_place()
## 0 on the ground, 1 gliding (the Dark Lord's cape streams out with it).
@export var air := 0.0:
	set(value):
		air = value
		_place()

var cls := "warrior"
var _fit: Node3D
var _wings: Array[MeshInstance3D] = []
var _cape: CapeArt
static var _mesh: ArrayMesh
static var _materials := {}
static var _library: AnimationLibrary


## The pair as worn by class [param p_cls]. [param light]: a crowd's light dress (the
## shader holds still).
static func build(p_cls: String, light := false) -> Node3D:
	var art := DragonWingArt.new()
	art.cls = p_cls if SetGearData.THEMES.has(p_cls) else "warrior"
	art.name = "Wings_dragon_" + art.cls
	art._make(light or GameSettings.quality == 0)
	return art


## The class's wing colours: the membrane from the set's cloth to its glow, veins of
## its glow; gold bones and jade scales on every class.
static func colors(p_cls: String) -> Dictionary:
	var own := SetGearData.palette(p_cls)
	var cloth: Color = own.cloth
	var glow: Color = own.glow
	var deep: Color = (own.dark as Color).lerp(cloth, 0.3)
	# A pale cloth (the priest's) keeps a warm body so the wings do not wash out.
	if cloth.v > 0.9 and cloth.s < 0.2:
		cloth = Color("ecc46e")
		deep = Color("a8722e")
	return {"membrane_deep": deep, "membrane": cloth, "membrane_edge": glow.lerp(cloth, 0.25), "vein": glow.lerp(Color.WHITE, 0.35),
		"bone": DragonGearData.GOLD, "bone_light": DragonGearData.GOLD_LIGHT, "scale_color": DragonGearData.JADE, "scale_light": DragonGearData.JADE_LIGHT}


static func material(p_cls: String, still := false) -> ShaderMaterial:
	var key := "%s_%s" % [p_cls, "still" if still else "moving"]
	if not _materials.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		var c := colors(p_cls)
		for param in c:
			mat.set_shader_parameter(param, c[param])
		mat.set_shader_parameter("motion", 0.0 if still else 1.0)
		MaterialKeeper.keep(mat)
		_materials[key] = mat
	return _materials[key]


func _make(still: bool) -> void:
	_fit = Node3D.new()
	_fit.name = "Fit"
	_fit.scale = Vector3.ONE * FIT
	_fit.position = BACK
	add_child(_fit)
	if cls == "muaythai":
		_cape = CapeArt.build_tinted("DragonCape", {"outer_color": Color("13785c"), "outer_deep": Color("052a21"), "lining_color": Color("10261f"),
			"trim_color": DragonGearData.GOLD, "glow_color": SetGearData.palette(cls).glow, "boxer": 3.0}, cls)
		var own_player := _cape.get_node_or_null("AnimationPlayer")
		if own_player != null:
			_cape.remove_child(own_player)
			own_player.free()
		add_child(_cape)
		_cape._fit.add_child(_clasps())
	elif cls == "darklord":
		var own := SetGearData.palette(cls)
		_cape = CapeArt.build_tinted("DragonCape", {"outer_color": Color("14725c"), "outer_deep": Color("05221d"), "lining_color": Color("2c1548"),
			"trim_color": DragonGearData.GOLD, "glow_color": own.glow, "capelet_color": Color("1f9a78"), "capelet_deep": Color("0a3a30"), "gem": own.gem})
		# This node's clips drive the cape: its own player would fight them.
		var own_player := _cape.get_node_or_null("AnimationPlayer")
		if own_player != null:
			_cape.remove_child(own_player)
			own_player.free()
		add_child(_cape)
	var mat := material(cls, still)
	for side in ([] if cls == "muaythai" else [1.0, -1.0]):
		var mi := MeshInstance3D.new()
		mi.name = "Wing" + ("R" if side > 0 else "L")
		mi.mesh = wing_mesh()
		mi.set_surface_override_material(0, mat)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("no_outline", true)
		# The shader sways the tips past the mesh's own bounds.
		mi.custom_aabb = AABB(Vector3(-0.3, -1.2, -0.9), Vector3(3.2, 3.4, 1.8))
		_fit.add_child(mi)
		_wings.append(mi)
		if cls != "darklord":
			var sigil := _sigil()
			sigil.position = Vector3(WRIST.x, WRIST.y, 0.0)
			mi.add_child(sigil)
	_place()
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	add_child(player)
	player.add_animation_library("", _clips())
	player.play("Idle")


## The Muay Thai robe's clasps: a gold dragon head on each shoulder, over the knot of
## the prajiad tails, looking forward and out, eyes in the class's fire (DragonGearArt's
## head, both in one baked mesh). In the robe's authored space (CapeArt._fit).
func _clasps() -> Node3D:
	var key := "dragonwing_clasps_" + cls
	if not StarGearArt._cache.has(key):
		var b := StarGearArt._builder()
		var p := DragonGearArt.palette(cls)
		for side in [-1.0, 1.0]:
			var at := Vector3(side * 0.2, CapeArt.TOP_Y - 0.02, CapeArt.BACK_Z + 0.13)
			StarGearArt._ring_at(b, at + Vector3(0, -0.01, -0.03), 0.045, 0.02, DragonGearData.GOLD)
			DragonGearArt._head(b, p, at, Vector3(side * 0.35, 0.25, 1.0), Vector3(0, 1, -0.2), 0.085)
		StarGearArt._store(key, b)
	var root := Node3D.new()
	root.name = "DragonClasps"
	StarGearArt._attach(root, key)
	var art := root.get_child(0) as MeshInstance3D
	if art != null and art.mesh != null and art.mesh.get_surface_count() > 1:
		art.set_surface_override_material(1, DragonGearArt.glow_material())
	return root


## The class sigil that burns at a wrist (SetGearArt._sigil, front and back).
func _sigil() -> Node3D:
	var key := "dragonwing_sigil_" + cls
	if not StarGearArt._cache.has(key):
		var b := StarGearArt._builder()
		var p := SetGearData.palette(cls)
		StarGearArt._ring_at(b, Vector3.ZERO, 0.2, 0.035, DragonGearData.GOLD)
		SetGearArt._sigil(b, p, cls, Vector3(0, 0, 0.05), 0.15)
		SetGearArt._sigil(b, p, cls, Vector3(0, 0, -0.05), 0.15)
		StarGearArt._part(b, MeshKit.sphere_low(), p.gem, Vector3.ZERO, Vector3(0.2, 0.2, 0.12), Vector3.ZERO, true)
		StarGearArt._store(key, b)
	var root := Node3D.new()
	root.name = "Sigil"
	StarGearArt._attach(root, key)
	return root


## Places the wings for the current beat and fold (the left one mirrors the right).
func _place() -> void:
	if _cape != null:
		_cape.billow = clampf(0.14 + 0.82 * air + 0.08 * beat, 0.0, 1.0)
		_cape.fold = fold
	if _fit == null or _wings.size() < 2:
		return
	var small := cls == "darklord"
	var size := (SMALL if small else GREAT) * lerpf(1.0, 0.5, fold)
	# Folding rolls the wings down along the back and draws them in.
	var open := Basis.from_euler(Vector3(deg_to_rad(-6.0 + 6.0 * fold), deg_to_rad(24.0 + 30.0 * fold), deg_to_rad(beat * 15.0 - 6.0 - 96.0 * fold + (14.0 if small else 0.0))))
	open = open.scaled(Vector3.ONE * size)
	var pivot := SMALL_PIVOT if small else PIVOT
	_wings[0].transform = Transform3D(open, pivot)
	_wings[1].transform = Transform3D(Basis.from_scale(Vector3(-1, 1, 1)) * open, pivot * Vector3(-1, 1, 1))


## The wing clips, shared by every pair (they key this node's beat, fold and air).
static func _clips() -> AnimationLibrary:
	if _library == null:
		_library = AnimationLibrary.new()
		_library.add_animation("Idle", _clip(3.6, [[0.0, 0.0], [1.8, 0.2], [3.6, 0.0]], [[0.0, 0.0]], [[0.0, 0.0]], true))
		_library.add_animation("Flap", _clip(1.2, [[0.0, -0.6], [0.55, 0.8], [1.2, -0.6]], [[0.0, 0.0]], [[0.0, 0.5]], true))
		_library.add_animation("Glide", _clip(2.2, [[0.0, 0.3], [1.1, 0.42], [2.2, 0.3]], [[0.0, 0.0]], [[0.0, 1.0]], true))
		_library.add_animation("Fold", _clip(0.4, [[0.0, 0.0], [0.4, -0.2]], [[0.0, 0.0], [0.4, 1.0]], [[0.0, 0.0]], false))
		_library.add_animation("Unfold", _clip(0.5, [[0.0, -0.2], [0.3, 0.5], [0.5, 0.0]], [[0.0, 1.0], [0.3, 0.0]], [[0.0, 0.0]], false))
	return _library


static func _clip(length: float, beat_keys: Array, fold_keys: Array, air_keys: Array, loop: bool) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for spec in [["beat", beat_keys], ["fold", fold_keys], ["air", air_keys]]:
		var track := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track, NodePath(".:" + String(spec[0])))
		anim.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
		for key in spec[1]:
			anim.track_insert_key(track, float(key[0]), float(key[1]))
	return anim


## The inventory icon model (ItemLook.build_icon_node).
static func build_icon_node(p_cls: String) -> Node3D:
	var holder := Node3D.new()
	var wings := build(p_cls, true)
	wings.rotation_degrees = Vector3(0, 180, 0)
	holder.add_child(wings)
	if p_cls == "muaythai":
		# The robe and its mantra ring alone (no wings): framed closer.
		holder.set_meta("frame", Vector3(0.0, 0.42, 0.92))
	elif p_cls == "darklord":
		holder.set_meta("frame", Vector3(0.0, 0.4, 1.16))
	else:
		holder.set_meta("frame", Vector3(0.0, 0.8, 1.72))
	return holder


## Surfaces and triangles of a built pair (the budget the tests hold it to).
static func cost(root: Node3D) -> Dictionary:
	var surfaces := 0
	var tris := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		# (A primitive's arrays live on the rendering server: one surface, counted as built.)
		if mesh is ArrayMesh:
			surfaces += mesh.get_surface_count()
			tris += LegendWingMesh.triangles(mesh)
		elif mesh != null:
			surfaces += 1
	return {"surfaces": surfaces, "triangles": tris}


# --- The mesh ---------------------------------------------------------------------

## The right wing (the left is the same mesh mirrored), built once a session.
static func wing_mesh() -> ArrayMesh:
	if _mesh == null:
		_mesh = _build_wing()
	return _mesh


static func _v3(p: Vector2, z := 0.0) -> Vector3:
	return Vector3(p.x, p.y, z)


## A finger from the wrist to its tip, bowed a little upward.
static func _finger(i: int, s: float) -> Vector2:
	var tip: Vector2 = TIPS[i]
	var mid := (WRIST + tip) * 0.5
	var bow := (tip - WRIST).orthogonal().normalized() * -0.1 * (tip - WRIST).length()
	if bow.y < 0.0 and i < 2:
		bow = -bow
	var c := mid + bow
	var k := 1.0 - s
	return WRIST * k * k + c * 2.0 * k * s + tip * s * s


## The membrane's inner edge from the shoulder down to the hip.
static func _inner(s: float) -> Vector2:
	var c := Vector2(0.5, -0.2)
	var k := 1.0 - s
	return SHOULDER * k * k + c * 2.0 * k * s + HIP * s * s


static func _edge(i: int, s: float) -> Vector2:
	return _finger(i, s) if i < TIPS.size() else _inner(s)


static func _add(st: SurfaceTool, pos: Vector3, normal: Vector3, uv: Vector2, row: int, phase: float) -> void:
	st.set_uv(uv)
	st.set_uv2(Vector2(float(row) + clampf(phase, 0.0, 0.99), clampf(Vector2(pos.x, pos.y).length() / REACH, 0.0, 1.0)))
	st.set_normal(normal)
	st.add_vertex(pos)


static func _build_wing() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The membrane, panel by panel: between the fingers, then from the last finger to the hip.
	for panel in TIPS.size():
		var deep := 0.24 if panel < TIPS.size() - 1 else 0.3
		for r in ALONG:
			for c in ACROSS:
				var quad: Array = []
				for corner in [[0, 0], [1, 0], [1, 1], [0, 1]]:
					var s := float(r + corner[0]) / float(ALONG)
					var t := float(c + corner[1]) / float(ACROSS)
					# The trailing edge hangs in a scallop between two tips.
					var reach := s * (1.0 - deep * sin(PI * t))
					var p := _edge(panel, reach).lerp(_edge(panel + 1, reach), t)
					quad.append([Vector3(p.x, p.y, -0.14 * sin(PI * t) * reach - 0.05 * p.x * p.x / 4.0), Vector2(t, s)])
				var normal := ((quad[1][0] - quad[0][0]) as Vector3).cross(quad[3][0] - quad[0][0]).normalized()
				if normal.z < 0.0:
					normal = -normal
				for idx in [0, 1, 2, 0, 2, 3]:
					_add(st, quad[idx][0], normal, quad[idx][1], ROW_MEMBRANE, float(panel) / 8.0)
	# The skin between shoulder, elbow and wrist.
	for tri in [[SHOULDER, ELBOW, WRIST]]:
		var uvs := [Vector2(0.5, 0.05), Vector2(0.05, 0.3), Vector2(0.5, 0.0)]
		for i in 3:
			_add(st, _v3(tri[i], -0.01), Vector3.BACK, uvs[i], ROW_MEMBRANE, 0.6)
	# Bones: the arm, then the fingers, tapering to the claws.
	_tube(st, [_v3(SHOULDER, 0.02), _v3(SHOULDER.lerp(ELBOW, 0.5), 0.04), _v3(ELBOW, 0.03)], 0.11, 0.095, 0.1)
	_tube(st, [_v3(ELBOW, 0.03), _v3(ELBOW.lerp(WRIST, 0.5), 0.04), _v3(WRIST, 0.03)], 0.095, 0.075, 0.2)
	for i in TIPS.size():
		var line: Array = []
		for k in 9:
			var s := float(k) / 8.0
			var p := _finger(i, s)
			line.append(Vector3(p.x, p.y, 0.02 - 0.05 * p.x * p.x / 4.0))
		_tube(st, line, 0.046, 0.014, 0.3 + 0.1 * i)
		var tip: Vector3 = line[8]
		var dir := (tip - (line[7] as Vector3)).normalized()
		_spike(st, tip - dir * 0.02, (dir + Vector3(0, -0.5, 0)).normalized(), 0.2, 0.05, ROW_CLAW)
	for joint in [ELBOW, WRIST]:
		_ball(st, _v3(joint, 0.03), 0.1)
	# The thumb claw on the wrist and a spur on the elbow.
	_spike(st, _v3(WRIST, 0.03), Vector3(-0.25, 1.0, 0.1).normalized(), 0.42, 0.11, ROW_CLAW)
	_spike(st, _v3(WRIST, 0.03) + Vector3(0.08, 0.02, 0), Vector3(0.3, 1.0, 0.1).normalized(), 0.26, 0.08, ROW_CLAW)
	_spike(st, _v3(ELBOW, 0.03), Vector3(-0.8, 0.45, -0.2).normalized(), 0.3, 0.1, ROW_CLAW)
	# Scales down the arm, overlapping like roof tiles, on both faces.
	var arm := [SHOULDER, ELBOW, WRIST]
	for seg in 2:
		var from: Vector2 = arm[seg]
		var to: Vector2 = arm[seg + 1]
		var along := (to - from).normalized()
		var across := along.orthogonal()
		if across.y > 0.0:
			across = -across
		for k in 5:
			var at := from.lerp(to, (float(k) + 0.5) / 5.0) + across * 0.1
			for face in [-1.0, 1.0]:
				_scale(st, _v3(at, 0.03 + face * 0.05), along, across, 0.19, 0.2, face, float(seg * 5 + k) / 10.0)
		# A second, smaller row hanging under it onto the membrane.
		for k in 4:
			var at := from.lerp(to, (float(k) + 1.0) / 5.0) + across * 0.25
			for face in [-1.0, 1.0]:
				_scale(st, _v3(at, 0.03 + face * 0.04), along, across, 0.14, 0.16, face, float(seg * 4 + k) / 8.0 + 0.05)
	st.index()
	return st.commit()


## A tapering five-sided tube along [param points].
static func _tube(st: SurfaceTool, points: Array, r0: float, r1: float, phase: float) -> void:
	var sides := 5
	var rings: Array = []
	for i in points.size():
		var a: Vector3 = points[maxi(i - 1, 0)]
		var c: Vector3 = points[mini(i + 1, points.size() - 1)]
		var tangent := (c - a).normalized()
		var normal := tangent.cross(Vector3.BACK).normalized()
		var radius := lerpf(r0, r1, float(i) / float(points.size() - 1))
		var ring: Array = []
		for s in sides + 1:
			var ang := TAU * float(s) / float(sides)
			var dir := normal * cos(ang) + Vector3.BACK * sin(ang)
			ring.append([(points[i] as Vector3) + dir * radius, dir, Vector2(float(s) / float(sides), float(i) / float(points.size() - 1))])
		rings.append(ring)
	for i in points.size() - 1:
		for s in sides:
			var quad := [rings[i][s], rings[i + 1][s], rings[i + 1][s + 1], rings[i][s + 1]]
			for idx in [0, 1, 2, 0, 2, 3]:
				_add(st, quad[idx][0], quad[idx][1], quad[idx][2], ROW_BONE, phase)


## A knuckle: an eight-faced ball.
static func _ball(st: SurfaceTool, at: Vector3, r: float) -> void:
	var tops := [Vector3.UP, Vector3.DOWN]
	var ring := [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD]
	for top in tops:
		for k in 4:
			var tri := [top, ring[k], ring[(k + 1) % 4]]
			for dir in tri:
				_add(st, at + (dir as Vector3) * r, dir, Vector2(0.5, 0.5), ROW_BONE, 0.5)


## A four-sided spike (a claw, a spur).
static func _spike(st: SurfaceTool, base: Vector3, dir: Vector3, length: float, width: float, row: int) -> void:
	var side := dir.cross(Vector3.BACK).normalized()
	var other := dir.cross(side).normalized()
	var tip := base + dir * length
	var corners := [base + side * width * 0.5, base + other * width * 0.5, base - side * width * 0.5, base - other * width * 0.5]
	for i in 4:
		var a: Vector3 = corners[i]
		var c: Vector3 = corners[(i + 1) % 4]
		var normal := (c - a).cross(tip - a).normalized()
		_add(st, a, normal, Vector2(float(i) / 4.0, 0.0), row, 0.0)
		_add(st, c, normal, Vector2(float(i + 1) / 4.0, 0.0), row, 0.0)
		_add(st, tip, normal, Vector2(float(i) / 4.0 + 0.125, 1.0), row, 0.0)


## One scale: a pointed plate, its tip down the wing, raised along its ridge.
static func _scale(st: SurfaceTool, at: Vector3, along: Vector2, across: Vector2, width: float, length: float, face: float, phase: float) -> void:
	var a3 := Vector3(along.x, along.y, 0)
	var c3 := Vector3(across.x, across.y, 0)
	var top_l := at - a3 * width * 0.5 - c3 * length * 0.3
	var top_r := at + a3 * width * 0.5 - c3 * length * 0.3
	var tip := at + c3 * length * 0.7
	var ridge := at + Vector3(0, 0, face * 0.035)
	var normal := Vector3(0, 0, face)
	for tri in [[top_l, top_r, ridge, Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 0.4)], [top_r, tip, ridge, Vector2(1, 0), Vector2(0.5, 1), Vector2(0.5, 0.4)],
			[tip, top_l, ridge, Vector2(0.5, 1), Vector2(0, 0), Vector2(0.5, 0.4)]]:
		for i in 3:
			_add(st, tri[i], normal, tri[i + 3], ROW_SCALE, phase)
