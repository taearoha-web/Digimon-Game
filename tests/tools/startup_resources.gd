extends Node
## Lists the resources alive at the title screen with their sizes (audio data,
## textures, meshes), biggest first: what the game holds before any zone loads.
##   godot --rendering-driver opengl3 --path . res://tests/tools/startup_resources.tscn
func _ready() -> void:
	print("autoloads static=%.1fMB" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0))
	var sounds := 0
	for v in [AudioManager]:
		for p in v.get_property_list():
			var val: Variant = v.get(p.name)
			if val is Dictionary:
				var n := 0
				for k in val:
					if val[k] is AudioStreamWAV: n += (val[k] as AudioStreamWAV).data.size()
				if n > 0: print("AUDIO %s %.2fMB (%d)" % [p.name, n / 1048576.0, (val as Dictionary).size()])
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	for i in 10:
		await get_tree().process_frame
	print("static=%.1fMB" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0))
	var seen := {}
	var rows := []
	var by_kind := {}
	_scan_script_constants(rows, seen, by_kind)
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows.slice(0, 40):
		print("RES %7.2fMB %s" % [r[0] / 1048576.0, r[1]])
	for k in by_kind:
		print("KIND %-22s %7.2fMB" % [k, by_kind[k] / 1048576.0])
	get_tree().quit()


func _size(r: Resource) -> int:
	if r is AudioStreamWAV:
		return (r as AudioStreamWAV).data.size()
	if r is AudioStreamOggVorbis:
		return (r as AudioStreamOggVorbis).packet_sequence.packet_data.size() * 64 if false else 0
	if r is Texture2D:
		return (r as Texture2D).get_width() * (r as Texture2D).get_height() * 4
	if r is Mesh:
		var n := 0
		for s in (r as Mesh).get_surface_count():
			for a in (r as Mesh).surface_get_arrays(s):
				if a is PackedVector3Array: n += a.size() * 12
				elif a is PackedVector2Array: n += a.size() * 8
				elif a is PackedColorArray: n += a.size() * 16
				elif a is PackedFloat32Array: n += a.size() * 4
				elif a is PackedInt32Array: n += a.size() * 4
		return n
	return 0


## Every cached resource path under res:// that ResourceLoader holds right now.
func _scan_script_constants(rows: Array, seen: Dictionary, by_kind: Dictionary) -> void:
	for path in _all_files("res://"):
		if ResourceLoader.has_cached(path):
			var r := load(path)
			if r == null or seen.has(r):
				continue
			seen[r] = true
			var n := _size(r)
			if r is PackedScene:
				var inst := (r as PackedScene).instantiate()
				for c in inst.find_children("*", "MeshInstance3D", true, false):
					n += _size((c as MeshInstance3D).mesh) if (c as MeshInstance3D).mesh else 0
				inst.free()
			by_kind[r.get_class()] = int(by_kind.get(r.get_class(), 0)) + n
			rows.append([n, "%s %s" % [r.get_class(), path]])


func _all_files(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		var p := dir.path_join(f.trim_suffix(".import").trim_suffix(".remap"))
		out.append(p)
	for sub in d.get_directories():
		if sub.begins_with(".") or sub in ["docs", "build", "tests", "node_modules", "hosting"]:
			continue
		out.append_array(_all_files(dir.path_join(sub)))
	return out
