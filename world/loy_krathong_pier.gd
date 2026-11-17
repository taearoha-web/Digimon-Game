class_name LoyKrathongPier
extends Node3D
## The village during the Loy Krathong festival (LoyKrathong): the koi pond of the homes
## district (JapanVillage.POND) becomes ท่าน้ำลอยกระทง.
##   - a wooden pier on the pond's east bank with lanterns, the interaction point
##     "ลอยกระทง" at its foot (role "loyk_pier");
##   - strings of coloured lights on posts round the pond and the pageant stage (เวที
##     ประกวดนางนพมาศ) on its south bank with its host (role "loyk_stage");
##   - a big full moon low over the pond, shown with the night (DayNight.now.night);
##   - krathongs drifting across the pond from the pier: the hero's own (LoyKrathong.listen)
##     and the world players' (LoyKrathong.ai_floats, read off the clock, the same on
##     every device), each with its wish floating above it;
##   - on the night of Loy Krathong, sky lanterns (โคมลอย) rising over the town.
## Everything is code-built: one merged mesh for the static pieces, a cached mesh per
## krathong tier (krathong_mesh), additive soft-dot billboards for the glows (no lights,
## no particles), the sky lanterns one MultiMesh moved from here (VfxBudget.count).

const POND := JapanVillage.POND
## Pond-local spots: the pier runs along x at PIER_Z from the bank (PIER_LAND) over the
## water (PIER_TIP), authored on the +x side and built on the west bank (SIDE mirrors x:
## the east bank has the lane's sakura); krathongs set off from LAUNCH and drift east.
const SIDE := -1.0
const PIER_Z := -0.5
const PIER_LAND := 11.2
const PIER_TIP := 4.6
const LAUNCH := Vector3(-4.2, 0.1, -0.5)
const STAGE := Vector3(0, 0, 12.6)
## The water the krathongs float on (the pond's surface height).
const WATER_Y := 0.1
## How many krathongs drift at most (the oldest go first).
const MAX_FLOATS := 9
## Sky lanterns on the night: how many (VfxBudget.count), their rise (m/s) and top.
const SKY_LANTERNS := 26
const LANTERN_RISE := 0.7
const LANTERN_TOP := 70.0
const MOON_SIZE := 52.0
const MOON_AT := Vector3(160, 40, 18)

static var current: LoyKrathongPier = null
static var _meshes := {}
static var _glow_mat: StandardMaterial3D
static var _moon_mat: ShaderMaterial

var zone: Node3D
var _floats: Array = []
var _seen := {}
var _sync := 0.0
var _moon: MeshInstance3D
var _halos: MultiMeshInstance3D
var _halo_mat: StandardMaterial3D
var _lanterns: MultiMeshInstance3D
var _lantern_seeds: Array = []
var _night := -1.0
var _sink: Callable


## Adds the festival's pond to the village zone (only while LoyKrathong.decor_on).
static func build(p_zone: Node3D, npcs: Array) -> LoyKrathongPier:
	var node := LoyKrathongPier.new()
	node.name = "LoyKrathongPier"
	node.zone = p_zone
	node.position = POND
	p_zone.add_child(node)
	node._build_static(npcs)
	return node


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null
	if _sink.is_valid():
		LoyKrathong.unlisten(_sink)


## Whether `who` stands at the pier now (within reach of its foot).
static func at_pier(who: Node3D) -> bool:
	if current == null or not is_instance_valid(current) or who == null or not is_instance_valid(who):
		return false
	var foot := current.to_global(_m(Vector3(PIER_LAND - 1.2, 0, PIER_Z)))
	return Vector2(who.global_position.x - foot.x, who.global_position.z - foot.z).length() < 7.0


## Whether the village's hero stands at the pier now (the menu's float buttons).
static func hero_at_pier() -> bool:
	if current == null or not is_instance_valid(current) or current.zone == null:
		return false
	var hero: Variant = current.zone.get("hero")
	return hero is Node3D and at_pier(hero)


# --- Building -------------------------------------------------------------------------------

