class_name DayNight
extends Node
## Morning, day, evening and night on the world's clock: Thai time on
## WorldPlayers.world_time (SPEED x real time, so a world day passes every 8 real
## hours and the sky agrees with the world players' schedules).
##
## One node per zone that follows the clock (CLOCK_ZONES: the village and the open
## hunting fields; fixed-mood places such as the moonlit fields, the star and divine
## regions, the tower, the arenas and the guild war keep their own sky). Every UPDATE
## seconds it re-grades the zone's WorldEnvironment and sun by blending the zone's
## designed look toward the phase's tint (KEYS); from DAY_FROM to DAY_TO the look IS the
## designed one. At night the sun turns into cool moonlight, a moon and stars come out
## (one additive MultiMesh, hidden by day) and the "night_glow" props (the village's
## lantern halos) shine brighter, with soft amber pools on the ground under them. A warm
## zone (the village, `warmth` 1) gets a more golden morning and sunset and a cozy night:
## a deep blue sky over warm ambient light and bright lantern pools. No new lights, no render passes; the sky material and
## the light are only touched when the change is visible (a sky change re-renders its
## radiance), so a steady day or night costs nothing.
##
## Tests and screenshots: `DayNight.fixed_hour` (NAN follows the clock) or TOON_HOUR=21.5
## in the environment. Headless runs and the tools under res://tests/ start at midday
## (TOON_HOUR=clock follows the clock there too).

## Zones whose sky follows the clock.
const CLOCK_ZONES: Array[StringName] = [&"town", &"meadow", &"desert", &"snow", &"swamp", &"sky"]
## Seconds between two re-grades.
const UPDATE := 0.5
## The designed look holds from DAY_FROM to DAY_TO (world hours).
const DAY_FROM := 9.5
const DAY_TO := 15.5
## The designed sun (Scenery.environment) at noon, and the moonlight at night (degrees).
const NOON_PITCH := -42.0
const NOON_YAW := -32.0
const MOON_PITCH := -40.0
const MOON_YAW := -6.0
## The smallest change worth re-rendering the sky for.
const SKY_STEP := 0.012
const ANGLE_STEP := 0.4

## Tint keys over the day: [hour, sky top, k, horizon, k, fog, k, ambient, k, ambient energy x,
## sun, k, sun energy x, cloud multiply, night (stars, moon), lantern glow x, shadow opacity x].
## Each colour is the zone's own one lerped toward the key's by k; between two keys the
## results blend with a smoothstep, so every value is continuous (KEYS[0] == KEYS[-1]).
const NIGHT_KEY := [Color("0a1230"), 0.86, Color("22346a"), 0.8, Color("141f44"), 0.85, Color("5f78c4"), 0.72, 0.95,
	Color("9ab2f2"), 1.0, 0.44, Color(0.26, 0.32, 0.5), 1.0, 2.2, 0.55]
const DAY_KEY := [Color.WHITE, 0.0, Color.WHITE, 0.0, Color.WHITE, 0.0, Color.WHITE, 0.0, 1.0,
	Color.WHITE, 0.0, 1.0, Color.WHITE, 0.0, 1.0, 1.0]
