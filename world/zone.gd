class_name Zone
extends Node3D
## One playable area: the village or a hunting field. Builds the scenery,
## the hero and camera, portals, NPCs (village) or monster spawning and loot
## (fields). The persistent HUD (in Main) talks to it through signals.

signal travel_requested(zone_id: StringName)
signal interact_changed(label: String)
signal npc_interact(role: String)
signal hero_died()
signal banner_requested(text: String)
## A ranked duel ended (result: see Game.pvp_finish).
signal pvp_finished(result: Dictionary)
signal guildwar_finished(result: Dictionary)
## A Void Tower climb ended.
signal tower_finished(result: Dictionary)

const FIELD_RADIUS := 52.0
## The hunting fields (Lv.1 meadow to the Lv.100 void) are wider, with their outer camps
## (ZoneData.OUTER_CAMPS); the tower and the arena keep FIELD_RADIUS.
const HUNT_RADIUS := 74.0
const TOWN_RADIUS := JapanVillage.RADIUS
const SAFE_START_RADIUS := 14.0
const SPAWN_INTERVAL := 1.6
const DROP_RATE_GEAR := 0.14
const DROP_RATE_POTION := 0.3
const DROP_RATE_GEM := 0.07
## Chance that the Lv.100 boss drops a pair of wings (it respawns 1 minute after dying).
const WING_DROP_RATE := 0.35

var zone_id: StringName = &"meadow"
var data: Dictionary = {}
var is_town := false
var is_pvp := false
var gw_match: GuildWarMatch
var is_tower := false
var tower_run: TowerRun
var tower_start_floor := 1
var pvp_match: PvpMatch
var hero: Hero
var camera_rig: ThirdPersonCamera
var rng := RandomNumberGenerator.new()
var portals: Array[Dictionary] = []
var npcs: Array[Npc] = []
var companions: Array[Companion] = []
## Playable radius of this field (see HUNT_RADIUS).
var field_radius := FIELD_RADIUS
## The world players online here (see WorldPresence); none in duels, the tower or the arena.
var presence: WorldPresence
var current_interact: Dictionary = {}

## Ambient life per weather preset: layers of untracked CPUParticles3D that
## follow the hero and never draw from the combat VFX budget. Keys: amount (x
## particle_scale), life, size (float or Vector2), color, add (additive), dir,
## spread, speed [min, max], gravity, y (emitter height), box (half extents),
## scale [min, max], pulse (flicker over the lifetime), ring (ring texture),
## upright (streaks stay vertical).
const WEATHER := {
	&"snow": [{"amount": 110, "life": 7.0, "size": 0.16, "color": Color(1, 1, 1, 0.7), "dir": Vector3(0.15, -1, 0.05), "spread": 12.0, "speed": [1.6, 2.6], "y": 14.0}],
	&"embers": [{"amount": 48, "life": 4.5, "size": 0.12, "color": Color(1.0, 0.72, 0.45, 0.7), "add": true, "dir": Vector3(0.1, 1, 0.1), "spread": 20.0, "speed": [0.8, 2.2], "y": 0.4}],
	&"petals": [
		{"amount": 42, "life": 6.5, "size": Vector2(0.16, 0.11), "color": Color("ffc8da"), "dir": Vector3(0.5, -1, 0.2), "spread": 30.0, "speed": [0.5, 1.1], "gravity": Vector3(0.3, -0.2, 0.1), "y": 9.0, "scale": [0.6, 1.0]},
		{"amount": 36, "life": 8.0, "size": 0.07, "color": Color(1.0, 0.95, 0.7, 0.6), "add": true, "dir": Vector3(0.3, 0.1, 0.1), "spread": 60.0, "speed": [0.2, 0.6], "y": 1.5, "box": Vector3(26, 1.2, 26), "pulse": true},
	],
	&"fireflies": [{"amount": 46, "life": 6.0, "size": 0.12, "color": Color(0.75, 1.0, 0.5, 0.9), "add": true, "dir": Vector3(0, 0.2, 0), "spread": 80.0, "speed": [0.2, 0.5], "y": 1.2, "box": Vector3(26, 1.0, 26), "pulse": true}],
	&"sand": [{"amount": 64, "life": 5.0, "size": Vector2(0.22, 0.08), "color": Color(0.9, 0.8, 0.6, 0.45), "dir": Vector3(1, 0.05, 0.2), "spread": 10.0, "speed": [3.0, 5.0], "y": 0.8, "box": Vector3(26, 1.0, 26), "scale": [0.6, 1.6]}],
	&"rain": [{"amount": 170, "life": 1.3, "size": Vector2(0.04, 0.55), "color": Color(0.8, 0.9, 1.0, 0.5), "dir": Vector3(0.25, -1, 0.05), "spread": 3.0, "speed": [16.0, 20.0], "y": 16.0, "upright": true}],
	&"wisps": [{"amount": 30, "life": 7.0, "size": 0.26, "color": Color(0.6, 0.8, 1.0, 0.5), "add": true, "dir": Vector3(0, 0.3, 0), "spread": 70.0, "speed": [0.2, 0.5], "y": 1.0, "box": Vector3(26, 0.8, 26), "pulse": true}],
	&"brimstone": [
		{"amount": 44, "life": 4.5, "size": 0.12, "color": Color(1.0, 0.5, 0.4, 0.7), "add": true, "dir": Vector3(0.1, 1, 0.1), "spread": 20.0, "speed": [0.8, 2.2], "y": 0.4},
		{"amount": 20, "life": 7.0, "size": 0.3, "color": Color(1.0, 0.35, 0.4, 0.45), "add": true, "dir": Vector3(0, 0.3, 0), "spread": 70.0, "speed": [0.2, 0.5], "y": 1.0, "box": Vector3(26, 0.8, 26), "pulse": true},
	],
	&"runes": [
		{"amount": 30, "life": 7.0, "size": 0.34, "color": Color(0.7, 0.55, 1.0, 0.7), "add": true, "dir": Vector3(0, 1, 0), "spread": 15.0, "speed": [0.3, 0.7], "y": 0.6, "box": Vector3(26, 0.5, 26), "ring": true, "pulse": true},
		{"amount": 36, "life": 4.5, "size": 0.1, "color": Color(0.77, 0.7, 1.0, 0.6), "add": true, "dir": Vector3(0.1, 1, 0.1), "spread": 20.0, "speed": [0.8, 2.2], "y": 0.4},
	],
	&"motes": [
		{"amount": 44, "life": 7.0, "size": 0.1, "color": Color(1.0, 0.9, 0.55, 0.8), "add": true, "dir": Vector3(0.2, 0.3, 0.1), "spread": 60.0, "speed": [0.2, 0.6], "y": 2.0, "box": Vector3(26, 1.5, 26), "pulse": true},
		{"amount": 18, "life": 9.0, "size": Vector2(0.12, 0.3), "color": Color(1.0, 1.0, 1.0, 0.9), "dir": Vector3(0.4, -1, 0.2), "spread": 35.0, "speed": [0.3, 0.7], "gravity": Vector3(0.4, -0.15, 0.2), "y": 10.0, "scale": [0.6, 1.0]},
	],
}

var _spawn_timer := 0.0
var _weather: Node3D
var _env: WorldEnvironment
var _ambient_base := 0.33
var _arena_wave := 0
var _arena_state := "wait"
var _arena_timer := 4.0
var _arena_mobs: Array[Mob] = []
var _camps: Array[Dictionary] = []
var _boss: Mob
var _boss_timer := 8.0
var _boss_spot := Vector3.ZERO
## The world boss of the day (WorldEvents), while its window is on in this field.
var _wboss: Mob
var _portal_hold := 0.0
var _interact_timer := 0.0
var _start := Vector3.ZERO
var _kills := 0