func _build_static(npcs: Array) -> void:
	var b := JapanKit.Batch.new()
	var bulbs: Array = []
	_pier(b, bulbs)
	_light_strings(b, bulbs)
	_stage(b, bulbs)
	b.commit(self, "LoyKrathongDecor")
	_bulb_halos(bulbs)
	_build_moon()
	_build_lanterns()
	# The stage's floor and the pier's posts stop the hero walking through them.
	JapanKit.collider(self, STAGE + Vector3(0, 0.35, 0.4), Vector3(6.4, 0.7, 3.4))
	var sign := Label3D.new()
	sign.text = "ท่าน้ำลอยกระทง"
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.pixel_size = 0.0075
	sign.font_size = 56
	sign.outline_size = 14
	sign.modulate = Color("ffe08a")
	sign.position = _m(Vector3(PIER_LAND + 0.4, 3.3, PIER_Z + 1.5))
	sign.visibility_range_end = 45.0
	add_child(sign)
	var title := Label3D.new()
	title.text = "ประกวดนางนพมาศ & หนุ่มลอยกระทง ๒๕๖๙"
	title.pixel_size = 0.0062
	title.font_size = 52
	title.outline_size = 14
	title.modulate = Color("ffe08a")
	title.position = STAGE + Vector3(0, 4.25, 1.45)
	title.rotation.y = PI
	title.visibility_range_end = 45.0
	add_child(title)
	var point := PierPoint.new()
	point.position = _m(Vector3(PIER_LAND - 1.0, 0, PIER_Z))
	add_child(point)
	point.setup("loyk_pier", "ลอยกระทง", &"mage", "ทำกระทง · ขอพร · ลอยวันละ %d ใบ" % LoyKrathong.DAILY_FLOATS)
	npcs.append(point)
	var host := Npc.new()
	host.position = STAGE + Vector3(-2.2, 0.0, -2.4)
	add_child(host)
	host.setup("loyk_stage", "พิธีกรเวทีนพมาศ", &"bard", "ประกวดนางนพมาศ / หนุ่มลอยกระทง", "Mage",
		{"gender": 1, "skin": 1, "hair": 5, "hair_color": 0, "eyes": 0, "eye_color": 1, "nose": 0, "mouth": 2,
		"npc_outfit": ["Mage", Color(1.6, 0.55, 0.75), ""], "npc_hat": ["ribbon", Color("ffcf3a")]})
	host.face(host.global_position + Vector3(0, 0, -5))
	npcs.append(host)
	_sink = func(entry: Dictionary): _launch(entry)
	LoyKrathong.listen(_sink)


## The pier: plank deck over the water on posts, rails with lanterns, a bamboo arch with
## a banner at the foot, krathongs and marigolds laid out at the bank.
func _pier(b: JapanKit.Batch, bulbs: Array) -> void:
	b.xform = Transform3D(Basis.from_scale(Vector3(SIDE, 1, 1)), Vector3.ZERO)
	var wood := Color("9a6a40")
	var plank := Color("c89a62")
	var length := PIER_LAND - PIER_TIP
	var mid := (PIER_LAND + PIER_TIP) * 0.5
	var k := 0
	var x := PIER_TIP
	while x < PIER_LAND:
		b.box(Vector3(x + 0.15, 0.2, PIER_Z), Vector3(0.28, 0.08, 2.2), plank if k % 2 == 0 else plank.darkened(0.08))
		x += 0.31
		k += 1
	for side in [-1.0, 1.0]:
		b.box(Vector3(mid, 0.12, PIER_Z + side * 1.05), Vector3(length, 0.1, 0.12), wood)
		for px in [PIER_TIP + 0.15, PIER_TIP + length * 0.5, PIER_LAND - 0.3]:
			b.cyl(Vector3(px, -0.2, PIER_Z + side * 1.15), 0.1, 1.0, wood.darkened(0.2), Vector3.ZERO, 6)
		# Rails: posts and a top bar, a little lantern on every other post.
		for i in 5:
			var rx := lerpf(PIER_TIP + 0.2, PIER_LAND - 0.4, float(i) / 4.0)
			b.cyl(Vector3(rx, 0.6, PIER_Z + side * 1.05), 0.05, 0.8, wood, Vector3.ZERO, 6)
			if i % 2 == 0:
				var col: Color = [Color("ff8a3a"), Color("ffcf3a"), Color("ff5a7a")][i / 2 % 3]
				b.ball(Vector3(rx, 1.12, PIER_Z + side * 1.05), Vector3(0.24, 0.3, 0.24), col.lightened(0.2), true)
				b.cyl(Vector3(rx, 1.3, PIER_Z + side * 1.05), 0.07, 0.05, Color("3a2a20"), Vector3.ZERO, 6)
				bulbs.append([_m(Vector3(rx, 1.12, PIER_Z + side * 1.05)), col, 1.5])
		b.box(Vector3(mid, 1.0, PIER_Z + side * 1.05), Vector3(length, 0.06, 0.08), wood)
	# The bamboo arch at the foot, a banner of marigold garlands across it.
	var foot := PIER_LAND - 0.2
	for side in [-1.0, 1.0]:
		b.cyl(Vector3(foot, 1.5, PIER_Z + side * 1.3), 0.08, 3.0, Color("c8b46a"), Vector3.ZERO, 6)
		b.cone(Vector3(foot, 3.15, PIER_Z + side * 1.3), 0.14, 0.3, Color("ffcf3a"))
	b.box(Vector3(foot, 2.75, PIER_Z), Vector3(0.12, 0.5, 2.7), Color("b81a3a"))
	b.box(Vector3(foot, 2.98, PIER_Z), Vector3(0.14, 0.06, 2.75), Color("ffcf3a"))
	b.box(Vector3(foot, 2.52, PIER_Z), Vector3(0.14, 0.06, 2.75), Color("ffcf3a"))
	for i in 9:
		var z := lerpf(-1.2, 1.2, float(i) / 8.0)
		var sag := (1.0 - pow(z / 1.2, 2.0)) * 0.25
		b.ball(Vector3(foot + 0.08, 2.4 - sag, PIER_Z + z), Vector3(0.16, 0.16, 0.16), Color("ff9a1a") if i % 2 == 0 else Color("ffd23a"))
	# A table at the bank with krathongs ready for floating, and a basket of marigolds.
	var table := Vector3(PIER_LAND + 0.9, 0, PIER_Z - 2.1)
	b.box(table + Vector3(0, 0.75, 0), Vector3(1.6, 0.08, 0.9), Color("b81a3a"))
	b.box(table + Vector3(0, 0.4, 0), Vector3(1.4, 0.7, 0.7), wood)
	b.cyl(Vector3(PIER_LAND + 0.9, 0.25, PIER_Z + 2.0), 0.35, 0.5, Color("b0884a"), Vector3.ZERO, 8)
	for i in 7:
		var a := TAU * float(i) / 7.0
		b.ball(Vector3(PIER_LAND + 0.9 + cos(a) * 0.2, 0.55, PIER_Z + 2.0 + sin(a) * 0.2), Vector3.ONE * 0.18, Color("ff9a1a"))
	# Three small krathongs on the table (the tiers' look, scaled down).
	for i in 3:
		_krathong_into(b, i, table + Vector3(-0.5 + 0.5 * float(i), 0.79, 0), 0.55)
	b.xform = Transform3D.IDENTITY