const KEYS := [
	[0.0, NIGHT_KEY],
	[4.7, NIGHT_KEY],
	# Blue hour before sunrise: a pink horizon under a deep sky, stars fading.
	[5.6, [Color("283066"), 0.72, Color("e08a7c"), 0.62, Color("6a5682"), 0.62, Color("9a8cc0"), 0.55, 0.95,
		Color("ffa880"), 0.8, 0.55, Color(0.6, 0.5, 0.62), 0.45, 1.9, 0.6]],
	# Sunrise: golden, low warm light.
	[6.6, [Color("8cb0dc"), 0.35, Color("ffd890"), 0.7, Color("fad8a8"), 0.5, Color("ffe6bc"), 0.32, 1.08,
		Color("ffcc80"), 0.7, 1.0, Color(1.0, 0.88, 0.74), 0.0, 1.2, 0.85]],
	# Morning: a warm wash fading into the day's own colours.
	[8.1, [Color("88b4e2"), 0.1, Color("fbe4c0"), 0.28, Color("f6e2c4"), 0.2, Color("fff0dc"), 0.12, 1.0,
		Color("ffe2b4"), 0.3, 1.0, Color(1.0, 0.95, 0.9), 0.0, 1.0, 1.0]],
	[DAY_FROM, DAY_KEY],
	[DAY_TO, DAY_KEY],
	# Late afternoon: the light goes golden.
	[16.8, [Color("7aa6dc"), 0.1, Color("ffd49a"), 0.38, Color("f8d2a0"), 0.3, Color("ffe0b8"), 0.2, 1.0,
		Color("ffc480"), 0.5, 0.98, Color(1.0, 0.9, 0.8), 0.0, 1.0, 1.0]],
	# Sunset: an orange and pink horizon, the sun red-gold and low.
	[18.0, [Color("3e4c98"), 0.55, Color("ff8a64"), 0.8, Color("e88a84"), 0.6, Color("e89ab0"), 0.45, 0.9,
		Color("ff7c44"), 0.88, 0.82, Color(1.0, 0.64, 0.6), 0.06, 1.6, 0.8]],
	# Dusk: violet horizon, the first stars, the lanterns already bright.
	[19.1, [Color("1a2254"), 0.8, Color("7c4e86"), 0.7, Color("3e3466"), 0.72, Color("8a80c8"), 0.62, 0.95,
		Color("a898e0"), 0.95, 0.48, Color(0.44, 0.42, 0.6), 0.7, 2.0, 0.6]],
	[20.3, NIGHT_KEY],
	[24.0, NIGHT_KEY],
]

static var fixed_hour := _initial_hour()


## One graded look: what the zone's environment and sun are set to.
class Look:
	var top := Color.WHITE
	var horizon := Color.WHITE
	var fog := Color.WHITE
	var ambient := Color.WHITE
	var ambient_energy := 0.33
	var sun := Color.WHITE
	var sun_energy := 0.6
	var cloud := Color.WHITE
	var night := 0.0
	var lantern := 1.0
	var shadow := 0.68
	var sun_angle := 6.0

	func copy_from(o: Look) -> void:
		top = o.top; horizon = o.horizon; fog = o.fog; ambient = o.ambient
		ambient_energy = o.ambient_energy; sun = o.sun; sun_energy = o.sun_energy; cloud = o.cloud
		night = o.night; lantern = o.lantern; shadow = o.shadow; sun_angle = o.sun_angle

	## Luma of the light falling on an upward face (sun at its elevation plus the ambient):
	## what the tests hold above a readability floor.
	func brightness(elevation_deg: float) -> float:
		var luma := func(c: Color) -> float: return c.r * 0.299 + c.g * 0.587 + c.b * 0.114
		return float(luma.call(sun)) * sun_energy * sin(deg_to_rad(elevation_deg)) + float(luma.call(ambient)) * ambient_energy


var zone: Node3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var radius := 60.0
## 0..1: how much warmer the golden hours and the night are (the village: 1).
var warmth := 0.0
## The zone's designed look and the one applied now.
var base := Look.new()
var now := Look.new()
var _ka := Look.new()
var _kb := Look.new()
var _timer := 0.0
var _sky_top := Color(-1, -1, -1)
var _sky_horizon := Color(-1, -1, -1)
var _sky_angle := -1.0
var _light_color := Color(-1, -1, -1)
var _light_energy := -1.0
var _light_angles := Vector2(INF, INF)
var _night_sky: MultiMeshInstance3D
var _night_mat: StandardMaterial3D
var _dots: MultiMeshInstance3D
var _dot_base: Array[Color] = []
var _disc := Vector3(INF, INF, INF)
var _cloud_mat: StandardMaterial3D
var _haze_mat: StandardMaterial3D
## [material, designed albedo, additive] of the weather and smoke particles.
var _particles: Array = []
## [node, material, designed buffer] of the "night_glow" MultiMeshes.
var _glows: Array = []
var _glow_level := -1.0
## Amber pools on the ground under the lanterns (one additive MultiMesh, shown after dark).
var _pools: MultiMeshInstance3D
var _pool_mat: StandardMaterial3D
## Frames left in which the night layers stay drawn (invisibly, alpha 0 by day) so their
## shaders compile behind the travel fade rather than at the first dusk.
var _warm_frames := 4
var _cloud_tint := Color(-1, -1, -1)


