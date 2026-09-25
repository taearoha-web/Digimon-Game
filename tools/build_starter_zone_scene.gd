extends SceneTree
## Assembles res://maps/starter_zone/starter_zone.tscn (and its environment)
## from a readable layout table. After generation the .tscn is a normal scene:
## move NPCs, pickups, triggers and spawners freely in the editor.
## Re-running this tool OVERWRITES the scene.
##
## Usage: godot --headless --path . -s res://tools/build_starter_zone_scene.gd

const OUT_SCENE := "res://maps/starter_zone/starter_zone.tscn"
const OUT_ENV := "res://resources/environments/starter_zone_env.tres"

var scene_root: Node3D


func _initialize() -> void:
	scene_root = Node3D.new()
	scene_root.name = "StarterZone"
	scene_root.set_script(load("res://maps/starter_zone/starter_zone.gd"))
	scene_root.set("map_id", &"starter_zone")

	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	env_node.environment = _make_environment()
	_add(scene_root, env_node)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.set_script(load("res://systems/world/quality_light.gd"))
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 0.68
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 45.0
	_add(scene_root, sun)

	var nav := NavigationRegion3D.new()
	nav.name = "NavigationRegion3D"
	nav.navigation_mesh = _make_navmesh()
	_add(scene_root, nav)
	var builder := Node3D.new()
	builder.name = "Builder"
	builder.set_script(load("res://maps/starter_zone/starter_zone_builder.gd"))
	_add(nav, builder)

	var spawns := _group_node("SpawnPoints")
	_marker(spawns, "start", Vector2(-40, 17), 150.0)
	_marker(spawns, "from_gateway", Vector2(44, -41), -45.0)

	var npcs := _group_node("NPCs")
	_npc(npcs, "Mira", &"mira", Vector2(-30.5, 8.0), -46.0)
	_npc(npcs, "Byte", &"byte", Vector2(-46, 3), 90.0)
	_npc(npcs, "Kai", &"kai", Vector2(13, -7), -120.0)

	var objects := _group_node("Interactables")
	var terminal := _interactable(objects, "RecoveryTerminal", "res://systems/world/recovery_terminal.gd", Vector2(-38, 0.5), 0.0)
	terminal.set("respawn_spawn_id", &"start")
	var sign1 := _interactable(objects, "SignPlaza", "res://systems/world/signpost.gd", Vector2(-29, 13), -60.0)
	sign1.set("dialogue_id", &"sign_plaza")
	sign1.set("title", "Plaza")
	var sign2 := _interactable(objects, "SignMeadow", "res://systems/world/signpost.gd", Vector2(19, 12), -40.0)
	sign2.set("dialogue_id", &"sign_meadow")
	sign2.set("title", "Wild Meadow")
	var sign3 := _interactable(objects, "SignTraining", "res://systems/world/signpost.gd", Vector2(18, -9), -90.0)
	sign3.set("dialogue_id", &"sign_training")
	sign3.set("title", "Training")
	var portal := _interactable(objects, "Gateway", "res://systems/world/portal.gd", Vector2(48, -48), -45.0)
	portal.set("target_map_id", &"data_forest")
	portal.set("target_spawn_id", &"from_starter_zone")
	portal.set("required_flag", &"gateway_unlocked")
	portal.set_meta("clear_radius", 6.0)

	var pickups := _group_node("Pickups")
	_pickup(pickups, "frag_hill", &"data_fragment", 1, Vector2(-26, -38))
	_pickup(pickups, "frag_river", &"data_fragment", 1, Vector2(13, 22))
	_pickup(pickups, "frag_meadow", &"data_fragment", 1, Vector2(38, 35))
	_pickup(pickups, "frag_forest", &"data_fragment", 1, Vector2(-60, -8))
	_pickup(pickups, "patch_path", &"small_patch", 2, Vector2(-12, -6))
	_pickup(pickups, "patch_training", &"small_patch", 1, Vector2(31, -31))
	_pickup(pickups, "treat_meadow", &"friend_treat", 1, Vector2(19, 37))
	_pickup(pickups, "sp_hill", &"sp_capsule", 1, Vector2(-19, -45))
	_pickup(pickups, "chip_grove", &"reboot_chip", 1, Vector2(-58, 34))

	var triggers := _group_node("AreaTriggers")
	_trigger(triggers, &"start_plaza", "Start Plaza", Vector2(-38, 10), 10.0)
	_trigger(triggers, &"training_grounds", "Training Grounds", Vector2(24, -22), 10.5)
	_trigger(triggers, &"wild_meadow", "Wild Meadow", Vector2(28, 28), 15.0)
	_trigger(triggers, &"bitstream_river", "Bitstream River", Vector2(2, 0), 5.0)
	_trigger(triggers, &"gateway", "Gateway", Vector2(48, -48), 7.0)

	var spawners := _group_node("Spawners")
	_spawner(spawners, "MeadowSpawner", &"starter_meadow", Vector2(28, 28), Vector3(13, 0, 9), 3)
	_spawner(spawners, "TrainingSpawner", &"training_grounds", Vector2(24, -22), Vector3(6, 0, 6), 1)

	var waypoints := _group_node("Waypoints")
	for w in [["training_grounds", Vector2(24, -22)], ["wild_meadow", Vector2(28, 28)], ["gateway", Vector2(48, -48)],
			["start_plaza", Vector2(-38, 10)]]:
		_marker(waypoints, w[0], w[1], 0.0)

	var packed := PackedScene.new()
	var err := packed.pack(scene_root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT_SCENE)
	print("build_starter_zone_scene: ", error_string(err))
	scene_root.free()
	quit()


