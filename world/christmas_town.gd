class_name ChristmasTown
extends Node3D
## The village during the Christmas and New Year festival (Christmas.decor_on):
##   - a big Christmas tree on the plaza's terrace (the great sakura steps aside for it):
##     tiers of fir with snow on the tips, baubles, a gold tinsel spiral, a ribbon of
##     twinkling bulbs, a glowing star on top and gift boxes round its foot; strands of
##     bulbs run from its top down to the plaza's stone lanterns;
##   - strings of coloured bulbs along every lantern line over the streets;
##   - snowmen round the plaza;
##   - snow falling round the camera (one mesh of quads moved by its shader: SNOW flakes by
##     the quality setting, none while memory is strict);
##   - in the New Year countdown (Christmas.fireworks_on) fireworks over the town (one mesh
##     of sparks moved by its shader, FIREWORKS bursts by the quality setting), a countdown
##     sign over the tree, and at midnight a big burst, "สวัสดีปีใหม่ 2027" over the plaza
##     and on the screen (the zone's banner).
## Everything is code-built: one merged mesh for the static pieces, one mesh of twinkling
## glow quads for every bulb, no lights, no particles, no shadows from the glows; the
## script only looks at the clock once a second.

const TREE_AT := Vector3(0, 1.03, 0)
const TREE_HEIGHT := 9.6
const TREE_BASE := 2.75
## Flakes by quality (0 low .. 2 high) and the box round the camera they fall in.
const SNOW: Array[int] = [220, 520, 1000]
const SNOW_BOX := Vector3(46.0, 26.0, 46.0)
## Firework bursts by quality, sparks a burst.
const FIREWORKS: Array[int] = [3, 5, 8]
const SPARKS: Array[int] = [28, 40, 48]
const FIREWORK_CENTER := Vector3(0, 0, -6)
const SNOWMEN: Array[Vector3] = [Vector3(8.1, 0, 8.1), Vector3(-8.1, 0, 8.1), Vector3(11.6, 0, -2.4), Vector3(-11.6, 0, -2.4)]
const BULB_COLORS := [Color("ff3a4a"), Color("3aff6a"), Color("ffd23a"), Color("4aa8ff"), Color("ff8ad8"), Color("fff6e0")]

static var current: ChristmasTown = null
static var _twinkle_mat: ShaderMaterial
static var _snow_mat: ShaderMaterial
static var _fire_mat: ShaderMaterial

var zone: Node3D
var snow: MeshInstance3D
var fireworks: MeshInstance3D
var lights: MeshInstance3D
var sign_label: Label3D
var bulb_count := 0
var _tick := 0.0
var _night := -1.0
var _told_new := false


## Dresses the village zone (only while Christmas.decor_on).
static func build(p_zone: Node3D) -> ChristmasTown:
	var node := ChristmasTown.new()
	node.name = "ChristmasTown"
	node.zone = p_zone
	p_zone.add_child(node)
	node._build()
	return node


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


## World spots the random trees and rocks keep off while the town is dressed: (x, z, r).
static func clear_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p in SNOWMEN:
		out.append(Vector3(p.x, p.z, 1.6))
	return out


# --- Building -------------------------------------------------------------------------------

func _build() -> void:
	# The great sakura steps aside for the tree (it comes back when the festival is over and
	# the town is built again).
	var sakura := zone.find_child("GreatSakura", true, false) as Node3D
	if sakura != null:
		sakura.visible = false
	var b := JapanKit.Batch.new()
	var bulbs: Array = []
	_tree(b, bulbs)
	_strands(b, bulbs)
	_street_strings(b, bulbs)
	for p in SNOWMEN:
		_snowman(b, p)
		JapanKit.collider(self, p + Vector3(0, 0.8, 0), Vector3(1.2, 1.6, 1.2))
	var mi := b.commit(self, "ChristmasDecor", false)
	mi.visibility_range_end = 120.0 * GameSettings.view_scale()
	_twinkles(bulbs)
	_build_snow()
	_build_fireworks()
	_build_sign()
	_update(Christmas.now())


