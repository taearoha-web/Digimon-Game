class_name CelestialDragon
extends RefCounted
## The eastern dragons of เกาะลอยฟ้าเทพมังกร, drawn the way the Summoner's god skill
## จักรพรรดิมังกรสวรรค์ draws its dragon (combat/god_art/celestial_dragon_emperor.gd): one
## long toon body with a scale pattern, a maned head with antlers, whiskers and glowing
## eyes, a saw of dorsal fins and four clawed legs, laid along a spline by a vertex shader
## (shaders/celestial_dragon.gdshader). Here the spline is a fixed pose per kind (a
## throne coil for the Dragon God, a reared guard, a ground coil, a rising spiral, small
## hovering S-curves), and the shader's few scalars animate it (CelestialDragonVisual):
## the head lunges along its own body, rears, the body ripples, wings beat.
##
## Every kind has its own palette, size, head, horns (antlers, swept horns, a fin crest,
## nubs), mane, beard, wings, crown and moves. One mesh per kind (vertex colours, built
## once, a lighter one at low quality) and one shader for all; each dragon on the field
## has its own small material, because the Compatibility renderer has no per-instance
## uniforms and each one moves on its own. No textures, lights or particles.

const K := preload("res://combat/god_art/_kit_arcane.gd")
const SHADER := preload("res://shaders/celestial_dragon.gdshader")
const MAX_PTS := 72

## Palettes: back (top, dark), belly (top, dark), horn (light, dark), mane (root, tip),
## fin, eye, rim light, shadow tint.
const PALETTES := {
	"god": {"back": Color("fbf4e2"), "back_dk": Color("e9cf96"), "belly": Color("ffd766"), "belly_dk": Color("e9a62c"), "horn": Color("ffcf45"), "horn_dk": Color("c98418"),
		"mane": Color("6ee8bc"), "mane_tip": Color("e8fff6"), "fin": Color("ffc93a"), "eye": Color("8ffff0"), "rim": Color("fff1c2"), "shade": Color(0.66, 0.6, 0.72)},
	# The shrine guardian (shrine_dragon): a temple dragon in lacquer vermilion and gold, as its
	# rig fallback is painted (SkyIsleData "paint"), unlike the jade elder beside it.
	"guardian": {"back": Color("e04a32"), "back_dk": Color("7c1a16"), "belly": Color("fff0c2"), "belly_dk": Color("f2bd48"), "horn": Color("fff0c8"), "horn_dk": Color("d8a03a"),
		"mane": Color("ffc84a"), "mane_tip": Color("fff3c8"), "fin": Color("ffb43a"), "eye": Color("fff2a0"), "rim": Color("ffe2c0"), "shade": Color(0.62, 0.46, 0.5)},
	"elder": {"back": Color("38d884"), "back_dk": Color("0a6040"), "belly": Color("f4eaa8"), "belly_dk": Color("c9b860"), "horn": Color("f6efd6"), "horn_dk": Color("b8a77c"),
		"mane": Color("f4f8ec"), "mane_tip": Color("b9ffd8"), "fin": Color("1f9a64"), "eye": Color("ffe27a"), "rim": Color("e4ffd0"), "shade": Color(0.4, 0.55, 0.62)},
	"prism": {"back": Color("eef9ff"), "back_dk": Color("a8d4ff"), "belly": Color("ffffff"), "belly_dk": Color("d8ecff"), "horn": Color("e8fbff"), "horn_dk": Color("9ee8ff"),
		"mane": Color("ffffff"), "mane_tip": Color("ffc4f0"), "fin": Color("c8f4ff"), "eye": Color("ffffff"), "rim": Color("ffffff"), "shade": Color(0.7, 0.72, 0.86)},
	"whelp": {"back": Color("eef8ff"), "back_dk": Color("86c4f0"), "belly": Color("ffffff"), "belly_dk": Color("d6ecff"), "horn": Color("ffd76a"), "horn_dk": Color("d89a2a"),
		"mane": Color("ffffff"), "mane_tip": Color("bfe6ff"), "fin": Color("7cc4f4"), "eye": Color("5ad0ff"), "rim": Color("ffffff"), "shade": Color(0.6, 0.7, 0.88)},
	"wyrmling": {"back": Color("ffc93a"), "back_dk": Color("e07818"), "belly": Color("fff5d0"), "belly_dk": Color("ffd890"), "horn": Color("ff6248"), "horn_dk": Color("b82a2a"),
		"mane": Color("ff7038"), "mane_tip": Color("ffd28a"), "fin": Color("ff5a3a"), "eye": Color("fff6c0"), "rim": Color("fff4c8"), "shade": Color(0.68, 0.52, 0.56)},
	"wyvern": {"back": Color("6a52e0"), "back_dk": Color("26206a"), "belly": Color("dccdff"), "belly_dk": Color("9c84f0"), "horn": Color("fff27a"), "horn_dk": Color("e0a81a"),
		"mane": Color("fff27a"), "mane_tip": Color("ffffff"), "fin": Color("ffe24a"), "eye": Color("fff6a0"), "rim": Color("cfc0ff"), "shade": Color(0.5, 0.48, 0.78)},
	# พญานาค of the Loy Krathong night (LoyKrathong): emerald scales over a gold belly, a
	# flame-red crest and mane, gold crown and fins, amber eyes alight.
	"naga": {"back": Color("1f9a6a"), "back_dk": Color("0a4a3a"), "belly": Color("ffe08a"), "belly_dk": Color("d89a2a"), "horn": Color("ffcf3a"), "horn_dk": Color("b87818"),
		"mane": Color("ff5a2a"), "mane_tip": Color("ffe08a"), "fin": Color("ffb03a"), "eye": Color("ffe85a"), "rim": Color("bfffe0"), "shade": Color(0.4, 0.52, 0.64)},
	"mount": {"back": Color("12a07c"), "back_dk": Color("08584a"), "belly": Color("fff4cf"), "belly_dk": Color("efc46a"), "horn": Color("ffcf3a"), "horn_dk": Color("c98418"),
		"mane": Color("fffaf0"), "mane_tip": Color("a8ffe0"), "fin": Color("ffc72e"), "eye": Color("fffbd0"), "rim": Color("d6fff0"), "shade": Color(0.44, 0.54, 0.72)},
}

