class_name WorldArt
extends RefCounted
## Decorative storybook silhouettes. Everything here is visual only: landmarks
## sit beyond the encounter area and never add collision or alter spawns.

static var _materials: Dictionary = {}

const PALETTES := {
	&"meadow": [Color("a9b68b"), Color("e5c695"), Color("ce8095")],
	&"digital": [Color("827997"), Color("b7accc"), Color("9ad6cd")],
	&"desert": [Color("c29d7d"), Color("ead2a5"), Color("91c1bf")],
	&"snow": [Color("94afc3"), Color("dfedf0"), Color("91cddd")],
	&"volcano": [Color("75636c"), Color("a18a8a"), Color("f2ae83")],
	&"graveyard": [Color("7b7c91"), Color("b6b6c3"), Color("b9b3df")],
	&"swamp": [Color("70867d"), Color("aeb8a0"), Color("b9d8b1")],
	&"storm": [Color("8294a7"), Color("b4c4d0"), Color("e4dba5")],
	&"sky": [Color("ccc5af"), Color("f2e5c2"), Color("efd19a")],
	&"abyss": [Color("746074"), Color("ad8895"), Color("edb1b6")],
	&"void": [Color("736c94"), Color("b3a5ca"), Color("c7b4ee")],
}


static func landscape(parent: Node3D, theme: StringName, radius: float, seed_value: int) -> void:
	var palette: Array = PALETTES.get(theme, PALETTES[&"meadow"])
	var art_rng := RandomNumberGenerator.new()
	art_rng.seed = seed_value + 7301
	var root := MeshKit.pivot(parent, "DistantLandscape")
	var count := 12 if GameSettings.quality > 0 else 8
	for i in count:
		var angle := TAU * float(i) / count + 0.13
		var distance := radius + art_rng.randf_range(29.0, 42.0)
		var height := art_rng.randf_range(14.0, 26.0)
		var color: Color = palette[0]
		color = color.lerp(Color("a5b7c3"), 0.18 + float(i % 3) * 0.07)
		var hill := MeshKit.part(root, MeshKit.sphere_low(), _mat(color),
			Vector3(cos(angle) * distance, -2.6, sin(angle) * distance),
			Vector3(art_rng.randf_range(28.0, 44.0), height, art_rng.randf_range(23.0, 38.0)))
		hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if theme in [&"snow", &"storm", &"volcano", &"void", &"abyss"]:
			var peak := MeshKit.part(root, MeshKit.cone(), _mat(palette[1]),
				hill.position + Vector3(0, height * 0.35, 0), Vector3(13, height * 0.85, 13))
			peak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func boss_landmark(parent: Node3D, theme: StringName, boss_spot: Vector3) -> void:
	var outward := Vector3(boss_spot.x, 0, boss_spot.z).normalized()
	var root := MeshKit.pivot(parent, "BossLandmark", boss_spot + outward * 13.5)
	root.rotation.y = atan2(outward.x, outward.z)
	var palette: Array = PALETTES.get(theme, PALETTES[&"meadow"])
	var stone := _mat(palette[0])
	var trim := _mat(palette[1])
	var accent := _mat(palette[2], 0.2)
	match theme:
		&"meadow", &"swamp":
			_mushroom(root, Vector3.ZERO, 1.6, palette[2])
			_mushroom(root, Vector3(-4.0, 0, 1.2), 0.85, palette[1])
			_mushroom(root, Vector3(4.2, 0, 2.0), 1.05, palette[2])
		&"snow":
			for i in 5:
				var x := (i - 2) * 2.0
				_crystal(root, Vector3(x, 0.2, absf(x) * 0.25), 7.5 - absf(x) * 0.7, palette[2])
		&"volcano", &"abyss":
			for side in [-1.0, 1.0]:
				MeshKit.part(root, MeshKit.cone(), stone, Vector3(side * 3.0, 3.8, 0), Vector3(3.2, 8.0, 3.2), Vector3(0, 0, side * 12.0))
				MeshKit.part(root, MeshKit.cone(), trim, Vector3(side * 4.4, 2.0, 1.2), Vector3(2.0, 4.4, 2.0), Vector3(0, 0, side * 18.0))
			_crystal(root, Vector3(0, 1.6, 0), 3.8, palette[2])
		&"void":
			for i in 5:
				var angle := TAU * i / 5.0
				_crystal(root, Vector3(cos(angle) * 3.7, 2.4 + sin(angle) * 1.6, 0), 2.0, palette[2])
			_crystal(root, Vector3(0, 1.8, 0), 5.5, palette[1])
		_:
			# Sandstone gate, moon ruin and celestial arch share construction but
			# have distinct palettes, crests and silhouettes for each region.
			for side in [-1.0, 1.0]:
				MeshKit.part(root, MeshKit.cylinder(), stone, Vector3(side * 3.6, 0.35, 0), Vector3(2.0, 0.7, 2.0))
				for j in 3:
					MeshKit.part(root, MeshKit.box(), stone if j % 2 == 0 else trim,
						Vector3(side * 3.6, 1.35 + j * 1.35, 0), Vector3(1.15, 1.25, 1.35))
			for i in 7:
				var angle := PI * float(i) / 6.0
				MeshKit.part(root, MeshKit.box(), trim, Vector3(cos(angle) * 3.6, 4.2 + sin(angle) * 3.6, 0),
					Vector3(1.35, 1.65, 1.4), Vector3(0, 0, rad_to_deg(angle)))
			if theme == &"sky":
				MeshKit.part(root, MeshKit.torus(), accent, Vector3(0, 8.8, 0), Vector3(2.2, 2.2, 2.2), Vector3(90, 0, 0))
			elif theme == &"graveyard":
				MeshKit.part(root, MeshKit.sphere_low(), accent, Vector3(0, 8.6, 0), Vector3(1.5, 1.5, 0.45))
			else:
				_crystal(root, Vector3(0, 7.8, 0), 1.4, palette[2])
	# Restrained base stones anchor the landmark without covering the fight.
	for i in 5:
		MeshKit.part(root, MeshKit.sphere_low(), stone, Vector3((i - 2) * 2.2, 0.25, 1.8), Vector3(2.1, 0.8, 1.4))