## The fir: tiers of cones narrowing up, snow on each tier's rim, baubles, a gold tinsel
## spiral, a spiral of bulbs, the star and gift boxes at its foot.
func _tree(b: JapanKit.Batch, bulbs: Array) -> void:
	var base := TREE_AT
	b.cyl(base + Vector3(0, 0.45, 0), 0.32, 0.9, Color("6a4428"), Vector3.ZERO, 8)
	var tiers := 6
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var greens := [Color("1f6a3a"), Color("24804a"), Color("1a5c34")]
	for k in tiers:
		var u := float(k) / float(tiers - 1)
		var r := lerpf(TREE_BASE, 0.75, u)
		var y := lerpf(0.7, TREE_HEIGHT - 2.4, u)
		var h := lerpf(2.6, 1.9, u)
		b.cone(base + Vector3(0, y + h * 0.5, 0), r, h, greens[k % 3])
		# Snow on the rim: a ring of white blobs.
		var n := int(lerpf(16.0, 7.0, u))
		for i in n:
			var a := TAU * (float(i) + 0.5 * float(k % 2)) / float(n)
			b.ball(base + Vector3(cos(a) * r * 0.92, y + 0.12, sin(a) * r * 0.92), Vector3(0.5, 0.18, 0.5) * lerpf(1.0, 0.6, u), Color("f4f8ff"))
		# Baubles hanging under the rim.
		var m := int(lerpf(10.0, 4.0, u))
		for i in m:
			var a := TAU * (float(i) + rng.randf_range(-0.2, 0.2)) / float(m) + float(k)
			var rr := r * rng.randf_range(0.55, 0.8)
			var yy := y + h * (1.0 - rr / r) * 0.9 + 0.15
			var col: Color = [Color("e8243a"), Color("ffcf3a"), Color("3a7bff"), Color("d8d8e8"), Color("b04aff")][(i + k) % 5]
			b.ball(base + Vector3(cos(a) * rr, yy, sin(a) * rr), Vector3.ONE * lerpf(0.36, 0.24, u), col)
	# A gold tinsel spiral and a spiral of bulbs (offset half a turn).
	var turns := 4.5
	var steps := 90
	for s in steps:
		var u := float(s) / float(steps)
		var y := lerpf(0.9, TREE_HEIGHT - 1.0, u)
		var r := _radius_at(y) + 0.06
		var a := u * turns * TAU
		b.ball(base + Vector3(cos(a) * r, y, sin(a) * r), Vector3(0.16, 0.12, 0.16), Color("ffd84a"), true)
		if s % 2 == 0:
			var a2 := a + PI
			var r2 := _radius_at(y) + 0.1
			var col: Color = BULB_COLORS[(s / 2) % BULB_COLORS.size()]
			var at := base + Vector3(cos(a2) * r2, y, sin(a2) * r2)
			b.ball(at, Vector3.ONE * 0.17, col.lightened(0.3), true)
			bulbs.append([at, col, 0.95])
	# The star: five gold rays round a bright heart, facing the south entry and the north.
	var top := base + Vector3(0, TREE_HEIGHT + 0.25, 0)
	for k in 5:
		var a := TAU * float(k) / 5.0
		var dir := Vector3(sin(a), cos(a), 0)
		b.cone(top + dir * 0.36, 0.22, 0.75, Color("ffe066"), Vector3(0, 0, -rad_to_deg(a)))
	b.ball(top, Vector3(0.5, 0.5, 0.3), Color("fff3a8"), true)
	for k in 5:
		var a := TAU * float(k) / 5.0
		b.ball(top + Vector3(sin(a), cos(a), 0) * 0.62, Vector3.ONE * 0.16, Color("fff8d0"), true)
	bulbs.append([top, Color("ffe066"), 5.0])
	bulbs.append([top, Color("fff6d0"), 2.2])
	# Gift boxes round the foot, on the terrace.
	var colors := [[Color("e8243a"), Color("ffd84a")], [Color("2f9a4a"), Color("e8243a")], [Color("3a7bff"), Color("f4f4ff")], [Color("ffd84a"), Color("b81a3a")], [Color("b04aff"), Color("ffd84a")]]
	for i in 7:
		var a := TAU * (float(i) + 0.3) / 7.0
		var size := Vector3.ONE * rng.randf_range(0.45, 0.8)
		var at := base + Vector3(cos(a) * 2.05, size.y * 0.5, sin(a) * 2.05)
		var pair: Array = colors[i % colors.size()]
		var yaw := rad_to_deg(rng.randf() * TAU)
		b.box(at, size, pair[0], Vector3(0, yaw, 0))
		b.box(at, Vector3(size.x * 1.02, size.y * 1.02, size.z * 0.2), pair[1], Vector3(0, yaw, 0))
		b.box(at, Vector3(size.x * 0.2, size.y * 1.02, size.z * 1.02), pair[1], Vector3(0, yaw, 0))
		b.ball(at + Vector3(0, size.y * 0.55, 0), Vector3(0.3, 0.16, 0.3) * size.x, pair[1])