## Build-time phases of the last zone (label, milliseconds), filled only while
## `phase_log` is on: tests/tools/zone_switch_probe.gd turns it on to find what a zone change costs.
static var phase_log := false
static var phases: Array = []
var _phase_t := 0

## Main.go builds a zone in slices, one per frame, behind the black fade (a phone otherwise
## stalls for a second or more at every zone change). Left off, the zone is complete as
## soon as it enters the tree, which is what tests and tools rely on.
var staged := false
signal built
var is_built := false
## A fixed layout seed rebuilds the same random scenery (tests, bug reports); 0 picks a new one.
var layout_seed := 0


func _slice() -> void:
	if staged and is_inside_tree():
		await FrameSlicer.pace(get_tree())


func _phase(label: String) -> void:
	if not phase_log:
		return
	var now := Time.get_ticks_usec()
	if _phase_t > 0:
		phases.append([label, snappedf(float(now - _phase_t) / 1000.0, 0.1)])
	_phase_t = now


func _ready() -> void:
	_phase("")
	FrameSlicer.begin()
	if layout_seed != 0:
		rng.seed = layout_seed
	else:
		rng.randomize()
	# Every monster that enters the zone (spawned or scripted) pays out when it dies.
	child_entered_tree.connect(func(node: Node):
		var mob := node as Mob
		if mob and not mob.died.is_connected(_on_mob_died):
			mob.died.connect(_on_mob_died)
			mob.phase_changed.connect(_on_boss_phase))
	data = ZoneData.get_zone(zone_id)
	is_town = bool(data.get("safe", false))
	is_pvp = bool(data.get("pvp", false))
	is_tower = bool(data.get("tower", false))
	await _slice()
	if is_town:
		await _build_town()
	elif is_pvp and bool(data.get("guildwar", false)):
		_build_siege()
	elif is_pvp:
		_build_pvp()
	else:
		await _build_field()
	_phase("build_world")
	await _slice()
	MemoryGuard.reset_scale_3d(get_tree())
	await VfxArt.warm_up(get_tree() if staged else null)
	if int(Game.paragon().level)>=50: StarGeometry.warm()
	_phase("warm_art")
	await _slice()
	_spawn_hero()
	_phase("spawn_hero")
	await _slice()
	# The village too: the players arriving there bring their wings, glow and level-up
	# flashes, and a shader compiled on first sight is a hitch on a phone.
	await VfxKit.warm_shaders(self, hero.global_position, get_tree() if staged else null)
	await _slice()
	ElementFx.warm(self, hero.global_position)
	_phase("warm_shaders")
	await _slice()
	if not is_pvp:
		_spawn_party()
		_phase("spawn_party")
	elif bool(data.get("guildwar", false)):
		gw_match = GuildWarMatch.new()
		gw_match.setup(self, hero)
		gw_match.finished.connect(func(result: Dictionary): guildwar_finished.emit(result))
		add_child(gw_match)
		await gw_match.build(get_tree() if staged else null)
		_phase("spawn_fighters")
	else:
		pvp_match = PvpMatch.new()
		pvp_match.setup(self, hero)
		pvp_match.finished.connect(func(result: Dictionary): pvp_finished.emit(result))
		add_child(pvp_match)
	if is_tower:
		Game.tower_begin_run()
		tower_run = TowerRun.new()
		tower_run.setup(self, hero, tower_start_floor)
		tower_run.finished.connect(func(result: Dictionary): tower_finished.emit(result))
		add_child(tower_run)
	await _slice()
	AudioManager.play_music(data.get("music", &"meadow"))
	AudioManager.play_ambient(data.get("ambience", &""), -14.0)
	_phase("audio")
	if not is_town:
		var spawned := 0
		for camp in _camps:
			for i in int(camp.count):
				_spawn_in_camp(camp, true)
				spawned += 1
				await _slice()
	_phase("spawn_mobs")
	if WorldPresence.enabled and not is_pvp and not is_tower and not bool(data.get("arena", false)):
		presence = WorldPresence.new()
		presence.setup(self)
		add_child(presence)
		_phase("world_players")
	is_built = true
	built.emit()


## Models farther than this from the camera stop animating (they are tiny and
## half-hidden by fog); a phone saves a skeleton update per model that way.
const ANIM_RADIUS := [24.0, 34.0, 48.0]
const AWAKE_RADIUS := [36.0, 44.0, 72.0]
var _lod_timer := 0.0


func _update_anim_lod() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var limit: float = ANIM_RADIUS[clampi(GameSettings.quality, 0, 2)]
	var from := camera.global_position
	for node in get_tree().get_nodes_in_group("anim_lod"):
		var model := node as Node3D
		var player: Variant = model.get("anim") if model else null
		if player is AnimationPlayer and is_instance_valid(player):
			(player as AnimationPlayer).active = model.global_position.distance_squared_to(from) < limit * limit
	if not is_instance_valid(hero):
		return
	var awake: float = AWAKE_RADIUS[clampi(GameSettings.quality, 0, 2)]
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob := node as Mob
		if mob:
			var d := Vector2(mob.global_position.x - hero.global_position.x, mob.global_position.z - hero.global_position.z).length()
			if d > awake + 4.0:
				mob.set_dormant(true)
			elif d < awake:
				mob.set_dormant(false)


func _process(delta: float) -> void:
	if hero == null or not is_built:
		return
	_lod_timer -= delta
	if _lod_timer <= 0.0:
		_lod_timer = 0.4
		_update_anim_lod()
	_interact_timer -= delta
	if _interact_timer <= 0.0:
		_interact_timer = 0.15
		_update_interact()
	_check_portals(delta)
	if _weather and is_instance_valid(hero):
		_weather.global_position = Vector3(hero.global_position.x, _weather.position.y, hero.global_position.z)
	if is_town:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = SPAWN_INTERVAL
		for camp in _camps:
			_refill_camp(camp)
	_tick_boss(delta)
	_tick_world_boss()
	if bool(data.get("arena", false)):
		_arena_tick(delta)


# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------

func _build_pvp() -> void:
	PvpArena.build(self, rng)
	SpecialStageArt.decorate_pvp(self)
	_start = Vector3(-PvpArena.SPAWN_X, 0, 0)
	_make_boundary_walls(PvpArena.RADIUS + 1.5)


## The guild war's castle siege: our guild's camp on the left, the rival's on the right.
func _build_siege() -> void:
	var ours: Color = WorldPlayers.GUILD_COLORS.get(Game.guild(), Color("4a8cff"))
	var theirs: Color = WorldPlayers.GUILD_COLORS.get(WorldPlayers.other_guild(Game.guild()), Color("ff5a4a")) if Game.guild() > 0 else Color("ff5a4a")
	SiegeArena.build(self, rng, ours, theirs)
	_start = Vector3(-SiegeArena.BASE_X, 0, SiegeArena.BASE_Z)
	_make_boundary_walls(SiegeArena.RADIUS + 1.5)


## The sky and air of this zone (Scenery.environment / sky_dressing "look").
func _sky_look() -> Dictionary:
	var look := {"theme": StringName(data.get("theme", &"meadow")), "sun_size": float(data.get("sun_size", 1.0)),
		"moon": bool(data.get("moon", false)), "sun_color": data.get("sun", Color(1.0, 0.96, 0.88))}
	if data.has("sky_palette"):
		look["palette"] = data.sky_palette
	return look