static func _initial_hour() -> float:
	var value := OS.get_environment("TOON_HOUR")
	if value.is_valid_float():
		return fposmod(float(value), 24.0)
	if value == "clock":
		return NAN
	if DisplayServer.get_name() == "headless":
		return 12.0
	for arg in OS.get_cmdline_args():
		if String(arg).begins_with("res://tests/"):
			return 12.0
	return NAN


## The world's hour of the day now (0..24, Thai time on the world clock).
static func hour() -> float:
	if not is_nan(fixed_hour):
		return fixed_hour
	return world_hour(WorldPresence.clock())


## The world's hour of the day at real unix time t.
static func world_hour(t: float) -> float:
	return fposmod(WorldPlayers.world_time(t) + float(WorldPlayers.TZ), 86400.0) / 3600.0


static func follows(zone_id: StringName) -> bool:
	return zone_id in CLOCK_ZONES


## &"morning" 05-09, &"day" 09-16, &"evening" 16-19, &"night" 19-05.
static func phase(h: float) -> StringName:
	if h >= 5.0 and h < 9.0:
		return &"morning"
	if h >= 9.0 and h < 16.0:
		return &"day"
	if h >= 16.0 and h < 19.0:
		return &"evening"
	return &"night"


static func phase_label(h: float) -> String:
	return {&"morning": "เช้า", &"day": "กลางวัน", &"evening": "เย็น", &"night": "กลางคืน"}[phase(h)]


## "HH:MM" of an hour.
static func clock_text(h: float) -> String:
	var minutes := int(floor(fposmod(h, 24.0) * 60.0))
	return "%02d:%02d" % [minutes / 60, minutes % 60]


## The sun's light angles (pitch, yaw in degrees) at hour h: rising low in the east,
## the designed (-42, -32) at noon, setting low; the moonlight from dusk to dawn.
static func light_angles(h: float) -> Vector2:
	var s := clampf((h - 6.0) / 12.0, 0.0, 1.0)
	var sun_angles := Vector2(-(18.0 + 24.0 * sin(PI * s)), NOON_YAW + clampf(h - 12.0, -6.5, 6.5) * 7.0)
	var moon := night_light(h)
	return sun_angles.lerp(Vector2(MOON_PITCH, MOON_YAW), moon)


## How far the light has turned into moonlight (0 by day, 1 at night).
static func night_light(h: float) -> float:
	return smoothstep(18.5, 19.5, h) if h >= 12.0 else 1.0 - smoothstep(4.8, 5.8, h)


## The sun disc's height over the horizon (degrees; below 0 it has set).
static func disc_elevation(h: float) -> float:
	return 42.0 * sin(PI * (h - 5.6) / 12.8) if h > 3.0 and h < 21.0 else -42.0