## The fir's radius at height y above its foot (the tiers' outline).
static func _radius_at(y: float) -> float:
	var u := clampf((y - 0.7) / (TREE_HEIGHT - 0.7), 0.0, 1.0)
	return lerpf(TREE_BASE * 0.88, 0.1, u)


## Strands of bulbs from the tree's top down to the plaza's eight stone lanterns.
func _strands(b: JapanKit.Batch, bulbs: Array) -> void:
	var top := TREE_AT + Vector3(0, TREE_HEIGHT - 1.2, 0)
	for i in 8:
		var a := TAU * (float(i) + 0.5) / 8.0
		var end := Vector3(cos(a) * 7.0, 2.45, sin(a) * 7.0)
		_string(b, bulbs, top + Vector3(cos(a), 0, sin(a)) * 0.6, end, 12, 0.6, i)


## Bulbs along every lantern line over the streets (JapanVillage's _overhead_line posts).
func _street_strings(b: JapanKit.Batch, bulbs: Array) -> void:
	var lines: Array = []
	for dir in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var across := Vector3(dir.z, 0, -dir.x)
		var at: Vector3 = dir * (JapanVillage.PLAZA_RADIUS + 1.2)
		lines.append([at - across * 6.6, at + across * 6.6])
	for x in [24.0, 41.5, 65.5]:
		lines.append([Vector3(x, 0, -JapanVillage.STALL_ROW - 0.6), Vector3(x, 0, JapanVillage.STALL_ROW + 0.6)])
	for x in [-26.0, -44.0, -58.0]:
		lines.append([Vector3(x, 0, -4.7), Vector3(x, 0, 4.7)])
	for x in [26.0, 54.0, -26.0, -42.0, -54.0]:
		lines.append([Vector3(x, 0, JapanVillage.CROSS_Z - 4.7), Vector3(x, 0, JapanVillage.CROSS_Z + 4.7)])
	for z in [22.0, 30.0, 45.5, 56.0, 64.0]:
		lines.append([Vector3(-4.3, 0, z), Vector3(4.3, 0, z)])
	for z in [-28.0, -40.0, -52.0]:
		lines.append([Vector3(-5.6, 0, z), Vector3(5.6, 0, z)])
	for i in lines.size():
		var pair: Array = lines[i]
		var a: Vector3 = pair[0]
		var c: Vector3 = pair[1]
		_string(b, bulbs, a + Vector3(0, 3.82, 0), c + Vector3(0, 3.82, 0), int(clampf(a.distance_to(c) / 1.1, 6.0, 14.0)), 0.5, i)