static func camp_details(parent: Node3D, theme: StringName, radius: float, seed_value: int) -> void:
	var palette: Array = PALETTES.get(theme, PALETTES[&"meadow"])
	var art_rng := RandomNumberGenerator.new()
	art_rng.seed = seed_value
	# Broken arcs of half-buried stones suggest a clearing instead of a bright
	# UI ring. The entry side stays completely open and all pieces are low.
	var count := 7 if GameSettings.quality > 0 else 4
	for i in count:
		var angle := -1.4 + float(i) / maxf(count - 1, 1) * 2.8
		var position := Vector3(cos(angle), 0, sin(angle)) * (radius + 0.3)
		var s := art_rng.randf_range(0.7, 1.15)
		MeshKit.part(parent, MeshKit.sphere_low(), _mat(palette[1]), position + Vector3(0, 0.08, 0), Vector3(0.8, 0.28, 0.55) * s)
	if GameSettings.quality > 0 and theme in [&"meadow", &"digital", &"swamp"]:
		for i in 3:
			_mushroom(parent, Vector3(radius * 0.72 + i * 0.38, 0, radius * 0.74), 0.09 + i * 0.025, palette[2])


static func cottage_details(parent: Node3D, size: Vector3, roof_color: Color) -> void:
	var timber := _mat(Color("8c705d"))
	var cream := _mat(Color("f2dfba"))
	var glass := _mat(Color("b9d9dd"), 0.12)
	var front := size.z * 0.5 + 0.1
	# Foundation, timber corners and roof ridge add scale to the plaster body.
	MeshKit.part(parent, MeshKit.box(), _mat(Color("a49d92")), Vector3(0, 0.2, 0), Vector3(size.x + 0.25, 0.4, size.z + 0.25))
	for x in [-size.x * 0.48, size.x * 0.48]:
		MeshKit.part(parent, MeshKit.box(), timber, Vector3(x, size.y * 0.51, front), Vector3(0.18, size.y, 0.2))
	MeshKit.part(parent, MeshKit.box(), timber, Vector3(0, size.y * 0.95, front), Vector3(size.x, 0.2, 0.2))
	MeshKit.part(parent, MeshKit.cylinder(), _mat(roof_color.lightened(0.15)), Vector3(0, size.y + 1.83, 0), Vector3(0.25, size.z + 1.0, 0.25), Vector3(90, 0, 0))
	for x in [-size.x * 0.3, size.x * 0.3]:
		MeshKit.part(parent, MeshKit.box(), cream, Vector3(x, size.y * 0.6, front + 0.02), Vector3(1.24, 1.24, 0.15))
		MeshKit.part(parent, MeshKit.box(), glass, Vector3(x, size.y * 0.6, front + 0.12), Vector3(0.95, 0.95, 0.09))
		MeshKit.part(parent, MeshKit.box(), cream, Vector3(x, size.y * 0.6, front + 0.18), Vector3(0.07, 0.98, 0.06))
		MeshKit.part(parent, MeshKit.box(), cream, Vector3(x, size.y * 0.6, front + 0.18), Vector3(0.98, 0.07, 0.06))
		MeshKit.part(parent, MeshKit.box(), timber, Vector3(x, size.y * 0.6 - 0.72, front + 0.2), Vector3(1.4, 0.3, 0.5))
		if GameSettings.quality > 0:
			for i in 3:
				MeshKit.part(parent, MeshKit.sphere_low(), _mat(Color("93a773")), Vector3(x - 0.4 + i * 0.4, size.y * 0.6 - 0.52, front + 0.25), Vector3(0.46, 0.35, 0.4))
				MeshKit.part(parent, MeshKit.sphere_low(), _mat(Color("e3a6b8")), Vector3(x - 0.4 + i * 0.4, size.y * 0.6 - 0.35, front + 0.3), Vector3(0.2, 0.2, 0.2))
	MeshKit.part(parent, MeshKit.box(), cream, Vector3(0, 1.06, front), Vector3(1.62, 2.15, 0.2))
	MeshKit.part(parent, MeshKit.box(), timber, Vector3(0, 1.0, front + 0.12), Vector3(1.3, 2.0, 0.13))
	MeshKit.part(parent, MeshKit.sphere_low(), _mat(Color("e0be7e")), Vector3(0.38, 0.9, front + 0.24), Vector3(0.14, 0.14, 0.12))
	MeshKit.part(parent, MeshKit.box(), _mat(Color("c4b7a3")), Vector3(0, 0.12, front + 0.42), Vector3(1.95, 0.24, 0.9))
	MeshKit.part(parent, MeshKit.box(), _mat(Color("ba9a85")), Vector3(size.x * 0.28, size.y + 1.3, -size.z * 0.23), Vector3(0.8, 2.0, 0.8))
	MeshKit.part(parent, MeshKit.box(), cream, Vector3(size.x * 0.28, size.y + 2.3, -size.z * 0.23), Vector3(1.0, 0.2, 1.0))


