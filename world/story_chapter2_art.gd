class_name StoryChapter2Art
extends RefCounted
## The chapter's looks (StoryChapter2): the landmark markers of the investigation, the
## throne stage's architecture (SpecialStageArt.build for STAGE_ID) and the finale's
## cosmetic, รัศมีดาวเงา, a dark-violet star ring at the hero's feet with rising motes
## (HeroVisual._make_aura when flags[AURA_FLAG] is set). Cheap meshes only, no lights.

const VIOLET := Color("8a5cff")
const DEEP := Color("2a1b4a")
const STAR := Color("e8d8ff")


## A landmark to walk to: a slowly turning violet ring, a floating rune and the name.
static func landmark(parent: Node3D, pos: Vector3, title: String, index := 0) -> Node3D:
	var holder := Node3D.new()
	holder.name = "StoryMark%d" % index
	holder.position = pos
	holder.set_meta("visual_only", true)
	parent.add_child(holder)
	var ring := MeshInstance3D.new()
	ring.mesh = MeshKit.torus()
	ring.material_override = MeshKit.toon(VIOLET, {"emission": 0.8, "unshaded": true})
	ring.scale = Vector3(2.4, 0.2, 2.4)
	ring.position = Vector3(0, 0.08, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(ring)
	var spin := ring.create_tween().set_loops()
	spin.tween_property(ring, "rotation:y", TAU, 6.0)
	var rune := MeshKit.part(holder, MeshKit.prism(), MeshKit.toon(STAR, {"emission": 0.9, "unshaded": true}), Vector3(0, 1.6, 0), Vector3(0.5, 0.9, 0.5))
	rune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bob := rune.create_tween().set_loops()
	bob.tween_property(rune, "position:y", 2.0, 1.4).set_trans(Tween.TRANS_SINE)
	bob.tween_property(rune, "position:y", 1.6, 1.4).set_trans(Tween.TRANS_SINE)
	var label := Label3D.new()
	label.text = "สำรวจ: " + title
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.005
	label.font_size = 40
	label.outline_size = 9
	label.modulate = Color("e3d4ff")
	label.position = Vector3(0, 3.0, 0)
	label.visibility_range_end = 40.0
	holder.add_child(label)
	return holder


## The throne court: a raised dais with the shadow throne at the east end, broken star
## pillars round the edge and a ring of drowned columns far out, all beyond the play
## radius where SpecialStageArt puts its geometry (STAGE_ID's floor is its own).
static func throne_court(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "ShadowThroneArt"
	root.set_meta("visual_only", true)
	parent.add_child(root)
	var stone := MeshKit.toon(DEEP)
	var trim := MeshKit.toon(VIOLET, {"emission": 0.5})
	var pale := MeshKit.toon(Color("4a3a72"))
	# The dais and throne stand behind the queen's spot (StoryStage.THRONE), outside play.
	for i in 4:
		MeshKit.part(root, MeshKit.cylinder(), stone if i % 2 == 0 else pale, Vector3(58, 0.3 + i * 0.5, 0), Vector3(16 - i * 2.6, 0.5, 16 - i * 2.6))
	MeshKit.part(root, MeshKit.box(), stone, Vector3(62, 4.4, 0), Vector3(2.2, 5.2, 4.6))
	MeshKit.part(root, MeshKit.box(), pale, Vector3(60.5, 2.9, 0), Vector3(2.4, 1.0, 3.4))
	for side in [-1.0, 1.0]:
		MeshKit.part(root, MeshKit.box(), pale, Vector3(60.5, 4.0, side * 2.0), Vector3(2.4, 2.2, 0.6))
		MeshKit.part(root, MeshKit.prism(), trim, Vector3(62, 8.2, side * 1.6), Vector3(0.6, 2.6, 0.6))
	MeshKit.part(root, MeshKit.prism(), trim, Vector3(62, 9.0, 0), Vector3(1.0, 3.6, 1.0))
	# Broken star pillars round the court, with violet caps; the west gateway stays open.
	for i in 14:
		var a := TAU * float(i) / 14.0
		if absf(a - PI) < 0.42:
			continue
		var at := Vector3(cos(a), 0, sin(a)) * 60.0
		var h := 7.0 + float((i * 5) % 7) * 1.3
		MeshKit.part(root, MeshKit.cylinder(), stone, at + Vector3(0, h * 0.5, 0), Vector3(1.8, h, 1.8))
		if i % 3 != 1:
			MeshKit.part(root, MeshKit.prism(), trim, at + Vector3(0, h + 0.9, 0), Vector3(1.2, 1.8, 1.2))
	# A far ring of drowned columns, the abyss the throne rose out of.
	for i in 9:
		var a := -2.7 + float(i) * 0.5
		var at := Vector3(cos(a), 0, sin(a)) * 78.0
		MeshKit.part(root, MeshKit.cylinder(), pale, at + Vector3(0, 9.0, 0), Vector3(3.2, 18.0 + float(i % 3) * 4.0, 3.2))
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## รัศมีดาวเงา: the finale's aura at the hero's feet (visual space). A violet star ring
## with five small stars and, unless [param light], rising motes. The caller frees it with
## the outfit (HeroVisual._body_nodes).
static func aura(light := false) -> Node3D:
	var root := Node3D.new()
	root.name = "ShadowStarAura"
	root.set_meta("story_aura", true)
	var ring := MeshInstance3D.new()
	ring.mesh = MeshKit.torus()
	ring.material_override = MeshKit.toon(VIOLET, {"emission": 0.9, "unshaded": true})
	ring.scale = Vector3(0.9, 0.05, 0.9)
	ring.position = Vector3(0, 0.03, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var spin := ring.create_tween().set_loops()
	spin.tween_property(ring, "rotation:y", TAU, 9.0)
	var stars := Node3D.new()
	stars.name = "Stars"
	root.add_child(stars)
	for k in 5:
		var a := TAU * float(k) / 5.0
		var star := MeshKit.part(stars, MeshKit.prism(), MeshKit.toon(STAR, {"emission": 1.0, "unshaded": true}), Vector3(sin(a) * 0.95, 0.12, cos(a) * 0.95), Vector3(0.09, 0.16, 0.09))
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var turn := stars.create_tween().set_loops()
	turn.tween_property(stars, "rotation:y", -TAU, 14.0)
	if not light and GameSettings.quality > 0:
		var motes := CPUParticles3D.new()
		motes.name = "ShadowMotes"
		var quad := QuadMesh.new()
		quad.size = Vector2(0.14, 0.14)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_texture = VfxKit.soft_dot()
		mat.albedo_color = Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.7)
		quad.material = mat
		motes.mesh = quad
		motes.amount = VfxBudget.count(16)
		motes.lifetime = 1.9
		motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		motes.emission_ring_axis = Vector3.UP
		motes.emission_ring_radius = 0.9
		motes.emission_ring_inner_radius = 0.6
		motes.emission_ring_height = 0.05
		motes.direction = Vector3.UP
		motes.spread = 12.0
		motes.initial_velocity_min = 0.35
		motes.initial_velocity_max = 0.7
		motes.gravity = Vector3.ZERO
		root.add_child(motes)
	return root