## One wire from `from` to `to` sagging `sag`, `count` bulbs on it.
func _string(b: JapanKit.Batch, bulbs: Array, from: Vector3, to: Vector3, count: int, sag: float, shift: int) -> void:
	var seg := count + 1
	var prev := from
	for s in range(1, seg + 1):
		var t := float(s) / float(seg)
		var at := from.lerp(to, t) - Vector3(0, sin(t * PI) * sag, 0)
		var d := at - prev
		b.box((at + prev) * 0.5, Vector3(0.025, 0.025, d.length()), Color("1e2a22"), Vector3(-rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length())), rad_to_deg(atan2(d.x, d.z)), 0))
		if s < seg:
			var col: Color = BULB_COLORS[(s + shift) % BULB_COLORS.size()]
			var bulb := at - Vector3(0, 0.1, 0)
			b.ball(bulb, Vector3(0.12, 0.16, 0.12), col.lightened(0.3), true)
			bulbs.append([bulb, col, 0.75])
		prev = at


## A snowman: three snowballs, coal eyes and buttons, a carrot nose, a red scarf, a top hat
## and twig arms, facing the plaza's middle.
func _snowman(b: JapanKit.Batch, p: Vector3) -> void:
	var yaw := atan2(-p.x, -p.z)
	var basis := Basis(Vector3.UP, yaw)
	var at := func(v: Vector3) -> Vector3: return p + basis * v
	var white := Color("f4f8ff")
	b.ball(at.call(Vector3(0, 0.45, 0)), Vector3(1.0, 0.9, 1.0), white)
	b.ball(at.call(Vector3(0, 1.12, 0)), Vector3(0.72, 0.66, 0.72), white)
	b.ball(at.call(Vector3(0, 1.62, 0)), Vector3(0.52, 0.5, 0.52), white)
	var coal := Color("1e1a1c")
	for x in [-0.09, 0.09]:
		b.ball(at.call(Vector3(x, 1.68, 0.23)), Vector3.ONE * 0.06, coal)
	for k in 3:
		b.ball(at.call(Vector3(0, 1.28 - 0.17 * float(k), 0.33 - 0.02 * float(k))), Vector3.ONE * 0.07, coal)
	b.cone(at.call(Vector3(0, 1.6, 0.34)), 0.045, 0.24, Color("ff8a1a"), Vector3(rad_to_deg(PI * 0.5), rad_to_deg(yaw), 0))
	b.cyl(at.call(Vector3(0, 1.4, 0)), 0.27, 0.1, Color("d8202f"), Vector3.ZERO, 10)
	b.box(at.call(Vector3(0.12, 1.22, 0.26)), Vector3(0.12, 0.3, 0.05), Color("d8202f"), Vector3(10, rad_to_deg(yaw), 0))
	b.cyl(at.call(Vector3(0, 1.86, 0)), 0.3, 0.04, coal, Vector3.ZERO, 10)
	b.cyl(at.call(Vector3(0, 2.02, 0)), 0.19, 0.3, coal, Vector3.ZERO, 10)
	b.cyl(at.call(Vector3(0, 1.91, 0)), 0.195, 0.06, Color("d8202f"), Vector3.ZERO, 10)
	for side in [-1.0, 1.0]:
		var arm_at: Vector3 = at.call(Vector3(side * 0.5, 1.22, 0))
		b.box(arm_at, Vector3(0.05, 0.05, 0.6), Color("5a3a22"), Vector3(-25, rad_to_deg(yaw) + side * 90.0, 0))


# --- Twinkling bulbs --------------------------------------------------------------------------