## The look at hour h for a zone designed as `designed`; `out` receives it (ka / kb are
## scratch Looks, so a running zone allocates nothing).
static func sample(h: float, designed: Look, out: Look, ka: Look = null, kb: Look = null, warm := 0.0) -> Look:
	h = fposmod(h, 24.0)
	if ka == null:
		ka = Look.new()
	if kb == null:
		kb = Look.new()
	var i := 0
	while i < KEYS.size() - 2 and h >= float(KEYS[i + 1][0]):
		i += 1
	var h0 := float(KEYS[i][0])
	var h1 := float(KEYS[i + 1][0])
	var t := smoothstep(0.0, 1.0, (h - h0) / maxf(h1 - h0, 0.0001))
	_key(KEYS[i][1], designed, ka)
	_key(KEYS[i + 1][1], designed, kb)
	out.top = ka.top.lerp(kb.top, t)
	out.horizon = ka.horizon.lerp(kb.horizon, t)
	out.fog = ka.fog.lerp(kb.fog, t)
	out.ambient = ka.ambient.lerp(kb.ambient, t)
	out.ambient_energy = lerpf(ka.ambient_energy, kb.ambient_energy, t)
	out.sun = ka.sun.lerp(kb.sun, t)
	out.sun_energy = lerpf(ka.sun_energy, kb.sun_energy, t)
	out.cloud = ka.cloud.lerp(kb.cloud, t)
	out.night = lerpf(ka.night, kb.night, t)
	out.lantern = lerpf(ka.lantern, kb.lantern, t)
	out.shadow = lerpf(ka.shadow, kb.shadow, t)
	out.sun_angle = lerpf(ka.sun_angle, kb.sun_angle, t)
	if t <= 0.0:
		out.copy_from(ka)
	elif t >= 1.0:
		out.copy_from(kb)
	if warm > 0.0:
		_warm_up(h, out, warm)
	return out


## A warm zone's extra: golden light at sunrise and sunset, warm ambient and fog, brighter
## lanterns at night (the deep blue sky stays). Nothing changes in the day.
static func _warm_up(h: float, out: Look, warm: float) -> void:
	var gold := golden(h) * warm
	var n := out.night * warm
	out.sun = out.sun.lerp(Color("ffae5c"), gold * 0.3)
	out.ambient = out.ambient.lerp(Color("ffcf9c"), gold * 0.18).lerp(Color("d8a47c"), n * 0.5)
	out.ambient_energy *= 1.0 + n * 0.1
	out.horizon = out.horizon.lerp(Color("ffb27a"), gold * 0.16).lerp(Color("5a4878"), n * 0.22)
	out.fog = out.fog.lerp(Color("ffc890"), gold * 0.14).lerp(Color("4a3a5c"), n * 0.3)
	out.cloud = out.cloud.lerp(Color(1.0, 0.8, 0.66), gold * 0.25)
	out.lantern *= 1.0 + n * 0.3


## 0..1: how golden the hour is (sunrise to mid-morning, late afternoon to dusk).
static func golden(h: float) -> float:
	return smoothstep(5.4, 6.6, h) * (1.0 - smoothstep(7.6, 9.4, h)) + smoothstep(15.6, 17.0, h) * (1.0 - smoothstep(18.6, 19.5, h))


static func _key(key: Array, d: Look, out: Look) -> void:
	out.top = d.top.lerp(key[0], key[1])
	out.horizon = d.horizon.lerp(key[2], key[3])
	out.fog = d.fog.lerp(key[4], key[5])
	out.ambient = d.ambient.lerp(key[6], key[7])
	out.ambient_energy = d.ambient_energy * float(key[8])
	out.sun = d.sun.lerp(key[9], key[10])
	out.sun_energy = d.sun_energy * float(key[11])
	out.cloud = key[12]
	out.night = key[13]
	out.lantern = key[14]
	out.shadow = d.shadow * float(key[15])
	# The sky's own sun disc shrinks to a small moon at night.
	out.sun_angle = lerpf(d.sun_angle, minf(d.sun_angle, 1.6), float(key[13]))


## Adds the day/night node to a built zone (its WorldEnvironment `world_env`, the sun it
## made beside it, the SkyDressing) and grades it for the hour at once.
static func attach(p_zone: Node3D, world_env: WorldEnvironment, p_radius: float, p_warmth := 0.0) -> DayNight:
	if world_env == null or world_env.environment == null:
		return null
	var node := DayNight.new()
	node.name = "DayNight"
	node.zone = p_zone
	node.radius = p_radius
	node.warmth = p_warmth
	node.env = world_env.environment
	for child in p_zone.get_children():
		if child is DirectionalLight3D and child.is_in_group("sun"):
			node.sun = child
			break
	if node.env.sky:
		node.sky_mat = node.env.sky.sky_material as ProceduralSkyMaterial
	if node.sun == null or node.sky_mat == null:
		return null
	node._capture()
	p_zone.add_child(node)
	node.apply(true)
	return node