## Posts round the pond with strings of coloured bulbs sagging between them (not over the
## red bridge's ends).
func _light_strings(b: JapanKit.Batch, bulbs: Array) -> void:
	var posts: Array[Vector3] = []
	for a_deg in [30.0, 70.0, 110.0, 150.0, 210.0, 250.0, 290.0, 330.0]:
		var a := deg_to_rad(a_deg)
		posts.append(Vector3(cos(a) * 9.8, 0, sin(a) * 7.8))
	var colors := [Color("ff4a5a"), Color("ffcf3a"), Color("5ad0ff"), Color("8aff7a"), Color("ff8fd8"), Color("ffa040")]
	var n := 0
	for i in posts.size():
		var p: Vector3 = posts[i]
		b.cyl(p + Vector3(0, 1.6, 0), 0.08, 3.2, Color("6a4a30"), Vector3.ZERO, 6)
		b.ball(p + Vector3(0, 3.25, 0), Vector3.ONE * 0.2, Color("ffcf3a"))
		var q: Vector3 = posts[(i + 1) % posts.size()]
		# The bridge's ends (pond x ~ 0) get no string over them.
		if (p.x > 0.0) != (q.x > 0.0):
			continue
		var a3 := p + Vector3(0, 3.1, 0)
		var c3 := q + Vector3(0, 3.1, 0)
		var seg := 9
		for s in seg + 1:
			var t := float(s) / float(seg)
			var at := a3.lerp(c3, t) - Vector3(0, sin(t * PI) * 0.55, 0)
			if s < seg:
				var nxt := a3.lerp(c3, t + 1.0 / float(seg)) - Vector3(0, sin((t + 1.0 / float(seg)) * PI) * 0.55, 0)
				var mid := (at + nxt) * 0.5
				var d := nxt - at
				b.box(mid, Vector3(0.025, 0.025, d.length()), Color("2a2420"), Vector3(-rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length())), rad_to_deg(atan2(d.x, d.z)), 0))
			if s > 0 and s < seg:
				var col: Color = colors[n % colors.size()]
				b.ball(at - Vector3(0, 0.12, 0), Vector3(0.14, 0.18, 0.14), col.lightened(0.25), true)
				bulbs.append([at - Vector3(0, 0.12, 0), col, 0.9])
				n += 1