func _build_field() -> void:
	var theme: StringName = data.theme
	var sky: Color = data.sky
	var fog: Color = data.get("fog", sky.lerp(Color.WHITE, 0.35))
	_env = Scenery.environment(self, sky, fog, data.get("ambient", Color(0.9, 0.95, 1.0)), data.get("sun", Color(1.0, 0.96, 0.88)), _sky_look())
	_ambient_base = _env.environment.ambient_light_energy
	if StarProgression.is_region(zone_id) or zone_id == DivineRegionData.ID:
		_build_star_field()
		return
	if not is_tower and not bool(data.get("arena", false)):
		field_radius = HUNT_RADIUS
	_start = Vector3(-field_radius + 8.0, 0, 0)
	var ground_color: Color = data.ground
	var paths: Array[PackedVector2Array] = [PackedVector2Array([Vector2(-field_radius, 0), Vector2(-20, 4), Vector2(0, -2), Vector2(26, 6), Vector2(field_radius, 0)])]
	# Side trails from the main path out to the outer camps.
	for camp in data.camps:
		if camp.get("outer", false):
			var to := Vector2(camp.pos.x, camp.pos.y)
			var from: Vector2 = paths[0][0]
			for p in paths[0]:
				if p.distance_to(to) < from.distance_to(to):
					from = p
			paths.append(PackedVector2Array([from, from.lerp(to, 0.5) + Vector2(3, -3), to]))
	var clearings: Array[Vector3] = []
	for camp in data.camps:
		clearings.append(Vector3(camp.pos.x, camp.pos.y, float(camp.radius)))
	_phase("env")
	await _slice()
	Scenery.ground(self, 130.0, ground_color.darkened(0.16), ground_color.lightened(0.07), int(data.get("seed", 5)),
			data.get("path_color", Color("c5b394")), paths, 2.8, clearings, theme)
	_boss_spot = Vector3(30, 0, 26)
	var clear: Array[Vector3] = [
		Vector3(_start.x, _start.z, 6.0), Vector3(field_radius - 8.0, 0, 6.0), Vector3(_boss_spot.x, _boss_spot.z, 9.0),
	]
	for path in paths:
		for i in path.size() - 1:
			for t in 8:
				var p := path[i].lerp(path[i + 1], t / 8.0)
				clear.append(Vector3(p.x, p.y, 2.2))
	_camps.clear()
	for c in data.camps:
		var camp: Dictionary = c.duplicate()
		camp["mobs"] = []
		_camps.append(camp)
		clear.append(Vector3(c.pos.x, c.pos.y, float(c.radius) + 2.0))
	# Keep the paved/sand encounter courts open; foliage belongs at their edges.
	if is_tower or bool(data.get("arena", false)):
		clear.append(Vector3(0, 0, 42.0))
	_phase("ground")
	await _slice()
	await Scenery.populate(self, theme, rng, field_radius, clear, float(data.get("tree_density", 1.0)), true, get_tree() if staged else null)
	_phase("populate")
	await _slice()
	WorldArt.landscape(self, theme, field_radius, int(data.get("seed", 5)))
	var special := is_tower or bool(data.get("arena", false))
	if not special:
		WorldArt.silhouettes(self, theme, field_radius, int(data.get("seed", 5)))
	Scenery.sky_dressing(self, theme, _sky_look(), field_radius, int(data.get("seed", 5)))
	_phase("landscape")
	await _slice()
	WorldArt.region_edges(self, theme, field_radius, int(data.get("seed", 5)), clear, not special)
	_phase("edges")
	await _slice()
	if special:
		SpecialStageArt.build(self, zone_id)
	if data.has("boss"):
		WorldArt.boss_landmark(self, theme, _boss_spot)
	for camp in _camps:
		_make_camp_marker(camp)
	var prev: StringName = data.get("prev", &"town")
	var next: StringName = data.get("next", &"")
	portals = [{"to": prev, "pos": _start + Vector3(-3.0, 0, 0), "label": String(ZoneData.get_zone(prev).name), "level": 1}]
	if next != &"":
		var next_data := ZoneData.get_zone(next)
		portals.append({"to": next, "pos": Vector3(field_radius - 6.0, 0, 0), "label": "%s (Lv.%d+)" % [next_data.name, int(next_data.level[0])], "level": int(next_data.level[0])})
	for portal in portals:
		_make_portal(portal)
	_make_boundary_walls(field_radius + 1.0)
	if is_tower:
		_start = Vector3(0, 0, 0)
	if not bool(data.get("arena", false)) and not is_tower:
		_add_warp(_start + Vector3(3.5, 0, -5.0), "วาปกลับเมือง / ข้ามแมพ")
		_add_warp(Vector3(field_radius - 10.0, 0, -6.0), "วาปกลับเมือง / ข้ามแมพ")
	_make_weather(StringName(data.get("weather", &"")))


func _build_star_field() -> void:
	var divine := zone_id == DivineRegionData.ID
	var layout := DivineRegionArt.layout() if divine else StarRegionArt.layout(zone_id)
	_start = layout.spawn
	_boss_spot = layout.boss_pos
	if divine: DivineRegionArt.build(self)
	else: StarRegionArt.build(self, zone_id)
	for source in data.camps:
		var camp: Dictionary = source.duplicate(true)
		camp["mobs"] = []
		_camps.append(camp)
	var prev: StringName = data.prev
	var back := _start + _start.normalized() * 3.5
	portals = [{"to":prev,"pos":back,"label":String(ZoneData.get_zone(prev).name),"level":100}]
	if String(data.next) != "":
		var next := ZoneData.get_zone(data.next)
		portals.append({"to":data.next,"pos":layout.exit,"label":"%s • ดาว %d" % [next.name,int(next.star)],"level":100})
	for portal in portals: _make_portal(portal)
	_add_warp(_start + Vector3(3.5,0,-3.5), "วาปกลับเมือง / ข้ามแมพ")
	_make_boundary_walls(55.0)
	if int(data.boss.get("star",0)) == 200:
		var label := Label3D.new()
		label.text = "วิหารบัวดารา • ดรอปชุดเทพ 200 ดาว" if divine else "บัลลังก์สุริยคราส • ดาว 200"
		label.position = _boss_spot + Vector3(0,4,0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 48
		label.pixel_size = 0.005
		label.visibility_range_end = 32
		add_child(label)


## Snow, embers, petals, fireflies, rain... that follow the hero (cheap CPU
## particles, see WEATHER). Storm rain also flashes the sky now and then.
func _make_weather(kind: StringName) -> void:
	var layers: Array = WEATHER.get(kind, [])
	if layers.is_empty():
		return
	_weather = Node3D.new()
	_weather.name = "Weather"
	add_child(_weather)
	for layer in layers:
		_weather.add_child(_weather_layer(layer))
	if kind == &"rain":
		_storm_flash()


static var _ring_texture: Texture2D


func _weather_layer(spec: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(1, int(float(spec.amount) * GameSettings.particle_scale()))
	p.lifetime = float(spec.life)
	p.lifetime_randomness = 0.35
	p.preprocess = p.lifetime
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = spec.get("box", Vector3(26, 0.5, 26))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	var size: Variant = spec.size
	quad.size = size if size is Vector2 else Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y if spec.get("upright", false) else BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = spec.color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if spec.get("ring", false):
		if _ring_texture == null:
			var gradient := Gradient.new()
			gradient.offsets = PackedFloat32Array([0.0, 0.5, 0.66, 0.84, 1.0])
			gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
			var tex := GradientTexture2D.new()
			tex.gradient = gradient
			tex.fill = GradientTexture2D.FILL_RADIAL
			tex.fill_from = Vector2(0.5, 0.5)
			tex.fill_to = Vector2(1.0, 0.5)
			tex.width = 64
			tex.height = 64
			_ring_texture = tex
		mat.albedo_texture = _ring_texture
	else:
		mat.albedo_texture = VfxKit.soft_dot()
	if spec.get("add", false):
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad.material = mat
	p.mesh = quad
	p.direction = spec.dir
	p.spread = float(spec.spread)
	p.initial_velocity_min = float(spec.speed[0])
	p.initial_velocity_max = float(spec.speed[1])
	p.gravity = spec.get("gravity", Vector3.ZERO)
	p.position.y = float(spec.y)
	if spec.has("scale"):
		p.scale_amount_min = float(spec.scale[0])
		p.scale_amount_max = float(spec.scale[1])
	if spec.get("pulse", false):
		# Each mote fades in, flickers twice and fades out; different ages
		# flicker at different moments, so the swarm never pulses in step.
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.35, 0.5, 0.7, 0.85, 1.0])
		ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.25), Color(1, 1, 1, 1), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
		p.color_ramp = ramp
	return p