## The kinds. length: the body in mesh metres (the god skill's dragon is 26); thick: the
## body's girth; head: the head's size (the young ones' heads are bigger); horns:
## "antlers", "horns" (swept back), "crest" (a fan of fins), "nubs"; crown: 0 none, 5 an
## elite's, 7 the god's; wings: a bat-wing pair that beats; pose: the spline (_pose);
## move: how it attacks (CelestialDragonVisual); wave: [amp, length, speed]; rise_k: how
## far its rearing moves lift the head (1: all the way); room: head room kept over the
## head in its bounds (mesh metres: the template height then fits the same dragon, the
## head lower in it); horn_lift: how high the antlers sweep (1: all the way); soft:
## rounded horn tips, a softer mane and fins, no saw of teeth (the crystal dragon);
## mane_drop: the mane falls this much down the neck; whisker_len: whisker length
## (the mount's, short and drooping, clear of the rider).
const KINDS := {
	"god": {"palette": "god", "length": 26.0, "thick": 1.6, "head": 1.45, "horns": "antlers", "mane": 13, "beard": true, "whiskers": true, "crown": 7, "pose": "throne", "move": "rear", "wave": [0.22, 9.0, 1.4], "legs": true, "rise_k": 0.4, "room": 0.75, "horn_lift": 0.8},
	"guardian": {"palette": "guardian", "length": 20.0, "thick": 1.4, "head": 1.2, "horns": "crest", "mane": 11, "beard": true, "whiskers": true, "crown": 5, "pose": "guard", "move": "rear", "wave": [0.18, 8.0, 1.6], "legs": true},
	"elder": {"palette": "elder", "length": 22.0, "thick": 1.55, "head": 1.3, "horns": "antlers", "mane": 13, "beard": true, "long_beard": true, "whiskers": true, "crown": 5, "pose": "elder", "move": "lunge", "wave": [0.16, 10.0, 1.2], "legs": true},
	"prism": {"palette": "prism", "length": 24.0, "thick": 1.4, "head": 1.2, "horns": "antlers", "mane": 7, "mane_len": 0.8, "beard": false, "whiskers": false, "crown": 0, "pose": "spiral", "move": "rear", "wave": [0.3, 9.0, 1.8], "legs": true, "prism": 1.0, "soft": true},
	"whelp": {"palette": "whelp", "length": 12.0, "thick": 1.35, "head": 1.5, "horns": "nubs", "mane": 7, "mane_len": 0.55, "beard": false, "whiskers": true, "crown": 0, "pose": "whelp", "move": "lunge", "wave": [0.26, 6.0, 2.4], "legs": true},
	"wyrmling": {"palette": "wyrmling", "length": 11.0, "thick": 1.5, "head": 1.4, "horns": "horns", "mane": 9, "mane_len": 0.6, "beard": true, "whiskers": false, "crown": 0, "pose": "wyrm", "move": "spin", "wave": [0.12, 6.0, 2.0], "legs": true},
	"wyvern": {"palette": "wyvern", "length": 13.0, "thick": 1.25, "head": 1.25, "horns": "horns", "mane": 0, "beard": false, "whiskers": false, "crown": 0, "pose": "wyvern", "move": "swoop", "wave": [0.3, 6.5, 2.2], "legs": false, "wings": true},
	"naga": {"palette": "naga", "length": 24.0, "thick": 1.55, "head": 1.3, "horns": "crest", "mane": 11, "mane_len": 0.85, "beard": false, "whiskers": false, "crown": 7, "pose": "naga", "move": "rear", "wave": [0.2, 8.0, 1.5], "legs": false, "rise_k": 0.6, "room": 0.4},
	"mount": {"palette": "mount", "length": 20.0, "thick": 1.35, "head": 1.2, "horns": "antlers", "mane": 9, "mane_len": 0.75, "mane_drop": 0.7, "beard": true, "whiskers": true, "whisker_len": 0.5, "crown": 0, "pose": "ride", "move": "lunge", "wave": [0.16, 6.5, 1.6], "legs": true},
}

static var _meshes := {}
static var _poses := {}
static var _bases := {}


static func has(kind: String) -> bool:
	return KINDS.has(kind)


## The kind's mesh (shared), with the pose's bounds as its AABB (culling, MonsterVisual._bounds).
static func mesh(kind: String) -> ArrayMesh:
	var lite := VfxBudget.quality() == 0
	var key := "%s|%d" % [kind, int(lite)]
	if not _meshes.has(key):
		var built := _build(KINDS.get(kind, KINDS.whelp), lite)
		built.custom_aabb = pose(kind).box
		_meshes[key] = built
	return _meshes[key]


