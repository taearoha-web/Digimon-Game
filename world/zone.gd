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

const FIELD_RADIUS := 52.0
const TOWN_RADIUS := 38.0
const SAFE_START_RADIUS := 14.0
const SPAWN_INTERVAL := 1.6
const DROP_RATE_GEAR := 0.14
const DROP_RATE_POTION := 0.3
const DROP_RATE_GEM := 0.07

var zone_id: StringName = &"meadow"
var data: Dictionary = {}
var is_town := false
var hero: Hero
var camera_rig: ThirdPersonCamera
var rng := RandomNumberGenerator.new()
var portals: Array[Dictionary] = []
var npcs: Array[Npc] = []
var companions: Array[Companion] = []
var current_interact: Dictionary = {}

var _spawn_timer := 0.0
var _weather: CPUParticles3D
var _arena_wave := 0
var _arena_state := "wait"
var _arena_timer := 4.0
var _arena_mobs: Array[Mob] = []
var _camps: Array[Dictionary] = []
var _boss: Mob
var _boss_timer := 8.0
var _boss_spot := Vector3.ZERO
var _portal_hold := 0.0
var _interact_timer := 0.0
var _start := Vector3.ZERO
var _kills := 0


func _ready() -> void:
	rng.randomize()
	# Every monster that enters the zone (spawned or scripted) pays out when it dies.
	child_entered_tree.connect(func(node: Node):
		var mob := node as Mob
		if mob and not mob.died.is_connected(_on_mob_died):
			mob.died.connect(_on_mob_died))
	data = ZoneData.get_zone(zone_id)
	is_town = bool(data.get("safe", false))
	if is_town:
		_build_town()
	else:
		_build_field()
	VfxArt.warm_up()
	_spawn_hero()
	_spawn_party()
	AudioManager.play_music(data.get("music", &"field"))
	AudioManager.play_ambient(data.get("ambience", &""), -14.0)
	if not is_town:
		for camp in _camps:
			for i in int(camp.count):
				_spawn_in_camp(camp, true)


func _process(delta: float) -> void:
	if hero == null:
		return
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
	if bool(data.get("arena", false)):
		_arena_tick(delta)


# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------

func _build_field() -> void:
	var theme: StringName = data.theme
	var sky: Color = data.sky
	var fog: Color = data.get("fog", sky.lerp(Color.WHITE, 0.35))
	Scenery.environment(self, sky, fog, data.get("ambient", Color(0.9, 0.95, 1.0)), data.get("sun", Color(1.0, 0.96, 0.88)))
	_start = Vector3(-FIELD_RADIUS + 8.0, 0, 0)
	var ground_color: Color = data.ground
	var paths: Array[PackedVector2Array] = [PackedVector2Array([Vector2(-FIELD_RADIUS, 0), Vector2(-20, 4), Vector2(0, -2), Vector2(26, 6), Vector2(FIELD_RADIUS, 0)])]
	Scenery.ground(self, 130.0, ground_color.darkened(0.2), ground_color.darkened(0.02), int(data.get("seed", 5)),
			data.get("path_color", Color("a98f62")), paths, 2.2)
	_boss_spot = Vector3(30, 0, 26)
	var clear: Array[Vector3] = [
		Vector3(_start.x, _start.z, 6.0), Vector3(FIELD_RADIUS - 8.0, 0, 6.0), Vector3(_boss_spot.x, _boss_spot.z, 9.0),
	]
	for i in paths[0].size() - 1:
		for t in 8:
			var p := paths[0][i].lerp(paths[0][i + 1], t / 8.0)
			clear.append(Vector3(p.x, p.y, 2.2))
	_camps.clear()
	for c in data.camps:
		var camp: Dictionary = c.duplicate()
		camp["mobs"] = []
		_camps.append(camp)
		clear.append(Vector3(c.pos.x, c.pos.y, float(c.radius) + 2.0))
	Scenery.populate(self, theme, rng, FIELD_RADIUS, clear, float(data.get("tree_density", 1.0)))
	for camp in _camps:
		_make_camp_marker(camp)
	var prev: StringName = data.get("prev", &"town")
	var next: StringName = data.get("next", &"")
	portals = [{"to": prev, "pos": _start + Vector3(-3.0, 0, 0), "label": String(ZoneData.get_zone(prev).name), "level": 1}]
	if next != &"":
		var next_data := ZoneData.get_zone(next)
		portals.append({"to": next, "pos": Vector3(FIELD_RADIUS - 6.0, 0, 0), "label": "%s (Lv.%d+)" % [next_data.name, int(next_data.level[0])], "level": int(next_data.level[0])})
	for portal in portals:
		_make_portal(portal)
	_make_boundary_walls(FIELD_RADIUS + 1.0)
	_make_weather(StringName(data.get("weather", &"")))