## A sheet-lightning flash: the ambient light and fog brighten for a moment,
## then the next flash is scheduled 5-13 s later. No lights are involved.
func _storm_flash() -> void:
	if _env == null or not is_inside_tree():
		return
	var env := _env.environment
	var fog := env.fog_light_color
	var tween := create_tween()
	tween.tween_property(env, "ambient_light_energy", _ambient_base * 3.4, 0.05)
	tween.parallel().tween_property(env, "fog_light_color", fog.lightened(0.5), 0.05)
	tween.tween_property(env, "ambient_light_energy", _ambient_base * 1.5, 0.08)
	tween.tween_property(env, "ambient_light_energy", _ambient_base * 3.0, 0.05)
	tween.tween_property(env, "ambient_light_energy", _ambient_base, 0.4)
	tween.parallel().tween_property(env, "fog_light_color", fog, 0.4)
	tween.tween_interval(rng.randf_range(5.0, 13.0))
	tween.tween_callback(_storm_flash)


func _build_town() -> void:
	var look := {"theme": &"village", "palette": [Color("6fa8dc"), Color("b6d4ea"), Color("f3e9dc")], "sun_size": 1.1,
		"sun_color": Color("fff0d5"), "cloud_range": Vector2(100.0, 150.0), "cloud_height": Vector2(12.0, 24.0)}
	_env = Scenery.environment(self, Color("a7cddd"), Color("e7e4d7"), Color("c2d2df"), Color("fff0d5"), look)
	_start = JapanVillage.START
	await _slice()
	Scenery.ground(self, 140.0, Color("7e9568"), Color("a1b586"), 2, Color("cbbba0"), JapanVillage.paths(), 3.6, [], &"village")
	await _slice()
	var clear := JapanVillage.build(self, rng)
	var villagers := _villagers()
	for v in villagers:
		# Random rocks and trees keep off where a villager stands and the ground in front where
		# the hero walks up to talk (a big rock there walled the elder in on ~1 town in 150).
		var spot: Vector3 = v[4]
		var yard: Vector3 = spot + (v[6] - spot).normalized()
		clear.append(Vector3(yard.x, yard.z, 3.0))
	for stall in JapanVillage.STALLS:
		clear.append(Vector3(stall.x, stall.z, 1.6))
	await _slice()
	await Scenery.populate(self, &"village", rng, TOWN_RADIUS, clear, 0.7, true, get_tree() if staged else null)
	await _slice()
	WorldArt.landscape(self, &"meadow", TOWN_RADIUS, 2)
	Scenery.sky_dressing(self, &"village", look, TOWN_RADIUS, 2)
	await _slice()
	_petals()
	JapanVillage.life(self, rng)
	portals = [{"to": &"meadow", "pos": JapanVillage.GATE + Vector3(0, 0, 4), "label": "ทุ่งหญ้ามิสต์วูด", "level": 1}]
	_make_portal(portals[0])
	_make_boundary_walls(TOWN_RADIUS + 1.0)
	for v in villagers:
		_add_npc(v[0], v[1], v[2], v[3], v[4], v[5], v[6])
	var board := NoticeBoard.new()
	board.position = Vector3(6.5, 0, 8.0)
	board.rotation.y = -0.6
	add_child(board)
	board.setup("daily", "กระดานเควสต์รายวัน", &"mage", "งานประจำวัน")
	npcs.append(board)
	_add_warp(Vector3(-8.0, 0, 3.5), "จุดวาปข้ามแมพ / กลับเมือง")


## The villagers: role, name, class, title, where they stand, model, the point they face.
func _villagers() -> Array:
	var V := JapanVillage
	return [
		["elder", "ผู้ใหญ่บ้านโชคดี", &"warrior", "ผู้ให้เควสต์", Vector3(-10, 0, -23), "Mage", Vector3(0, 0, -23)],
		["job", "ปรมาจารย์ผู้เปลี่ยนชะตา", &"warrior", "เลือกสาย (Lv.%d) / เลื่อนขั้น" % ClassData.LINE_LEVEL, V.DOJO + Vector3(-2.5, 0, 9.0), "Knight", V.DOJO + Vector3(-2.5, 0, 20)],
		["skill", "ปรมาจารย์สกิล", &"mage", "ฝึกและอัปสกิล", V.DOJO + Vector3(2.5, 0, 9.0), "Mage", V.DOJO + Vector3(2.5, 0, 20)],
		["shop", "พ่อค้าเก่งกาจ", &"archer", "ร้านค้า", V.SHOP + Vector3(1.0, 0, 5.8), "Rogue", V.SHOP + Vector3(1.0, 0, 20)],
		["forge", "ช่างตีเหล็กหนวดแดง", &"warrior", "ตีบวก / ใส่อัญมณี", V.FORGE + Vector3(0, 0, 5.8), "Barbarian", V.FORGE + Vector3(0, 0, 20)],
		["storage", "เจ้าของคลัง", &"warrior", "ฝากของ / ขยายกระเป๋า", V.KURA + Vector3(-3.0, 0, -5.2), "Rogue", V.KURA + Vector3(-3.0, 0, -20)],
		["registry", "นายทะเบียนเกม", &"archer", "ทะเบียนผู้เล่น · ใครอยู่ไหน", V.IZAKAYA + Vector3(-2.0, 0, -5.4), "Ranger", V.IZAKAYA + Vector3(-2.0, 0, -20)],
		["arena", "ผู้ดูแลสนามประลอง", &"warrior", "สนามประลอง 3 รอบ", V.RING + Vector3(-5.5, 0, -6.5), "Barbarian", V.RING],
		["pvp", "ผู้จัดการลีกจัดอันดับ", &"warrior", "ดวลผู้เล่น AI · ไต่แรงก์", V.RING + Vector3(4.0, 0, -7.5), "Knight", V.RING],
		["guild", "นายทะเบียนกิลด์", &"warrior", "กิลด์ Alpha · Neverdie", V.RING + Vector3(-14.0, 0, -3.5), "Knight", V.RING],
		["guildwar", "ผู้บัญชาการสงครามกิลด์", &"warrior", "ชิงปราสาท ทุกคนในกิลด์ · 30 นาที", V.RING + Vector3(-9.5, 0, -7.5), "Knight", V.RING],
		["tower", "ผู้เฝ้าหอคอยห้วงวิบัติ", &"mage", "หอคอยไม่รู้จบ · ร้านผลึก", V.PAGODA + Vector3(-5.0, 0, 5.5), "Mage", Vector3(0, 0, -30)],
		["healer", "ซิสเตอร์เมตตา", &"priest", "รักษาฟรี", Vector3(-4.5, 0, -10), "Mage", Vector3(0, 0, 0)],
		["guide", "ครูฝึกใจดี", &"mage", "แนะนำการเล่น", V.START + Vector3(4.0, 0, -2.0), "Ranger", V.START + Vector3(0, 0, 6)],
	]


## Sakura petals drifting over the village: an untracked weather layer (it
## follows the hero, and it never takes particles from the combat budget).
func _petals() -> void:
	_weather = Node3D.new()
	_weather.name = "Weather"
	add_child(_weather)
	var spec: Dictionary = WEATHER[&"petals"][0].duplicate()
	spec["amount"] = 250
	spec["life"] = 7.5
	spec["box"] = Vector3(30, 1.0, 30)
	_weather.add_child(_weather_layer(spec))


