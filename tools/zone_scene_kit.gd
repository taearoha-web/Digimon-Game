extends RefCounted
## Shared helpers for the zone scene build tools (tools/build_*_scene.gd).
## Creates a WorldMap scene root with environment, sun, navigation region +
## builder, and offers one-liners for markers, NPCs, interactables, pickups,
## area triggers and encounter spawners. Load with preload(); not a global
## class because tools/ is excluded from exported builds.

var scene_root: Node3D


func _init(root_name: String, map_script: String, map_id: StringName) -> void:
	scene_root = Node3D.new()
	scene_root.name = root_name
	scene_root.set_script(load(map_script))
	scene_root.set("map_id", map_id)


## Environment, sun and NavigationRegion3D with the builder node inside.
func add_world(builder_script: String, env: Environment, sun_rotation: Vector3, nav_extent: float) -> void:
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	env_node.environment = env
	add(scene_root, env_node)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.set_script(load("res://systems/world/quality_light.gd"))
	sun.rotation_degrees = sun_rotation
	sun.light_energy = 0.68
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 45.0
	add(scene_root, sun)

	var nav := NavigationRegion3D.new()
	nav.name = "NavigationRegion3D"
	nav.navigation_mesh = make_navmesh(nav_extent)
	add(scene_root, nav)
	var builder := Node3D.new()
	builder.name = "Builder"
	builder.set_script(load(builder_script))
	add(nav, builder)


func save(out_scene: String) -> Error:
	var packed := PackedScene.new()
	var err := packed.pack(scene_root)
	if err == OK:
		err = ResourceSaver.save(packed, out_scene)
	scene_root.free()
	return err


func add(parent: Node, child: Node) -> Node:
	parent.add_child(child)
	child.owner = scene_root
	return child


func group_node(node_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	add(scene_root, n)
	return n


func place(node: Node3D, pos: Vector2, yaw_deg: float, keep_clear := true) -> void:
	node.position = Vector3(pos.x, 0.0, pos.y)
	node.rotation_degrees = Vector3(0, yaw_deg, 0)
	node.add_to_group("ground_snap", true)
	if keep_clear:
		node.add_to_group("keep_clear", true)


func marker(parent: Node, marker_name: String, pos: Vector2, yaw_deg: float) -> Marker3D:
	var m := Marker3D.new()
	m.name = marker_name
	add(parent, m)
	place(m, pos, yaw_deg)
	return m


func npc(parent: Node, node_name: String, npc_id: StringName, pos: Vector2, yaw_deg: float) -> void:
	var node := StaticBody3D.new()
	node.name = node_name
	node.set_script(load("res://characters/npc/npc.gd"))
	node.set("npc_id", npc_id)
	node.set("initial_yaw_degrees", yaw_deg)
	add(parent, node)
	place(node, pos, 0.0)


func interactable(parent: Node, node_name: String, script_path: String, pos: Vector2, yaw_deg: float) -> Node3D:
	var node := Area3D.new()
	node.name = node_name
	node.set_script(load(script_path))
	add(parent, node)
	place(node, pos, yaw_deg)
	return node


func signpost(parent: Node, node_name: String, dialogue_id: StringName, title: String, pos: Vector2, yaw_deg: float) -> Node3D:
	var node := interactable(parent, node_name, "res://systems/world/signpost.gd", pos, yaw_deg)
	node.set("dialogue_id", dialogue_id)
	node.set("title", title)
	return node


func portal(parent: Node, node_name: String, pos: Vector2, yaw_deg: float, target_map: StringName, target_spawn: StringName,
		required_flag: StringName) -> Node3D:
	var node := interactable(parent, node_name, "res://systems/world/portal.gd", pos, yaw_deg)
	node.set("target_map_id", target_map)
	node.set("target_spawn_id", target_spawn)
	node.set("required_flag", required_flag)
	node.set_meta("clear_radius", 6.0)
	return node


func pickup(parent: Node, pickup_id: String, item_id: StringName, amount: int, pos: Vector2) -> void:
	var node := interactable(parent, pickup_id, "res://systems/world/world_pickup.gd", pos, 0.0)
	node.set("pickup_id", pickup_id)
	node.set("item_id", item_id)
	node.set("amount", amount)
	node.set_meta("clear_radius", 1.5)


func trigger(parent: Node, area_id: StringName, display_name: String, pos: Vector2, radius: float) -> void:
	var node := Area3D.new()
	node.name = String(area_id)
	node.set_script(load("res://systems/world/area_trigger.gd"))
	node.set("area_id", area_id)
	node.set("display_name", display_name)
	node.set("radius", radius)
	add(parent, node)
	place(node, pos, 0.0, false)


func spawner(parent: Node, node_name: String, table_id: StringName, pos: Vector2, extents: Vector3, initial: int) -> void:
	var node := Node3D.new()
	node.name = node_name
	node.set_script(load("res://systems/world/encounter_spawner.gd"))
	node.set("table_id", table_id)
	node.set("extents", extents)
	node.set("initial_spawns", initial)
	add(parent, node)
	place(node, pos, 0.0, false)


static func make_navmesh(extent: float) -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.cell_size = 0.3
	nm.cell_height = 0.25
	nm.agent_radius = 0.6
	nm.agent_height = 1.0
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 46.0
	nm.filter_baking_aabb = AABB(Vector3(-extent, -6, -extent), Vector3(extent * 2.0, 30, extent * 2.0))
	return nm


## Sky + ambient + fog + glow tuned for the toon look. opts: sky colours
## (top, horizon, bottom, grid), ambient, fog colour/density.
static func make_environment(out_path: String, opts := {}) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://shaders/digital_sky.gdshader")
	for key in ["top_color", "horizon_color", "bottom_color", "grid_color"]:
		if opts.has(key):
			sky_material.set_shader_parameter(key, opts[key])
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = opts.get("ambient", Color(0.7, 0.78, 1.0))
	env.ambient_light_energy = 0.34
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = opts.get("fog_color", Color(0.62, 0.76, 0.98))
	env.fog_light_energy = 0.9
	env.fog_density = opts.get("fog_density", 0.0022)
	env.fog_sky_affect = 0.0
	# Glow only picks up emissive details (threshold above lit albedo).
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.6
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	ResourceSaver.save(env, out_path)
	return load(out_path)
