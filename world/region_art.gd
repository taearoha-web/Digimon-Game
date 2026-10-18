class_name RegionArt
extends RefCounted
## Composed, visual-only region landmarks and habitat edges. Terrain and props
## are static meshes with shared resources. Every shoreline stays beyond the
## playable radius, leaving the original floor, spawns and travel routes intact.

const WATER_SHADER := preload("res://shaders/region_water.gdshader")
const RIDGE_HEIGHT := {
	&"meadow": 15.0, &"digital": 23.0, &"desert": 17.0, &"snow": 34.0,
	&"volcano": 30.0, &"graveyard": 22.0, &"swamp": 13.0, &"storm": 35.0,
	&"sky": 20.0, &"abyss": 32.0, &"void": 29.0,
}
const RIDGE_COLORS := {
	&"meadow": [Color("667f70"), Color("9aafba")],
	&"digital": [Color("56546d"), Color("8c91b0")],
	&"desert": [Color("a98063"), Color("c6b4a4")],
	&"snow": [Color("6f899e"), Color("aabfce")],
	&"volcano": [Color("64535b"), Color("a18b91")],
	&"graveyard": [Color("5e6478"), Color("999eb7")],
	&"swamp": [Color("526d62"), Color("95aaa7")],
	&"storm": [Color("536b82"), Color("95afc3")],
	&"sky": [Color("929e91"), Color("c1cbce")],
	&"abyss": [Color("5e4a61"), Color("97869e")],
	&"void": [Color("575371"), Color("9695b4")],
}
const WATERS := {
	&"meadow": [Color("588f94"), Color("a7c5ae")],
	&"digital": [Color("456c78"), Color("83b7b0")],
	&"snow": [Color("7ca7be"), Color("c7e1e8")],
	&"swamp": [Color("536e61"), Color("a0b398")],
	&"storm": [Color("536e85"), Color("a6bac4")],
	&"sky": [Color("80a7b4"), Color("d7e2d6")],
	&"volcano": [Color("bd674b"), Color("e6a069")],
	&"abyss": [Color("8c485f"), Color("b88289")],
	&"void": [Color("666187"), Color("a29bbd")],
	&"village": [Color("3f86a0"), Color("a6d6d8")],
}
## The hunting field's brook: from the north cove, between the first camps,
## then along the north side of the trail (x, z). Visual only, never on the trail.
const STREAM := [Vector2(-12, -56), Vector2(-13, -40), Vector2(-12, -30), Vector2(-11.5, -18), Vector2(-10, -9),
	Vector2(-4, -7.5), Vector2(8, -8.5), Vector2(20, -4), Vector2(30, -2), Vector2(34, -2.5)]
static var _stone_mesh: ArrayMesh
static var _pyramid_mesh: Mesh
static var _vertex_mat: StandardMaterial3D
static var _water_mats: Dictionary = {}


static func landscape(parent: Node3D, theme: StringName, radius: float, seed_value: int) -> void:
	var root := MeshKit.pivot(parent, "SculptedLandscape")
	var colors: Array = RIDGE_COLORS.get(theme, RIDGE_COLORS[&"meadow"])
	var layers := 3 if GameSettings.quality > 0 else 2
	for layer in layers:
		var start := radius + 33.0 + layer * 34.0
		var depth := float(layer) / maxf(layers - 1, 1)
		var tint: Color = colors[0].lerp(colors[1], depth)
		var height: float = float(RIDGE_HEIGHT.get(theme, 18.0)) * (0.9 + layer * 0.52)
		var mesh := _ridge_mesh(theme, start, 64.0, height, seed_value, layer, tint)
		var part := MeshKit.part(root, mesh, _colored_material(), Vector3.ZERO, Vector3.ONE, Vector3.ZERO, "Ridge_%d" % layer)
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.set_meta("art_theme", theme)
	root.set_meta("ridge_layers", layers)


static func _ridge_mesh(theme: StringName, inner: float, width: float, height: float, seed_value: int,
		layer: int, tint: Color) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value + layer * 41 + 407
	noise.frequency = 0.03
	var segments := 128 if GameSettings.quality > 0 else 80
	var bands := 6
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in bands:
		for j in segments:
			# Godot front faces wind clockwise when viewed from above.
			for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var t := float(ring + corner.x) / bands
				var angle := TAU * float(j + corner.y) / segments
				var radial := Vector2(cos(angle), sin(angle))
				var sample := radial * (inner + 13.0)
				var broad := noise.get_noise_2d(sample.x, sample.y) * 0.5 + 0.5
				var detail := noise.get_noise_2d(sample.x * 2.5, sample.y * 2.5)
				# Four unequal mountain groups, separated by open valleys. Each
				# depth layer is rotated, revealing the next range through gaps.
				var phase := layer * 0.82 + fmod(seed_value * 0.037, 0.3)
				var envelope := 0.0
				for group in 4:
					var center: float = [0.48, 2.0, 3.64, 5.15][group] + phase
					var spread: float = [0.67, 0.48, 0.72, 0.5][group]
					var distance := absf(wrapf(angle - center, -PI, PI))
					if distance < spread:
						var amplitude: float = [0.8, 1.16, 0.73, 0.96][group]
						envelope = maxf(envelope, pow(cos(distance / spread * PI * 0.5), 1.3) * amplitude)
				var crest := _crest(theme, envelope * (0.72 + broad * 0.6 + detail * 0.35), angle, detail, envelope, layer, phase)
				var profile := pow(sin(t * PI), 1.7)
				if theme in [&"desert", &"volcano", &"abyss"]:
					profile = minf(profile * 1.18, 1.0)
				var y := height * profile * crest - 1.8
				var r := inner + width * t + broad * 10.0 + sin(angle * 3.0 + layer) * 9.0
				var shade := tint.darkened((1.0 - t) * 0.08 + (1.0 - broad) * 0.08)
				if theme == &"snow":
					shade = shade.lerp(Color("e3eaed"), smoothstep(height * 0.46, height * 0.75, y) * 0.86)
				st.set_color(shade)
				st.add_vertex(Vector3(radial.x * r, y, radial.y * r))
	st.generate_normals()
	st.index()
	return st.commit()


