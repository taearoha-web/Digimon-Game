class_name AscendCelebration
extends RefCounted
## The Ascension's looks (AscensionData): the trial stage's altar of light (altar) and the
## promotion's celebration (play): a pillar of heaven over the hero (StarSkillArt roots in
## the white-gold palette: three seals, a pantheon, a sunburst, feathers and a crown), the
## level-up burst and shockwaves, and a full-screen banner (CanvasLayer "AscendBanner") with
## "เปลี่ยนอาชีพขั้นที่ 6", the new name and its title. Cosmetic only, every 3D layer a
## VfxBudget decoration; the banner fades out by itself.

const GOLD := Color("ffd86a")
const PALE := Color("fff6d8")
const DEEP := Color("6a3a8a")
const COLORS := {"primary": Color("ffd86a"), "accent": Color("fff8e0"), "shade": Color("5a3a8a")}
const BANNER_SECONDS := 5.6
const PILLARS := 8
const ALTAR_RADIUS := 13.0


## The altar: a ring of white-gold pillars and a glowing floor seal round [param at].
static func altar(parent: Node3D, at: Vector3) -> Node3D:
	if not is_instance_valid(parent):
		return null
	var root := Node3D.new()
	root.name = "AscendAltar"
	root.position = at
	parent.add_child(root)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("f4ecd8")
	stone.emission_enabled = true
	stone.emission = Color("ffd86a")
	stone.emission_energy_multiplier = 0.35
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(1.0, 0.86, 0.45, 0.35)
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	var column := CylinderMesh.new()
	column.top_radius = 0.55
	column.bottom_radius = 0.7
	column.height = 7.0
	column.radial_segments = 10
	var cap := SphereMesh.new()
	cap.radius = 0.75
	cap.height = 1.5
	cap.radial_segments = 10
	cap.rings = 5
	for i in PILLARS:
		var a := TAU * float(i) / float(PILLARS)
		var spot := Vector3(sin(a), 0, cos(a)) * ALTAR_RADIUS
		var pillar := MeshInstance3D.new()
		pillar.name = "AltarPillar%d" % i
		pillar.mesh = column
		pillar.material_override = stone
		pillar.position = spot + Vector3.UP * 3.5
		root.add_child(pillar)
		var orb := MeshInstance3D.new()
		orb.name = "AltarOrb%d" % i
		orb.mesh = cap
		orb.material_override = glow
		orb.position = spot + Vector3.UP * 7.4
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(orb)
	var seal := MeshInstance3D.new()
	seal.name = "AltarSeal"
	var disc := CylinderMesh.new()
	disc.top_radius = ALTAR_RADIUS - 1.0
	disc.bottom_radius = ALTAR_RADIUS - 1.0
	disc.height = 0.04
	disc.radial_segments = 48
	seal.mesh = disc
	seal.material_override = glow
	seal.position = Vector3.UP * 0.03
	seal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(seal)
	return root


## The celebration over [param hero] (a Node3D in [param zone]).
static func play(zone: Node3D, hero: Node3D) -> void:
	if not is_instance_valid(zone) or not is_instance_valid(hero):
		return
	var at := hero.global_position
	VfxKit.level_up(zone, at)
	VfxKit.shockwave(zone, at + Vector3.UP * 0.1, GOLD, 9.0)
	VfxKit.shockwave(zone, at + Vector3.UP * 0.15, PALE, 14.0)
	pillar(zone, at)
	banner(zone)