## The hero's party: the world players who joined (Game.party_invite) walk with the hero.
## One standing here joins where it stands; one let go while still online goes back to
## its own hunting (WorldPresence.release), one who logged off leaves.
func _spawn_party() -> void:
	var members := Game.party()
	var kept: Array[Companion] = []
	for k in members.size():
		var i: int = Game.world_party[k]
		var buddy: FieldPlayer = null
		for old in companions:
			if is_instance_valid(old) and old is FieldPlayer and (old as FieldPlayer).world_index == i:
				buddy = old
		if buddy == null and presence != null:
			buddy = presence.adopt(i)
			if buddy != null:
				buddy.join_party(members[k], k)
		if buddy == null:
			buddy = FieldPlayer.new()
			buddy.party_mode = true
			buddy.setup_world(i, members[k], hero, self)
			add_child(buddy)
			buddy.global_position = hero.global_position + Vector3(3.0 - 6.0 * k, 0.3, -0.6)
		buddy.member = members[k]
		buddy.index = k
		kept.append(buddy)
	for old in companions:
		if not is_instance_valid(old) or kept.has(old):
			continue
		var gone := old as FieldPlayer
		if gone != null and presence != null and bool(WorldPlayers.state(gone.world_index, WorldPresence.clock()).online):
			presence.release(gone)
		elif gone != null:
			gone.leave()
		else:
			old.queue_free()
	companions = kept
	if presence != null:
		presence.sync(false)
	if not Game.party_leveled.is_connected(_on_party_leveled):
		Game.party_leveled.connect(_on_party_leveled)
	if not Game.party_roster_changed.is_connected(_spawn_party):
		Game.party_roster_changed.connect(_spawn_party)


func _on_party_leveled(i: int, _level: int) -> void:
	if i < companions.size() and is_instance_valid(companions[i]):
		companions[i].level_up_fx()


func _exit_tree() -> void:
	if Game.party_leveled.is_connected(_on_party_leveled):
		Game.party_leveled.disconnect(_on_party_leveled)
	if Game.party_roster_changed.is_connected(_spawn_party):
		Game.party_roster_changed.disconnect(_spawn_party)


func _spawn_hero() -> void:
	hero = Hero.new()
	hero.name = "Hero"
	hero.field = self
	hero.safe_zone = is_town
	hero.field_radius = TOWN_RADIUS if is_town else ((SiegeArena.RADIUS if bool(data.get("guildwar", false)) else PvpArena.RADIUS) if is_pvp else field_radius)
	add_child(hero)
	var spawn := _start
	if Game.has_profile and Game.profile.get("spawn_override", "") != "":
		spawn = _spawn_for(String(Game.profile["spawn_override"]))
		Game.profile["spawn_override"] = ""
	hero.global_position = spawn + Vector3(0, 0.2, 0)
	hero.set_facing(PI * 0.5 if not is_town else PI)
	camera_rig = ThirdPersonCamera.new()
	camera_rig.name = "CameraRig"
	camera_rig.target = hero
	BattleVfx.text_scale = 1.0 if is_town else 1.8
	if is_town:
		camera_rig.pitch_degrees = -22.0
		camera_rig.distance = 8.0
		camera_rig.max_distance = 15.0
		camera_rig.height_offset = 1.5
	else:
		# Fighting in the field: a high, pulled-back view of the whole battlefield
		# (like an action RPG), with only a small tilt range so it stays readable.
		camera_rig.pitch_degrees = -47.0
		camera_rig.min_pitch = -56.0
		camera_rig.max_pitch = -38.0
		camera_rig.distance = 22.0
		camera_rig.min_distance = 14.0
		camera_rig.max_distance = 32.0
		camera_rig.height_offset = 0.9
		camera_rig.base_fov = 40.0
		camera_rig.far_plane = 150.0
	add_child(camera_rig)
	camera_rig.add_excluded_body(hero)
	camera_rig.set_yaw_behind(PI * 1.5 if not is_town else 0.0)
	camera_rig.snap_to_target()
	hero.camera_rig = camera_rig
	# A ranked duel ends through PvpMatch; only a normal death sends the hero home.
	hero.died.connect(func():
		if not is_pvp and not is_tower:
			hero_died.emit())
	hero.target_changed.connect(func(mob: Mob): camera_rig.combat_focus = mob)
	Game.leveled_up.connect(func(_l): hero.level_up_fx())


## Where someone walking into this zone appears (the hero's arrival point).
func entrance() -> Vector3:
	return _start


## Where to appear after arriving from another zone.
func _spawn_for(from_zone: String) -> Vector3:
	for portal in portals:
		if String(portal.to) == from_zone:
			var p: Vector3 = portal.pos
			return p + (Vector3(4, 0, 0) if not is_town and p.x < 0 else (Vector3(-4, 0, 0) if not is_town else Vector3(0, 0, 4)))
	return _start


