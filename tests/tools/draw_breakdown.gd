extends Node
## Where a field's draw calls go: builds the zone with a Lv.100 hero hunting on auto,
## then counts the visible geometry by owner (hero, mobs, world players, party, effects,
## scenery) with its surfaces and whether it casts a shadow, beside the renderer's total.
## Needs a real renderer:
##   xvfb-run -a godot --rendering-driver opengl3 --path . res://tests/tools/draw_breakdown.tscn -- [zone] [class] [quality] [seconds]


func _ready() -> void:
	Game.set_process(false)
	var args := OS.get_cmdline_user_args()
	var zone_id := StringName(args[0]) if args.size() > 0 else &"dawn_forest"
	var cls := StringName(args[1]) if args.size() > 1 else &"darklord"
	GameSettings.quality = int(args[2]) if args.size() > 2 else 1
	var seconds := float(args[3]) if args.size() > 3 else 8.0
	Game.new_profile(cls, "Draw")
	var p := Game.profile
	p.level = 100
	p.adv = 4
	Game.current_zone = zone_id
	var zone := Zone.new()
	zone.zone_id = zone_id
	add_child(zone)
	await get_tree().create_timer(1.0).timeout
	var hero := zone.hero
	var camp: Dictionary = zone.data.camps[0]
	hero.global_position = Vector3(camp.pos.x - float(camp.radius) * 0.5, 0.2, camp.pos.y)
	p.hp = 1000000000
	p.mp = 1000000000
	hero.set_auto(true)
	for i in 4:
		await get_tree().create_timer(seconds / 4.0).timeout
		await RenderingServer.frame_post_draw
		_report(zone, "t+%ds" % int(seconds / 4.0 * (i + 1)))
	get_tree().quit()


func _report(zone: Node, label: String) -> void:
	var total := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var objects := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var tris := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var cats := {}
	for node in zone.find_children("*", "GeometryInstance3D", true, false):
		var g := node as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var surfaces := 1
		if g is MeshInstance3D and (g as MeshInstance3D).mesh != null:
			surfaces = (g as MeshInstance3D).mesh.get_surface_count()
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null and (g as MultiMeshInstance3D).multimesh.mesh != null:
			surfaces = (g as MultiMeshInstance3D).multimesh.mesh.get_surface_count()
		var cat := _category(g)
		var row: Array = cats.get(cat, [0, 0, 0])
		row[0] += 1
		row[1] += surfaces
		if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			row[2] += surfaces
		cats[cat] = row
	print("DRAW %s total_draws=%d objects=%d triangles=%d" % [label, total, objects, tris])
	var keys := cats.keys()
	keys.sort_custom(func(a, b): return cats[a][1] > cats[b][1])
	for k in keys:
		print("  %-16s nodes=%5d surfaces=%5d shadow_surfaces=%5d" % [k, cats[k][0], cats[k][1], cats[k][2]])


static func _category(n: Node) -> String:
	var at := n
	while at != null:
		if at is Hero:
			return "hero"
		if at.is_in_group("mobs"):
			return "mobs"
		if at.is_in_group("world_players"):
			return "world_players"
		if at.is_in_group("companions") or at.is_in_group("summons"):
			return "party/summons"
		if at is Zone:
			return "scenery/effects"
		at = at.get_parent()
	return "other"
