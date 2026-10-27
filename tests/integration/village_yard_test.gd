extends Node
## The village's random rocks and trees must never land where a villager stands or on
## the ground in front where the hero walks up to talk. These layout seeds each put a big
## rock (or a tree trunk) in front of the elder before the villagers' yards were cleared,
## which failed flow_test's "inside a wall" check on about one town build in 150.
## godot --headless --path . res://tests/integration/village_yard_test.tscn
const SEEDS := [88, 89, 206, 318, 465, 487, 535, 786, 803, -6635177975616929427, 7040182240606962677,
	4851753353769316937, -2885833577669833673, -628667933669102549, 8046892783805682638, -705214897870573975]

var failures: Array[String] = []
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


## Villagers whose own spot or the spot 2 m in front of them is inside a collider
## (the same query as flow_test's village check).
func _blocked(zone: Zone) -> Array[String]:
	var space := zone.get_world_3d().direct_space_state
	var blocked: Array[String] = []
	for npc in zone.npcs:
		if npc is NoticeBoard or npc.role == "warp":
			continue
		var front := Vector3(sin(npc.visual.rotation.y), 0, cos(npc.visual.rotation.y))
		for spot in [npc.global_position, npc.global_position + front * 2.0]:
			var q := PhysicsShapeQueryParameters3D.new()
			var ball := SphereShape3D.new()
			ball.radius = 0.45
			q.shape = ball
			q.transform = Transform3D(Basis(), spot + Vector3(0, 1.0, 0))
			q.collision_mask = 1
			if not space.intersect_shape(q, 4).is_empty():
				blocked.append(npc.role)
	return blocked


func _ready() -> void:
	Game.set_process(false)
	Game.new_profile(&"warrior", "Yard")
	for layout_seed in SEEDS:
		Game.current_zone = &"town"
		var zone := Zone.new()
		zone.zone_id = &"town"
		zone.layout_seed = layout_seed
		add_child(zone)
		await get_tree().physics_frame
		await get_tree().physics_frame
		check(zone.is_built and zone.npcs.size() == 16, "seed %d: the village is built with its villagers (%d)" % [layout_seed, zone.npcs.size()])
		var blocked := _blocked(zone)
		check(blocked.is_empty(), "seed %d: no villager or the spot in front of them is inside a rock, tree or wall (%s)" % [layout_seed, blocked])
		zone.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	print("village_yard_test: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)