## Per-theme ridge profile: jagged teeth for snow and storm, flat mesas for the
## desert, one dominant cone for the volcano, low banks under the sky kingdom's
## islands, needles for the void, rolling hills everywhere else.
static func _crest(theme: StringName, crest: float, angle: float, detail: float, envelope: float, layer: int, phase: float) -> float:
	match theme:
		&"snow", &"storm":
			return crest + pow(absf(sin(angle * 29.0 + layer)), 7.0) * envelope * 0.55 + pow(maxf(detail + 0.45, 0.0), 2.0) * envelope * 0.5
		&"desert":
			var mesa := minf(crest, 0.58) + smoothstep(0.5, 0.58, crest) * 0.1
			return mesa + smoothstep(0.78, 0.9, crest) * 0.08
		&"volcano":
			var d := absf(wrapf(angle - (2.0 + phase), -PI, PI))
			return crest + maxf(0.0, 1.0 - d / 0.6) * (1.3 if layer == 1 else 0.35)
		&"sky":
			return crest * 0.45
		&"void":
			return crest * 0.7 + pow(absf(sin(angle * 17.0 + layer * 2.0)), 10.0) * envelope * 1.1
		&"abyss":
			return crest + pow(absf(sin(angle * 11.0 + layer)), 5.0) * envelope * 0.35
	return crest