## A fresh material of the kind (its pose, look and palette rim), for one dragon.
static func material(kind: String) -> ShaderMaterial:
	if not _bases.has(kind):
		var spec: Dictionary = KINDS.get(kind, KINDS.whelp)
		var pal: Dictionary = PALETTES[spec.palette]
		var p := pose(kind)
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("pts", p.pts)
		m.set_shader_parameter("count", p.count)
		m.set_shader_parameter("spacing", p.spacing)
		m.set_shader_parameter("head", p.head)
		var wave: Array = spec.wave
		m.set_shader_parameter("wave_amp", wave[0])
		m.set_shader_parameter("wave_len", wave[1])
		m.set_shader_parameter("wave_speed", wave[2])
		m.set_shader_parameter("rim_color", pal.rim)
		m.set_shader_parameter("rim", 0.5)
		m.set_shader_parameter("shadow_tint", pal.shade)
		m.set_shader_parameter("prism", float(spec.get("prism", 0.0)))
		m.set_shader_parameter("flap", 0.22 if spec.get("wings", false) else 0.0)
		m.set_shader_parameter("flap_rate", 5.0)
		m.set_shader_parameter("breath_color", pal.mane_tip if kind != "god" else Color("ffe9a0"))
		if p.has("calm"):
			m.set_shader_parameter("calm_from", p.calm[0])
			m.set_shader_parameter("calm_to", p.calm[1])
		_bases[kind] = m
	return (_bases[kind] as ShaderMaterial).duplicate() as ShaderMaterial