func _capture() -> void:
	base.top = sky_mat.sky_top_color
	base.horizon = sky_mat.sky_horizon_color
	base.fog = env.fog_light_color
	base.ambient = env.ambient_light_color
	base.ambient_energy = env.ambient_light_energy
	base.sun = sun.light_color
	base.sun_energy = sun.light_energy
	base.shadow = sun.shadow_opacity
	base.sun_angle = sky_mat.sun_angle_max
	now.copy_from(base)
	var dressing := zone.get_node_or_null("SkyDressing")
	var holder: Node3D = dressing if dressing is Node3D else zone
	if dressing:
		var clouds := dressing.get_node_or_null("Clouds") as MultiMeshInstance3D
		if clouds:
			_cloud_mat = clouds.material_override as StandardMaterial3D
		var haze := dressing.get_node_or_null("Haze") as MeshInstance3D
		if haze:
			_haze_mat = haze.material_override as StandardMaterial3D
		_dots = dressing.get_node_or_null("SkyDots") as MultiMeshInstance3D
		if _dots and _dots.multimesh.instance_count >= 2:
			_dot_base = [_dots.multimesh.get_instance_color(0), _dots.multimesh.get_instance_color(1)]
		else:
			_dots = null
	for holder_name in ["Weather", "VillageLife"]:
		var group := zone.get_node_or_null(holder_name)
		if group == null:
			continue
		for p in group.get_children():
			var quad := (p as CPUParticles3D).mesh as QuadMesh if p is CPUParticles3D else null
			var mat := quad.material as StandardMaterial3D if quad else null
			if mat:
				_particles.append([mat, mat.albedo_color, mat.blend_mode == BaseMaterial3D.BLEND_MODE_ADD])
	for node in zone.get_tree().get_nodes_in_group("night_glow") if zone.is_inside_tree() else []:
		var mmi := node as MultiMeshInstance3D
		if mmi and mmi.material_override is StandardMaterial3D and zone.is_ancestor_of(mmi):
			_glows.append([mmi, mmi.material_override, mmi.multimesh.buffer])
	_build_night_sky(holder)
	_build_pools()