## Big landmark shapes between the tree wall and the first ridge (radius + 10
## .. + 30): 3-6 batched, vertex-coloured silhouettes per theme. No colliders,
## no shadows, nothing inside the play radius.
static func silhouettes(parent: Node3D, theme: StringName, radius: float, seed_value: int) -> void:
	var root := MeshKit.pivot(parent, "Silhouettes")
	root.set_meta("art_theme", theme)
	root.set_meta("visual_only", true)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 17 + 909
	var p: Array = WorldArt.PALETTES.get(theme, WorldArt.PALETTES[&"meadow"])
	var ring := func(angle: float, r: float, y := 0.0) -> Vector3:
		return Vector3(cos(angle) * (radius + r), y, sin(angle) * (radius + r))
	match theme:
		&"volcano":
			var cones: Array[Transform3D] = []
			var cone_colors: Array[Color] = []
			for spec in [[2.3, 28.0, 34.0, 30.0], [3.9, 24.0, 18.0, 15.0], [0.9, 26.0, 16.0, 12.0]]:
				var base: Vector3 = ring.call(spec[0], spec[1])
				cones.append(Transform3D(Basis.from_scale(Vector3(spec[2], spec[3], spec[2])), base + Vector3(0, spec[3] * 0.5 - 1.0, 0)))
				cone_colors.append(Color("4a3238").lerp(Color("5c4044"), rng.randf()))
			_batch(root, MeshKit.cone(), cones, cone_colors, "VolcanoCones")
			var top: Vector3 = ring.call(2.3, 28.0, 25.0)
			_batch(root, MeshKit.torus(), [Transform3D(Basis.from_scale(Vector3(10.0, 3.0, 10.0)), top)], [Color("ff7a2a")], "CraterRim", true)
			var streaks: Array[Transform3D] = []
			for i in 3:
				var a := 2.3 + (i - 1) * 0.08
				streaks.append(Transform3D(Basis.from_euler(Vector3(0, -a, deg_to_rad(-48.0))).scaled(Vector3(0.9, 14.0, 0.9)), ring.call(a, 28.0 - 7.0, 18.0)))
			_batch(root, MeshKit.box(), streaks, [Color("ff6a1e"), Color("ff9040"), Color("ff5a1a")], "LavaStreaks", true)
		&"snow":
			var spires: Array[Transform3D] = []
			var spire_colors: Array[Color] = []
			var feet: Array[Transform3D] = []
			var feet_colors: Array[Color] = []
			for i in 6:
				var a := 0.5 + i * 1.0 + rng.randf() * 0.3
				var h := rng.randf_range(16.0, 26.0)
				var base: Vector3 = ring.call(a, rng.randf_range(14.0, 28.0))
				spires.append(Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.08, 0.08), a, rng.randf_range(-0.08, 0.08))).scaled(Vector3(h * 0.28, h, h * 0.28)), base + Vector3(0, h * 0.5 - 1.0, 0)))
				spire_colors.append(Color("dfeaf2").lerp(Color("b9d0e4"), rng.randf()))
				feet.append(Transform3D(Basis(Vector3.UP, a).scaled(Vector3(h * 0.5, h * 0.18, h * 0.42)), base))
				feet_colors.append(Color("c7d9e8"))
			_batch(root, MeshKit.cone(), spires, spire_colors, "IceSpires")
			_batch(root, MeshKit.sphere_low(), feet, feet_colors, "SpireFeet")
		&"graveyard":
			var chapel := MeshKit.pivot(root, "RuinedChapel", ring.call(2.2, 22.0))
			chapel.rotation.y = -2.2 + PI * 0.5
			var walls: Array[Transform3D] = [
				Transform3D(Basis.from_scale(Vector3(11.0, 7.0, 6.5)), Vector3(0, 3.5, 0)),
				Transform3D(Basis.from_scale(Vector3(3.6, 13.0, 3.6)), Vector3(6.2, 6.5, 2.0)),
				Transform3D(Basis.from_scale(Vector3(1.2, 4.0, 0.6)), Vector3(-5.0, 8.0, -0.6)),
			]
			_batch(chapel, MeshKit.box(), walls, [Color("4e5068"), Color("5a5c74"), Color("44465c")], "ChapelWalls")
			_batch(chapel, MeshKit.cone(), [Transform3D(Basis.from_euler(Vector3(0.12, 0, 0.2)).scaled(Vector3(4.6, 4.0, 4.6)), Vector3(6.2, 14.6, 2.0))], [Color("3a3c50")], "TowerRoof")
			_batch(chapel, MeshKit.prism(), [Transform3D(Basis.from_scale(Vector3(11.4, 3.5, 6.9)), Vector3(0, 8.6, 0))], [Color("3c3e54")], "ChapelRoof")
			var windows: Array[Transform3D] = []
			for i in 3:
				windows.append(Transform3D(Basis.from_scale(Vector3(1.0, 2.6, 0.3)), Vector3(-3.2 + i * 3.0, 3.8, 3.3)))
			_batch(chapel, MeshKit.box(), windows, [Color("9fb0ff"), Color("8aa0f0"), Color("a8b8ff")], "Windows", true)
			var tombs: Array[Transform3D] = []
			var tomb_colors: Array[Color] = []
			var tomb_count: int = [18, 28, 40][clampi(GameSettings.quality, 0, 2)]
			for i in tomb_count:
				var a := 2.2 + rng.randf_range(-1.1, 1.1)
				var base: Vector3 = ring.call(a, rng.randf_range(7.0, 24.0))
				tombs.append(Transform3D(Basis.from_euler(Vector3(0, -a + rng.randf_range(-0.3, 0.3), rng.randf_range(-0.1, 0.1))).scaled(Vector3.ONE * rng.randf_range(1.0, 1.7)), base))
				tomb_colors.append(Color("7c7e94").lerp(Color("55586c"), rng.randf()))
			_batch(root, Scenery._prop("tomb"), tombs, tomb_colors, "GraveField")
		&"swamp":
			var stems: Array[Transform3D] = []
			var caps: Array[Transform3D] = []
			var cap_colors: Array[Color] = []
			var cones: Array[Transform3D] = []
			for i in 4:
				var a := 0.8 + i * 1.5 + rng.randf() * 0.4
				var h := rng.randf_range(12.0, 18.0)
				var base: Vector3 = ring.call(a, rng.randf_range(14.0, 26.0))
				stems.append(Transform3D(Basis.from_scale(Vector3(h * 0.22, h, h * 0.22)), base + Vector3(0, h * 0.5, 0)))
				caps.append(Transform3D(Basis.from_scale(Vector3(h * 1.1, h * 0.5, h * 1.1)), base + Vector3(0, h, 0)))
				cap_colors.append([Color("6a5a78"), Color("8a4a5a"), Color("5a6a4a"), Color("7a6a3a")][i])
				cones.append(Transform3D(Basis(Vector3.UP, a).scaled(Vector3(10.0, 11.0 + i * 1.5, 10.0)), ring.call(a + 0.5, 20.0 + i, 5.0 + i * 0.7)))
			_batch(root, MeshKit.cylinder(), stems, [Color("d8ccb0"), Color("c8bca0")], "MushroomStems")
			_batch(root, MeshKit.hemisphere(), caps, cap_colors, "MushroomCaps")
			_batch(root, MeshKit.cone(), cones, [Color("3f6a44"), Color("4a7a4c"), Color("36603e")], "MossCones")
		&"desert":
			_batch(root, _pyramid(), [Transform3D(Basis(Vector3.UP, 0.6).scaled(Vector3(38.0, 24.0, 38.0)), ring.call(2.4, 30.0, 11.0))], [Color("c8a878")], "Pyramid")
			var obelisks: Array[Transform3D] = []
			var tips: Array[Transform3D] = []
			for i in 3:
				var a := 4.0 + i * 0.55
				var h := 14.0 + i * 2.0
				var base: Vector3 = ring.call(a, 16.0 + i * 4.0)
				obelisks.append(Transform3D(Basis(Vector3.UP, a).scaled(Vector3(1.8, h, 1.8)), base + Vector3(0, h * 0.5, 0)))
				tips.append(Transform3D(Basis(Vector3.UP, a + PI * 0.25).scaled(Vector3(2.4, 2.2, 2.4)), base + Vector3(0, h + 1.0, 0)))
			_batch(root, MeshKit.box(), obelisks, [Color("d8c0a0"), Color("c8b090"), Color("e0c8a8")], "Obelisks")
			_batch(root, _pyramid(), tips, [Color("e8c060")], "ObeliskTips", true)
		&"sky":
			var tops: Array[Transform3D] = []
			var roots: Array[Transform3D] = []
			var pillars: Array[Transform3D] = []
			for i in 4:
				var a := 0.7 + i * 1.55 + rng.randf() * 0.3
				var y := rng.randf_range(7.0, 16.0)
				var w := rng.randf_range(14.0, 22.0)
				var base: Vector3 = ring.call(a, rng.randf_range(14.0, 28.0), y)
				tops.append(Transform3D(Basis(Vector3.UP, a).scaled(Vector3(w, w * 0.28, w * 0.85)), base))
				roots.append(Transform3D(Basis(Vector3.UP, a).scaled(Vector3(w * 0.8, w * 0.7, w * 0.7)), base - Vector3(0, w * 0.36, 0)))
				for j in 2:
					pillars.append(Transform3D(Basis.from_scale(Vector3(1.4, 6.0, 1.4)), base + Vector3(cos(a + j * 2.0) * w * 0.25, 3.0 + w * 0.1, sin(a + j * 2.0) * w * 0.25)))
			_batch(root, MeshKit.sphere_low(), tops, [Color("a8c090"), Color("b4c898")], "IslandTops")
			var holder := root.get_node("IslandTops") as Node3D
			var drift := holder.create_tween().set_loops()
			drift.tween_property(holder, "position:y", 1.2, 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			drift.tween_property(holder, "position:y", -0.8, 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_batch(root, MeshKit.cone(), roots.map(func(t: Transform3D): return Transform3D(t.basis.rotated(Vector3.RIGHT, PI), t.origin)), [Color("b8a890"), Color("c4b49c")], "IslandRoots")
			_batch(root, MeshKit.cylinder(), pillars, [p[1], Color("f4ecd8")], "IslandPillars")
			for n in ["IslandRoots", "IslandPillars"]:
				var part := root.get_node(n) as Node3D
				var t := part.create_tween().set_loops()
				t.tween_property(part, "position:y", 1.2, 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				t.tween_property(part, "position:y", -0.8, 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		&"void":
			var shards: Array[Transform3D] = []
			var shard_colors: Array[Color] = []
			for i in 6:
				var a := i * TAU / 6.0 + rng.randf() * 0.5
				var h := rng.randf_range(10.0, 18.0)
				shards.append(Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), a, rng.randf_range(-0.3, 0.3))).scaled(Vector3(h * 0.3, h, h * 0.3)), ring.call(a, rng.randf_range(14.0, 28.0), rng.randf_range(10.0, 28.0))))
				shard_colors.append(Color("8a5cff").lerp(Color("d0b8ff"), rng.randf()))
			_batch(root, Scenery._prop("shard"), shards, shard_colors, "OrbitingShards", true)
			var orbit := root.get_node("OrbitingShards") as Node3D
			var spin := orbit.create_tween().set_loops()
			spin.tween_property(orbit, "rotation:y", TAU, 240.0).from(0.0)
		&"digital":
			var trunks: Array[Transform3D] = []
			var crowns: Array[Transform3D] = []
			var crown_colors: Array[Color] = []
			for i in 5:
				var a := 0.4 + i * 1.25 + rng.randf() * 0.3
				var h := rng.randf_range(18.0, 26.0)
				var base: Vector3 = ring.call(a, rng.randf_range(12.0, 26.0))
				trunks.append(Transform3D(Basis.from_scale(Vector3(h * 0.14, h, h * 0.14)), base + Vector3(0, h * 0.5, 0)))
				for j in 3:
					var off := Vector3(cos(j * 2.1) * h * 0.22, h + (j - 1) * h * 0.12, sin(j * 2.1) * h * 0.22)
					crowns.append(Transform3D(Basis.from_scale(Vector3(h * 0.6, h * 0.42, h * 0.6)), base + off))
					crown_colors.append(Color("5a3f7c").lerp(Color("7a58a8"), rng.randf()))
			_batch(root, MeshKit.cylinder(), trunks, [Color("3a2a4a"), Color("2e2240")], "GiantTrunks")
			_batch(root, MeshKit.sphere_low(), crowns, crown_colors, "GiantCrowns")
		&"storm":
			var stones: Array[Transform3D] = []
			var tips: Array[Transform3D] = []
			for i in 5:
				var a := 0.3 + i * 1.3 + rng.randf() * 0.4
				var h := rng.randf_range(12.0, 20.0)
				var base: Vector3 = ring.call(a, rng.randf_range(12.0, 26.0))
				var tilt := Vector3(rng.randf_range(-0.15, 0.15), a, rng.randf_range(-0.2, 0.2))
				stones.append(Transform3D(Basis.from_euler(tilt).scaled(Vector3(h * 0.2, h, h * 0.16)), base + Vector3(0, h * 0.45, 0)))
				tips.append(Transform3D(Basis.from_euler(tilt).scaled(Vector3(1.6, 3.0, 1.6)), base + Vector3(0, h * 0.95, 0)))
			_batch(root, MeshKit.box(), stones, [Color("5a6878"), Color("4a5666"), Color("66768a")], "Monoliths")
			_batch(root, MeshKit.cone(), tips, [Color("f4e27a"), Color("fff2a0")], "ChargedTips", true)
		&"abyss":
			var horns: Array[Transform3D] = []
			var horn_colors: Array[Color] = []
			for i in 6:
				var a := 0.2 + i * 1.05 + rng.randf() * 0.3
				var h := rng.randf_range(14.0, 24.0)
				var base: Vector3 = ring.call(a, rng.randf_range(12.0, 26.0))
				horns.append(Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.25, 0.25), a, rng.randf_range(-0.35, 0.35))).scaled(Vector3(h * 0.18, h, h * 0.18)), base + Vector3(0, h * 0.45, 0)))
				horn_colors.append(Color("5a2030").lerp(Color("7a3040"), rng.randf()))
			_batch(root, MeshKit.cone(), horns, horn_colors, "Horns")
			var eyes: Array[Transform3D] = []
			for i in 4:
				eyes.append(Transform3D(Basis.from_scale(Vector3(2.2, 1.0, 2.2)), ring.call(0.2 + i * 1.6, 20.0, 12.0 + i * 2.0)))
			_batch(root, MeshKit.sphere_low(), eyes, [Color("ff4a4a"), Color("ff7060")], "Embers", true)
		_:
			# Meadow: three old oaks and a windmill on the hill.
			var trunks: Array[Transform3D] = []
			var crowns: Array[Transform3D] = []
			for i in 3:
				var a := 0.9 + i * 1.9 + rng.randf() * 0.3
				var h := rng.randf_range(12.0, 16.0)
				var base: Vector3 = ring.call(a, rng.randf_range(12.0, 24.0))
				trunks.append(Transform3D(Basis.from_scale(Vector3(h * 0.16, h, h * 0.16)), base + Vector3(0, h * 0.5, 0)))
				crowns.append(Transform3D(Basis.from_scale(Vector3(h * 0.85, h * 0.6, h * 0.85)), base + Vector3(0, h * 0.95, 0)))
			_batch(root, MeshKit.cylinder(), trunks, [Color("6a4a34")], "OakTrunks")
			_batch(root, MeshKit.sphere_low(), crowns, [Color("4f7a3c"), Color("5f8a44"), Color("457238")], "OakCrowns")
			var mill := MeshKit.pivot(root, "Windmill", ring.call(4.2, 24.0))
			mill.rotation.y = -4.2 + PI
			_batch(mill, MeshKit.cone(), [Transform3D(Basis.from_scale(Vector3(7.0, 15.0, 7.0)), Vector3(0, 7.5, 0))], [Color("e4dccb")], "MillTower")
			_batch(mill, MeshKit.cone(), [Transform3D(Basis.from_scale(Vector3(5.0, 3.0, 5.0)), Vector3(0, 16.4, 0))], [Color("8a5a40")], "MillCap")
			var hub := MeshKit.pivot(mill, "Blades", Vector3(0, 14.5, 3.0))
			var blades: Array[Transform3D] = []
			for i in 4:
				blades.append(Transform3D(Basis(Vector3.BACK, i * PI * 0.5).scaled(Vector3(1.6, 8.5, 0.2)), Basis(Vector3.BACK, i * PI * 0.5) * Vector3(0, 4.4, 0)))
			_batch(hub, MeshKit.box(), blades, [Color("f0e6d2"), Color("d8ccb4")], "MillBlades")
			var turn := hub.create_tween().set_loops()
			turn.tween_property(hub, "rotation:z", -TAU, 18.0).from(0.0)


