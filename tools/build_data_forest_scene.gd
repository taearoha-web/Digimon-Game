extends SceneTree
## Assembles res://maps/data_forest/data_forest.tscn (and its environment).
## After generation the .tscn is a normal scene: tweak it in the editor.
## Re-running this tool OVERWRITES the scene.
##
## Usage: godot --headless --path . -s res://tools/build_data_forest_scene.gd

const Kit := preload("res://tools/zone_scene_kit.gd")
const OUT_SCENE := "res://maps/data_forest/data_forest.tscn"
const OUT_ENV := "res://resources/environments/data_forest_env.tres"


func _initialize() -> void:
	var kit := Kit.new("DataForest", "res://maps/data_forest/data_forest.gd", &"data_forest")
	var env := Kit.make_environment(OUT_ENV, {
		"top_color": Color(0.2, 0.36, 0.72),
		"horizon_color": Color(0.74, 0.92, 0.94),
		"bottom_color": Color(0.3, 0.52, 0.62),
		"grid_color": Color(0.55, 1.0, 0.85),
		"ambient": Color(0.66, 0.8, 0.95),
		"fog_color": Color(0.5, 0.76, 0.8),
		"fog_density": 0.0024,
	})
	kit.add_world("res://maps/data_forest/data_forest_builder.gd", env, Vector3(-48, 30, 0), 72.0)

	var spawns := kit.group_node("SpawnPoints")
	kit.marker(spawns, "from_starter_zone", Vector2(-40, 40), 135.0)
	kit.marker(spawns, "start", Vector2(-27, 27), 135.0)

	var npcs := kit.group_node("NPCs")
	kit.npc(npcs, "Lumi", &"lumi", Vector2(-22.95, 28.3), 171.0)

	var objects := kit.group_node("Interactables")
	var terminal := kit.interactable(objects, "RecoveryTerminal", "res://systems/world/recovery_terminal.gd", Vector2(-28, 21.5), 90.0)
	terminal.set("respawn_spawn_id", &"start")
	kit.signpost(objects, "SignCamp", &"sign_forest_camp", "Ranger Camp", Vector2(-31.5, 27), -45.0)
	kit.signpost(objects, "SignLake", &"sign_lake", "Crystal Lake", Vector2(4, -13), -37.0)
	kit.signpost(objects, "SignRuins", &"sign_ruins", "Old Ruins", Vector2(26, 12), -90.0)
	kit.portal(objects, "GatewayHome", Vector2(-46, 46), 135.0, &"starter_zone", &"from_gateway", &"")

	var pickups := kit.group_node("Pickups")
	kit.pickup(pickups, "forest_vital_chip", &"vital_chip", 1, Vector2(44, 10))
	kit.pickup(pickups, "forest_focus_chip", &"focus_chip", 1, Vector2(-12, -48))
	kit.pickup(pickups, "forest_patch_lake", &"medium_patch", 1, Vector2(-10, -24))
	kit.pickup(pickups, "forest_capsule_grove", &"sp_capsule", 1, Vector2(24, 40))
	kit.pickup(pickups, "forest_treat_hollow", &"friend_treat", 2, Vector2(-44, -16))
	kit.pickup(pickups, "forest_reboot", &"reboot_chip", 1, Vector2(50, 30))
	kit.pickup(pickups, "forest_shard", &"evo_shard", 1, Vector2(22, -44))

	var triggers := kit.group_node("AreaTriggers")
	kit.trigger(triggers, &"ranger_camp", "Ranger Camp", Vector2(-22, 22), 10.0)
	kit.trigger(triggers, &"crystal_lake", "Crystal Lake", Vector2(4, -30), 18.0)
	kit.trigger(triggers, &"old_ruins", "Old Ruins", Vector2(40, 6), 12.0)
	kit.trigger(triggers, &"whispering_grove", "Whispering Grove", Vector2(18, 36), 13.0)
	kit.trigger(triggers, &"mossy_hollow", "Mossy Hollow", Vector2(-42, -12), 11.0)
	kit.trigger(triggers, &"gateway_home", "Gateway", Vector2(-46, 46), 7.0)

	var spawners := kit.group_node("Spawners")
	kit.spawner(spawners, "GroveSpawner", &"forest_grove", Vector2(18, 36), Vector3(12, 0, 8), 3)
	kit.spawner(spawners, "HollowSpawner", &"forest_grove", Vector2(-42, -12), Vector3(8, 0, 9), 2)
	kit.spawner(spawners, "RuinsSpawner", &"old_ruins", Vector2(40, 6), Vector3(7, 0, 7), 2)

	var waypoints := kit.group_node("Waypoints")
	for w in [["crystal_lake", Vector2(2, -14)], ["old_ruins", Vector2(30, 7)], ["ranger_camp", Vector2(-22, 22)],
			["gateway", Vector2(-46, 46)]]:
		kit.marker(waypoints, w[0], w[1], 0.0)

	print("build_data_forest_scene: ", error_string(kit.save(OUT_SCENE)))
	quit()
