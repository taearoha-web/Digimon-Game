extends Node3D
## Contact sheet of the MeleeArt unit shapes in their shaders, held at mid-life.
## xvfb-run -a godot --rendering-driver opengl3 --path . res://tests/tools/melee_shapes_sheet.tscn -- OUT.png

const SHOW := [["spear", 4, "x"], ["blade", 4, "x"], ["dragon", 4, "x"], ["banner", 4, "u"], ["chain", 4, "x"], ["light_cross", 4, "u"],
	["hexplate", 2, "u"], ["hexwall", 2, "f"], ["hexdome", 2, "f"], ["aura", 3, "a"], ["spiral", 0, "f"], ["arc220", 0, "f"],
	["cross", 1, "f"], ["cracks", 1, "f"], ["ring", 5, "f"], ["streak", 0, "f"]]


func _ready() -> void:
	GameSettings.load_settings()
	GameSettings.quality = 2
	get_window().size = Vector2i(1200, 800)
	Scenery.environment(self, Color("6d91ac"), Color("7f9b9c"), Color("d3e5f0"), Color("ffedda"))
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	ground.material_override = MeshKit.toon(Color("526e60"))
	add_child(ground)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 15.0
	add_child(cam)
	cam.position = Vector3(6, 11, 15)
	cam.look_at(Vector3(6, 0.5, 3))
	cam.make_current()
	await get_tree().process_frame
	var c := [Color("ff6a2a"), Color("fff0b0"), Color("4a0a18")]
	for i in SHOW.size():
		var entry: Array = SHOW[i]
		var at := Vector3(float(i % 4) * 3.4, 0, float(i / 4) * 2.6)
		MeleeArt._rig_count = 0
		var rig := MeleeArt.acquire(self, at, 0.0, 3.0)
		if rig == null:
			continue
		var style := {"initial": 1.0, "dissolve": 0.95, "sweep": 0.01, "pattern": 1.0 if entry[0] == "dragon" else 0.0, "wave": 0.15 if entry[0] == "banner" else 0.0}
		if entry[2] == "x":
			style["bill"] = Vector3.RIGHT
		elif entry[2] == "u":
			style["bill"] = "upright"
		var size := Vector3.ONE * (1.6 if entry[2] != "f" else 1.0)
		if entry[2] == "a":
			size = Vector3(0.8, 2.1, 0.8)
			style["pulse"] = 96.0
			style["veins"] = 1.0
		rig.layer(entry[0], int(entry[1]), c, Vector3(0, 0.05 if entry[2] == "f" else 0.8, 0), size, Vector3.ZERO, 0.0, 3.0, style, true)
		rig.commit()
	MeleeArt._rig_count = 0
	var debris := MeleeArt.acquire(self, Vector3(13.6, 0, 6), 0.0, 3.0)
	debris.chips(Vector3.ZERO, 12, 5.0, Color("8c7a62"), 0.6, 0.3)
	debris.emit(MeleeArt.SPARK, 20, Vector3.UP, Vector3.UP * 5.0, 0.8, Color("ff8a3a"), 0.14, 1.0, 0.0, 6.0)
	debris.emit(MeleeArt.SHARD, 10, Vector3.UP * 1.5, Vector3.UP * 1.0, 0.8, Color("bfe4ff"), 0.4, 1.5, 0.0, 0.0)
	debris.commit()
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
