extends Node
## Triangles and draws of the guild war's castle (SiegeArena) by node, built on its own:
##   godot --headless --path . res://tests/tools/siege_mesh_probe.tscn
## One line a node under the zone: its triangles (a MultiMesh: instances x its mesh's) and
## surfaces (each a draw), then the totals.


func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	GameSettings.quality = 1
	var zone := Node3D.new()
	add_child(zone)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	SiegeArena.build(zone, rng, [Color.RED, Color.BLUE])
	var total := 0
	var draws := 0
	var rows: Array = []
	for node in _all(zone):
		var tris := 0
		var surfaces := 0
		if node is MultiMeshInstance3D:
			var mm := (node as MultiMeshInstance3D).multimesh
			if mm != null and mm.mesh != null:
				tris = _tris(mm.mesh) * mm.instance_count
				surfaces = mm.mesh.get_surface_count()
		elif node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			tris = _tris((node as MeshInstance3D).mesh)
			surfaces = (node as MeshInstance3D).mesh.get_surface_count()
		if surfaces > 0:
			total += tris
			draws += surfaces
			rows.append([tris, "%s/%s" % [node.get_parent().name, node.name], surfaces])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows.slice(0, 40):
		print("%8d tris %2d draws  %s" % [r[0], r[2], r[1]])
	print("SIEGE_MESH total_tris=%d draws=%d nodes=%d" % [total, draws, rows.size()])
	get_tree().quit(0)


func _all(node: Node) -> Array:
	var out: Array = [node]
	for c in node.get_children():
		out.append_array(_all(c))
	return out


func _tris(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var idx: Variant = arrays[Mesh.ARRAY_INDEX]
		if idx != null and (idx as PackedInt32Array).size() > 0:
			n += (idx as PackedInt32Array).size() / 3
		else:
			n += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n