## Falling snow or rising embers that follow the hero (cheap CPU particles).
func _make_weather(kind: StringName) -> void:
	if kind == &"":
		return
	_weather = CPUParticles3D.new()
	_weather.amount = int((160 if kind == &"snow" else 90) * GameSettings.particle_scale())
	_weather.lifetime = 7.0 if kind == &"snow" else 4.5
	_weather.preprocess = _weather.lifetime
	_weather.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_weather.emission_box_extents = Vector3(26, 0.5, 26)
	_weather.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22) if kind == &"snow" else Vector2(0.2, 0.2)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(1, 1, 1, 0.9) if kind == &"snow" else Color(1.0, 0.55, 0.2, 0.95)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = VfxKit.soft_dot()
	if kind == &"embers":
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad.material = mat
	_weather.mesh = quad
	if kind == &"snow":
		_weather.direction = Vector3(0.15, -1, 0.05)
		_weather.spread = 12.0
		_weather.initial_velocity_min = 1.6
		_weather.initial_velocity_max = 2.6
		_weather.gravity = Vector3.ZERO
		_weather.position.y = 14.0
	else:
		_weather.direction = Vector3(0.1, 1, 0.1)
		_weather.spread = 20.0
		_weather.initial_velocity_min = 0.8
		_weather.initial_velocity_max = 2.2
		_weather.gravity = Vector3.ZERO
		_weather.position.y = 0.4
	add_child(_weather)


func _build_town() -> void:
	Scenery.environment(self, Color("7fc8ff"), Color("dff0ff"), Color(1.0, 0.98, 0.95))
	_start = Vector3(0, 0, 14)
	var paths: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(0, -36), Vector2(0, 36)]),
		PackedVector2Array([Vector2(-36, 0), Vector2(36, 0)]),
	]
	Scenery.ground(self, 130.0, Color("4fa84e"), Color("6bc05c"), 2, Color("a98f62"), paths, 2.6)
	# Plaza disc
	var plaza := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 9.0
	disc.bottom_radius = 9.0
	disc.height = 0.06
	disc.radial_segments = 40
	plaza.mesh = disc
	plaza.material_override = MeshKit.toon(Color("c9b27c"))
	plaza.position = Vector3(0, 0.02, 0)
	add_child(plaza)
	var clear: Array[Vector3] = [Vector3(0, 0, 11.0), Vector3(0, 0, 0), Vector3(0, -33, 5.0)]
	for t in 20:
		clear.append(Vector3(0, -36 + t * 3.6, 2.6))
		clear.append(Vector3(-36 + t * 3.6, 0, 2.6))
	var houses := [
		[Vector3(-16, 0, -13), 0.4, Color("f2b880"), Color("c0503a"), Vector3(7, 4, 6)],
		[Vector3(15, 0, -14), -0.5, Color("e8d8a8"), Color("4a78c8"), Vector3(7, 4, 6)],
		[Vector3(-19, 0, 14), 2.6, Color("d8e0f0"), Color("7a4ac8"), Vector3(7, 4, 6)],
		[Vector3(18, 0, 15), -2.4, Color("f0d8a0"), Color("3aa86a"), Vector3(8, 4.2, 6.5)],
		[Vector3(-27, 0, -2), 1.5, Color("f2c8a0"), Color("c87a3a"), Vector3(6, 3.6, 5.5)],
	]
	for h in houses:
		_house(h[0], h[1], h[2], h[3], h[4])
		clear.append(Vector3(h[0].x, h[0].z, 6.5))
	Scenery.populate(self, &"meadow", rng, TOWN_RADIUS, clear, 0.8)
	_fountain(Vector3(0, 0, 0))
	for lamp in [Vector3(-6, 0, -6), Vector3(6, 0, -6), Vector3(-6, 0, 6), Vector3(6, 0, 6), Vector3(0, 0, -20), Vector3(0, 0, 22)]:
		_lamp(lamp)
	portals = [{"to": &"meadow", "pos": Vector3(0, 0, -33), "label": "ทุ่งหญ้ามิสต์วูด", "level": 1}]
	_make_portal(portals[0])
	_make_boundary_walls(TOWN_RADIUS + 1.0)
	_add_npc("elder", "ผู้ใหญ่บ้านโชคดี", &"warrior", "ผู้ให้เควสต์", Vector3(-7, 0, -8), "Barbarian")
	_add_npc("job", "ปรมาจารย์ผู้เปลี่ยนชะตา", &"warrior", "เลือกสาย (Lv.%d) / เลื่อนขั้น" % ClassData.LINE_LEVEL, Vector3(-11, 0, 5), "Knight")
	_add_npc("skill", "ปรมาจารย์สกิล", &"mage", "ฝึกและอัปสกิล", Vector3(-8, 0, 10), "Mage")
	_add_npc("party", "นายหน้าเพื่อนร่วมทาง", &"archer", "เลือกเพื่อนปาร์ตี้ AI", Vector3(11, 0, 2), "Ranger")
	_add_npc("daily", "กระดานเควสต์รายวัน", &"mage", "งานประจำวัน", Vector3(-3, 0, 12), "Rogue_Hooded")
	_add_npc("arena", "ผู้ดูแลสนามประลอง", &"warrior", "สนามประลอง 3 รอบ", Vector3(4, 0, -14), "Knight")
	_add_npc("forge", "ช่างตีเหล็กหนวดแดง", &"warrior", "ตีบวก / ใส่อัญมณี", Vector3(-12, 0, -2), "Barbarian")
	_add_npc("shop", "พ่อค้าเก่งกาจ", &"archer", "ร้านค้า", Vector3(8, 0, -7), "Rogue")
	_add_npc("healer", "ซิสเตอร์เมตตา", &"priest", "รักษาฟรี", Vector3(0, 0, 8))
	_add_npc("guide", "ครูฝึกใจดี", &"mage", "แนะนำการเล่น", Vector3(10, 0, 9), "Rogue_Hooded")