const TWINKLE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;
uniform float night = 1.0;
varying vec4 tint;
void vertex() {
	float ph = UV2.x;
	float tw = 0.5 + 0.5 * sin(TIME * (1.4 + fract(ph * 7.13) * 2.6) + ph * 6.2832);
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.xy += (UV - 0.5) * UV2.y * (0.8 + 0.35 * tw);
	VERTEX = view.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
	tint = vec4(pow(COLOR.rgb, vec3(2.2)), COLOR.a * mix(0.3, 1.0, night) * (0.3 + 0.7 * tw));
}
void fragment() {
	float d = length(UV - 0.5);
	float a = pow(smoothstep(0.5, 0.0, d), 1.7) * tint.a;
	ALBEDO = mix(tint.rgb, vec3(1.0), smoothstep(0.12, 0.0, d)) * a;
	ALPHA = a;
}
"""


static func twinkle_material() -> ShaderMaterial:
	if _twinkle_mat == null:
		var shader := Shader.new()
		shader.code = TWINKLE_SHADER
		_twinkle_mat = ShaderMaterial.new()
		_twinkle_mat.shader = shader
	return _twinkle_mat


## One quad per bulb, each on its own twinkle (UV2 = phase, size).
func _twinkles(bulbs: Array) -> void:
	bulb_count = bulbs.size()
	if bulbs.is_empty() or GameSettings.safe_picture:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for k in bulbs.size():
		var e: Array = bulbs[k]
		var phase := float(absi(hash(k * 7919 + 13)) % 1000) / 1000.0
		for c in corners:
			st.set_color(Color((e[1] as Color).lightened(0.15), 0.8))
			st.set_uv(c)
			st.set_uv2(Vector2(phase, float(e[2])))
			st.set_normal(Vector3.BACK)
			st.add_vertex(e[0])
		var i := k * 4
		for j in [0, 1, 2, 0, 2, 3]:
			st.add_index(i + j)
	lights = MeshInstance3D.new()
	lights.name = "ChristmasLights"
	lights.mesh = st.commit()
	# Its own copy: its strength follows this village's night.
	lights.material_override = twinkle_material().duplicate()
	lights.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lights.extra_cull_margin = 6.0
	lights.visibility_range_end = 110.0 * GameSettings.view_scale()
	lights.set_meta("visual_only", true)
	add_child(lights)


# --- Snow ---------------------------------------------------------------------------------------

const SNOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;
uniform vec3 box = vec3(46.0, 26.0, 46.0);
uniform float fall = 1.3;
uniform float wind = 0.35;
varying float fade;
void vertex() {
	float ph = UV2.x;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 p = VERTEX * box;
	p.y -= TIME * fall * (0.7 + 0.6 * ph);
	p.x += TIME * wind + sin(TIME * 0.9 + ph * 40.0) * 0.7;
	p.z += cos(TIME * 0.7 + ph * 30.0) * 0.5;
	vec3 rel = mod(p - cam + box * 0.5, box) - box * 0.5;
	vec3 world = cam + rel;
	vec3 e = abs(rel) / (box * 0.5);
	fade = (1.0 - smoothstep(0.7, 1.0, max(max(e.x, e.y), e.z))) * smoothstep(0.8, 2.5, length(rel)) * step(0.0, world.y);
	vec4 view = VIEW_MATRIX * vec4(world, 1.0);
	view.xy += (UV - 0.5) * UV2.y;
	VERTEX = view.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
	float d = length(UV - 0.5);
	float a = smoothstep(0.5, 0.25, d) * 0.9 * fade;
	ALBEDO = vec3(1.0, 1.0, 1.0);
	ALPHA = a;
}
"""


static func snow_count() -> int:
	if MemoryGuard.pressure >= 2:
		return 0
	return int(float(SNOW[VfxBudget.quality()]) * MemoryGuard.effect_scale())


func _build_snow() -> void:
	var n := snow_count()
	if n <= 0:
		return
	if _snow_mat == null:
		var shader := Shader.new()
		shader.code = SNOW_SHADER
		_snow_mat = ShaderMaterial.new()
		_snow_mat.shader = shader
		_snow_mat.set_shader_parameter("box", SNOW_BOX)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1225
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for k in n:
		var home := Vector3(rng.randf(), rng.randf(), rng.randf())
		var phase := rng.randf()
		var size := rng.randf_range(0.07, 0.16)
		for c in corners:
			st.set_uv(c)
			st.set_uv2(Vector2(phase, size))
			st.set_normal(Vector3.BACK)
			st.add_vertex(home)
		var i := k * 4
		for j in [0, 1, 2, 0, 2, 3]:
			st.add_index(i + j)
	snow = MeshInstance3D.new()
	snow.name = "Snowfall"
	snow.mesh = st.commit()
	snow.material_override = _snow_mat
	snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The flakes follow the camera in the shader: never culled while in the village.
	snow.custom_aabb = AABB(Vector3(-400, -100, -400), Vector3(800, 300, 800))
	snow.set_meta("visual_only", true)
	add_child(snow)