static func _pyramid() -> Mesh:
	if _pyramid_mesh == null:
		var m := CylinderMesh.new()
		m.top_radius = 0.0
		m.bottom_radius = 0.7
		m.height = 1.0
		m.radial_segments = 4
		m.rings = 1
		_pyramid_mesh = m
	return _pyramid_mesh


static func build(parent: Node3D, theme: StringName, radius: float, seed_value: int,
		clearings: Array[Vector3] = [], with_stream := false) -> void:
	var root := MeshKit.pivot(parent, "RegionalHabitat")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 11873
	var palette: Array = WorldArt.PALETTES.get(theme, WorldArt.PALETTES[&"meadow"])
	# Two authored coves create an asymmetric composition. Neither intersects
	# the east/west portals, the boss clearing, or any camp footprint. In the
	# meadow, swamp and snow the north cove reaches a few metres into the field.
	var inside := theme in [&"meadow", &"swamp", &"snow"]
	for side in [-1.0, 1.0]:
		var near: bool = inside and side < 0.0
		var center := Vector3(-12.0 if side < 0.0 else -26.0, 0, side * (radius + (5.5 if near else 11.0)))
		if not _clear(center, 10.0, clearings):
			continue
		var cove := MeshKit.pivot(root, "Shoreline" if WATERS.has(theme) else "DryWash", center)
		cove.rotation.y = side * 0.35
		var dry := theme in [&"desert", &"graveyard"]
		var edge_color: Color = palette[1].lerp(palette[0], 0.35)
		var size := Vector2(18.0, 10.0) if near else Vector2(15.0, 8.0)
		_oval(cove, Vector3(0, 0.018, 0), size, edge_color, 0.32)
		if not dry:
			var surface := MeshKit.part(cove, _oval_mesh(size - Vector2(1.2, 1.2), 0.32), _water_material(theme), Vector3(0, 0.045, 0), Vector3.ONE)
			surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			_oval(cove, Vector3(0, 0.033, 0), Vector2(13.5, 6.4), palette[0].darkened(0.06), 0.32)
		_rock_cluster(cove, Vector3(-8.0, 0.0, 3.3), palette, rng, 7 if GameSettings.quality > 0 else 4, 1.1)
		_rock_cluster(cove, Vector3(10.0, 0.0, -2.6), palette, rng, 5 if GameSettings.quality > 0 else 3, 0.8)
		match theme:
			&"meadow", &"digital", &"swamp":
				_reeds(cove, Vector3(-7.0, 0.0, -4.1), 1.0, palette[0])
				_reeds(cove, Vector3(5.8, 0.0, 4.4), 0.75, palette[0])
				_lilies(cove, theme, rng)
				_log(cove, Vector3(10.3, 0.2, 4.0), 4.8, 0.7, Color("796b5b"), -25.0)
			&"desert":
				for i in 3:
					_strata(cove, Vector3(-8.0 + i * 7.0, 0, -5.0), Vector3(2.8, 1.2 + i * 0.4, 2.2), palette)
			&"snow":
				for i in 4:
					_rock(cove, Vector3(-9.0 + i * 5.0, 0.4, -4.4 + i % 2), Vector3(3.6, 0.45, 2.5), palette[1], i * 17.0)
			&"volcano", &"abyss", &"void":
				for i in 4:
					_strata(cove, Vector3(-8.0 + i * 5.2, 0, -5.7), Vector3(2.8, 1.8 + i % 3, 2.5), palette)
			&"graveyard":
				for i in 3:
					_gravestone(cove, Vector3(-6.0 + i * 5.0, 0, -4.4), 0.7 + i * 0.12, palette)
			&"storm":
				_log(cove, Vector3(-4.0, 0.2, -5.0), 6.0, 0.5, palette[0].darkened(0.2), 20.0)
			&"sky":
				for i in 3:
					_fluted_column(cove, Vector3(-7.0 + i * 7.0, 0, -6.0), 1.1 + i * 0.5, palette)
	if with_stream and WATERS.has(theme):
		_stream(root, theme, 1.6 if theme != &"volcano" else 1.2)
	root.set_meta("art_theme", theme)
	root.set_meta("visual_only", true)