## The moon (disc and two halos, at the moonlight's direction) and the stars: one additive
## MultiMesh shown only while it is dark.
func _build_night_sky(holder: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90717
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var moon_dir := Basis.from_euler(Vector3(deg_to_rad(-21.0), deg_to_rad(MOON_YAW - 14.0), 0)).z
	var moon_pos := moon_dir * (radius + 50.0)
	for spec in [[5.2, Color("fbf6e4"), 1.0], [13.0, Color("dfe6ff"), 0.32], [34.0, Color("9fb4ff"), 0.12]]:
		transforms.append(Transform3D(Basis.from_scale(Vector3.ONE * float(spec[0])), moon_pos))
		colors.append(Color(spec[1], spec[2]))
	var count: int = [70, 120, 170][clampi(GameSettings.quality, 0, 2)]
	for i in count:
		var a := rng.randf() * TAU
		var pitch := asin(rng.randf_range(0.12, 0.98))
		var d := radius + rng.randf_range(22.0, 60.0)
		var star := Vector3(cos(a) * cos(pitch), sin(pitch), sin(a) * cos(pitch)) * d
		var bright := rng.randf() < 0.12
		var size := rng.randf_range(1.3, 2.1) if bright else rng.randf_range(0.55, 1.15)
		transforms.append(Transform3D(Basis.from_scale(Vector3.ONE * size), star))
		var tint := Color("ffffff").lerp([Color("bcd0ff"), Color("ffe8c0"), Color("ffffff")][i % 3], rng.randf() * 0.6)
		colors.append(Color(tint, rng.randf_range(0.75, 1.0) if bright else rng.randf_range(0.4, 0.85)))
	_night_sky = Scenery._billboards(holder, "NightSky", transforms, colors, true)
	_night_sky.set_meta("visual_only", true)
	_night_mat = _night_sky.material_override as StandardMaterial3D
	_night_sky.visible = false


## Soft amber discs on the ground under every "night_glow" lantern that hangs low enough
## to light the street (from the halos' own positions: the larger halo of each pair).
func _build_pools() -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var flat := Basis(Vector3.RIGHT, -PI * 0.5)
	for entry in _glows:
		var mm := (entry[0] as MultiMeshInstance3D).multimesh
		for i in range(0, mm.instance_count, 2):
			var at := (entry[0] as MultiMeshInstance3D).global_transform * mm.get_instance_transform(i).origin
			if at.y > 6.5:
				continue
			var reach := clampf(2.4 + at.y * 1.2, 3.0, 6.5)
			transforms.append(Transform3D(flat.scaled(Vector3(reach, reach, 1.0)), Vector3(at.x, 0.09, at.z)))
			colors.append(Color(Color("ffa848").lerp(mm.get_instance_color(i), 0.2), 0.5))
	if transforms.is_empty():
		return
	_pools = Scenery._billboards(zone, "LanternPools", transforms, colors, true)
	_pool_mat = _pools.material_override as StandardMaterial3D
	_pool_mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	_pools.visibility_range_end = 70.0 * GameSettings.view_scale()
	_pools.set_meta("visual_only", true)


func _process(delta: float) -> void:
	if _warm_frames > 0:
		_warm_frames -= 1
		if _warm_frames == 0:
			_timer = 0.0
	_timer -= delta
	if _timer <= 0.0:
		_timer = UPDATE
		apply()


## Grades the zone for the current hour (`force` re-sets everything, e.g. after a jump).
func apply(force := false) -> void:
	if env == null or not is_instance_valid(sun):
		return
	var h := hour()
	sample(h, base, now, _ka, _kb, warmth)
	var flashing: bool = zone.has_method("is_flashing") and zone.is_flashing()
	if "_ambient_base" in zone:
		zone.set("_ambient_base", now.ambient_energy)
	if not flashing:
		env.ambient_light_energy = now.ambient_energy
		env.fog_light_color = now.fog
	env.ambient_light_color = now.ambient
	if force or _far(_sky_top, now.top) or _far(_sky_horizon, now.horizon) or absf(_sky_angle - now.sun_angle) > 0.05:
		_sky_top = now.top
		_sky_horizon = now.horizon
		_sky_angle = now.sun_angle
		sky_mat.sky_top_color = now.top
		sky_mat.sky_horizon_color = now.horizon
		sky_mat.ground_bottom_color = now.horizon.darkened(0.25)
		sky_mat.ground_horizon_color = now.horizon
		sky_mat.sun_angle_max = now.sun_angle
		if _haze_mat:
			_haze_mat.albedo_color = Color(_ratio(now.horizon.r, base.horizon.r), _ratio(now.horizon.g, base.horizon.g), _ratio(now.horizon.b, base.horizon.b))
	if force or _far(_light_color, now.sun) or absf(_light_energy - now.sun_energy) > 0.01:
		_light_color = now.sun
		_light_energy = now.sun_energy
		sun.light_color = now.sun
		sun.light_energy = now.sun_energy
	var angles := light_angles(h)
	if force or absf(angles.x - _light_angles.x) > ANGLE_STEP or absf(angles.y - _light_angles.y) > ANGLE_STEP:
		_light_angles = angles
		sun.rotation_degrees = Vector3(angles.x, angles.y, 0.0)
	sun.shadow_opacity = now.shadow
	if force or _far(_cloud_tint, now.cloud):
		_cloud_tint = now.cloud
		if _cloud_mat:
			_cloud_mat.albedo_color = now.cloud
		var dim := now.cloud.lerp(Color.WHITE, 0.25)
		var shine := 1.0 + (now.lantern - 1.0) * 0.35
		for entry in _particles:
			var c: Color = entry[1]
			(entry[0] as StandardMaterial3D).albedo_color = Color(c.r * shine, c.g * shine, c.b * shine, c.a) if entry[2] else Color(c.r * dim.r, c.g * dim.g, c.b * dim.b, c.a)
	_update_disc(h, force)
	var warming := _warm_frames > 0
	_night_sky.visible = now.night > 0.01 or warming
	_night_mat.albedo_color = Color(1, 1, 1, clampf(now.night, 0.0, 1.0))
	if _pools:
		var pool := clampf((now.lantern - 1.0) / 1.3, 0.0, 1.0)
		_pools.visible = pool > 0.01 or warming
		_pool_mat.albedo_color = Color(1, 1, 1, pool)
	if force or absf(now.lantern - _glow_level) > 0.04:
		_glow_level = now.lantern
		_update_glows()


func _update_disc(h: float, force: bool) -> void:
	if _dots == null:
		return
	var elevation := disc_elevation(h)
	var yaw := NOON_YAW + clampf(h - 12.0, -7.0, 7.0) * 7.0
	var shown := smoothstep(-3.0, 5.0, elevation)
	var key := Vector3(elevation, yaw, shown)
	if not force and absf(key.x - _disc.x) < 0.3 and absf(key.y - _disc.y) < 0.3 and absf(key.z - _disc.z) < 0.02:
		return
	_disc = key
	_dots.visible = shown > 0.005
	var pos := Basis.from_euler(Vector3(deg_to_rad(-elevation), deg_to_rad(yaw), 0)).z * (radius + 50.0)
	var mm := _dots.multimesh
	var warm := 1.0 - smoothstep(10.0, 30.0, elevation)
	for i in 2:
		var t := mm.get_instance_transform(i)
		mm.set_instance_transform(i, Transform3D(t.basis, pos))
		var c := _dot_base[i].lerp(Color("ff8a50") if i == 1 else Color("ffe2b0"), warm * 0.75)
		mm.set_instance_color(i, Color(c, _dot_base[i].a * shown))


## The lantern halos: brighter and a little larger after dark, as designed by day.
func _update_glows() -> void:
	var level := now.lantern
	var grow := 1.0 + (level - 1.0) * 0.22
	for entry in _glows:
		if not is_instance_valid(entry[0]):
			continue
		var mmi: MultiMeshInstance3D = entry[0]
		# Brighter but still amber: red climbs most, blue least, so the halos never blow out white.
		var up := level - 1.0
		(entry[1] as StandardMaterial3D).albedo_color = Color(1.0 + up * 0.55, 1.0 + up * 0.38, 1.0 + up * 0.12, 1.0)
		# The designed instances (kept in RAM since they were set from script; a headless
		# run has none, and then only the colour changes).
		var designed: PackedFloat32Array = entry[2]
		var stride := 12 + (4 if mmi.multimesh.use_colors else 0) + (4 if mmi.multimesh.use_custom_data else 0)
		if designed.size() != mmi.multimesh.instance_count * stride or mmi.multimesh.transform_format != MultiMesh.TRANSFORM_3D:
			continue
		var buffer := designed.duplicate()
		if grow != 1.0:
			var at := 0
			while at + 11 < buffer.size():
				for k in [0, 1, 2, 4, 5, 6, 8, 9, 10]:
					buffer[at + k] *= grow
				at += stride
		mmi.multimesh.buffer = buffer


static func _far(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) > SKY_STEP or absf(a.g - b.g) > SKY_STEP or absf(a.b - b.b) > SKY_STEP


static func _ratio(a: float, b: float) -> float:
	return clampf(a / maxf(b, 0.02), 0.0, 1.6)
