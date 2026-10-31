class_name LeaderMark
extends RefCounted
## The guild leader's mark (หัวหน้ากิลด์) in the guild war: a big golden crown floating
## over the head, bobbing and turning, with a gem in the guild's colour and the title
## under it. Drawn on top of everything and seen from across the field, so both guilds
## know whom to strike and whom to guard.

const NAME := "LeaderMark"
const GOLD := Color("ffd24a")


## Puts the mark on `owner`, its crown `height` metres up. Returns the holder.
static func attach(owner: Node3D, gem_color: Color, height := 3.6) -> Node3D:
	var old := owner.get_node_or_null(NAME)
	if old != null:
		old.free()
	var holder := Node3D.new()
	holder.name = NAME
	holder.position = Vector3(0, height, 0)
	owner.add_child(holder)
	var crown := Node3D.new()
	crown.name = "Crown"
	crown.scale = Vector3.ONE * 1.8
	holder.add_child(crown)
	var gold := _material(GOLD, 1.0)
	var gem := _material(gem_color.lerp(Color.WHITE, 0.15), 1.0)
	# The band, five points with a pearl on each, a gem on the front and back.
	MeshKit.part(crown, MeshKit.cylinder(), gold, Vector3.ZERO, Vector3(0.62, 0.2, 0.62))
	MeshKit.part(crown, MeshKit.torus(), gold, Vector3(0, -0.1, 0), Vector3(0.68, 0.5, 0.68))
	for k in 5:
		var a := TAU * float(k) / 5.0
		var at := Vector3(cos(a) * 0.27, 0.22, sin(a) * 0.27)
		MeshKit.part(crown, MeshKit.cone(), gold, at, Vector3(0.18, 0.32, 0.18))
		MeshKit.part(crown, MeshKit.sphere_low(), gold, at + Vector3(0, 0.2, 0), Vector3(0.09, 0.09, 0.09))
	for side in [-1.0, 1.0]:
		MeshKit.part(crown, MeshKit.sphere_low(), gem, Vector3(0, 0.02, float(side) * 0.31), Vector3(0.13, 0.13, 0.08))
	for m in MeshKit.collect_meshes(crown):
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var title := Label3D.new()
	title.name = "Title"
	title.text = "หัวหน้ากิลด์"
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.no_depth_test = true
	title.fixed_size = false
	title.pixel_size = 0.009
	title.font_size = 44
	title.outline_size = 14
	title.modulate = GOLD
	title.outline_modulate = Color(0.25, 0.12, 0.0, 1.0)
	title.position = Vector3(0, 1.05, 0)
	holder.add_child(title)
	var bob := holder.create_tween().set_loops()
	bob.tween_property(holder, "position:y", height + 0.15, 0.8).set_trans(Tween.TRANS_SINE)
	bob.tween_property(holder, "position:y", height, 0.8).set_trans(Tween.TRANS_SINE)
	var spin := crown.create_tween().set_loops()
	spin.tween_property(crown, "rotation:y", TAU, 4.0).from(0.0)
	return holder


## Unshaded and drawn over everything (bodies and walls), so the crown is never lost.
static func _material(color: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = true
	m.render_priority = 2
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return MaterialKeeper.keep(m) as StandardMaterial3D
