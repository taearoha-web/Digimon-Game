extends Node
## Where a zone's triangles come from: every mesh instance (and multimesh) in the built
## zone, summed per name group, with the share that also casts shadows (drawn twice).
##   godot --headless --path . res://tests/tools/tri_census.tscn -- town [class] [quality]
var _cache: Dictionary = {}


func _tris(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	if _cache.has(mesh):
		return _cache[mesh]
	var total := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		if arrays.is_empty():
			continue
		var idx = arrays[Mesh.ARRAY_INDEX]
		var n: int = idx.size() if idx != null and idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		total += n / 3
	_cache[mesh] = total
	return total


func _group(node: Node, zone: Node) -> String:
	var path := String(zone.get_path_to(node))
	var parts := path.split("/")
	# Strip auto-numbering ("@MeshInstance3D@12") and digits to group by role.
	var name := String(parts[0])
	var rx := RegEx.new()
	rx.compile("[@0-9]+")
	var key := rx.sub(name, "", true)
	if parts.size() > 2:
		key += "/" + rx.sub(String(parts[1]), "", true)
	return key


func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	var args := OS.get_cmdline_user_args()
	var zone_id := StringName(args[0]) if args.size() > 0 else &"town"
	var cls := StringName(args[1]) if args.size() > 1 else &"summoner"
	GameSettings.quality = int(args[2]) if args.size() > 2 else 2
	Game.new_profile(cls, "Census")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.current_zone = zone_id
	var zone := Zone.new()
	zone.zone_id = zone_id
	add_child(zone)
	await get_tree().create_timer(1.0).timeout
	var groups: Dictionary = {}
	var total := 0
	var shadowed := 0
	var ranged := 0
	for node in zone.find_children("*", "VisualInstance3D", true, false):
		var t := 0
		var shadow := false
		if node is MeshInstance3D:
			t = _tris((node as MeshInstance3D).mesh)
			shadow = (node as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif node is MultiMeshInstance3D:
			var mm := (node as MultiMeshInstance3D).multimesh
			if mm:
				t = _tris(mm.mesh) * mm.visible_instance_count if mm.visible_instance_count >= 0 else _tris(mm.mesh) * mm.instance_count
			shadow = (node as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			continue
		if not (node as VisualInstance3D).is_visible_in_tree():
			continue
		var g := _group(node, zone)
		var row: Array = groups.get(g, [0, 0, 0, 0])
		row[0] += t
		row[1] += 1
		if shadow:
			row[2] += t
			shadowed += t
		if (node as GeometryInstance3D).visibility_range_end > 0.0:
			row[3] += t
			ranged += t
		groups[g] = row
		total += t
	var keys: Array = groups.keys()
	keys.sort_custom(func(a, b): return groups[a][0] > groups[b][0])
	print("CENSUS zone=%s total=%d shadow-casting=%d with-visibility-range=%d" % [zone_id, total, shadowed, ranged])
	for k in keys.slice(0, 22):
		var r: Array = groups[k]
		print("  %-44s tris=%7d  instances=%5d  shadowTris=%7d  rangedTris=%7d" % [k, r[0], r[1], r[2], r[3]])
	get_tree().quit()
