class_name DragonTombArt
extends RefCounted
## The mechanics dungeon's arena (DungeonData): a mossy stone floor with the special-stage
## floor shader, a ring of bone pillars (rib arches) outside the playable radius, a great
## dragon skull at the back with two glowing eyes, scattered bone piles and a glowing
## rune circle where the dragon rises. Vertex-coloured, batched into a handful of meshes
## (SpecialStageArt's helpers), no lights, colliders or particle emitters: cheap on a phone.
## Every raised vertex stands outside 52 m except the flat circle (a few cm high).

const FLOOR_RADIUS := 54.5
const STONE := Color("2e3a34")
const STONE_LIGHT := Color("465a50")
const BONE := Color("d8d0b8")
const BONE_DARK := Color("a09880")
const RUNE := Color("5cf28a")
const EYE := Color("ffb02a")


static func build(parent: Node3D) -> void:
	if parent.has_node("DragonTombArt"):
		return
	var root := Node3D.new()
	root.name = "DragonTombArt"
	root.set_meta("stage", String(DungeonData.ID))
	root.set_meta("visual_only", true)
	parent.add_child(root)
	_floor(root)
	_ribs(root)
	_skull(root)
	_rune_circle(root, DragonRun.CENTER + Vector3(0, 0, -6))


static func _floor(parent: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 96:
		var a := TAU * float(i) / 96.0
		var b := TAU * float(i + 1) / 96.0
		st.set_normal(Vector3.UP)
		for p in [Vector3.ZERO, Vector3(cos(b), 0, sin(b)) * FLOOR_RADIUS, Vector3(cos(a), 0, sin(a)) * FLOOR_RADIUS]:
			st.add_vertex(p)
	var mat := ShaderMaterial.new()
	mat.shader = SpecialStageArt.FLOOR_SHADER
	mat.set_shader_parameter("surface_kind", 0)
	mat.set_shader_parameter("base_color", Color("2a3630"))
	mat.set_shader_parameter("accent_color", Color("5a7a66"))
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "TombFloor"
	floor_mesh.mesh = st.commit()
	floor_mesh.material_override = mat
	floor_mesh.position.y = 0.014
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(floor_mesh)


## Rib arches of a buried dragon round the arena (eight on low quality) and bone piles.
static func _ribs(parent: Node3D) -> void:
	var st := SpecialStageArt._surface()
	var count := 8 if GameSettings.quality == 0 else 12
	for i in count:
		var angle := TAU * float(i) / float(count) + 0.2
		var at := Vector3(cos(angle), 0, sin(angle)) * (57.0 + float(i % 2) * 2.0)
		var frame := Transform3D(Basis(Vector3.UP, PI * 0.5 - angle), at)
		var height := 12.0 + float((i * 7) % 4) * 1.5
		SpecialStageArt._box(st, frame, Vector3(0, 0.4, 0), Vector3(4.0, 0.8, 4.0), STONE)
		# A rib: a leaning column with a bent tip (two segments).
		var lean := Transform3D(Basis(Vector3.RIGHT, -0.28), Vector3.ZERO)
		SpecialStageArt._column(st, frame * lean, Vector3(0, 0.6, 0), 1.1, height, BONE if i % 2 else BONE_DARK, 5)
		var tip := Transform3D(Basis(Vector3.RIGHT, -0.9), Vector3(0, height * 0.96, -height * 0.27))
		SpecialStageArt._column(st, frame * tip, Vector3.ZERO, 0.8, height * 0.4, BONE, 5)
		# A small bone pile at its foot.
		for k in 3:
			var off := Vector3(-1.6 + 1.6 * float(k), 0.3, 1.8 + 0.3 * float(k % 2))
			SpecialStageArt._box(st, frame, off, Vector3(1.6, 0.5, 0.5), BONE_DARK.lightened(0.05 * float(k)))
	SpecialStageArt._commit(parent, st, "DragonRibs", true)
	# Far crypt walls: dark stone slabs against the sky.
	var backdrop := SpecialStageArt._surface()
	for i in 9:
		var angle := -2.9 + float(i) * 0.72
		var frame := Transform3D(Basis(Vector3.UP, -angle), Vector3(cos(angle), 0, sin(angle)) * 78.0)
		SpecialStageArt._box(backdrop, frame, Vector3(0, 9.0 + float(i % 3) * 2.0, 0), Vector3(10.0, 18.0 + float(i % 3) * 4.0, 3.0), STONE.darkened(0.35))
	SpecialStageArt._commit(parent, backdrop, "CryptWalls", false)


## The dragon's skull at the back of the arena: a blocky head, two horns, a jaw and two
## glowing eye sockets (unshaded).
static func _skull(parent: Node3D) -> void:
	var st := SpecialStageArt._surface()
	var at := Vector3(0, 0, -66.0)
	var frame := Transform3D(Basis(), at)
	SpecialStageArt._box(st, frame, Vector3(0, 7.0, 0), Vector3(16.0, 10.0, 12.0), BONE)
	SpecialStageArt._box(st, frame, Vector3(0, 3.0, 6.0), Vector3(12.0, 4.0, 10.0), BONE_DARK)
	SpecialStageArt._box(st, frame, Vector3(0, 1.0, 7.0), Vector3(13.0, 1.6, 9.0), BONE)
	for side in [-1.0, 1.0]:
		var horn := Transform3D(Basis(Vector3.FORWARD, side * 0.5), at + Vector3(side * 7.5, 11.0, -2.0))
		SpecialStageArt._column(st, horn, Vector3.ZERO, 1.6, 9.0, BONE_DARK, 5)
		for tooth in 4:
			SpecialStageArt._box(st, frame, Vector3(side * (1.5 + 1.6 * float(tooth)), 2.4, 10.5), Vector3(0.6, 1.6, 0.5), BONE)
	SpecialStageArt._commit(parent, st, "DragonSkull", true)
	var eyes := SpecialStageArt._surface()
	for side in [-1.0, 1.0]:
		SpecialStageArt._box(eyes, frame, Vector3(side * 4.2, 8.0, 6.2), Vector3(2.6, 1.8, 0.6), EYE)
	var glow := MeshInstance3D.new()
	glow.name = "SkullEyes"
	glow.mesh = eyes.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.5, 1.2, 0.9)
	glow.material_override = mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(glow)