# --- Fireworks ----------------------------------------------------------------------------------

const FIRE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;
uniform vec3 center = vec3(0.0, 0.0, -6.0);
uniform float spread = 30.0;
uniform float h_lo = 22.0;
uniform float h_hi = 34.0;
uniform float radius = 13.0;
uniform float period = 3.6;
uniform float active = 8.0;
uniform float boost = 0.0;
varying vec3 col;
varying float alpha;
vec3 hash3(float n) {
	return fract(sin(vec3(n, n + 1.31, n + 2.77)) * vec3(43758.5453, 22578.1459, 19642.349));
}
vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}
void vertex() {
	float k = floor(UV2.x);
	float per = mix(period, period * 0.55, boost) * (0.85 + 0.3 * fract(k * 0.618));
	float t = TIME / per + fract(k * 0.371);
	float cyc = floor(t);
	float f = fract(t);
	vec3 h = hash3(k * 17.0 + cyc * 3.1);
	vec3 c = center + vec3((h.x - 0.5) * 2.0 * spread, mix(h_lo, h_hi, h.y), (h.z - 0.5) * spread);
	float rad = radius * (0.7 + 0.6 * fract(h.x * 7.0)) * (1.0 + 0.6 * boost);
	vec3 pos;
	float s = UV2.y;
	float lift = 0.22;
	if (f < lift) {
		float u = f / lift;
		pos = vec3(c.x, mix(3.0, c.y, 1.0 - (1.0 - u) * (1.0 - u)), c.z);
		alpha = COLOR.r;
		s *= 0.7;
		col = vec3(1.0, 0.8, 0.5);
	} else {
		// A trail quad (COLOR.b) follows its spark a little behind, fainter and smaller.
		float u = max(0.0, (f - lift) / (1.0 - lift) - COLOR.b * 0.045);
		float e = 1.0 - pow(1.0 - u, 3.0);
		s *= 1.0 - COLOR.b * 0.35;
		pos = c + VERTEX * rad * e + vec3(0.0, -5.0 * u * u, 0.0);
		alpha = pow(1.0 - u, 1.3) * (0.7 + 0.3 * sin(TIME * 31.0 + COLOR.g * 60.0));
		col = mix(hue(h.z), hue(fract(h.z + 0.45)), step(0.62, COLOR.g));
		col = mix(col, vec3(1.0), smoothstep(0.12, 0.0, u) * 0.8);
		alpha *= 1.0 - COLOR.b * 0.5;
	}
	alpha *= step(k + 0.5, active);
	vec4 view = VIEW_MATRIX * vec4(pos, 1.0);
	view.xy += (UV - 0.5) * s;
	VERTEX = view.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
	float d = length(UV - 0.5);
	float a = pow(smoothstep(0.5, 0.0, d), 1.5) * alpha;
	ALBEDO = mix(col, vec3(1.0), smoothstep(0.15, 0.0, d)) * a;
	ALPHA = a;
}
"""


static func burst_count() -> int:
	if MemoryGuard.pressure >= 2:
		return 2
	return FIREWORKS[VfxBudget.quality()]


func _build_fireworks() -> void:
	if GameSettings.safe_picture:
		return
	var bursts := burst_count()
	var sparks: int = SPARKS[VfxBudget.quality()]
	if _fire_mat == null:
		var shader := Shader.new()
		shader.code = FIRE_SHADER
		_fire_mat = ShaderMaterial.new()
		_fire_mat.shader = shader
	var rng := RandomNumberGenerator.new()
	rng.seed = Christmas.YEAR
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var q := 0
	for k in bursts:
		for s in sparks:
			# Evenly round a sphere (a Fibonacci spiral), a little jitter.
			var y := 1.0 - 2.0 * (float(s) + 0.5) / float(sparks)
			var r := sqrt(maxf(0.0, 1.0 - y * y))
			var a := float(s) * 2.39996 + float(k)
			var dir := Vector3(cos(a) * r, y, sin(a) * r) * rng.randf_range(0.85, 1.05)
			var tone := rng.randf()
			var size := rng.randf_range(1.4, 2.1)
			# The spark, then its trail quad.
			for trail in 2:
				for c in corners:
					st.set_color(Color(1.0 if s == 0 and trail == 0 else 0.0, tone, float(trail), 1.0))
					st.set_uv(c)
					st.set_uv2(Vector2(float(k) + 0.5, size))
					st.set_normal(Vector3.BACK)
					st.add_vertex(dir)
				for j in [0, 1, 2, 0, 2, 3]:
					st.add_index(q * 4 + j)
				q += 1
	fireworks = MeshInstance3D.new()
	fireworks.name = "Fireworks"
	fireworks.mesh = st.commit()
	fireworks.material_override = _fire_mat.duplicate()
	(fireworks.material_override as ShaderMaterial).set_shader_parameter("center", FIREWORK_CENTER)
	(fireworks.material_override as ShaderMaterial).set_shader_parameter("active", float(bursts))
	fireworks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fireworks.custom_aabb = AABB(Vector3(-80, -10, -80), Vector3(160, 90, 160))
	fireworks.set_meta("visual_only", true)
	fireworks.visible = false
	add_child(fireworks)


func _build_sign() -> void:
	sign_label = Label3D.new()
	sign_label.name = "NewYearSign"
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.font_size = 110
	sign_label.pixel_size = 0.02
	sign_label.outline_size = 24
	sign_label.modulate = Color("ffe066")
	sign_label.outline_modulate = Color("7a1020")
	sign_label.position = TREE_AT + Vector3(0, TREE_HEIGHT + 3.4, 0)
	sign_label.visibility_range_end = 140.0
	sign_label.no_depth_test = false
	sign_label.visible = false
	add_child(sign_label)


# --- Every second -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	_update(Christmas.now())


## The bulbs follow the night, the fireworks and the sign the countdown; at midnight the
## banner and the big burst.
func _update(now: float) -> void:
	var night := 0.0
	var dn: Variant = zone.get("day_night") if zone != null else null
	if dn is DayNight and is_instance_valid(dn):
		night = clampf((dn as DayNight).now.night, 0.0, 1.0)
	elif not is_nan(DayNight.fixed_hour):
		night = clampf(DayNight.night_light(DayNight.fixed_hour), 0.0, 1.0)
	if Christmas.bonus_on(now):
		night = 1.0
	if lights != null and absf(night - _night) > 0.01:
		_night = night
		(lights.material_override as ShaderMaterial).set_shader_parameter("night", night)
	var on_now := Christmas.fireworks_on(now)
	if fireworks != null:
		fireworks.visible = on_now
		if on_now:
			var burst := Christmas.burst(now)
			var mat := fireworks.material_override as ShaderMaterial
			mat.set_shader_parameter("boost", burst)
	sign_label.visible = on_now
	if on_now:
		if now < float(Christmas.NEW_YEAR):
			var left := int(ceil(float(Christmas.NEW_YEAR) - now))
			sign_label.text = "นับถอยหลังสู่ปี %d\n%02d:%02d:%02d" % [Christmas.YEAR, left / 3600, (left % 3600) / 60, left % 60]
			sign_label.modulate = Color("e8f4ff")
		else:
			sign_label.text = "%s!" % Christmas.NEW_YEAR_TEXT
			sign_label.modulate = Color("ffe066")
			if not _told_new and now - float(Christmas.NEW_YEAR) < Christmas.BURST_LENGTH:
				_told_new = true
				if zone != null and zone.has_signal("banner_requested"):
					zone.emit_signal("banner_requested", "%s!" % Christmas.NEW_YEAR_TEXT)
				if not GameSettings.safe_picture:
					Game.screen_flash.emit(Color("ffe066"), 0.25)