## A shallow brook (or lava rill) along STREAM: a flat ribbon 2 cm above the
## floor, UV.y 1 at both banks for the shader's foam, no collider.
static func _stream(parent: Node3D, theme: StringName, width: float) -> void:
	var points: Array[Vector2] = []
	points.assign(STREAM)
	var samples: Array[Vector2] = []
	for i in points.size() - 1:
		var p0 := points[maxi(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(i + 2, points.size() - 1)]
		for k in 6:
			var t := float(k) / 6.0
			samples.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	samples.append(points[points.size() - 1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := samples.size()
	for i in n:
		var tangent := (samples[mini(i + 1, n - 1)] - samples[maxi(i - 1, 0)]).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var along := float(i) / float(n - 1)
		var meander := 1.0 + sin(along * 23.0) * 0.18
		var half := width * 0.5 * meander * (1.0 - smoothstep(0.86, 1.0, along)) * smoothstep(0.0, 0.05, along + 0.02)
		for side in [-1.0, 1.0]:
			var q: Vector2 = samples[i] + normal * half * side
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(along * 20.0, 1.0))
			st.add_vertex(Vector3(q.x, 0.02, q.y))
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(along * 20.0, 0.0))
		st.add_vertex(Vector3(samples[i].x, 0.02, samples[i].y))
	for i in n - 1:
		var a := i * 3
		var b := a + 3
		# Each step: left bank (a), right bank (a + 1), centre (a + 2); clockwise from above.
		for tri in [[a, b, a + 2], [a + 2, b, b + 2], [a + 2, b + 2, a + 1], [a + 1, b + 2, b + 1]]:
			for k in tri:
				st.add_index(k)
	var ribbon := MeshInstance3D.new()
	ribbon.name = "Stream"
	ribbon.mesh = st.commit()
	ribbon.material_override = _water_material(theme)
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ribbon)


