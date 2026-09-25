extends SceneTree
## Assembles res://maps/starter_zone/starter_zone.tscn (and its environment)
## from a readable layout table. After generation the .tscn is a normal scene:
## move NPCs, pickups, triggers and spawners freely in the editor.
## Re-running this tool OVERWRITES the scene.
##
## Usage: godot --headless --path . -s res://tools/build_starter_zone_scene.gd [-- --out=res://path.tscn]

const Kit := preload("res://tools/zone_scene_kit.gd")
const OUT_SCENE := "res://maps/starter_zone/starter_zone.tscn"
const OUT_ENV := "res://resources/environments/starter_zone_env.tres"


func _initialize() -> void:
	var out_scene := OUT_SCENE
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_scene = arg.trim_prefix("--out=")
	var kit := Kit.new("StarterZone", "res://maps/starter_zone/starter_zone.gd", &"starter_zone")
	kit.add_world("res://maps/starter_zone/starter_zone_builder.gd", Kit.make_environment(OUT_ENV), Vector3(-52, -38, 0), 76.0)

	var spawns := kit.group_node("SpawnPoints")
	kit.marker(spawns, "start", Vector2(-40, 17), 150.0)
	kit.marker(spawns, "from_gateway", Vector2(44, -41), -45.0)

	var npcs := kit.group_node("NPCs")
	kit.npc(npcs, "Mira", &"mira", Vector2(-30.5, 8.0), -46.0)
	kit.npc(npcs, "Byte", &"byte", Vector2(-46, 3), 90.0)
	kit.npc(npcs, "Kai", &"kai", Vector2(13, -7), -120.0)
	kit.npc(npcs, "Pip", &"pip", Vector2(-45.5, 11.5), 75.0)

	var objects := kit.group_node("Interactables")
	var terminal := kit.interactable(objects, "RecoveryTerminal", "res://systems/world/recovery_terminal.gd", Vector2(-38, 0.5), 0.0)
	terminal.set("respawn_spawn_id", &"start")
	kit.signpost(objects, "SignPlaza", &"sign_plaza", "Plaza", Vector2(-29, 13), -60.0)
	kit.signpost(objects, "SignMeadow", &"sign_meadow", "Wild Meadow", Vector2(19, 12), -40.0)
	kit.signpost(objects, "SignTraining", &"sign_training", "Training", Vector2(18, -9), -90.0)
	kit.portal(objects, "Gateway", Vector2(48, -48), -45.0, &"data_forest", &"from_starter_zone", &"gateway_unlocked")

	var pickups := kit.group_node("Pickups")
	kit.pickup(pickups, "frag_hill", &"data_fragment", 1, Vector2(-26, -38))
	kit.pickup(pickups, "frag_river", &"data_fragment", 1, Vector2(13, 22))
	kit.pickup(pickups, "frag_meadow", &"data_fragment", 1, Vector2(38, 35))
	kit.pickup(pickups, "frag_forest", &"data_fragment", 1, Vector2(-60, -8))
	kit.pickup(pickups, "patch_path", &"small_patch", 2, Vector2(-12, -6))
	kit.pickup(pickups, "patch_training", &"small_patch", 1, Vector2(31, -31))
	kit.pickup(pickups, "treat_meadow", &"friend_treat", 1, Vector2(19, 37))
	kit.pickup(pickups, "sp_hill", &"sp_capsule", 1, Vector2(-19, -45))
	kit.pickup(pickups, "chip_grove", &"reboot_chip", 1, Vector2(-58, 34))

	var triggers := kit.group_node("AreaTriggers")
	kit.trigger(triggers, &"start_plaza", "Start Plaza", Vector2(-38, 10), 10.0)
	kit.trigger(triggers, &"training_grounds", "Training Grounds", Vector2(24, -22), 10.5)
	kit.trigger(triggers, &"wild_meadow", "Wild Meadow", Vector2(28, 28), 15.0)
	kit.trigger(triggers, &"bitstream_river", "Bitstream River", Vector2(2, 0), 5.0)
	kit.trigger(triggers, &"gateway", "Gateway", Vector2(48, -48), 7.0)

	var spawners := kit.group_node("Spawners")
	kit.spawner(spawners, "MeadowSpawner", &"starter_meadow", Vector2(28, 28), Vector3(13, 0, 9), 3)
	kit.spawner(spawners, "TrainingSpawner", &"training_grounds", Vector2(24, -22), Vector3(6, 0, 6), 1)

	var waypoints := kit.group_node("Waypoints")
	for w in [["training_grounds", Vector2(24, -22)], ["wild_meadow", Vector2(28, 28)], ["gateway", Vector2(48, -48)],
			["start_plaza", Vector2(-38, 10)]]:
		kit.marker(waypoints, w[0], w[1], 0.0)

	print("build_starter_zone_scene: ", error_string(kit.save(out_scene)))
	quit()