func _spawn_party() -> void:
	Game.ensure_party()
	Game.party_catch_up()
	for old in companions:
		if is_instance_valid(old):
			old.queue_free()
	companions.clear()
	for i in Game.party().size():
		var buddy := Companion.new()
		buddy.setup(Game.party()[i], i, hero, self)
		add_child(buddy)
		buddy.global_position = hero.global_position + Vector3(3.0, 0.3, -0.6)
		companions.append(buddy)
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
	hero.field_radius = TOWN_RADIUS if is_town else FIELD_RADIUS
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
	camera_rig.pitch_degrees = -22.0
	camera_rig.distance = 8.0
	camera_rig.max_distance = 15.0
	camera_rig.height_offset = 1.5
	add_child(camera_rig)
	camera_rig.add_excluded_body(hero)
	camera_rig.set_yaw_behind(PI * 1.5 if not is_town else 0.0)
	camera_rig.snap_to_target()
	hero.camera_rig = camera_rig
	hero.died.connect(func(): hero_died.emit())
	hero.target_changed.connect(func(mob: Mob): camera_rig.combat_focus = mob)
	Game.leveled_up.connect(func(_l): hero.level_up_fx())


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
	var color := Color("5ad0ff") if portal.level <= Game.profile.get("level", 1) else Color("ff6a6a")
	for i in 2:
		var ring := MeshInstance3D.new()
		ring.mesh = MeshKit.torus()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color
		ring.material_override = mat
		ring.scale = Vector3(2.4 - i * 0.7, 2.4 - i * 0.7, 2.4 - i * 0.7)
		ring.rotation_degrees = Vector3(90, 0, 0)
		ring.position = Vector3(0, 2.4, 0)
		holder.add_child(ring)
		var tween := ring.create_tween().set_loops()
		tween.tween_property(ring, "rotation:z", TAU * (1 if i == 0 else -1), 5.0)
	var core := MeshInstance3D.new()
	core.mesh = MeshKit.cylinder()
	core.material_override = VfxKit._glow(color, 0.3)
	core.scale = Vector3(1.5, 0.04, 1.5)
	core.position = Vector3(0, 0.05, 0)
	holder.add_child(core)
	var beam := VfxKit.loot_beam(holder, color, 5.0)
	beam.scale = Vector3(1.2, 5.0, 1.2)
	var label := Label3D.new()
	label.text = "▶ " + String(portal.label)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.006
	label.font_size = 56
	label.outline_size = 14
	label.modulate = Color("e8fbff")
	label.position = Vector3(0, 5.0, 0)
	label.no_depth_test = true
	holder.add_child(label)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.4
	light.omni_range = 7.0
	light.position = Vector3(0, 2.5, 0)
	holder.add_child(light)


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