static func boss_landmark(parent: Node3D, theme: StringName, boss_spot: Vector3) -> void:
	var outward := Vector3(boss_spot.x, 0, boss_spot.z).normalized()
	var root := MeshKit.pivot(parent, "BossLandmark", boss_spot + outward * 14.8)
	root.rotation.y = atan2(outward.x, outward.z)
	var p: Array = WorldArt.PALETTES.get(theme, WorldArt.PALETTES[&"meadow"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(theme) + 831
	# Each boss has a different silhouette and material story, not a palette
	# swap of the same arch. All focal objects stand behind the fight.
	match theme:
		&"meadow":
			_log(root, Vector3(0, 0.8, 1.0), 10.5, 2.2, Color("806954"), -8.0)
			for i in 3:
				var f := MeshKit.pivot(root, "ShelfMushroom", Vector3(-3.8 + i * 3.8, 0.8, 0.5))
				WorldArt._mushroom(f, Vector3.ZERO, 0.8 + (0.55 if i == 1 else 0.0), p[2] if i != 0 else p[1])
			_reeds(root, Vector3(-5.4, 0, -1.0), 0.6, Color("829469"))
		&"digital":
			for side in [-1.0, 1.0]:
				_branch(root, Vector3(side * 4.0, 0, 0), Vector3(side * 3.0, 5.8, 0.3), 1.3, Color("6e6779"))
				_branch(root, Vector3(side * 3.0, 5.8, 0.3), Vector3(side * 0.7, 8.0, 0.1), 0.8, Color("80738b"))
				_branch(root, Vector3(side * 3.1, 4.8, 0.3), Vector3(side * 5.7, 6.4, 1.1), 0.55, Color("80738b"))
				for i in 3:
					_rock(root, Vector3(side * (2.0 + i), 6.5 + i * 0.35, 0.6), Vector3(3.4, 1.7, 2.8), p[0].lightened(0.05 + i * 0.04), i * 25.0)
				_branch(root, Vector3(side * 4.0, 0.2, 0), Vector3(side * 6.1, 0.18, -1.8), 0.55, Color("6e6779"))
			_rock(root, Vector3(0, 0.3, 0.7), Vector3(3.4, 0.9, 2.2), p[1])
		&"desert":
			for side in [-1.0, 1.0]:
				_strata(root, Vector3(side * 4.1, 0, 0), Vector3(3.0, 5.6 if side < 0 else 4.8, 2.7), p)
			_arch(root, Vector3(0, 4.0, 0), 4.1, 2.2, 1.4, p[1], 0.0, PI, 12)
			_rock(root, Vector3(-1.2, 0.4, 1.3), Vector3(3.9, 0.8, 2.8), p[0])
		&"snow":
			for i in 6:
				var h := 3.7 + sin(float(i) * 1.8) * 1.3 + (2.5 if i == 3 else 0.0)
				_rock(root, Vector3(-5.2 + i * 2.1, h * 0.48, 0.6), Vector3(2.9, h, 2.4), p[2].lerp(p[0], 0.25), i * 13.0)
				_rock(root, Vector3(-5.2 + i * 2.1, h * 0.89, 0.6), Vector3(3.05, h * 0.25, 2.55), p[1], i * 13.0)
		&"volcano":
			for i in 7:
				var h := 3.4 + 4.2 * sin(float(i + 1) / 8.0 * PI)
				_basalt(root, Vector3(-5.1 + i * 1.7, 0, 1.4 - absf(i - 3) * 0.35), h, 1.7, p[0].lightened(i % 3 * 0.04))
				_basalt(root, Vector3(-5.1 + i * 1.7, 0, -0.8), h * 0.32, 1.4, p[1])
			_oval(root, Vector3(0, 0.045, -1.4), Vector2(5.0, 1.2), p[2].darkened(0.12), 0.15)
		&"graveyard":
			for side in [-1.0, 1.0]:
				_fluted_column(root, Vector3(side * 4.1, 0, 0), 3.8, p)
				_gravestone(root, Vector3(side * 6.0, 0, 1.8), 1.1, p)
			_arch(root, Vector3(0, 3.6, 0), 4.1, 2.2, 0.9, p[1], 0.0, PI, 14)
			_arch(root, Vector3(0, 5.8, 0.1), 1.0, 1.0, 0.18, p[2], 0.0, TAU, 20)
			_branch(root, Vector3(-5.6, 0, -0.2), Vector3(-4.7, 5.2, 0.6), 0.2, p[0].darkened(0.25))
		&"swamp":
			for side in [-1.0, 1.0]:
				_arch(root, Vector3(side * 1.8, 0.2, 0), 3.3, 3.8, 0.65, Color("706856"), 0.04, PI - 0.04, 12)
				_reeds(root, Vector3(side * 5.0, 0, -1.0), 1.4, p[0])
			WorldArt._mushroom(root, Vector3(-3.4, 0, 1.6), 0.8, p[2])
			WorldArt._mushroom(root, Vector3(3.8, 0, 2.1), 1.0, p[1])
		&"storm":
			for i in 5:
				var h: float = [3.0, 5.4, 8.2, 6.8, 3.7][i]
				_rock(root, Vector3(-4.9 + i * 2.4, float(h) * 0.48, 0.7), Vector3(2.8, float(h), 2.7), p[0].lightened(i % 2 * 0.12), -16.0 + i * 5.0)
			_log(root, Vector3(-4.0, 0.5, -1.4), 5.1, 0.55, p[1].darkened(0.25), 30.0)
		&"sky":
			for i in 4:
				_fluted_column(root, Vector3(-5.4 + i * 3.6, 0, 0), 6.0 if i < 3 else 3.8, p)
			_rock(root, Vector3(-1.8, 6.5, 0), Vector3(9.8, 0.7, 1.8), p[1])
			_arch(root, Vector3(-1.8, 7.4, 0), 1.0, 1.0, 0.17, p[2], 0.0, TAU, 20)
			for i in 3:
				_rock(root, Vector3(4.4 + i * 0.7, 0.25 + i * 0.12, -1.4), Vector3(2.8, 0.4, 1.1), p[1], i * 23.0)
		&"abyss":
			for i in 4:
				_arch(root, Vector3(0, 0.1, i * 1.8), 5.2 - i * 0.6, 6.6 - i * 0.65, 0.65, p[1].darkened(i * 0.09), 0.04, PI - 0.04, 14)
				_rock(root, Vector3(-5.4 + i * 3.5, 0.4, -0.8), Vector3(2.6, 1.0, 2.2), p[0])
		&"void":
			for i in 9:
				var a := TAU * i / 9.0
				_rock(root, Vector3(cos(a) * 4.4, 0.35, sin(a) * 2.8), Vector3(3.1, 1.1 + i % 3 * 0.45, 1.8), p[0], -rad_to_deg(a))
			_rock(root, Vector3(0.4, 2.4, 0.6), Vector3(4.4, 5.5, 3.7), p[1], 18.0)
			_arch(root, Vector3(0.0, 2.8, -1.3), 2.8, 2.8, 0.14, p[2], -0.25, PI * 1.25, 28)
	_rock_cluster(root, Vector3(-5.0, 0, 2.2), p, rng, 4, 0.85)
	_rock_cluster(root, Vector3(5.0, 0, 2.6), p, rng, 3, 0.65)
	root.set_meta("art_theme", theme)
	root.set_meta("visual_only", true)


## Optional hook for non-biome combat maps. Keep every ruin beyond the wall.
static func challenge_perimeter(parent: Node3D, kind: StringName, radius: float, seed_value := 53) -> void:
	var root := MeshKit.pivot(parent, "ChallengeLandmarks")
	var theme: StringName = &"void" if kind == &"tower" else &"sky"
	root.set_meta("art_theme", theme)
	root.set_meta("art_stage", kind)
	root.set_meta("visual_only", true)
	var p: Array = WorldArt.PALETTES[theme]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 4:
		var angle := PI * 0.25 + i * PI * 0.5
		var pos := Vector3(cos(angle), 0, sin(angle)) * (radius + 8.0)
		var cluster := MeshKit.pivot(root, "PerimeterRuins", pos)
		cluster.rotation.y = -angle
		if kind == &"tower":
			for j in 3:
				_basalt(cluster, Vector3((j - 1) * 2.4, 0, 0), 5.0 + j * 1.5, 2.0, p[j % 2])
			_arch(cluster, Vector3(0, 3.5, 0), 2.7, 2.7, 0.16, p[2], -0.2, PI + 0.2, 18)
		else:
			for j in 2:
				_fluted_column(cluster, Vector3((j - 0.5) * 5.0, 0, 0), 4.2 + j * 1.2, p)
			_rock_cluster(cluster, Vector3(0, 0, 1.8), p, rng, 5, 0.7)


static func _clear(pos: Vector3, radius: float, clearings: Array[Vector3]) -> bool:
	for area in clearings:
		if Vector2(pos.x, pos.z).distance_to(Vector2(area.x, area.y)) < radius + area.z:
			return false
	return true


static func _colored_material() -> StandardMaterial3D:
	if _vertex_mat == null:
		_vertex_mat = StandardMaterial3D.new()
		_vertex_mat.vertex_color_use_as_albedo = true
		_vertex_mat.vertex_color_is_srgb = true
		_vertex_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
		_vertex_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_vertex_mat.roughness = 1.0
	return _vertex_mat


static func _water_material(theme: StringName) -> ShaderMaterial:
	if not _water_mats.has(theme):
		var colors: Array = WATERS.get(theme, WATERS[&"meadow"])
		var mat := ShaderMaterial.new()
		mat.shader = WATER_SHADER
		mat.set_shader_parameter("deep_color", colors[0])
		mat.set_shader_parameter("shallow_color", colors[1])
		mat.set_shader_parameter("flow_speed", 0.0 if theme == &"snow" else 0.28)
		mat.set_shader_parameter("glow", 0.16 if theme in [&"volcano", &"abyss", &"void"] else 0.0)
		_water_mats[theme] = mat
	return _water_mats[theme]


static func _oval_mesh(size: Vector2, irregularity: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 64
	for i in count:
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.5, 0.0))
		st.add_vertex(Vector3.ZERO)
		for j in [i, i + 1]:
			var a := TAU * float(j) / count
			var edge := 1.0 + (sin(a * 3.0 + 0.4) * 0.18 + sin(a * 7.0) * 0.12) * irregularity
			st.set_uv(Vector2(float(j) / count, 1.0))
			st.add_vertex(Vector3(cos(a) * size.x * edge, 0, sin(a) * size.y * edge))
	return st.commit()


static func _oval(parent: Node3D, pos: Vector3, size: Vector2, color: Color, irregularity := 0.25) -> void:
	var mesh := MeshKit.part(parent, _oval_mesh(size, irregularity), WorldArt._mat(color), pos, Vector3.ONE)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _stone() -> ArrayMesh:
	if _stone_mesh != null:
		return _stone_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var slices := 7
	var rings := [Vector2(-0.5, 0.37), Vector2(-0.23, 0.53), Vector2(0.21, 0.47), Vector2(0.5, 0.28)]
	for ring in rings.size() - 1:
		for i in slices:
			for c in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var level: Vector2 = rings[ring + c.x]
				var a := TAU * float(i + c.y) / slices
				var offset := sin(a * 3.0 + ring * 1.1) * 0.045
				st.add_vertex(Vector3(cos(a) * (level.y + offset), level.x, sin(a) * (level.y + offset)))
	for i in slices:
		st.add_vertex(Vector3(0, 0.5, 0))
		for j in [i, i + 1]:
			var a := TAU * float(j) / slices
			st.add_vertex(Vector3(cos(a) * (0.28 + sin(a * 3.0 + 3.3) * 0.045), 0.5, sin(a) * (0.28 + sin(a * 3.0 + 3.3) * 0.045)))
	st.generate_normals()
	_stone_mesh = st.commit()
	return _stone_mesh


static func _rock(parent: Node3D, pos: Vector3, size: Vector3, color: Color, yaw := 0.0) -> void:
	var mi := MeshKit.part(parent, _stone(), WorldArt._mat(color), pos, size, Vector3(0, yaw, 0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _rock_cluster(parent: Node3D, pos: Vector3, palette: Array, rng: RandomNumberGenerator, count: int, size: float) -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in count:
		var scale := Vector3(rng.randf_range(0.8, 2.4), rng.randf_range(0.3, 1.2), rng.randf_range(0.7, 1.5)) * size
		var p := pos + Vector3(rng.randf_range(-2.5, 2.5), scale.y * 0.39, rng.randf_range(-1.5, 1.5))
		transforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(scale), p))
		colors.append(palette[i % 2])
	_batch(parent, _stone(), transforms, colors, "RiverStones")


## One MultiMesh for a set of placements; `colors` may be shorter than
## `transforms` (it repeats). `glow` makes the tint emissive (lava, crystals).
static func _batch(parent: Node3D, mesh: Mesh, transforms: Array, colors: Array, node_name: String, glow := false) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i % colors.size()])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = mm
	instance.material_override = Scenery.glow_material() if glow else _colored_material()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