## The pageant stage on the south bank: a raised floor with steps to the pond, a red
## backdrop between gold pillars under a gold lotus arch, banana plants in pots.
func _stage(b: JapanKit.Batch, bulbs: Array) -> void:
	var s := STAGE
	var red := Color("b81a3a")
	var gold := Color("ffcf3a")
	var gold_deep := Color("c98a18")
	b.box(s + Vector3(0, 0.32, 0.4), Vector3(6.4, 0.64, 3.4), Color("7a2a2a"))
	b.box(s + Vector3(0, 0.66, 0.4), Vector3(6.5, 0.06, 3.5), Color("e8c890"))
	b.box(s + Vector3(0, 0.6, -1.32), Vector3(6.5, 0.1, 0.08), gold)
	for i in 3:
		b.box(s + Vector3(0, 0.1 + 0.2 * float(i), -1.6 + 0.24 * float(i)), Vector3(2.4, 0.2, 0.3), Color("e8c890").darkened(0.1 * float(2 - i)))
	# A red runner up the steps and across the stage.
	b.box(s + Vector3(0, 0.7, 0.2), Vector3(1.4, 0.02, 2.8), red)
	# The backdrop.
	b.box(s + Vector3(0, 2.0, 1.95), Vector3(6.0, 2.7, 0.12), red)
	b.box(s + Vector3(0, 3.4, 1.95), Vector3(6.3, 0.16, 0.18), gold)
	b.box(s + Vector3(0, 0.7, 1.95), Vector3(6.3, 0.12, 0.18), gold)
	for i in 7:
		var x := lerpf(-2.6, 2.6, float(i) / 6.0)
		b.box(s + Vector3(x, 2.05, 1.88), Vector3(0.06, 2.6, 0.04), red.darkened(0.25))
	for side in [-1.0, 1.0]:
		b.cyl(s + Vector3(side * 3.15, 2.0, 1.9), 0.18, 4.0, gold, Vector3.ZERO, 8)
		b.cone(s + Vector3(side * 3.15, 4.35, 1.9), 0.26, 0.7, gold_deep)
		b.ball(s + Vector3(side * 3.15, 4.75, 1.9), Vector3.ONE * 0.22, gold, true)
		bulbs.append([s + Vector3(side * 3.15, 4.75, 1.9), Color("ffcf3a"), 1.4])
		# Banana plants in pots either side of the steps.
		var pot := s + Vector3(side * 2.4, 0.66, -0.8)
		b.cyl(pot + Vector3(0, 0.25, 0), 0.32, 0.5, Color("b8643a"), Vector3.ZERO, 8)
		b.cyl(pot + Vector3(0, 0.9, 0), 0.08, 1.3, Color("7ab04a"), Vector3.ZERO, 6)
		for k in 5:
			var a: float = TAU * float(k) / 5.0 + float(side)
			b.box(pot + Vector3(cos(a) * 0.45, 1.55, sin(a) * 0.45), Vector3(0.32, 0.04, 1.1), Color("5ab84a").darkened(0.08 * float(k % 2)), Vector3(28.0, rad_to_deg(a) + 90.0, 0))
	# The arch: a half ring of gold petals over the backdrop with a lotus at its crown.
	for k in 13:
		var a := PI * float(k) / 12.0
		var at := s + Vector3(cos(a) * 3.0, 3.45 + sin(a) * 1.2, 1.9)
		b.add(JapanKit.arrays("ball"), JapanKit.place(at, Vector3(0.28, 0.5, 0.12), Vector3(0, 0, rad_to_deg(a) - 90.0)), gold if k % 2 == 0 else Color("ff8fc8"))
		if k % 3 == 0:
			b.ball(at + Vector3(0, 0, -0.1), Vector3.ONE * 0.16, Color("fff0a8"), true)
			bulbs.append([at + Vector3(0, 0, -0.1), Color("ffe08a"), 0.9])
	for k in 7:
		var a := lerpf(-1.1, 1.1, float(k) / 6.0)
		b.add(JapanKit.arrays("ball"), JapanKit.place(s + Vector3(sin(a) * 0.35, 4.95 + cos(a) * 0.3, 1.85), Vector3(0.22, 0.55, 0.1), Vector3(0, 0, -rad_to_deg(a))), Color("ff8fc8") if k % 2 else Color("ffc2e0"))
	b.ball(s + Vector3(0, 4.85, 1.8), Vector3.ONE * 0.24, gold, true)


## One soft additive halo per bulb, its strength following the night (_update_night).
func _bulb_halos(bulbs: Array) -> void:
	var t: Array[Transform3D] = []
	var c: Array[Color] = []
	for e in bulbs:
		t.append(Transform3D(Basis.from_scale(Vector3.ONE * float(e[2])), e[0]))
		c.append(Color((e[1] as Color).lightened(0.2), 0.55))
	_halos = Scenery._billboards(self, "BulbHalos", t, c, true)
	_halo_mat = _halos.material_override as StandardMaterial3D
	_halos.visibility_range_end = 80.0 * GameSettings.view_scale()
	_halos.set_meta("visual_only", true)


# --- The moon ---------------------------------------------------------------------------------

