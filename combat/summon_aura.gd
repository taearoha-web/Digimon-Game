class_name SummonAura
extends RefCounted
## What makes a summoned spirit special: a soft halo of light behind it, a ring of
## sparkles circling the body and a second layer that suits the creature (leaves for
## the forest ones, embers for the fire demon, frost for wolves ...). All of it is
## shader work (shaders/summon_aura.gdshader): one mesh and one draw call per layer,
## nothing simulated on the CPU, which is what a phone's web build needs.

const SHADER := preload("res://shaders/summon_aura.gdshader")
const MODES := {"orbit": 0, "rise": 1, "spiral": 2, "fall": 3}

## kind -> the creature layer: [mode, texture, colour tint (or null for the kind colour), cards, size, speed]
const THEME := {
	"falcon": ["rise", "spark", Color("ffe9a0"), 10, 0.30, 1.1],
	"wolf": ["spiral", "snow", Color("d8f0ff"), 12, 0.30, 0.9],
	"spirit_wolf": ["spiral", "snow", Color("d8f0ff"), 16, 0.45, 0.8],
	"beast": ["rise", "leaf", Color("b8ff9a"), 12, 0.34, 1.0],
	"cactus": ["rise", "leaf", Color("b8ff9a"), 12, 0.34, 1.0],
	"treant": ["fall", "leaf", Color("c8ff8a"), 14, 0.36, 1.0],
	"guardian": ["rise", "leaf", Color("e8d6a0"), 12, 0.34, 1.0],
	"frog": ["rise", "snow", Color("c8ffd8"), 12, 0.26, 1.0],
	"cat": ["rise", "heart", Color("ffd0e0"), 10, 0.30, 0.9],
	"elemental": ["rise", "spark", Color("9ad8ff"), 12, 0.28, 1.2],
	"fire_elemental": ["rise", "spark", Color("ffb060"), 18, 0.40, 1.4],
	"sword": ["spiral", "spark", Color("ffffff"), 10, 0.22, 1.6],
	"muspell": ["fall", "snow", Color("e8fbff"), 16, 0.30, 0.8],
	"drake": ["spiral", "spark", Color("9affe0"), 14, 0.30, 1.4],
	"elder_dragon": ["spiral", "star", Color("ffe27a"), 18, 0.36, 1.3],
	"wind_king": ["spiral", "leaf", Color("d8ffe6"), 22, 0.42, 1.5],
	"poseidon": ["rise", "snow", Color("c8f2ff"), 24, 0.40, 1.1],
	"fairy": ["orbit", "heart", Color("ff9ed6"), 10, 0.20, 1.2],
}


## Builds the aura as children of [param summon] (local units; the summon's own scale
## grows it with the creature's stars). [param rank] is the skill's star count.
static func attach(summon: Node3D, kind_id: String, kind: Dictionary, rank: int) -> void:
	var color: Color = kind.color
	var height := float(kind.get("height", 1.6))
	var hover := float(kind.get("hover", 0.0))
	if bool(kind.get("proc", false)):
		# The floating swords: the aura is centred on the blade, not on a body standing on the ground.
		height = 2.4
		hover = maxf(hover - 1.2, 0.0)
	var body_r := clampf(height * 0.42, 0.55, 1.6)
	var root := Node3D.new()
	root.name = "SummonAura"
	summon.add_child(root)
	_halo(root, color, height, hover)
	var stars := clampi(rank, 1, 5)
	_layer(root, 0, "star", color.lerp(Color.WHITE, 0.45), 8 + 2 * stars, 0.26 + 0.02 * stars, 1.0, height, hover, body_r * 1.05)
	var theme: Array = THEME.get(kind_id, ["rise", "spark", color.lerp(Color.WHITE, 0.3), 10, 0.3, 1.0])
	var tint: Color = theme[2] if theme[2] != null else color
	_layer(root, int(MODES[theme[0]]), String(theme[1]), tint, int(theme[3]) + stars, float(theme[4]), float(theme[5]), height, hover, body_r)
	if kind_id == "muspell":
		_crown(root, color, height, hover)
	elif kind_id == "fairy":
		_crown(root, color, height, hover, Color(1.0, 0.75, 0.9))


## A soft pulsing glow of the creature's colour behind its body. Small bodies (the
## tiny fairy) get a glow under a metre instead of the 1.8 m floor that would swallow them.
static func _halo(root: Node3D, color: Color, height: float, hover: float) -> void:
	var mat := VfxKit._glow(Color(color.r, color.g, color.b), 0.7 if height >= 1.2 else 0.5, true)
	mat.albedo_texture = VfxArt.texture("flare")
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = false
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * (clampf(height * 1.15, 0.7, 1.2) if height < 1.2 else clampf(height * 1.7, 1.8, 5.0))
	var halo := MeshInstance3D.new()
	halo.name = "Halo"
	halo.mesh = quad
	halo.material_override = mat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.position = Vector3(0, hover + height * 0.5, -0.1)
	root.add_child(halo)
	var pulse := halo.create_tween().set_loops()
	pulse.tween_property(halo, "scale", Vector3.ONE * 1.12, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(halo, "scale", Vector3.ONE * 0.9, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


static func _layer(root: Node3D, mode: int, texture: String, color: Color, count: int, size: float, speed: float, height: float, hover: float, radius: float) -> void:
	var n := clampi(VfxBudget.count(count, 4), 4, 32)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("color", Color(color.r, color.g, color.b, 0.95))
	mat.set_shader_parameter("tex", VfxArt.texture(texture))
	mat.set_shader_parameter("mode", mode)
	mat.set_shader_parameter("body_height", height)
	mat.set_shader_parameter("body_radius", radius)
	mat.set_shader_parameter("base_height", hover)
	mat.set_shader_parameter("size", size * 1.35)
	mat.set_shader_parameter("speed", speed)
	var mi := MeshInstance3D.new()
	mi.name = "Sparkle%d" % mode
	mi.mesh = ShaderBurst._mesh(n)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var reach := height * 1.6 + radius * 2.0 + 2.0
	mi.custom_aabb = AABB(Vector3(-reach, -1.0, -reach), Vector3(reach * 2.0, reach * 2.0 + height, reach * 2.0))
	root.add_child(mi)


## A turning halo of light above the head: gold for the guardian penguin, pink for the
## fairy ([param glow]), sized to the body so the tiny fairy wears a small ring.
static func _crown(root: Node3D, color: Color, height: float, hover: float, glow := Color(1.0, 0.92, 0.55)) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "Crown"
	var torus := TorusMesh.new()
	var fit := clampf(height / 1.9, 0.55, 1.0)
	torus.inner_radius = 0.34 * fit
	torus.outer_radius = 0.42 * fit
	torus.rings = 16
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = VfxKit._glow(glow, 0.95, true)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(0, hover + height + 0.25 * fit, 0)
	ring.rotation_degrees = Vector3(18, 0, 0)
	root.add_child(ring)
	var bob := ring.create_tween().set_loops()
	bob.tween_property(ring, "position:y", ring.position.y + 0.1, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(ring, "position:y", ring.position.y, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var spin := ring.create_tween().set_loops()
	spin.tween_property(ring, "rotation:y", TAU, 5.0).as_relative()