func _house(pos: Vector3, yaw: float, wall: Color, roof: Color, size: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	add_child(holder)
	MeshKit.part(holder, MeshKit.box(), MeshKit.toon(wall), Vector3(0, size.y * 0.5, 0), size)
	# Roof: two sloped slabs.
	var slab_w := size.x * 0.62
	for side in [-1.0, 1.0]:
		var slab := MeshKit.part(holder, MeshKit.box(), MeshKit.toon(roof), Vector3(side * size.x * 0.25, size.y + 0.75, 0),
				Vector3(slab_w, 0.35, size.z + 1.0), Vector3(0, 0, -side * 32.0))
		slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	MeshKit.part(holder, MeshKit.box(), MeshKit.toon(wall.darkened(0.08)), Vector3(0, size.y + 0.4, 0), Vector3(size.x * 0.12, 1.4, size.z))
	MeshKit.part(holder, MeshKit.box(), MeshKit.toon(Color("7a4a2a")), Vector3(0, 1.0, size.z * 0.5 + 0.02), Vector3(1.3, 2.0, 0.12))
	for wx in [-size.x * 0.3, size.x * 0.3]:
		MeshKit.part(holder, MeshKit.box(), MeshKit.toon(Color("bfe8ff"), {"emission": 0.4}), Vector3(wx, size.y * 0.6, size.z * 0.5 + 0.02), Vector3(1.0, 1.0, 0.1))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(shape)
	holder.add_child(body)


func _fountain(pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = pos
	add_child(holder)
	MeshKit.part(holder, MeshKit.cylinder(), MeshKit.toon(Color("b8c0d8")), Vector3(0, 0.3, 0), Vector3(3.2, 0.6, 3.2))
	MeshKit.part(holder, MeshKit.cylinder(), MeshKit.toon(Color("6ec8ff", ), {"emission": 0.4}), Vector3(0, 0.62, 0), Vector3(2.7, 0.06, 2.7))
	MeshKit.part(holder, MeshKit.cylinder(), MeshKit.toon(Color("b8c0d8")), Vector3(0, 1.1, 0), Vector3(0.45, 1.5, 0.45))
	MeshKit.part(holder, MeshKit.sphere_low(), MeshKit.toon(Color("9ae0ff"), {"emission": 0.8}), Vector3(0, 2.0, 0), Vector3(0.7, 0.35, 0.7))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.7
	cyl.height = 2.0
	shape.shape = cyl
	shape.position = Vector3(0, 1.0, 0)
	body.add_child(shape)
	holder.add_child(body)
	var splash := VfxKit._particles(holder, pos + Vector3(0, 2.0, 0), Color("bfe8ff"), 40, 1.2, false)
	splash.direction = Vector3.UP
	splash.spread = 25.0
	splash.initial_velocity_min = 2.0
	splash.initial_velocity_max = 3.5
	splash.gravity = Vector3(0, -6.0, 0)


func _lamp(pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = pos
	add_child(holder)
	MeshKit.part(holder, MeshKit.cylinder(), MeshKit.toon(Color("4a4a58")), Vector3(0, 1.6, 0), Vector3(0.14, 3.2, 0.14))
	MeshKit.part(holder, MeshKit.sphere_low(), MeshKit.toon(Color("ffe9a0"), {"emission": 2.0}), Vector3(0, 3.3, 0), Vector3(0.45, 0.45, 0.45))
	var light := OmniLight3D.new()
	light.light_color = Color("ffe9b0")
	light.light_energy = 0.7
	light.omni_range = 7.0
	light.position = Vector3(0, 3.3, 0)
	holder.add_child(light)


func _add_npc(role: String, npc_name: String, class_id: StringName, title: String, pos: Vector3, model := "") -> void:
	var npc := Npc.new()
	npc.position = pos
	add_child(npc)
	npc.setup(role, npc_name, class_id, title, model)
	npc.face(_start)
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
			if Game.profile.level < int(portal.level):
				if _portal_hold == 0.0:
					Game.say("ต้องเลเวล %d ขึ้นไปถึงจะเข้าได้" % int(portal.level), &"warning")
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
	for npc in npcs:
		if npc.role == "elder":
			var quest_id := QuestData.current_quest()
			npc.marker.visible = quest_id != "" and Game.quest_status(quest_id) in ["new", "ready"] and Game.profile.level >= int(QuestData.get_quest(quest_id).get("level", 1)) - 1
	interact_changed.emit(label)


func interact() -> void:
	if current_interact.has("npc"):
		var npc: Npc = current_interact.npc
		npc.face(hero.global_position)
		npc_interact.emit(npc.role)


# ---------------------------------------------------------------------------
# Monsters, bosses, drops
# ---------------------------------------------------------------------------

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


## A flat painted patch plus a signpost naming the camp and its levels.
func _make_camp_marker(camp: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "Camp"
	holder.position = Vector3(camp.pos.x, 0, camp.pos.y)
	add_child(holder)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = float(camp.radius)
	cyl.bottom_radius = float(camp.radius)
	cyl.height = 0.02
	cyl.radial_segments = 40
	disc.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var tint: Color = data.ground
	mat.albedo_color = tint.lightened(0.18)
	mat.albedo_color.a = 0.55
	disc.material_override = mat
	disc.position.y = 0.03
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(disc)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = float(camp.radius) - 0.22
	torus.outer_radius = float(camp.radius)
	torus.rings = 40
	torus.ring_segments = 4
	ring.mesh = torus
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color("fff2b0")
	ring.material_override = ring_mat
	ring.scale = Vector3(1, 0.05, 1)
	ring.position.y = 0.05
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(ring)
	# Signpost on the side facing the village.
	var sign_pos := Vector3(-float(camp.radius) + 1.0, 0, 0)
	MeshKit.part(holder, MeshKit.cylinder(), MeshKit.toon(Color("7a5230")), sign_pos + Vector3(0, 1.1, 0), Vector3(0.16, 2.2, 0.16))
	MeshKit.part(holder, MeshKit.box(), MeshKit.toon(Color("a8763e")), sign_pos + Vector3(0, 2.1, 0), Vector3(1.9, 0.7, 0.14))
	var label := Label3D.new()
	label.text = "%s\nLv.%d-%d" % [camp.name, camp.levels[0], camp.levels[1]]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.008
	label.font_size = 40
	label.outline_size = 12
	label.modulate = Color("fff2c0")
	label.position = sign_pos + Vector3(0, 3.1, 0)
	label.visibility_range_end = 40.0
	holder.add_child(label)


func _tick_boss(delta: float) -> void:
	if not data.has("boss"):
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


func _on_mob_died(mob: Mob) -> void:
	_kills += 1
	var level_gap: int = Game.profile.level - mob.level
	var exp_scale := 1.0 if level_gap <= 4 else maxf(0.15, 1.0 - 0.17 * float(level_gap - 4))
	var exp_gain := int(round(float(mob.stats.exp) * exp_scale))
	Game.add_exp(exp_gain)
	Game.party_add_exp(exp_gain)
	BattleVfx.floating_text(self, mob.global_position + Vector3(0, mob.visual.height + 1.0, 0), "+%d EXP" % exp_gain, Color("66e0ff"), 0.8)
	Game.report_kill(mob.monster_id, mob.is_boss)
	_drop_loot(mob)
	if is_instance_valid(hero) and hero.target == mob:
		hero.set_target(null)


func _drop_loot(mob: Mob) -> void:
	var from := mob.global_position
	var gold: int = int(mob.stats.gold * rng.randf_range(0.7, 1.4))
	_spawn_loot({}, gold, from)
	var boss := mob.is_boss
	var class_id := Game.class_id()
	if boss:
		for i in 3:
			var item := ItemData.generate(mob.level, class_id, rng, maxi(1, ItemData.roll_rarity(rng, 0.3)))
			_spawn_loot(item, 0, from)
		_spawn_loot(ItemData.potion("hp_m", 3), 0, from)
		_spawn_loot(ItemData.potion("mp_m", 2), 0, from)
		for i in 2:
			_spawn_loot(_random_gem(mob.level, 1), 0, from)
		return
	if rng.randf() < DROP_RATE_GEM:
		_spawn_loot(_random_gem(mob.level, 0), 0, from)
	if rng.randf() < DROP_RATE_GEAR:
		_spawn_loot(ItemData.generate(mob.level, class_id, rng), 0, from)
	if rng.randf() < DROP_RATE_POTION:
		var tier := "s" if mob.level < 9 else ("m" if mob.level < 22 else "l")
		_spawn_loot(ItemData.potion(("hp_" if rng.randf() < 0.6 else "mp_") + tier, 1), 0, from)


func _random_gem(level: int, bonus_size: int) -> Dictionary:
	var kinds := ItemData.GEMS.keys()
	var size := clampi((0 if level < 12 else (1 if level < 26 else 2)) + (bonus_size if rng.randf() < 0.5 else 0), 0, 2)
	return ItemData.gem(String(kinds[rng.randi() % kinds.size()]), size)


func _spawn_loot(item: Dictionary, gold: int, from: Vector3) -> void:
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
	for id in [&"meadow", &"dark_forest", &"desert", &"snow", &"volcano"]:
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