const MOON_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float alpha = 1.0;
void vertex() {
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(sx, 0.0, 0.0, 0.0), vec4(0.0, sy, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
float crater(vec2 p, vec2 c, float r) {
	return 1.0 - smoothstep(r * 0.7, r, length(p - c));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float disc = 1.0 - smoothstep(0.37, 0.385, r);
	float shade = crater(p, vec2(-0.12, -0.1), 0.11) * 0.5 + crater(p, vec2(0.13, 0.08), 0.08) * 0.45
		+ crater(p, vec2(0.05, -0.2), 0.06) * 0.4 + crater(p, vec2(-0.05, 0.2), 0.07) * 0.35 + crater(p, vec2(0.2, -0.12), 0.05) * 0.4;
	vec3 face = mix(vec3(1.0, 0.97, 0.86), vec3(0.93, 0.85, 0.66), clamp(shade, 0.0, 1.0));
	face *= 1.0 - 0.12 * smoothstep(0.1, 0.38, length(p - vec2(-0.08, -0.08)));
	float halo = pow(1.0 - smoothstep(0.37, 1.0, r), 2.2) * 0.75;
	ALBEDO = mix(vec3(1.0, 0.85, 0.55), face, disc);
	ALPHA = max(disc, halo) * alpha;
}
"""


static func moon_material() -> ShaderMaterial:
	if _moon_mat == null:
		var shader := Shader.new()
		shader.code = MOON_SHADER
		_moon_mat = ShaderMaterial.new()
		_moon_mat.shader = shader
	return _moon_mat


func _build_moon() -> void:
	_moon = MeshInstance3D.new()
	_moon.name = "FullMoon"
	_moon.mesh = MeshKit.quad()
	# Its own material copy: its alpha follows this village's night.
	_moon.material_override = moon_material().duplicate()
	_moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_moon.position = MOON_AT
	_moon.scale = Vector3(MOON_SIZE, MOON_SIZE, 1.0)
	_moon.extra_cull_margin = MOON_SIZE
	_moon.set_meta("visual_only", true)
	add_child(_moon)


# --- Sky lanterns -----------------------------------------------------------------------------

func _build_lanterns() -> void:
	var n := VfxBudget.count(SKY_LANTERNS, 6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2569
	var t: Array[Transform3D] = []
	var c: Array[Color] = []
	for i in n:
		# Over the pond and the village, each on its own phase, two quads: glow and body.
		var r := rng.randf_range(3.0, 48.0)
		var a := rng.randf() * TAU
		var home := Vector3(cos(a) * r - POND.x * rng.randf_range(0.0, 0.7), 0, sin(a) * r - POND.z * rng.randf_range(0.0, 0.7))
		_lantern_seeds.append([home, rng.randf() * LANTERN_TOP, rng.randf_range(0.75, 1.25), rng.randf() * TAU])
		t.append(Transform3D(Basis.from_scale(Vector3(2.4, 2.4, 1.0)), home))
		c.append(Color(1.0, 0.62, 0.25, 0.4))
		t.append(Transform3D(Basis.from_scale(Vector3(0.75, 1.0, 1.0)), home))
		c.append(Color(1.0, 0.85, 0.5, 0.95))
	_lanterns = Scenery._billboards(self, "SkyLanterns", t, c, true)
	_lanterns.set_meta("visual_only", true)
	_lanterns.extra_cull_margin = 120.0
	_lanterns.visible = false


func _move_lanterns(now: float) -> void:
	var mm := _lanterns.multimesh
	for i in _lantern_seeds.size():
		var s: Array = _lantern_seeds[i]
		var speed := LANTERN_RISE * float(s[2])
		var h := fposmod(float(s[1]) + now * speed, LANTERN_TOP)
		var drift := Vector3(sin(now * 0.21 + float(s[3])) * 1.5 + h * 0.18, 4.0 + h, cos(now * 0.17 + float(s[3])) * 1.2)
		var fade := smoothstep(0.0, 6.0, h) * (1.0 - smoothstep(LANTERN_TOP - 15.0, LANTERN_TOP, h))
		var flicker := 0.85 + 0.15 * sin(now * 7.0 + float(s[3]) * 5.0)
		var at: Vector3 = (s[0] as Vector3) + drift
		mm.set_instance_transform(i * 2, Transform3D(Basis.from_scale(Vector3(2.4, 2.4, 1.0) * flicker), at))
		mm.set_instance_color(i * 2, Color(1.0, 0.62, 0.25, 0.4 * fade))
		mm.set_instance_transform(i * 2 + 1, Transform3D(Basis.from_scale(Vector3(0.75, 1.0, 1.0)), at))
		mm.set_instance_color(i * 2 + 1, Color(1.0, 0.85, 0.5, 0.95 * fade))


# --- Krathongs ---------------------------------------------------------------------------------

## The cached mesh of krathong tier k (a mesh a tier for every krathong on the water).
static func krathong_mesh(k: int) -> ArrayMesh:
	k = clampi(k, 0, LoyKrathong.KRATHONGS.size() - 1)
	if not _meshes.has(k):
		var b := JapanKit.Batch.new()
		_krathong_into(b, k, Vector3.ZERO, 1.0)
		_meshes[k] = b.mesh()
	return _meshes[k]


## Krathong tier k into batch `b` at `at` (its base on `at`), `s` its scale. A banana-leaf
## base with folded leaf points round the rim, two rows of petals (the tier's), flowers,
## incense, a candle with its flame (unshaded).
static func _krathong_into(b: JapanKit.Batch, k: int, at: Vector3, s: float) -> void:
	var looks := [
		{"base": Color("4a9a3a"), "top": Color("cfe8a0"), "rim": Color("6ac85a"), "outer": Color("7ad06a"), "inner": Color("b8ec98"), "candle": Color("fff4dc"), "flower": Color("ffffff")},
		{"base": Color("4a9a3a"), "top": Color("cfe8a0"), "rim": Color("6ac85a"), "outer": Color("ff7ab8"), "inner": Color("ffc2e0"), "candle": Color("fff4dc"), "flower": Color("ffd23a")},
		{"base": Color("c98a18"), "top": Color("ffe8a0"), "rim": Color("ffcf3a"), "outer": Color("ffc93a"), "inner": Color("ff9ccb"), "candle": Color("ffd23a"), "flower": Color("ff5a3a")},
		{"base": Color("0b5a4c"), "top": Color("a8f0d8"), "rim": Color("ffcf3a"), "outer": Color("2fd8a8"), "inner": Color("ffe27a"), "candle": Color("ffd23a"), "flower": Color("5cf2d0")},
	]
	var L: Dictionary = looks[clampi(k, 0, 3)]
	var p := func(v: Vector3) -> Vector3: return at + v * s
	b.cyl(p.call(Vector3(0, 0.07, 0)), 0.36 * s, 0.14 * s, L.base, Vector3.ZERO, 12)
	b.cyl(p.call(Vector3(0, 0.145, 0)), 0.31 * s, 0.02 * s, L.top, Vector3.ZERO, 12)
	# Folded leaf points round the rim.
	for i in 14:
		var a := TAU * float(i) / 14.0
		var yaw := rad_to_deg(a)
		b.add(JapanKit.arrays("cone"), JapanKit.place(p.call(Vector3(sin(a) * 0.32, 0.2, cos(a) * 0.32)), Vector3(0.12, 0.2, 0.05) * s, Vector3(18.0, yaw, 0)), L.rim)
	# Outer petals, then an inner row more upright.
	for i in 8:
		var a := TAU * (float(i) + 0.5) / 8.0
		b.add(JapanKit.arrays("ball"), JapanKit.place(p.call(Vector3(sin(a) * 0.19, 0.27, cos(a) * 0.19)), Vector3(0.15, 0.3, 0.06) * s, Vector3(34.0, rad_to_deg(a), 0)), L.outer)
	for i in 6:
		var a := TAU * float(i) / 6.0
		b.add(JapanKit.arrays("ball"), JapanKit.place(p.call(Vector3(sin(a) * 0.11, 0.3, cos(a) * 0.11)), Vector3(0.12, 0.26, 0.05) * s, Vector3(16.0, rad_to_deg(a), 0)), L.inner)
	# Flowers between the petals.
	for i in 6:
		var a := TAU * (float(i) + 0.5) / 6.0
		b.ball(p.call(Vector3(sin(a) * 0.25, 0.2, cos(a) * 0.25)), Vector3.ONE * 0.07 * s, L.flower)
	# Incense sticks and the candle with its flame.
	for side in [-1.0, 1.0]:
		b.cyl(p.call(Vector3(side * 0.06, 0.38, -0.04)), 0.008 * s, 0.32 * s, Color("8a4a2a"), Vector3(0, 0, side * -10.0), 4)
		b.ball(p.call(Vector3(side * 0.088, 0.54, -0.04)), Vector3.ONE * 0.02 * s, Color("ff5a2a"), true)
	b.cyl(p.call(Vector3(0, 0.42, 0.02)), 0.036 * s, 0.34 * s, L.candle, Vector3.ZERO, 8)
	b.ball(p.call(Vector3(0, 0.63, 0.02)), Vector3(0.05, 0.1, 0.05) * s, Color("ffb03a"), true)
	b.ball(p.call(Vector3(0, 0.62, 0.02)), Vector3(0.024, 0.05, 0.024) * s, Color("fff6c8"), true)
	if k >= 3:
		# The Naga krathong: a gold crest fanned behind the candle and teal gems on the rim.
		for i in 5:
			var a := lerpf(-1.0, 1.0, float(i) / 4.0)
			b.add(JapanKit.arrays("cone"), JapanKit.place(p.call(Vector3(sin(a) * 0.14, 0.42, -0.12 + absf(a) * 0.03)), Vector3(0.05, 0.22 - absf(a) * 0.06, 0.03) * s, Vector3(-12.0, 0, -rad_to_deg(a) * 0.6)), Color("ffcf3a"))
		for i in 4:
			var a := TAU * float(i) / 4.0
			b.ball(p.call(Vector3(sin(a) * 0.37, 0.12, cos(a) * 0.37)), Vector3.ONE * 0.05 * s, Color("7affe0"), true)
	elif k == 2:
		b.cyl(p.call(Vector3(0, 0.15, 0)), 0.37 * s, 0.03 * s, Color("ffe27a"), Vector3.ZERO, 12)


## The shared glow of the flames and the water's reflections (additive soft dot).
static func glow_material() -> StandardMaterial3D:
	if _glow_mat == null:
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_glow_mat.billboard_keep_scale = true
		_glow_mat.vertex_color_use_as_albedo = true
		_glow_mat.albedo_texture = VfxKit.soft_dot()
		_glow_mat.disable_fog = true
		_glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _glow_mat


static var _pool_mat: StandardMaterial3D


## The flat additive glow on the water under a krathong.
static func pool_material() -> StandardMaterial3D:
	if _pool_mat == null:
		_pool_mat = glow_material().duplicate() as StandardMaterial3D
		_pool_mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	return _pool_mat


## A drifting krathong: the mesh, a flame glow, the light on the water and the wish label.
static func make_krathong(k: int, who: String, wish: String, hero := false) -> Node3D:
	var root := Node3D.new()
	root.name = "Krathong"
	var mi := MeshInstance3D.new()
	mi.mesh = krathong_mesh(k)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * 1.5
	root.add_child(mi)
	var glow := MeshInstance3D.new()
	glow.name = "Flame"
	glow.material_override = glow_material()
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position = Vector3(0, 0.8, 0.02)
	glow.scale = Vector3(0.42, 0.6, 1.0)
	root.add_child(glow)
	var tint := Color(1.0, 0.62, 0.22, 0.9) if k < 3 else Color(0.4, 1.0, 0.8, 0.9)
	glow.mesh = _tinted_quad(tint)
	# The candle's light on the water round it.
	var pool := MeshInstance3D.new()
	pool.name = "WaterGlow"
	pool.mesh = _tinted_quad(Color(tint, 0.35))
	pool.material_override = pool_material()
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.rotation.x = -PI * 0.5
	pool.position = Vector3(0, 0.03, 0)
	pool.scale = Vector3(2.2, 2.2, 1.0)
	root.add_child(pool)
	var label := Label3D.new()
	label.name = "Wish"
	label.text = ("%s\n\"%s\"" % [who, wish]) if wish != "" else who
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.007
	label.font_size = 40
	label.outline_size = 12
	label.modulate = Color("fff2b0") if hero else Color("ffe8f4")
	label.outline_modulate = Color(0.25, 0.08, 0.05, 0.9)
	label.position = Vector3(0, 1.35, 0)
	label.visibility_range_end = 40.0
	label.no_depth_test = false
	root.add_child(label)
	return root


static var _quads := {}


## A small quad mesh with its vertex colour (the shared glow material reads the colour).
static func _tinted_quad(tint: Color) -> ArrayMesh:
	var key := tint.to_html()
	if _quads.has(key):
		return _quads[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector3(-0.5, -0.5, 0), Vector3(0.5, -0.5, 0), Vector3(0.5, 0.5, 0), Vector3(-0.5, 0.5, 0)]
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_color(tint)
		st.set_uv(uvs[i])
		st.set_normal(Vector3.BACK)
		st.add_vertex(corners[i])
	var mesh := st.commit()
	_quads[key] = mesh
	return mesh


## Where a krathong is `f` (0..1) of the way across the pond, on lane `lane` (-1..1): off
## the pier's tip, under the red bridge's middle, to the far bank.
static func path_at(f: float, lane: float) -> Vector3:
	var a := LAUNCH
	var b1 := Vector3(-1.6, WATER_Y, -0.2 + lane * 0.6)
	var c := Vector3(1.8, WATER_Y, 0.4 + lane * 1.0)
	var d := Vector3(5.8, WATER_Y, -0.2 + lane * 1.6)
	var t := clampf(f, 0.0, 1.0)
	var s := 1.0 - t
	var q := a * s * s * s + b1 * 3.0 * s * s * t + c * 3.0 * s * t * t + d * t * t * t
	q.y = WATER_Y
	return q


## The hero's own krathong (LoyKrathong.float_krathong's sink).
func _launch(entry: Dictionary) -> void:
	_add_float(entry, "hero|%d" % int(Time.get_ticks_msec()))


func _add_float(entry: Dictionary, key: String) -> void:
	if _seen.has(key):
		return
	_seen[key] = true
	while _floats.size() >= MAX_FLOATS:
		var old: Dictionary = _floats.pop_front()
		if is_instance_valid(old.node):
			old.node.queue_free()
	var node := make_krathong(int(entry.tier), String(entry.name), String(entry.wish), bool(entry.get("hero", false)))
	add_child(node)
	var lane := float(absi(hash(key)) % 1000) / 500.0 - 1.0
	_floats.append({"node": node, "at": float(entry.at), "lane": lane, "spin": float(absi(hash(key + "s")) % 100) / 100.0 * TAU, "key": key})
	_place(_floats[_floats.size() - 1], WorldPresence.clock())


func _place(f: Dictionary, now: float) -> void:
	var age := now - float(f.at)
	var u := clampf(age / LoyKrathong.FLOAT_LIFE, 0.0, 1.0)
	var node: Node3D = f.node
	var pos := path_at(u, float(f.lane))
	pos.y += sin(now * 1.7 + float(f.spin)) * 0.03
	node.position = pos
	node.rotation.y = float(f.spin) + age * 0.12
	var fade := 1.0 - smoothstep(0.8, 1.0, u)
	var label := node.get_node_or_null("Wish") as Label3D
	if label:
		label.modulate.a = fade
		label.outline_modulate.a = fade * 0.9
	node.scale = Vector3.ONE * lerpf(1.0, 0.6, smoothstep(0.85, 1.0, u))


# --- Every frame ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	var now := WorldPresence.clock()
	_sync -= delta
	if _sync <= 0.0:
		_sync = 1.0
		_sync_floats(now)
		_update_night(now)
	for i in range(_floats.size() - 1, -1, -1):
		var f: Dictionary = _floats[i]
		if not is_instance_valid(f.node) or now - float(f.at) >= LoyKrathong.FLOAT_LIFE:
			if is_instance_valid(f.node):
				(f.node as Node).queue_free()
			_floats.remove_at(i)
			continue
		_place(f, now)
	if _lanterns.visible:
		_move_lanterns(now)


## The world players' krathongs launched within their life (read off the clock).
func _sync_floats(now: float) -> void:
	for e in LoyKrathong.ai_floats(now):
		_add_float(e, "ai|%d" % int(round(float(e.at))))
	if _seen.size() > 200:
		var keep := {}
		for f in _floats:
			keep[f.key] = true
		_seen = keep


## The moon, the bulbs' halos and the sky lanterns follow the village's night.
func _update_night(now: float) -> void:
	var night := 0.0
	var dn: Variant = zone.get("day_night") if zone != null else null
	if dn is DayNight and is_instance_valid(dn):
		night = clampf((dn as DayNight).now.night, 0.0, 1.0)
	elif not is_nan(DayNight.fixed_hour):
		night = clampf(DayNight.night_light(DayNight.fixed_hour), 0.0, 1.0)
	if LoyKrathong.night_on(now):
		night = maxf(night, 1.0)
	if absf(night - _night) > 0.01:
		_night = night
		(_moon.material_override as ShaderMaterial).set_shader_parameter("alpha", night)
		_moon.visible = night > 0.01
		_halo_mat.albedo_color = Color(1, 1, 1, 0.3 + 0.7 * night)
	_lanterns.visible = LoyKrathong.night_on(now) and not GameSettings.safe_picture


## World spots the random trees and rocks keep off while the pond is dressed: (x, z, r).
static func clear_spots() -> Array[Vector3]:
	return [Vector3(POND.x + STAGE.x, POND.z + STAGE.z + 0.4, 4.6), Vector3(POND.x + SIDE * PIER_LAND, POND.z + PIER_Z, 2.6),
		Vector3(POND.x + SIDE * (PIER_LAND + 1.0), POND.z + PIER_Z - 2.2, 1.8)]


## A pier-side point (authored on +x) on the bank it is built on.
static func _m(v: Vector3) -> Vector3:
	return Vector3(v.x * SIDE, v.y, v.z)


const WATER_RING_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 deep : source_color = vec4(0.05, 0.32, 0.42, 0.62);
uniform vec4 foam : source_color = vec4(0.75, 1.0, 0.95, 0.9);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float swirl = sin(a * 3.0 + r * 14.0 - TIME * 2.4) * 0.5 + 0.5;
	float rings = smoothstep(0.82, 1.0, fract(r * 3.0 - TIME * 0.45));
	float edge = 1.0 - smoothstep(0.78, 1.0, r);
	vec3 col = mix(deep.rgb, foam.rgb, clamp(rings * 0.8 + swirl * 0.25 * r, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = edge * mix(deep.a, foam.a, rings) * (0.55 + 0.45 * r);
}
"""
static var _ring_mat: ShaderMaterial


## A ring of churning water round the Naga (a child of its mob, gone with it).
static func water_ring(mob: Node3D) -> MeshInstance3D:
	if _ring_mat == null:
		var shader := Shader.new()
		shader.code = WATER_RING_SHADER
		_ring_mat = ShaderMaterial.new()
		_ring_mat.shader = shader
	var mi := MeshInstance3D.new()
	mi.name = "NagaWater"
	mi.mesh = MeshKit.quad()
	mi.material_override = _ring_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation.x = -PI * 0.5
	mi.position = Vector3(0, 0.06, 0)
	mi.scale = Vector3(11.0, 11.0, 1.0)
	mi.set_meta("visual_only", true)
	mob.add_child(mi)
	return mi


## The pier's interaction point: no figure, just its place (the arch and the sign show it).
class PierPoint:
	extends Npc

	func setup(p_role: String, p_name: String, _p_class: StringName, p_title := "", _p_model := "", _p_look := {}) -> void:
		role = p_role
		display_name = p_name
		var label := Label3D.new()
		label.text = "%s\n%s" % [p_name, p_title]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.0048
		label.font_size = 40
		label.outline_size = 12
		label.modulate = Color("fff2c0")
		label.position = Vector3(0, 2.0, 0)
		label.visibility_range_end = 22.0
		add_child(label)

	func face(_point: Vector3) -> void:
		pass

	func _process(_delta: float) -> void:
		pass
