class_name RaidArenaArt
extends RefCounted
## The party raid's arena (RaidData): a crimson inlaid floor with the special-stage floor
## shader, a ring of blood-stone obelisks with burning caps outside the playable radius, a
## glowing summoning circle where the boss stands and a far colonnade. Vertex-coloured,
## batched into a handful of meshes (SpecialStageArt's helpers), no lights, colliders or
## particle emitters: cheap on a phone. Every raised vertex stands outside 52 m except the
## flat circle (a few cm high, no collider).

const FLOOR_RADIUS := 54.5
const BLOOD := Color("6a1a24")
const BLOOD_LIGHT := Color("9a2c38")
const TRIM := Color("e0a060")
const EMBER := Color("ff5a3a")
const RUNE := Color("ff3a50")


static func build(parent: Node3D) -> void:
	if parent.has_node("RaidArenaArt"):
		return
	var root := Node3D.new()
	root.name = "RaidArenaArt"
	root.set_meta("stage", String(RaidData.ID))
	root.set_meta("visual_only", true)
	parent.add_child(root)
	_floor(root)
	_obelisks(root)
	_summoning_circle(root, RaidRun.CENTER + Vector3(0, 0, -6))


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
	mat.set_shader_parameter("base_color", Color("5a2a32"))
	mat.set_shader_parameter("accent_color", Color("b0505a"))
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "BloodInlaidFloor"
	floor_mesh.mesh = st.commit()
	floor_mesh.material_override = mat
	floor_mesh.position.y = 0.014
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(floor_mesh)


## Twelve (eight on low quality) obelisks round the arena, each with an ember cap.
static func _obelisks(parent: Node3D) -> void:
	var st := SpecialStageArt._surface()
	var caps := SpecialStageArt._surface()
	var count := 8 if GameSettings.quality == 0 else 12
	for i in count:
		var angle := TAU * float(i) / float(count) + 0.13
		var at := Vector3(cos(angle), 0, sin(angle)) * (58.0 + float(i % 2) * 2.5)
		var frame := Transform3D(Basis(Vector3.UP, PI * 0.5 - angle), at)
		var height := 11.0 + float((i * 5) % 4) * 1.6
		SpecialStageArt._box(st, frame, Vector3(0, 0.5, 0), Vector3(5.0, 1.0, 5.0), BLOOD.darkened(0.2))
		SpecialStageArt._column(st, frame, Vector3(0, 1.0, 0), 1.5, height, BLOOD if i % 2 else BLOOD_LIGHT, 4)
		SpecialStageArt._box(st, frame, Vector3(0, height + 1.2, 0), Vector3(2.4, 0.5, 2.4), TRIM)
		SpecialStageArt._column(caps, frame, Vector3(0, height + 1.45, 0), 0.9, 2.2, EMBER, 4)
	SpecialStageArt._commit(parent, st, "BloodObelisks", true)
	var glow := MeshInstance3D.new()
	glow.name = "EmberCaps"
	glow.mesh = caps.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.4, 1.0, 1.0)
	glow.material_override = mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(glow)
	# The far wall: tall dark buttresses against the red sky.
	var backdrop := SpecialStageArt._surface()
	for i in 9:
		var angle := -2.9 + float(i) * 0.72
		var frame := Transform3D(Basis(Vector3.UP, -angle), Vector3(cos(angle), 0, sin(angle)) * 78.0)
		SpecialStageArt._column(backdrop, frame, Vector3.ZERO, 3.0, 20.0 + float(i % 3) * 4.0, Color("3a1218"), 6)
	SpecialStageArt._commit(parent, backdrop, "BloodButtresses", false)


## Flat rings and spokes where the boss rises: unshaded, a few cm high.
static func _summoning_circle(parent: Node3D, center: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in [[8.6, 9.2], [5.6, 6.0], [2.2, 2.5]]:
		_ring(st, center, float(ring[0]), float(ring[1]), 64)
	for k in 6:
		var a := TAU * float(k) / 6.0
		var dir := Vector3(cos(a), 0, sin(a))
		var side := dir.rotated(Vector3.UP, PI * 0.5) * 0.18
		var p0 := center + dir * 2.5
		var p1 := center + dir * 8.6
		for p in [p0 - side, p1 - side, p1 + side, p0 - side, p1 + side, p0 + side]:
			st.set_normal(Vector3.UP)
			st.add_vertex(p + Vector3(0, 0.03, 0))
	var mesh := MeshInstance3D.new()
	mesh.name = "SummoningCircle"
	mesh.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(RUNE.r, RUNE.g, RUNE.b, 0.75)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	# It breathes slowly (one tween on one material).
	var tween := mesh.create_tween().set_loops()
	tween.tween_property(mat, "albedo_color:a", 0.35, 1.6)
	tween.tween_property(mat, "albedo_color:a", 0.8, 1.6)


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