static func _reeds(parent: Node3D, pos: Vector3, size: float, color: Color) -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in (12 if GameSettings.quality > 0 else 7):
		var a := float(i) * 2.4
		var h := (0.7 + (i % 4) * 0.23) * size
		var offset := Vector3(cos(a) * 0.9, h * 0.5, sin(a) * 0.6) * size
		var basis := Basis.from_euler(Vector3(sin(a) * 0.18, a, cos(a) * 0.16)).scaled(Vector3(0.09 * size, h, 0.12 * size))
		transforms.append(Transform3D(basis, pos + offset))
		colors.append(color.lightened(0.08 * (i % 3)))
	_batch(parent, MeshKit.cone(), transforms, colors, "Reeds")


static func _lilies(parent: Node3D, theme: StringName, rng: RandomNumberGenerator) -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in (6 if GameSettings.quality > 0 else 3):
		var size := rng.randf_range(0.55, 1.1)
		transforms.append(Transform3D(Basis().scaled(Vector3(size, 0.025, size * 0.8)), Vector3(-4.0 + i * 1.2, 0.065, 1.5 + sin(i * 2.0) * 1.4)))
		colors.append(Color("859a77") if theme != &"digital" else Color("83a394"))
	_batch(parent, MeshKit.cylinder(), transforms, colors, "LilyPads")