## Flat rings and claw-mark spokes where the dragon rises: unshaded, a few cm high.
static func _rune_circle(parent: Node3D, center: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in [[9.0, 9.6], [6.0, 6.4], [2.4, 2.7]]:
		_ring(st, center, float(ring[0]), float(ring[1]), 64)
	for k in 5:
		var a := TAU * float(k) / 5.0
		var dir := Vector3(cos(a), 0, sin(a))
		var side := dir.rotated(Vector3.UP, PI * 0.5) * 0.2
		var p0 := center + dir * 2.7
		var p1 := center + dir * 9.0
		for p in [p0 - side, p1 - side, p1 + side, p0 - side, p1 + side, p0 + side]:
			st.set_normal(Vector3.UP)
			st.add_vertex(p + Vector3(0, 0.03, 0))
	var mesh := MeshInstance3D.new()
	mesh.name = "RuneCircle"
	mesh.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(RUNE.r, RUNE.g, RUNE.b, 0.7)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	var tween := mesh.create_tween().set_loops()
	tween.tween_property(mat, "albedo_color:a", 0.3, 1.8)
	tween.tween_property(mat, "albedo_color:a", 0.75, 1.8)


static func _ring(st: SurfaceTool, center: Vector3, inner: float, outer: float, sides: int) -> void:
	for i in sides:
		var a := TAU * float(i) / float(sides)
		var b := TAU * float(i + 1) / float(sides)
		var ia := center + Vector3(cos(a) * inner, 0.03, sin(a) * inner)
		var ib := center + Vector3(cos(b) * inner, 0.03, sin(b) * inner)
		var oa := center + Vector3(cos(a) * outer, 0.03, sin(a) * outer)
		var ob := center + Vector3(cos(b) * outer, 0.03, sin(b) * outer)
		for p in [ia, oa, ob, ia, ob, ib]:
			st.set_normal(Vector3.UP)
			st.add_vertex(p)
