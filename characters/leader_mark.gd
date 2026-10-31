class_name LeaderMark
extends RefCounted
## The guild leader's mark (หัวหน้ากิลด์) in the guild war: a big royal crown in the
## guild's own colour (Alpha gold, Neverdie rose gold) floating over the head, bobbing and
## turning, over a pulsing ring of light with sparkles, the title above it. Drawn on top of everything and seen from across the field, so both guilds
## know whom to strike and whom to guard.

const NAME := "LeaderMark"
const GOLD := Color("ffd24a")


## Puts the mark on `owner` in `color`, its crown `height` metres up. Returns the holder.
static func attach(owner: Node3D, color: Color, height := 3.6) -> Node3D:
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
	_build_crown(crown, color)
	# A ring of light under the crown and sparkles drifting off it.
	var ring := MeshKit.part(holder, MeshKit.torus(), _glow(color, 0.55), Vector3(0, -0.12, 0), Vector3(1.55, 0.25, 1.55))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pulse := ring.create_tween().set_loops()
	pulse.tween_property(ring, "scale", Vector3(1.85, 0.25, 1.85), 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(ring, "scale", Vector3(1.55, 0.25, 1.55), 0.9).set_trans(Tween.TRANS_SINE)
	var title := Label3D.new()
	title.name = "Title"
	title.text = "หัวหน้ากิลด์"
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.no_depth_test = true
	title.fixed_size = false
	title.pixel_size = 0.009
	title.font_size = 44
	title.outline_size = 14
	title.modulate = color.lerp(Color.WHITE, 0.2)
	title.outline_modulate = color.darkened(0.8)
	title.position = Vector3(0, 1.55, 0)
	holder.add_child(title)
	var bob := holder.create_tween().set_loops()
	bob.tween_property(holder, "position:y", height + 0.15, 0.8).set_trans(Tween.TRANS_SINE)
	bob.tween_property(holder, "position:y", height, 0.8).set_trans(Tween.TRANS_SINE)
	var spin := crown.create_tween().set_loops()
	spin.tween_property(crown, "rotation:y", TAU, 4.0).from(0.0)
	return holder


## A royal crown in `color`: a band with rims top and bottom and a row of small studs,
## eight points (tall ones tipped with a pearl and a little cross, short ones with a gem),
## a velvet cap inside under an orb and cross, and a big faceted gem in front and back.
## Shaded metal with a warm glow, so it reads as gold (or rose gold), not a flat cut-out.
static func _build_crown(crown: Node3D, color: Color) -> void:
	var metal := _metal(color)
	var rim := _metal(color.lightened(0.25))
	var velvet := _metal(color.darkened(0.55), 0.0, 0.85)
	var pearl := _metal(Color("fff8ec"), 0.2, 0.25)
	var jewel := _jewel(Color("ff3b5c") if color.r > color.b and color.g > 0.6 else Color("5ad8ff"))
	var jewel2 := _jewel(Color("5affb0"))
	# The velvet cap and the band.
	MeshKit.part(crown, MeshKit.hemisphere(), velvet, Vector3(0, 0.08, 0), Vector3(0.52, 0.42, 0.52))
	MeshKit.part(crown, MeshKit.cylinder(), metal, Vector3(0, 0.0, 0), Vector3(0.62, 0.22, 0.62))
	MeshKit.part(crown, MeshKit.torus(), rim, Vector3(0, -0.11, 0), Vector3(0.68, 0.55, 0.68))
	MeshKit.part(crown, MeshKit.torus(), rim, Vector3(0, 0.11, 0), Vector3(0.66, 0.45, 0.66))
	for k in 16:
		var a := TAU * (float(k) + 0.5) / 16.0
		MeshKit.part(crown, MeshKit.sphere_low(), pearl if k % 2 == 0 else rim, Vector3(cos(a) * 0.315, 0.0, sin(a) * 0.315), Vector3.ONE * 0.045)
	# Eight points round the band, tall and short in turn.
	for k in 8:
		var a := TAU * float(k) / 8.0
		var out := Vector3(cos(a), 0, sin(a))
		var tall := k % 2 == 0
		var h := 0.42 if tall else 0.26
		var base := out * 0.29 + Vector3(0, 0.12, 0)
		var spike := MeshKit.part(crown, MeshKit.cone(), metal, base + Vector3(0, h * 0.5, 0), Vector3(0.16, h, 0.07))
		spike.rotation.y = -a + PI * 0.5
		spike.rotation.z = 0.0
		var tip := base + Vector3(0, h + 0.02, 0)
		if tall:
			MeshKit.part(crown, MeshKit.sphere_low(), pearl, tip, Vector3.ONE * 0.085)
			MeshKit.part(crown, MeshKit.box(), rim, tip + Vector3(0, 0.1, 0), Vector3(0.025, 0.11, 0.025))
			MeshKit.part(crown, MeshKit.box(), rim, tip + Vector3(0, 0.115, 0), Vector3(0.07, 0.025, 0.025)).rotation.y = -a + PI * 0.5
		else:
			MeshKit.part(crown, MeshKit.sphere_low(), jewel2, tip, Vector3.ONE * 0.07)
		# A small gem on the band under each point.
		MeshKit.part(crown, MeshKit.sphere_low(), jewel if tall else jewel2, out * 0.325 + Vector3(0, 0.0, 0), Vector3(0.06, 0.06, 0.035)).rotation.y = -a + PI * 0.5
	# The big faceted gems on the front and the back.
	for side in [-1.0, 1.0]:
		var g := MeshKit.part(crown, MeshKit.sphere_low(), jewel, Vector3(0, 0.02, float(side) * 0.335), Vector3(0.13, 0.15, 0.06))
		g.rotation_degrees = Vector3(0, 0, 45)
	# The orb and cross on top of the cap.
	MeshKit.part(crown, MeshKit.sphere_low(), metal, Vector3(0, 0.5, 0), Vector3.ONE * 0.12)
	MeshKit.part(crown, MeshKit.box(), rim, Vector3(0, 0.64, 0), Vector3(0.04, 0.18, 0.04))
	MeshKit.part(crown, MeshKit.box(), rim, Vector3(0, 0.67, 0), Vector3(0.12, 0.04, 0.04))
	for m in MeshKit.collect_meshes(crown):
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The crown's colour for a side: its guild's own (WorldPlayers.GUILD_COLORS); the
## two sides always differ, so with no guild ours is gold and theirs rose.
static func guild_color(team: int) -> Color:
	var mine := Game.guild()
	var g := mine if team == GuildFighter.TEAM_ALLY else WorldPlayers.other_guild(mine)
	var fallback := GOLD if team == GuildFighter.TEAM_ALLY else Color("ff6f8e")
	return WorldPlayers.GUILD_COLORS.get(g, fallback) if mine > 0 else fallback


## Shaded metal with a glow of its own, drawn over everything (bodies and walls), so the
## crown is never lost behind a crowd.
static func _metal(color: Color, metallic := 0.85, roughness := 0.3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic * 0.6
	m.roughness = roughness
	m.metallic_specular = 0.9
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.7
	m.rim_enabled = true
	m.rim = 0.6
	m.no_depth_test = true
	m.render_priority = 2
	return MaterialKeeper.keep(m) as StandardMaterial3D


## A bright gem that glows.
static func _jewel(color: Color) -> StandardMaterial3D:
	var m := _metal(color, 0.3, 0.1)
	m.emission_energy_multiplier = 1.2
	return m


## Additive glow (the ring and the sparkles), over everything too.
static func _glow(color: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.no_depth_test = true
	m.render_priority = 2
	return MaterialKeeper.keep(m) as StandardMaterial3D