## A dragon of the kind ready to place: the body MeshInstance3D at mesh scale (scale it
## yourself), its own material.
static func body(kind: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "DragonBody"
	mi.mesh = mesh(kind)
	mi.material_override = material(kind)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2.0
	return mi


# ---------------------------------------------------------------------------
# Poses: control points from the tail end to the nose (+Z is the dragon's front).
# ---------------------------------------------------------------------------
static func _helix(centre: Vector3, r0: float, r1: float, a0: float, a1: float, y0: float, y1: float, n: int) -> Array:
	var out := []
	for i in n + 1:
		var f := float(i) / float(n)
		var a := lerpf(a0, a1, f)
		var r := lerpf(r0, r1, f)
		out.append(Vector3(centre.x + cos(a) * r, lerpf(y0, y1, f), centre.z + sin(a) * r))
	return out


static func _control(name: String) -> Array:
	match name:
		"throne":
			# Coiled one turn round its own cloud, rising, the neck up and over to the front.
			var turn := _helix(Vector3(0, 0, -1.6), 4.4, 3.4, PI * 0.5 - TAU * 1.0, PI * 0.5 - 0.5, 0.7, 2.8, 16)
			# The head carried low and forward over the coil, so the player's camera keeps
			# his crown in view, close up and while he calls down heaven's lightning.
			return turn + [Vector3(1.0, 3.9, 0.9), Vector3(0.5, 5.3, 0.8), Vector3(0.0, 6.15, 1.8), Vector3(0.0, 6.3, 3.3), Vector3(0.0, 5.85, 4.8), Vector3(0.0, 5.2, 6.15)]
		"guard":
			# A loop on the ground, then reared straight up like a temple lion.
			var loop := _helix(Vector3(0, 0, -0.8), 2.4, 2.0, PI * 0.5 - TAU * 0.9, PI * 0.5 - 0.3, 0.6, 1.1, 12)
			return loop + [Vector3(0.3, 2.4, 1.0), Vector3(0.0, 4.0, 0.5), Vector3(0.0, 5.5, 0.6), Vector3(0.0, 6.3, 1.7), Vector3(0.0, 6.2, 3.0), Vector3(0.0, 5.9, 4.0)]
		"elder":
			# A wide coil lying on the ground, the old head low and forward.
			var coil := _helix(Vector3(0, 0, -1.0), 3.4, 2.6, PI * 0.5 - TAU * 1.1, PI * 0.5 - 0.4, 0.75, 1.5, 16)
			return coil + [Vector3(0.6, 2.7, 1.6), Vector3(0.0, 3.9, 1.9), Vector3(0.0, 4.5, 3.0), Vector3(0.0, 4.35, 4.3), Vector3(0.0, 4.0, 5.4)]
		"spiral":
			# Rising through the air in a loose helix, light as glass.
			var spin := _helix(Vector3(0, 0, -0.6), 2.4, 2.8, PI * 0.5 - TAU * 1.25, PI * 0.5 - 0.4, 0.8, 5.6, 18)
			return spin + [Vector3(0.6, 6.7, 1.6), Vector3(0.0, 7.3, 2.6), Vector3(0.0, 7.2, 3.8), Vector3(0.0, 6.9, 4.9)]
		"naga":
			# Risen from the water: a wide coil on the surface, the body standing up like a
			# cobra's, the crowned head held high and forward over the coil.
			var ring := _helix(Vector3(0, 0, -0.6), 3.0, 2.3, PI * 0.5 - TAU * 1.05, PI * 0.5 - 0.35, 0.5, 1.0, 16)
			return ring + [Vector3(0.4, 2.3, 0.9), Vector3(0.0, 3.9, 0.3), Vector3(0.0, 5.4, 0.1), Vector3(0.0, 6.6, 0.8), Vector3(0.0, 7.0, 2.1), Vector3(0.0, 6.6, 3.3)]
		"whelp":
			return [Vector3(-0.9, 2.6, -6.4), Vector3(-1.1, 1.7, -5.5), Vector3(-0.4, 1.0, -4.3), Vector3(0.8, 1.0, -3.0), Vector3(1.0, 1.5, -1.6), Vector3(0.3, 2.1, -0.4),
				Vector3(0.0, 2.7, 0.7), Vector3(0.0, 2.9, 1.9), Vector3(0.0, 2.8, 3.0)]
		"wyrm":
			# Sat on its own tail like a cat, the tail tip curled round its front.
			var curl := _helix(Vector3(0, 0, -0.2), 1.9, 1.6, PI * 0.25, PI * 0.25 + TAU * 0.92, 0.75, 1.0, 12)
			return curl + [Vector3(0.7, 2.0, 0.2), Vector3(0.1, 3.0, 0.3), Vector3(0.0, 3.7, 1.0), Vector3(0.0, 3.8, 2.1), Vector3(0.0, 3.6, 3.1)]
		"wyvern":
			return [Vector3(0.2, 2.6, -8.2), Vector3(0.7, 1.7, -6.9), Vector3(-0.5, 1.3, -5.3), Vector3(-0.7, 1.6, -3.6), Vector3(0.2, 2.0, -2.0), Vector3(0.4, 2.4, -0.5),
				Vector3(0.0, 2.9, 0.9), Vector3(0.0, 3.1, 2.2), Vector3(0.0, 3.0, 3.4)]
		"ride":
			# Level under the saddle, the neck rising in an S in front (the head carried low
			# enough that the rider's face shows over it), the back rolling in waves behind,
			# the tail curled up.
			return [Vector3(0.0, 4.6, -11.2), Vector3(0.0, 3.6, -11.6), Vector3(0.2, 2.4, -10.8), Vector3(-0.2, 1.8, -9.2), Vector3(0.2, 2.6, -7.8), Vector3(0.0, 3.2, -6.2), Vector3(0.0, 2.4, -4.6),
				Vector3(0.0, 2.2, -3.0), Vector3(0.0, 2.2, -1.4), Vector3(0.0, 2.4, 0.2), Vector3(0.0, 3.2, 1.3), Vector3(0.0, 4.4, 1.95), Vector3(0.0, 5.3, 2.7), Vector3(0.0, 5.65, 3.8), Vector3(0.0, 5.4, 5.1)]
	return [Vector3(0, 1, -6), Vector3(0, 1, 0), Vector3(0, 2, 3)]


## The kind's pose: the shader's points ("pts", "count", "spacing", "head"), the box the
## dragon fills (mesh metres, room for its moves), and where its parts are: "nose",
## "crown" (top of the head), "chest", "seat" (the rider's saddle on the mount).
static func pose(kind: String) -> Dictionary:
	if _poses.has(kind):
		return _poses[kind]
	var spec: Dictionary = KINDS.get(kind, KINDS.whelp)
	var length := float(spec.length)
	var line := K.smooth(_control(String(spec.pose)), 8)
	var total := 0.0
	for i in range(1, line.size()):
		total += line[i].distance_to(line[i - 1])
	var spacing := maxf(0.25, total / float(MAX_PTS - 2))
	var points := K.resample(line, spacing)
	if points.size() > MAX_PTS:
		points.resize(MAX_PTS)
	var count := points.size()
	var head := float(count - 1) * spacing
	var pts := PackedVector3Array()
	pts.resize(MAX_PTS)
	for i in MAX_PTS:
		pts[i] = points[mini(i, count - 1)]
	var at := func(dist: float) -> Vector3:
		var p := clampf(dist / spacing, 0.0, float(count - 1))
		var i := mini(int(floor(p)), count - 2)
		return points[i].lerp(points[i + 1], p - float(i))
	# The bounds: the occupied stretch of the path, grown by the girth, the horns and the moves.
	var thick := float(spec.thick) * 0.7
	var box := AABB(at.call(head), Vector3.ZERO)
	var s := 0.0
	while s <= length:
		box = box.expand(at.call(head - s))
		s += 0.5
	var hs := float(spec.head)
	box = box.grow(thick + 0.3)
	var nose: Vector3 = at.call(head)
	var skull: Vector3 = at.call(head - 1.2 * hs)
	var crown := skull + Vector3(0, 0.75 * hs, 0)
	box = box.expand(skull + Vector3(0, 2.0 * hs + float(spec.get("room", 0.0)), 0))
	box = box.expand(nose + Vector3(0, 0, 1.0))
	if spec.get("wings", false):
		var shoulder: Vector3 = at.call(head - length * 0.24)
		box = box.expand(shoulder + Vector3(3.6, 1.8, 0)).expand(shoulder + Vector3(-3.6, 1.8, 0))
	var out := {"pts": pts, "count": count, "spacing": spacing, "head": head, "box": box, "nose": nose, "crown": crown,
		"skull": skull, "chest": at.call(head - minf(4.5, length * 0.3)), "length": length}
	if String(spec.pose) == "ride":
		# The saddle sits on the level back just behind the neck (z = -2.8 in the pose).
		var seat_s := 0.0
		var best := 1e9
		var d := 0.0
		while d < length:
			var q: Vector3 = at.call(head - d)
			if absf(q.z + 2.8) < best:
				best = absf(q.z + 2.8)
				seat_s = d
			d += 0.1
		var seat: Vector3 = at.call(head - seat_s)
		out["seat"] = seat + Vector3(0, 0.64 * float(spec.thick) * 0.92, 0)
		out["seat_s"] = seat_s
		out["calm"] = [seat_s - 1.4, seat_s + 1.6]
	_poses[kind] = out
	return out


# ---------------------------------------------------------------------------
# The mesh: the god skill's dragon (dragon_mesh) with a kind's palette and parts.
# ---------------------------------------------------------------------------
static func _girth(s: float, length: float) -> float:
	var f := clampf((s - 1.6) / (length - 1.6), 0.0, 1.0)
	return lerpf(0.5, 0.64, smoothstep(0.0, 0.18, f)) * (1.0 - 0.84 * smoothstep(0.5, 1.0, f))


static func _build(spec: Dictionary, lite: bool) -> ArrayMesh:
	var p: Dictionary = PALETTES[spec.palette]
	var back: Color = p.back
	var back_dk: Color = p.back_dk
	var belly: Color = p.belly
	var belly_dk: Color = p.belly_dk
	var horn: Color = p.horn
	var horn_dk: Color = p.horn_dk
	var mane: Color = p.mane
	var mane_tip: Color = p.mane_tip
	var fin: Color = p.fin
	var ivory := Color("fbfff2")
	var length := float(spec.length)
	var thick := float(spec.thick)
	var hs := float(spec.head)
	var soft := bool(spec.get("soft", false))
	var sides := 7 if lite else 10
	var b := K.Builder.new()
	# Body: the back over a pale belly, flagged for the scale pattern.
	b.weight = 1.0
	var path := []
	var radii := []
	var cols := []
	var s := 1.6 * hs * 0.85
	while s <= length + 0.01:
		var f := (s - 1.6) / (length - 1.6)
		path.append(Vector3(0, 0, s))
		radii.append(_girth(s, length) * thick)
		cols.append([back.lerp(back_dk, 0.5 * f), belly.lerp(belly_dk, 0.5 * f)])
		s += 0.5 if not lite else 0.7
	b.tube(path, radii, sides, cols)
	# Head: a long snout swelling into the skull, an open lower jaw.
	b.weight = 0.6
	b.xf = Transform3D(Basis.IDENTITY.scaled(Vector3(1.32, 1.32, 1.18) * hs), Vector3.ZERO)
	var top := back.lerp(Color.WHITE, 0.25)
	b.tube([Vector3(0, 0.05, 0), Vector3(0, 0.09, 0.3), Vector3(0, 0.13, 0.75), Vector3(0, 0.2, 1.15), Vector3(0, 0.14, 1.55), Vector3(0, 0.0, 1.9)],
		[Vector2(0.2, 0.13), Vector2(0.31, 0.2), Vector2(0.4, 0.28), Vector2(0.58, 0.42), Vector2(0.58, 0.48), Vector2(0.5, 0.5)], sides,
		[[top, belly], [top, belly], [back, belly], [back, belly], [back, belly], [back, belly]])
	b.weight = 0.0
	b.tube([Vector3(0, -0.36, 0.18), Vector3(0, -0.42, 0.55), Vector3(0, -0.4, 1.0), Vector3(0, -0.24, 1.45)],
		[Vector2(0.15, 0.06), Vector2(0.25, 0.09), Vector2(0.34, 0.12), Vector2(0.42, 0.16)], 8, [[belly, belly_dk]])
	# The mouth glows while it breathes (UV2.x = 2).
	b.emit = 2.0
	b.quad(Vector3(-0.28, -0.3, 0.3), Vector3(0.28, -0.3, 0.3), Vector3(0.36, -0.14, 1.35), Vector3(-0.36, -0.14, 1.35), Color("d8304a"), Color("7a1028"))
	b.emit = 0.0
	b.ball(Vector3(0, 0.15, 0.06), Vector3(0.19, 0.12, 0.14), top, back, 6, 4)
	for side in [-1.0, 1.0]:
		b.cone(Vector3(side * 0.16, -0.02, 0.2), Vector3(side * 0.17, -0.32, 0.26), 0.06, 5, ivory)
		if not lite and not soft:
			for k in 3:
				b.cone(Vector3(side * (0.24 + 0.04 * k), -0.06, 0.5 + 0.25 * k), Vector3(side * (0.25 + 0.04 * k), -0.24, 0.52 + 0.25 * k), 0.045, 4, ivory)
		# Brow ridge, then the lit eye under it.
		b.tube([Vector3(side * 0.2, 0.4, 0.62), Vector3(side * 0.44, 0.56, 0.9), Vector3(side * 0.6, 0.6, 1.3)], [0.07, 0.1, 0.05], 5, [back_dk])
		b.emit = 1.0
		b.ball(Vector3(side * 0.44, 0.4, 0.95), Vector3(0.12, 0.11, 0.15), Color("fffdf0"), p.eye, 6, 4)
		b.emit = 0.0
		b.ball(Vector3(side * 0.53, 0.4, 0.9), Vector3(0.04, 0.09, 0.07), Color("2a0a14"), Color("2a0a14"), 5, 3)
		var head_xf := b.xf
		var lift := float(spec.get("horn_lift", 1.0))
		b.xf = head_xf * Transform3D(Basis.IDENTITY.scaled(Vector3(1, lift, 1)), Vector3(0, 0.5 * (1.0 - lift), 0))
		_horns(b, String(spec.horns), side, horn, horn_dk, lite, soft)
		b.xf = head_xf
		if spec.get("whiskers", false):
			b.emit = 0.45
			var whisker := []
			var thin := []
			var wl := float(spec.get("whisker_len", 1.0))
			for k in 9:
				var u := float(k) / 8.0
				if wl < 1.0:
					# Short whiskers curling out and down from the snout, clear of a rider.
					whisker.append(Vector3(side * (0.24 + 0.55 * sin(u * 2.0)), -0.15 - 1.5 * u * u * wl + 0.15 * sin(u * 5.0) * u, 0.22 + u * 4.6 * wl))
				else:
					whisker.append(Vector3(side * (0.24 + 0.75 * sin(u * 2.4) + 0.2 * u), 0.45 * sin(u * 4.4) * u - 0.1 * u, 0.22 + u * 4.6))
				thin.append(lerpf(0.06, 0.014, u))
			b.tube(whisker, thin, 4, [horn])
			b.emit = 0.0
		# Cheek fins.
		var fin_k := lerpf(0.55, 1.0, float(spec.get("mane_len", 1.0))) * (0.7 if soft else 1.0)
		if soft:
			# Rounded fan fins instead of points: a few short petals.
			for k in 3:
				var a := lerpf(-0.5, 0.6, float(k) / 2.0)
				var tip := Vector3(side * (0.5 + 0.55 * cos(a)), 0.1 + 0.45 * sin(a), 1.6 + 0.35 * cos(a))
				b.tube([Vector3(side * 0.5, 0.1, 1.3), (Vector3(side * 0.5, 0.1, 1.3) + tip) * 0.5 + Vector3(0, 0.06, 0), tip], [Vector2(0.09, 0.05), Vector2(0.13, 0.06), Vector2(0.06, 0.04)], 5, [back.lerp(Color.WHITE, 0.3), mane_tip])
			continue
		b.tri3(Vector3(side * 0.5, 0.2, 1.25), Vector3(side * 0.56, -0.25, 1.35), Vector3(side * (0.5 + 0.75 * fin_k), 0.25, 1.25 + 1.05 * fin_k), back.lerp(Color.WHITE, 0.3), back, mane_tip)
		b.tri3(Vector3(side * 0.5, 0.2, 1.25), Vector3(side * 0.52, 0.5, 1.4), Vector3(side * (0.5 + 0.6 * fin_k), 0.2 + 0.55 * fin_k, 1.3 + 1.1 * fin_k), back.lerp(Color.WHITE, 0.3), back, mane_tip)
	# Mane: swept-back flames round the skull; a beard under the chin.
	b.emit = 0.3
	var manes := int(spec.get("mane", 0))
	if lite: manes = mini(manes, 7)
	for k in manes:
		var a := lerpf(-0.5, PI + 0.5, float(k) / float(maxi(manes - 1, 1)))
		var out := Vector3(cos(a), sin(a), 0)
		var long := (1.5 + 0.5 * float(k % 3)) * float(spec.get("mane_len", 1.0))
		var spread := lerpf(0.6, 1.05, float(spec.get("mane_len", 1.0)))
		var drop := float(spec.get("mane_drop", 0.0))
		var root := Vector3(out.x * 0.44, out.y * 0.4 + 0.08, 1.5)
		var tip := Vector3(out.x * spread * (1.0 - 0.35 * drop), out.y * spread * (1.0 - drop) + 0.1 - drop * 0.9, 1.6 + long)
		if soft:
			# Soft locks: a rounded taper, bowed, never a point.
			b.tube([root, root.lerp(tip, 0.5) + Vector3(0, 0.15, 0), tip], [0.2, 0.17, 0.07], 5, [mane, mane.lerp(mane_tip, 0.5), mane_tip])
		else:
			b.cone(root, tip, Vector2(0.17, 0.17), 5, mane, mane_tip)
	if spec.get("beard", false):
		var drop := 1.6 if spec.get("long_beard", false) else 1.05
		for k in 3:
			b.cone(Vector3(0.14 * (k - 1), -0.45, 1.0), Vector3(0.3 * (k - 1), -drop, 1.9 + 0.2 * (k % 2) + (0.6 if drop > 1.2 else 0.0)), 0.11, 5, mane, mane_tip)
	b.emit = 0.0
	var crown := int(spec.get("crown", 0))
	if crown > 0:
		_crown(b, crown, horn, horn_dk, p.mane)
	b.xf = Transform3D.IDENTITY
	# Dorsal fins: a saw down the back.
	s = 2.0 * hs
	while s < length - 1.2:
		var f := s / length
		var base := _girth(s, length) * thick * 0.86
		var high := (0.62 * (1.0 - 0.6 * f) + 0.1) * thick * ((smoothstep(2.0 * hs, 6.0 * hs, s) * 0.3 + 0.3) if soft else 1.0)
		b.tri3(Vector3(0, base, s - 0.08), Vector3(0, base, s + 0.56), Vector3(0, base + high, s + 0.62), fin, fin, fin.lerp(Color.WHITE, 0.6))
		s += 0.56 if not lite else 0.9
	# Tail tuft.
	b.emit = 0.25
	for k in 5:
		var a := lerpf(-0.9, 0.9, float(k) / 4.0)
		var tk := clampf(length / 22.0, 0.45, 1.0)
		b.tri3(Vector3(0, -0.12, length - 0.7), Vector3(0, 0.12, length - 0.7), Vector3(0, sin(a) * 1.5 * tk, length - 0.7 + (0.7 + cos(a) * 2.0) * tk), fin, fin, mane_tip)
		b.tri3(Vector3(-0.12, 0, length - 0.7), Vector3(0.12, 0, length - 0.7), Vector3(sin(a) * 1.1 * tk, 0, length - 0.7 + (0.7 + cos(a) * 1.7) * tk), fin, fin, mane_tip)
	b.emit = 0.0
	if spec.get("legs", false):
		for at in [length * 0.2, length * 0.54]:
			var size := (1.0 if at < length * 0.4 else 0.85) * thick
			for side in [-1.0, 1.0]:
				var foot := Vector3(side * 1.12 * size, -1.05 * size, at - 0.85)
				b.tube([Vector3(side * 0.36, -0.15, at), Vector3(side * 0.98 * size, -0.5 * size, at - 0.2), foot], [0.3 * size, 0.22 * size, 0.15 * size], 6, [[back, back_dk]])
				for k in 3:
					b.cone(foot, foot + Vector3(side * 0.26 * (k - 1) + side * 0.1, -0.32, -0.62) * size, 0.09 * size, 5, ivory)
	if spec.get("wings", false):
		_wings(b, length * 0.24, back_dk, back, horn, lite)
	return b.mesh()


static func _horns(b: K.Builder, style: String, side: float, horn: Color, horn_dk: Color, lite: bool, soft := false) -> void:
	match style:
		"antlers":
			if soft:
				# Short smooth antlers with rounded tips (the crystal dragon).
				b.tube([Vector3(side * 0.3, 0.5, 1.3), Vector3(side * 0.47, 0.85, 1.62), Vector3(side * 0.56, 1.05, 1.98)], [0.16, 0.13, 0.1], 6, [[horn, horn_dk]])
				b.ball(Vector3(side * 0.56, 1.05, 1.98), Vector3.ONE * 0.11, horn, horn_dk, 6, 3)
				b.tube([Vector3(side * 0.47, 0.85, 1.62), Vector3(side * 0.68, 1.0, 1.7), Vector3(side * 0.76, 1.12, 1.84)], [0.09, 0.08, 0.07], 5, [[horn, horn_dk]])
				b.ball(Vector3(side * 0.76, 1.12, 1.84), Vector3.ONE * 0.08, horn, horn_dk, 5, 3)
				return
			b.tube([Vector3(side * 0.3, 0.5, 1.3), Vector3(side * 0.52, 1.1, 1.9), Vector3(side * 0.66, 1.5, 2.7), Vector3(side * 0.6, 1.62, 3.3)], [0.13, 0.1, 0.06, 0.0], 6, [[horn, horn_dk]])
			b.tube([Vector3(side * 0.52, 1.1, 1.9), Vector3(side * 0.86, 1.5, 2.1), Vector3(side * 1.0, 1.9, 2.5)], [0.08, 0.06, 0.0], 5, [[horn, horn_dk]])
			if not lite:
				b.tube([Vector3(side * 0.6, 1.36, 2.4), Vector3(side * 0.9, 1.75, 2.9)], [0.06, 0.0], 5, [[horn, horn_dk]])
		"horns":
			# Two long horns swept straight back, a short pair under them.
			b.tube([Vector3(side * 0.3, 0.5, 1.25), Vector3(side * 0.5, 0.9, 1.9), Vector3(side * 0.62, 1.05, 2.8), Vector3(side * 0.58, 1.3, 3.6)], [0.15, 0.11, 0.06, 0.0], 6, [[horn, horn_dk]])
			b.tube([Vector3(side * 0.42, 0.25, 1.45), Vector3(side * 0.7, 0.3, 2.0), Vector3(side * 0.86, 0.5, 2.5)], [0.08, 0.05, 0.0], 5, [[horn, horn_dk]])
		"crest":
			# A fan of fins standing up from the brow, like a temple guardian's helm.
			if side > 0.0:
				for k in 5:
					var a := lerpf(-0.75, 0.75, float(k) / 4.0)
					var tip := Vector3(sin(a) * 0.9, 1.4 + 0.3 * cos(a * 2.0), 2.1 + 0.25 * absf(a))
					b.tri3(Vector3(sin(a) * 0.2 - 0.1, 0.48, 1.1), Vector3(sin(a) * 0.2 + 0.1, 0.48, 1.55), tip, horn_dk, horn, horn.lerp(Color.WHITE, 0.5))
			b.tube([Vector3(side * 0.34, 0.45, 1.35), Vector3(side * 0.62, 0.8, 1.9), Vector3(side * 0.7, 1.0, 2.5)], [0.11, 0.07, 0.0], 5, [[horn, horn_dk]])
		_:
			# Nubs: a young dragon's first horns.
			b.cone(Vector3(side * 0.3, 0.5, 1.35), Vector3(side * 0.48, 0.95, 1.85), 0.13, 6, horn_dk, horn)


## A crown of gold points round the brow with a jewel at the front.
static func _crown(b: K.Builder, points: int, gold: Color, gold_dk: Color, jewel: Color) -> void:
	var centre := Vector3(0, 0.62, 1.32)
	for i in points:
		var a := lerpf(-1.25, 1.25, float(i) / float(points - 1))
		var mid := 1.0 - absf(a) / 1.25
		var at := centre + Vector3(sin(a) * 0.42, 0.0, -cos(a) * 0.28 + 0.1)
		b.cone(at, at + Vector3(sin(a) * 0.16, 0.36 + 0.34 * mid, -0.1), 0.085, 4, gold_dk, gold)
	b.tube([centre + Vector3(-0.46, -0.04, 0.12), centre + Vector3(0, 0.0, -0.22), centre + Vector3(0.46, -0.04, 0.12)], [0.06], 5, [gold], Vector3.UP, false)
	b.emit = 1.0
	b.ball(centre + Vector3(0, 0.12, -0.24), Vector3(0.11, 0.11, 0.08), Color.WHITE, jewel, 6, 4)
	b.emit = 0.0


## A wyvern's bat wings at [param at] along the body (COLOR.a 0: the shader beats them,
## round the shoulder, the tips trailing). Each is a bat's hand: a bright arm (shoulder,
## elbow, wrist) with a thumb claw, three long finger bones fanning back from the wrist,
## and between them a darker membrane (UV2.y = -1: the shader lights it as thin skin)
## that billows down a little between the bones and is cut into scallops between the
## finger tips, paling to its trailing edge.
static func _wings(b: K.Builder, at: float, arm: Color, skin: Color, claw: Color, lite := false) -> void:
	b.phase = 0.0
	var membrane := arm.lerp(skin, 0.2)
	var thin := skin.lerp(arm, 0.15)
	var bone := skin.lerp(Color.WHITE, 0.7)
	var rows := 2 if lite else 3
	var cols := 2 if lite else 3
	for side in [-1.0, 1.0]:
		var sh := Vector3(side * 0.45, 0.35, at)
		var elbow := Vector3(side * 1.45, 1.05, at + 0.75)
		var wrist := Vector3(side * 2.55, 1.7, at - 0.05)
		var tips := [Vector3(side * 4.4, 2.0, at + 0.95), Vector3(side * 3.95, 0.9, at + 2.45), Vector3(side * 2.7, 0.25, at + 3.2)]
		var tail := Vector3(side * 0.5, 0.1, at + 2.55)
		# The membrane: a panel between each pair of fingers, and the inner one from the
		# arm to the last finger and back to the flank.
		b.weight = -1.0
		for k in 2:
			_membrane(b, func(u: float, v: float) -> Vector3:
				var a0: Vector3 = wrist.lerp(tips[k], u)
				var a1: Vector3 = wrist.lerp(tips[k + 1], u)
				return a0.lerp(a1, v), wrist, tips[k].lerp(tips[k + 1], 0.5), rows, cols, membrane, thin, side)
		_membrane(b, func(u: float, v: float) -> Vector3:
			# v runs from the shoulder out along the arm to the wrist; u from the arm to the trailing edge.
			var arm_pt: Vector3 = sh.lerp(elbow, v * 2.0) if v < 0.5 else elbow.lerp(wrist, v * 2.0 - 1.0)
			var edge_pt: Vector3 = tail.lerp(tips[2], v)
			return arm_pt.lerp(edge_pt, u), sh.lerp(wrist, 0.5), tail.lerp(tips[2], 0.5), rows, cols, membrane, thin, side)
		# The leading edge between shoulder and wrist, in front of the elbow.
		b.tri3(sh, wrist, elbow, membrane, membrane, membrane)
		b.weight = 0.0
		# Bones: the arm, the thumb claw, the fingers (bright against the skin).
		b.tube([sh, elbow, wrist], [0.14, 0.11, 0.09], 5, [[bone, bone.lerp(skin, 0.4)]])
		b.ball(elbow, Vector3.ONE * 0.12, bone, skin, 5, 3)
		b.ball(wrist, Vector3.ONE * 0.13, bone, skin, 5, 3)
		for tip in tips:
			var mid: Vector3 = wrist.lerp(tip, 0.5) + Vector3(0, 0.12, 0)
			b.tube([wrist, mid, tip], [0.075, 0.05, 0.02], 4, [[bone, bone.lerp(skin, 0.4)]])
		b.emit = 0.6
		b.cone(wrist + Vector3(0, 0.06, -0.05), wrist + Vector3(side * 0.12, 0.42, -0.3), 0.06, 4, claw)
		b.emit = 0.0
	b.phase = -1.0


## One panel of wing membrane: [param at](u, v) the flat point (u: from the root bone
## outward, v: across); the trailing edge (u = 1) is cut into a scallop toward
## [param hub], and the skin billows down between the bones.
static func _membrane(b: K.Builder, at: Callable, hub: Vector3, edge_mid: Vector3, rows: int, cols: int, col: Color, edge_col: Color, side: float) -> void:
	var into := (hub - edge_mid) * 0.3
	var base := b.v.size()
	for i in rows + 1:
		var u := float(i) / float(rows)
		for j in cols + 1:
			var v := float(j) / float(cols)
			var bow := sin(PI * v)
			var p: Vector3 = at.call(u, v) + into * bow * u * u - Vector3(0, 0.22, 0) * bow * sin(PI * minf(u * 1.2, 1.0))
			b.pt(p, Vector3(side * 0.15, 1.0, 0).normalized(), col.lerp(edge_col, u * u), Vector2(u, v))
	for i in rows:
		for j in cols:
			var a := base + i * (cols + 1) + j
			var d := a + cols + 1
			b.tri(a, a + 1, d + 1); b.tri(a, d + 1, d)