func _make_portal(portal: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "Portal_" + String(portal.to)
	holder.position = portal.pos
	add_child(holder)
	var color := Color("5baea7") if portal.level <= Game.profile.get("level", 1) else Color("c88789")
	MeshKit.part(holder, MeshKit.cylinder(), WorldArt._mat(Color("88989b")), Vector3(0, 0.12, 0), Vector3(2.2, 0.24, 2.2))
	for i in 2:
		var ring := MeshInstance3D.new()
		ring.mesh = MeshKit.torus()
		ring.material_override = WorldArt._mat(color, 0.1)
		var s := 1.95 - i * 0.5
		ring.scale = Vector3(s, s, s)
		ring.rotation_degrees = Vector3(90, 0, 0)
		ring.position = Vector3(0, 1.6, 0)
		ring.visibility_range_begin = 2.8
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(ring)
		var tween := ring.create_tween().set_loops()
		tween.tween_property(ring, "rotation:z", TAU * (1 if i == 0 else -1), 8.0)
	# An open rune and a small jewel replace the opaque additive light column.
	var jewel := MeshKit.part(holder, MeshKit.sphere_low(), WorldArt._mat(color.lightened(0.15), 0.1),
		Vector3(0, 1.6, 0), Vector3(0.35, 0.65, 0.35))
	jewel.visibility_range_begin = 2.8
	jewel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var label := Label3D.new()
	label.text = "▶ " + String(portal.label)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.005
	label.font_size = 40
	label.outline_size = 9
	label.modulate = Color("e5eee3")
	label.position = Vector3(0, 3.2, 0)
	label.visibility_range_begin = 4.0
	label.visibility_range_end = 24.0
	holder.add_child(label)


func _make_boundary_walls(radius: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	for i in 24:
		var angle := TAU * i / 24.0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(radius * 0.28, 6.0, 1.0)
		shape.shape = box
		shape.position = Vector3(cos(angle), 3.0, sin(angle)) * radius
		shape.rotation.y = -angle + PI * 0.5
		body.add_child(shape)


func _add_warp(pos: Vector3, title: String) -> void:
	var stone := WarpStone.new()
	stone.position = pos
	add_child(stone)
	stone.setup("warp", "เสาวาป", &"mage", title)
	npcs.append(stone)


func _add_npc(role: String, npc_name: String, class_id: StringName, title: String, pos: Vector3, model := "", facing := Vector3.INF) -> void:
	var npc := Npc.new()
	npc.position = pos
	add_child(npc)
	npc.setup(role, npc_name, class_id, title, model, Npc.LOOKS.get(role, {}))
	npc.face(_start if facing == Vector3.INF else facing)
	npcs.append(npc)


# ---------------------------------------------------------------------------
# Portals and interaction
# ---------------------------------------------------------------------------

func _check_portals(delta: float) -> void:
	var near := false
	for portal in portals:
		var d: Vector3 = hero.global_position - portal.pos
		d.y = 0.0
		if d.length() < 2.6:
			near = true
			var reason := ZoneData.access_reason(portal.to, int(Game.profile.level), int(Game.paragon().level))
			if not reason.is_empty():
				if _portal_hold == 0.0:
					Game.say(reason, &"warning")
				_portal_hold = 0.001
				continue
			_portal_hold += delta
			if _portal_hold > 0.45:
				_portal_hold = 0.0
				travel_requested.emit(portal.to)
				return
	if not near:
		_portal_hold = 0.0


func _update_interact() -> void:
	var best: Npc = null
	var best_d := Npc.RADIUS
	for npc in npcs:
		var d := (npc.global_position - hero.global_position)
		d.y = 0.0
		if d.length() < best_d:
			best_d = d.length()
			best = npc
	var label := ""
	current_interact = {}
	if best:
		label = "คุย: " + best.display_name
		current_interact = {"npc": best}
	elif gw_match != null and gw_match.hero_can_capture():
		# Standing on the castle's altar: hold it for a minute to take the castle.
		label = "ยึดแท่นปราสาท"
		current_interact = {"altar": true}
	for npc in npcs:
		if npc.role == "elder":
			var quest_id := QuestData.current_quest()
			npc.marker.visible = quest_id != "" and Game.quest_status(quest_id) in ["new", "ready"] and QuestData.unlock_problem(QuestData.get_quest(quest_id)) == ""
	interact_changed.emit(label)


func interact() -> void:
	if current_interact.has("altar") and gw_match != null:
		gw_match.start_hero_capture()
		return
	if current_interact.has("npc"):
		var npc: Npc = current_interact.npc
		npc.face(hero.global_position)
		npc_interact.emit(npc.role)


## How close a finger must land to a player on screen (canvas pixels, from its body line).
const TAP_SLOP := 56.0


## The world player (hunting here or in the party) drawn under a tap at `screen`, or null.
func player_at(screen: Vector2) -> FieldPlayer:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var best: FieldPlayer = null
	var best_d := TAP_SLOP
	var people: Array = get_tree().get_nodes_in_group("world_players")
	people.append_array(companions)
	for node in people:
		var p := node as FieldPlayer
		if p == null or not is_instance_valid(p) or not p.visible or p.is_queued_for_deletion() or p.get_parent() != self:
			continue
		var feet := p.global_position + Vector3(0, 0.2 + p.visual.position.y, 0)
		var head := p.global_position + Vector3(0, 2.3 + p.visual.position.y, 0)
		if camera.is_position_behind(feet) or camera.is_position_behind(head):
			continue
		var a := camera.unproject_position(feet)
		var b := camera.unproject_position(head)
		var d := Geometry2D.get_closest_point_to_segment(screen, a, b).distance_to(screen)
		if d < best_d:
			best_d = d
			best = p
	return best


# ---------------------------------------------------------------------------
# Monsters, bosses, drops
# ---------------------------------------------------------------------------

## The monster camp the point is inside (or just outside), or {}.
func camp_near(point: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for camp in _camps:
		var d := Vector2(point.x - camp.pos.x, point.z - camp.pos.y).length()
		if d <= float(camp.radius) + 3.0 and d < best_d:
			best = camp
			best_d = d
	return best


func _camp_spot(camp: Dictionary) -> Vector3:
	var angle := rng.randf() * TAU
	var r := sqrt(rng.randf()) * (float(camp.radius) - 1.5)
	return Vector3(camp.pos.x + cos(angle) * r, 0, camp.pos.y + sin(angle) * r)


func _refill_camp(camp: Dictionary) -> void:
	var alive: Array = []
	for m in camp.mobs:
		if is_instance_valid(m) and not m.is_dead():
			alive.append(m)
	camp.mobs = alive
	if alive.size() < int(camp.count):
		_spawn_in_camp(camp, false)


func _spawn_in_camp(camp: Dictionary, initial: bool) -> void:
	var spot := _camp_spot(camp)
	# Monsters keep spawning while the hero stands in the camp, just not on top of them.
	if not initial and hero:
		for attempt in 6:
			if Vector2(hero.global_position.x - spot.x, hero.global_position.z - spot.z).length() >= 6.0:
				break
			spot = _camp_spot(camp)
	var ids: Array = camp.monsters
	var mob := Mob.new()
	var level := rng.randi_range(int(camp.levels[0]), int(camp.levels[1]))
	mob.setup(ids[rng.randi() % ids.size()], level, spot, hero)
	mob.position = spot + Vector3(0, 0.3, 0)
	add_child(mob)
	camp.mobs.append(mob)


## Organic ground clearings are baked into Scenery.ground. Low stones and a
## readable wooden sign identify encounters without drawing UI rings on grass.
func _make_camp_marker(camp: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "Camp"
	holder.position = Vector3(camp.pos.x, 0, camp.pos.y)
	add_child(holder)
	WorldArt.camp_details(holder, StringName(data.theme), float(camp.radius), int(camp.pos.x * 17 + camp.pos.y * 31))
	# Signpost on the side facing the village.
	var sign_pos := Vector3(-float(camp.radius) + 1.0, 0, 0)
	MeshKit.part(holder, MeshKit.cylinder(), MeshKit.toon(Color("7a5230")), sign_pos + Vector3(0, 1.1, 0), Vector3(0.16, 2.2, 0.16))
	MeshKit.part(holder, MeshKit.box(), MeshKit.toon(Color("a8763e")), sign_pos + Vector3(0, 2.1, 0), Vector3(1.9, 0.7, 0.14))
	var label := Label3D.new()
	label.text = "%s\nLv.%d-%d" % [camp.name, camp.levels[0], camp.levels[1]]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.0065
	label.font_size = 40
	label.outline_size = 9
	label.modulate = Color("fff0d6")
	label.position = sign_pos + Vector3(0, 3.1, 0)
	label.visibility_range_end = 30.0
	holder.add_child(label)


func _tick_boss(delta: float) -> void:
	if not data.has("boss") or int(Game.paragon().level) < int(data.boss.get("star",0)):
		return
	if _boss != null and is_instance_valid(_boss) and not _boss.is_dead():
		return
	_boss_timer -= delta
	if _boss_timer > 0.0:
		return
	var info: Dictionary = data.boss
	_boss_timer = float(info.respawn)
	var mob := Mob.new()
	mob.setup(info.monster, int(info.level), _boss_spot, hero)
	mob.position = _boss_spot + Vector3(0, 0.3, 0)
	add_child(mob)
	_boss = mob
	Game.say("บอส %s ปรากฏตัวแล้ว!" % MonsterData.get_monster(info.monster).name, &"warning")


## The world boss (WorldEvents.boss_now): in its window, in the field of the day, the
## field's own boss once more at BOSS_HP_SCALE HP beside the boss spot, named บอสโลก.
## Spawned once a window: defeated, the day's flag (WorldEvents.flag_key) keeps it down.
func _tick_world_boss() -> void:
	if not data.has("boss") or bool(data.get("arena", false)) or not Game.has_profile:
		return
	if _wboss != null and is_instance_valid(_wboss) and not _wboss.is_dead():
		return
	var event := WorldEvents.boss_now(WorldPresence.clock())
	if event.is_empty() or StringName(event.zone) != zone_id or Game.profile.flags.has(WorldEvents.flag_key(int(event.day))):
		return
	if int(Game.paragon().level) < int(data.boss.get("star", 0)):
		return
	var info: Dictionary = data.boss
	var mob := Mob.new()
	mob.setup(info.monster, int(info.level), _boss_spot, hero)
	mob.template = mob.template.duplicate()
	mob.template["name"] = "%s %s" % [WorldEvents.NAME_BOSS, String(mob.template.name)]
	mob.max_hp = int(float(mob.max_hp) * WorldEvents.BOSS_HP_SCALE)
	mob.hp = mob.max_hp
	mob.set_meta("world_boss", int(event.day))
	mob.position = _boss_spot + Vector3(4.0, 0.3, 2.0)
	add_child(mob)
	_wboss = mob
	banner_requested.emit("%s ปรากฏตัวแล้ว!" % String(mob.template.name))
	Game.say("%s ปรากฏตัวแล้ว!" % String(mob.template.name), &"warning")


## The world boss is down: the day's window is spent; the hero that fought it is paid.
func _on_world_boss_died(mob: Mob) -> void:
	Game.profile.flags[WorldEvents.flag_key(int(mob.get_meta("world_boss", 0)))] = 1
	Game.mark_dirty()
	if mob.party_share() <= 0.0:
		return
	var gold := WorldEvents.BOSS_GOLD_PER_10 * maxi(1, int(Game.profile.level) / 10)
	Game.add_gold(gold)
	banner_requested.emit("ปราบบอสโลกแล้ว! +%d เหรียญ" % gold)
	Game.say("ปราบบอสโลกแล้ว! ได้รับ %d เหรียญ" % gold, &"info")


## Phase 1 and 2 of a boss: a handful of the field's monsters join the fight.
func _on_boss_phase(boss: Mob, _phase: int) -> void:
	var ids: Array = []
	for camp in data.get("camps", []):
		ids.append_array(camp.monsters)
	if ids.is_empty():
		return
	for i in 3:
		var angle := TAU * float(i) / 3.0 + rng.randf()
		var spot := boss.global_position + Vector3(cos(angle), 0, sin(angle)) * 4.5
		var add := Mob.new()
		add.setup(ids[rng.randi() % ids.size()], maxi(1, boss.level - 4), spot, hero)
		add.position = spot + Vector3(0, 0.3, 0)
		add_child(add)
		add.hostile = true
		VfxKit.shockwave(self, spot + Vector3(0, 0.1, 0), Color("ffd84a"), 2.0)


func _on_mob_died(mob: Mob) -> void:
	if mob is Rival or mob is CastleGate:
		if is_instance_valid(hero) and hero.target == mob:
			hero.set_target(null)
		return
	if is_instance_valid(hero) and hero.target == mob:
		hero.set_target(null)
	if mob == _wboss:
		_on_world_boss_died(mob)
	# A world player's kill is its own: the hero earns EXP by its share of the damage,
	# and the kill (loot, quests) only when it dealt most of it.
	var share := mob.party_share()
	if share <= 0.0:
		return
	_kills += 1
	var region_boost := 1.0 + maxf(0.0, float(data.get("gear_star",0)) / 25.0)
	# In a party the EXP is shared by everyone in it (Game.share_party_exp).
	var exp_gain := Game.share_party_exp(float(mob.stats.exp) * region_boost * share, int(mob.level))
	Game.add_exp(exp_gain)
	BattleVfx.floating_text(self, mob.global_position + Vector3(0, mob.visual.height + 1.0, 0), ("+%d EXP ปาร์ตี้" if not Game.party().is_empty() else "+%d EXP") % exp_gain, Color("66e0ff"), 0.8)
	if share < 0.5:
		return
	Game.report_kill(mob.monster_id, mob.is_boss)
	_drop_loot(mob)


func _drop_loot(mob: Mob) -> void:
	var from := mob.global_position
	# Weekend gold bonus (WorldEvents) on every kill's drop.
	var gold: int = int(mob.stats.gold * rng.randf_range(0.7, 1.4) * WorldEvents.gold_multiplier(WorldPresence.clock()))
	_spawn_loot({}, gold, from)
	_drop_jewels(from)
	var boss := mob.is_boss
	var class_id := Game.class_id()
	if zone_id == DivineRegionData.ID:
		_divine_loot(mob, from)
		return
	if StarProgression.is_region(zone_id):
		_star_loot(mob, from)
		return
	# Rich zones (the Lv.100 void) override the default drop odds.
	var loot: Dictionary = data.get("loot", {})
	var boost := float(loot.get("rarity_boost", 0.0))
	if boss:
		# The field's own boss follows its drop table: its own slots, a favourite
		# gem and chase pieces with a pity counter. Tower / arena bosses do not.
		var table := mob == _boss and BossLootData.has(mob.monster_id)
		var best := maxi(1, int(loot.get("boss_min_rarity", 3 if loot.has("boss_items") else 1)))
		for i in int(loot.get("boss_items", 3)):
			var rarity := maxi(1, ItemData.roll_rarity(rng, maxf(0.3, boost * 5.0)))
			if i < 2:
				rarity = maxi(rarity, best)
			var slot := BossLootData.slot_for(mob.monster_id, i) if table else ""
			_spawn_loot(ItemData.generate(_gear_level(mob, loot), class_id, rng, rarity, slot), 0, from)
		if table:
			_boss_chase(mob, from, class_id, loot)
		if int(mob.level) >= ItemData.WING_DROP_LEVEL and rng.randf() < float(loot.get("boss_wing", WING_DROP_RATE)):
			_spawn_loot(ItemData.wings(rng, String(class_id)), 0, from)
			Game.say("ปีกเทพตกจากบอส!", &"quest")
		if int(loot.get("boss_shards", 0)) > 0:
			var n := rng.randi_range(int(loot.boss_shards) / 2, int(loot.boss_shards))
			Game.tower_add_shards(n)
			Game.say("ผลึกห้วงวิบัติ +%d" % n, &"quest")
		var top := mob.level >= 100
		_spawn_loot(ItemData.potion("hp_xl" if top else "hp_m", 3), 0, from)
		_spawn_loot(ItemData.potion("mp_xl" if top else "mp_m", 2), 0, from)
		for i in (4 if loot.has("boss_items") else 2):
			var gem := _random_gem(mob.level, 1)
			if table:
				gem = ItemData.gem(BossLootData.gem_kind(mob.monster_id, rng), int(String(gem.id).split("_")[1]))
			_spawn_loot(gem, 0, from)
		return
	if rng.randf() < float(loot.get("gem", DROP_RATE_GEM)):
		_spawn_loot(_random_gem(mob.level, 1 if loot.has("gem") else 0), 0, from)
	if rng.randf() < float(loot.get("gear", DROP_RATE_GEAR)):
		var item := ItemData.generate(_gear_level(mob, loot), class_id, rng, ItemData.roll_rarity(rng, boost) if boost > 0.0 else -1)
		_spawn_loot(item, 0, from)
	if rng.randf() < float(loot.get("potion", DROP_RATE_POTION)):
		var tier := "s" if mob.level < 9 else ("m" if mob.level < 22 else "l")
		if mob.level >= 100:
			tier = "xl" if rng.randf() < 0.7 else "xxl"
		_spawn_loot(ItemData.potion(("hp_" if rng.randf() < 0.6 else "mp_") + tier, 1), 0, from)
	if float(loot.get("shard", 0.0)) > 0.0 and rng.randf() < float(loot.shard):
		Game.tower_add_shards(1)
		BattleVfx.floating_text(self, from + Vector3(0, 1.6, 0), "ผลึกห้วงวิบัติ +1", Color("c58aff"), 0.9)
	if float(loot.get("wing", 0.0)) > 0.0 and rng.randf() < float(loot.wing):
		_spawn_loot(ItemData.wings(rng, String(class_id)), 0, from)
		Game.say("ปีกเทพตกจากมอนสเตอร์!", &"quest")


## Forge jewels: every monster of a levelling field may drop a purple, a pink and a
## chaos jewel (ItemData.JEWEL_DROP), bosses as well; fields of FEATHER_STARS stars
## and up may also drop a feather.
func _drop_jewels(from: Vector3) -> void:
	if is_town or is_pvp:
		return
	for id in ItemData.JEWEL_DROP:
		if rng.randf() < float(ItemData.JEWEL_DROP[id]):
			_spawn_loot(ItemData.jewel(id), 0, from)
	if int(data.get("star", 0)) >= ItemData.FEATHER_STARS and rng.randf() < ItemData.FEATHER_DROP:
		_spawn_loot(ItemData.jewel("feather"), 0, from)
		Game.say("ขนนกตกแล้ว! เอาไปตีปีก 100 ดาวที่ช่างตีเหล็ก", &"quest")


## Chase pieces of a field boss; every miss raises the next kill's chance.
func _boss_chase(mob: Mob, from: Vector3, class_id: StringName, loot: Dictionary) -> void:
	var won := BossLootData.roll_chases(mob.monster_id, Game.boss_pity(), _gear_level(mob, loot), class_id, rng)
	for item in won:
		_spawn_loot(item, 0, from)
		Game.say("%s มอบ %s ที่รอคอย!" % [String(mob.template.name), ItemData.name_of(item)], &"quest")
	if won.is_empty():
		Game.say("โชคสะสม: อีก %d ครั้งจะได้ของหายากแน่นอน" % BossLootData.kills_left(mob.monster_id, Game.boss_pity()), &"info")


func _divine_loot(mob: Mob, from: Vector3) -> void:
	var elite := bool(mob.template.get("elite", false))
	for item in DivineGearData.drops(Game.class_id(), mob.is_boss, elite, rng):
		_spawn_loot(item, 0, from)
		Game.say("ชุดเทพประจำอาชีพ 200 ดาวตกแล้ว!", &"quest")
	# The divine set has no jewellery: the sanctuary adds 200★ rings and amulets.
	if mob.is_boss or rng.randf() < (STAR_GEAR_ELITE if elite else STAR_GEAR_NORMAL):
		var slot := "ring" if rng.randf() < 0.5 else "amulet"
		_spawn_loot(StarProgression.item(Game.class_id(), 200, slot, rng), 0, from)
	if mob.is_boss:
		_spawn_loot(ItemData.potion("hp_xl", 3), 0, from)
		_spawn_loot(ItemData.potion("mp_xl", 3), 0, from)
		_spawn_loot(_random_gem(100, 1), 0, from)
	elif rng.randf() < 0.35:
		_spawn_loot(ItemData.potion("hp_xl" if rng.randf() < 0.55 else "mp_xl", 1), 0, from)


## Chance that a ★ region kill drops a piece of that region's ★ gear.
const STAR_GEAR_NORMAL := 0.10
const STAR_GEAR_ELITE := 0.40


func _star_loot(mob: Mob, from: Vector3) -> void:
	# Each region drops its own ★ tier of class gear (weapon, armor, helm,
	# boots, ring, amulet). There is no forge: farming is the only source.
	var stars := int(data.gear_star)
	var elite := bool(mob.template.get("elite",false))
	var pieces := 0
	if mob.is_boss:
		pieces = 3
	elif rng.randf() < (STAR_GEAR_ELITE if elite else STAR_GEAR_NORMAL):
		pieces = 1
	for i in pieces:
		_spawn_loot(StarProgression.random_item(Game.class_id(),stars,rng),0,from)
	if pieces > 0 and mob.is_boss:
		Game.say("บอสมอบอุปกรณ์ดาว %d ประจำอาชีพ %d ชิ้น!" % [stars, pieces],&"quest")
	if rng.randf()<0.35 or mob.is_boss:
		_spawn_loot(ItemData.potion("hp_xl" if rng.randf()<0.55 else "mp_xl",3 if mob.is_boss else 1),0,from)
	if mob.is_boss: _spawn_loot(_random_gem(100,1),0,from)


## Gear level of a drop. Star zones (the Lv.100 void and tower) drop gear above
## Lv.100 (worn with paragon levels): about 70% of pieces carry a few stars above
## your own paragon level, and tower floors add more.
func _gear_level(mob: Mob, loot: Dictionary) -> int:
	if not bool(loot.get("stars", false)) or int(mob.level) < 100:
		return mob.level
	var bonus := 0
	if tower_run != null:
		bonus = tower_run.floor_no / 10
	return Game.star_gear_level(bonus)


func _random_gem(level: int, bonus_size: int) -> Dictionary:
	var kinds := ItemData.GEMS.keys()
	var size := clampi((0 if level < 12 else (1 if level < 26 else 2)) + (bonus_size if rng.randf() < 0.5 else 0), 0, 2)
	return ItemData.gem(String(kinds[rng.randi() % kinds.size()]), size)


func _spawn_loot(item: Dictionary, gold: int, from: Vector3) -> void:
	# Gear of grades switched off in the pickup filter is left behind.
	if gold <= 0 and not item.is_empty() and not Game.keeps_loot(item):
		return
	var drop := LootDrop.new()
	drop.setup(item, gold, hero, from)
	add_child(drop)


# ---------------------------------------------------------------------------
# Arena: three waves, the last one with a boss, then a reward chest
# ---------------------------------------------------------------------------

func _arena_tick(delta: float) -> void:
	match _arena_state:
		"wait", "rest":
			_arena_timer -= delta
			if _arena_timer <= 0.0:
				_arena_next_wave()
		"fight":
			_arena_mobs = _arena_mobs.filter(func(m): return is_instance_valid(m) and not m.is_dead())
			if _arena_mobs.is_empty():
				if _arena_wave >= 3:
					_arena_win()
				else:
					_arena_state = "rest"
					_arena_timer = 4.0
					banner_requested.emit("รอบที่ %d สำเร็จ!" % _arena_wave)


## The hunting field whose level range fits the hero (the last one for very high levels).
func _arena_source() -> Dictionary:
	var level: int = Game.profile.level
	var best := ZoneData.get_zone(&"meadow")
	for id in [&"meadow", &"dark_forest", &"desert", &"snow", &"volcano", &"graveyard", &"swamp", &"storm", &"sky", &"abyss"]:
		var info := ZoneData.get_zone(id)
		if level >= int(info.level[0]):
			best = info
	return best


func _arena_next_wave() -> void:
	_arena_wave += 1
	_arena_state = "fight"
	banner_requested.emit("รอบที่ %d / 3" % _arena_wave)
	var source := _arena_source()
	var ids: Array = []
	for camp in source.camps:
		ids.append_array(camp.monsters)
	var level: int = Game.profile.level
	var count: int = [4, 6, 2][_arena_wave - 1]
	for i in count:
		var angle := rng.randf() * TAU
		var spot := Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(8.0, 14.0)
		_arena_spawn(ids[rng.randi() % ids.size()], level + _arena_wave - 1, spot)
	if _arena_wave == 3:
		_arena_spawn(source.boss.monster, level + 2, Vector3(0, 0, -10))
		Game.say("บอสปรากฏตัวแล้ว!", &"warning")


func _arena_spawn(id: StringName, level: int, spot: Vector3) -> void:
	var mob := Mob.new()
	mob.setup(id, level, spot, hero)
	mob.position = spot + Vector3(0, 0.3, 0)
	add_child(mob)
	mob.hostile = true
	_arena_mobs.append(mob)


func _arena_win() -> void:
	_arena_state = "done"
	banner_requested.emit("ชนะสนามประลอง!")
	AudioManager.play_sfx(&"quest_complete")
	var today := GoalsData.today()
	var full: bool = Game.profile.flags.get("arena_day", "") != today
	Game.profile.flags["arena_day"] = today
	var level: int = Game.profile.level
	var scale := 1.0 if full else 0.35
	_spawn_loot({}, int(level * 150 * scale), hero.global_position + Vector3(0, 0, 1.5))
	for i in (2 if full else 1):
		_spawn_loot(_random_gem(level, 1), 0, hero.global_position + Vector3(1.5, 0, 0))
	if full:
		_spawn_loot(ItemData.generate(level + 1, Game.class_id(), rng, maxi(2, ItemData.roll_rarity(rng, 0.4))), 0, hero.global_position + Vector3(-1.5, 0, 0))
	Game.flag_add("arena_clears")
	Game.check_achievements()
	Game.say("ชนะแล้ว! รับรางวัลจากพื้น แล้วเดินกลับประตูเพื่อออกจากสนาม%s" % ("" if full else " (รางวัลลดลงเพราะชนะครั้งที่สองของวัน)"), &"success")