func _add(parent: Node, child: Node) -> Node:
	parent.add_child(child)
	child.owner = scene_root
	return child


func _group_node(node_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	_add(scene_root, n)
	return n


func _place(node: Node3D, pos: Vector2, yaw_deg: float, keep_clear := true) -> void:
	node.position = Vector3(pos.x, 0.0, pos.y)
	node.rotation_degrees = Vector3(0, yaw_deg, 0)
	node.add_to_group("ground_snap", true)
	if keep_clear:
		node.add_to_group("keep_clear", true)


func _marker(parent: Node, marker_name: String, pos: Vector2, yaw_deg: float) -> Marker3D:
	var m := Marker3D.new()
	m.name = marker_name
	_add(parent, m)
	_place(m, pos, yaw_deg)
	return m


func _npc(parent: Node, node_name: String, npc_id: StringName, pos: Vector2, yaw_deg: float) -> void:
	var npc := StaticBody3D.new()
	npc.name = node_name
	npc.set_script(load("res://characters/npc/npc.gd"))
	npc.set("npc_id", npc_id)
	npc.set("initial_yaw_degrees", yaw_deg)
	_add(parent, npc)
	_place(npc, pos, 0.0)


func _interactable(parent: Node, node_name: String, script_path: String, pos: Vector2, yaw_deg: float) -> Node3D:
	var node := Area3D.new()
	node.name = node_name
	node.set_script(load(script_path))
	_add(parent, node)
	_place(node, pos, yaw_deg)
	return node


func _pickup(parent: Node, pickup_id: String, item_id: StringName, amount: int, pos: Vector2) -> void:
	var node := _interactable(parent, pickup_id, "res://systems/world/world_pickup.gd", pos, 0.0)
	node.set("pickup_id", pickup_id)
	node.set("item_id", item_id)
	node.set("amount", amount)
	node.set_meta("clear_radius", 1.5)


func _trigger(parent: Node, area_id: StringName, display_name: String, pos: Vector2, radius: float) -> void:
	var trigger := Area3D.new()
	trigger.name = String(area_id)
	trigger.set_script(load("res://systems/world/area_trigger.gd"))
	trigger.set("area_id", area_id)
	trigger.set("display_name", display_name)
	trigger.set("radius", radius)
	_add(parent, trigger)
	_place(trigger, pos, 0.0, false)


func _spawner(parent: Node, node_name: String, table_id: StringName, pos: Vector2, extents: Vector3, initial: int) -> void:
	var spawner := Node3D.new()
	spawner.name = node_name
	spawner.set_script(load("res://systems/world/encounter_spawner.gd"))
	spawner.set("table_id", table_id)
	spawner.set("extents", extents)
	spawner.set("initial_spawns", initial)
	_add(parent, spawner)
	_place(spawner, pos, 0.0, false)


func _make_navmesh() -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.cell_size = 0.3
	nm.cell_height = 0.25
	nm.agent_radius = 0.6
	nm.agent_height = 1.0
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 46.0
	nm.filter_baking_aabb = AABB(Vector3(-76, -6, -76), Vector3(152, 30, 152))
	return nm


func _make_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://shaders/digital_sky.gdshader")
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.78, 1.0)
	env.ambient_light_energy = 0.34
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.76, 0.98)
	env.fog_light_energy = 0.9
	env.fog_density = 0.0022
	env.fog_sky_affect = 0.0
	# Glow only picks up emissive details (threshold above lit albedo).
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.6
	DirAccess.make_dir_recursive_absolute(OUT_ENV.get_base_dir())
	ResourceSaver.save(env, OUT_ENV)
	return load(OUT_ENV)