static func _mushroom(parent: Node3D, position: Vector3, size: float, color: Color) -> void:
	var root := MeshKit.pivot(parent, "StoryMushroom", position)
	root.scale = Vector3.ONE * size
	MeshKit.part(root, MeshKit.cylinder(), _mat(Color("eee1c6")), Vector3(0, 1.4, 0), Vector3(0.9, 2.8, 0.9))
	MeshKit.part(root, MeshKit.hemisphere(), _mat(color), Vector3(0, 2.8, 0), Vector3(4.2, 2.3, 4.2))
	MeshKit.part(root, MeshKit.cylinder(), _mat(Color("eedac3")), Vector3(0, 2.83, 0), Vector3(4.0, 0.14, 4.0))
	for i in 5:
		var angle := TAU * i / 5.0
		MeshKit.part(root, MeshKit.sphere_low(), _mat(Color("fff2d7")), Vector3(cos(angle) * 1.15, 3.78, sin(angle) * 1.15), Vector3(0.55, 0.14, 0.5))


static func _crystal(parent: Node3D, position: Vector3, height: float, color: Color) -> void:
	var mat := _mat(color, 0.14)
	MeshKit.part(parent, MeshKit.cone(), mat, position + Vector3(0, height * 0.6, 0), Vector3(height * 0.42, height * 0.8, height * 0.42))
	MeshKit.part(parent, MeshKit.cone(), mat, position + Vector3(0, height * 0.13, 0), Vector3(height * 0.42, height * 0.26, height * 0.42), Vector3(180, 0, 0))


static func _mat(color: Color, emission := 0.0) -> StandardMaterial3D:
	# Soft diffuse avoids the clipped broad highlights of the toon lobe on
	# large pale scenery. Cache separately so character materials stay intact.
	var key := "%s|%.2f" % [color.to_html(), emission]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		material.roughness = 1.0
		if emission > 0.0:
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = emission * 0.3
		_materials[key] = material
	return _materials[key]