static func _branch(parent: Node3D, from: Vector3, to: Vector3, width: float, color: Color) -> void:
	var d := to - from
	var mi := MeshKit.part(parent, MeshKit.cylinder(), WorldArt._mat(color), (from + to) * 0.5, Vector3(width, d.length(), width))
	mi.quaternion = Quaternion(Vector3.UP, d.normalized())


static func _log(parent: Node3D, pos: Vector3, length: float, width: float, color: Color, yaw: float) -> void:
	var root := MeshKit.pivot(parent, "FallenTimber", pos, Vector3(0, yaw, 0))
	MeshKit.part(root, MeshKit.cylinder(), WorldArt._mat(color), Vector3.ZERO, Vector3(width, length, width), Vector3(0, 0, 90))
	for side in [-1.0, 1.0]:
		MeshKit.part(root, MeshKit.cylinder(), WorldArt._mat(color.lightened(0.24)), Vector3(side * length * 0.5, 0, 0), Vector3(width * 0.74, 0.02, width * 0.74), Vector3(0, 0, 90))


static func _strata(parent: Node3D, pos: Vector3, size: Vector3, palette: Array) -> void:
	for i in 4:
		var width := 1.0 - i * 0.085
		_rock(parent, pos + Vector3(0.1 * sin(i * 2.0), size.y * (i + 0.5) / 4.0, 0), Vector3(size.x * width, size.y * 0.28, size.z * width), palette[i % 2], i * 8.0)


static func _arch(parent: Node3D, center: Vector3, width: float, height: float, thickness: float, color: Color,
		start: float, end: float, count: int) -> void:
	# One tube mesh, with continuous joined edges, replaces a beaded arch.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 6
	for i in count:
		for j in sides:
			for c in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var a := lerpf(start, end, float(i + c.x) / count)
				var b := TAU * float(j + c.y) / sides
				var normal := Vector3(cos(a), sin(a), 0)
				var v := Vector3(cos(a) * width, sin(a) * height, 0)
				v += normal * cos(b) * thickness * 0.5 + Vector3.BACK * sin(b) * thickness * 0.5
				st.add_vertex(v)
	st.generate_normals()
	var mi := MeshKit.part(parent, st.commit(), WorldArt._mat(color), center, Vector3.ONE)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _basalt(parent: Node3D, pos: Vector3, height: float, width: float, color: Color) -> void:
	_rock(parent, pos + Vector3(0, height * 0.49, 0), Vector3(width, height, width), color)
	_rock(parent, pos + Vector3(0, height * 0.75, 0), Vector3(width * 1.03, 0.08, width * 1.03), color.lightened(0.1))


static func _fluted_column(parent: Node3D, pos: Vector3, height: float, palette: Array) -> void:
	MeshKit.part(parent, MeshKit.cylinder(), WorldArt._mat(palette[0]), pos + Vector3(0, height * 0.5, 0), Vector3(1.2, height, 1.2))
	for y in [0.18, height - 0.18]:
		MeshKit.part(parent, MeshKit.box(), WorldArt._mat(palette[1]), pos + Vector3(0, y, 0), Vector3(1.8, 0.36, 1.8))
	if GameSettings.quality > 0:
		for i in 6:
			var a := TAU * i / 6.0
			MeshKit.part(parent, MeshKit.cylinder(), WorldArt._mat(palette[1]), pos + Vector3(cos(a) * 0.56, height * 0.5, sin(a) * 0.56), Vector3(0.07, maxf(height - 0.7, 0.2), 0.07))


static func _gravestone(parent: Node3D, pos: Vector3, size: float, palette: Array) -> void:
	var root := MeshKit.pivot(parent, "WeatheredMemorial", pos, Vector3(0, 8.0, -7.0))
	root.scale = Vector3.ONE * size
	MeshKit.part(root, MeshKit.box(), WorldArt._mat(palette[0]), Vector3(0, 1.0, 0), Vector3(1.3, 2.0, 0.5))
	MeshKit.part(root, MeshKit.cylinder(), WorldArt._mat(palette[1]), Vector3(0, 2.0, 0), Vector3(1.3, 0.5, 1.3), Vector3(90, 0, 0))
	MeshKit.part(root, MeshKit.box(), WorldArt._mat(palette[1]), Vector3(0, 1.35, -0.28), Vector3(0.08, 0.8, 0.035))
	MeshKit.part(root, MeshKit.box(), WorldArt._mat(palette[1]), Vector3(0, 1.5, -0.28), Vector3(0.5, 0.08, 0.035))