## The pillar of heaven: two StarSkillArt roots over [param at].
static func pillar(parent: Node3D, at: Vector3) -> void:
	var ground := StarSkillArt._root(parent, at, 4.2, "AscendHeaven")
	if ground:
		ground.add("god_halo", COLORS, Vector3.UP * 0.08, Vector3.ONE * 8.0, Vector3.ZERO, 4.0, {"initial": 0.1, "grow_time": 0.5, "fade_in": 0.05, "spin": 0.6, "decay": 0.8, "veil": 0.5})
		ground.add("celestial", COLORS, Vector3.UP * 0.12, Vector3.ONE * 5.0, Vector3.ZERO, 4.0, {"initial": 0.2, "grow_time": 0.6, "fade_in": 0.05, "spin": -0.9, "decay": 0.8})
		ground.add("pantheon", COLORS, Vector3.ZERO, Vector3(6.0, 4.0, 6.0), Vector3.ZERO, 4.0, {"initial": 0.2, "grow_time": 0.4, "fade_in": 0.05, "spin": 0.3, "decay": 0.8, "opacity": 0.75, "veil": 0.55})
		ground.add("feathers", COLORS, Vector3.UP * 0.4, Vector3(5.0, 5.0, 5.0), Vector3.ZERO, 3.5, {"initial": 0.6, "travel": Vector3.UP * 2.0, "decay": 0.7})
		ground._draw()
	var sky := StarSkillArt._root(parent, at, 4.2, "AscendCrown")
	if sky:
		sky.add("crown", COLORS, Vector3.UP * 3.6, Vector3.ONE * 1.0, Vector3.ZERO, 4.0, {"initial": 0.3, "grow_time": 0.5, "fade_in": 0.1, "spin": 1.0, "decay": 0.85, "travel": Vector3.DOWN * 0.6, "front": true})
		sky.add("aureole", COLORS, Vector3(0, 2.4, -0.5), Vector3.ONE * 2.2, Vector3.ZERO, 4.0, {"initial": 0.2, "grow_time": 0.4, "fade_in": 0.05, "decay": 0.85, "face_camera": true, "pulse": true})
		sky.add("sunrise", COLORS, Vector3.UP * 7.0, Vector3.ONE * 4.0, Vector3(GodSkillArt.TILT, 0, 0), 4.0, {"initial": 0.2, "grow_time": 0.6, "fade_in": 0.1, "spin": 0.4, "decay": 0.8, "face_camera": true})
		sky._draw()


## The full-screen banner: a gold band with the step, the new name and its title.
static func banner(host: Node) -> CanvasLayer:
	if not is_instance_valid(host):
		return null
	var layer := CanvasLayer.new()
	layer.name = "AscendBanner"
	layer.layer = 40
	host.add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var band := ColorRect.new()
	band.name = "Band"
	band.color = Color(0.1, 0.06, 0.2, 0.78)
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = 0.3
	band.anchor_bottom = 0.7
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(band)
	for edge in [0.3, 0.7]:
		var line := ColorRect.new()
		line.color = GOLD
		line.anchor_left = 0.0
		line.anchor_right = 1.0
		line.anchor_top = edge
		line.anchor_bottom = edge
		line.offset_top = -3
		line.offset_bottom = 3
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(line)
	var box := VBoxContainer.new()
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.anchor_top = 0.3
	box.anchor_bottom = 0.7
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	var cls: Dictionary = Game.class_data() if Game.has_profile else {}
	var lines := [["✦ เปลี่ยนอาชีพขั้นที่ 6 · %s ✦" % AscensionData.TITLE, 26, PALE], [String(cls.get("name", "")), 54, GOLD], ["— %s —" % String(cls.get("title", "")), 24, Color("f0dcff")]]
	for row in lines:
		var label := Label.new()
		label.name = "Line%d" % box.get_child_count()
		label.text = String(row[0])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", int(row[1]))
		label.add_theme_color_override("font_color", row[2])
		label.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.0))
		label.add_theme_constant_override("outline_size", 8)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)
	root.modulate.a = 0.0
	root.scale = Vector2(1.0, 1.0)
	var tween := root.create_tween()
	tween.tween_property(root, "modulate:a", 1.0, 0.45)
	tween.tween_interval(BANNER_SECONDS - 1.2)
	tween.tween_property(root, "modulate:a", 0.0, 0.75)
	tween.tween_callback(layer.queue_free)
	return layer
