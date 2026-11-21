extends SceneTree
## Bakes the create screen's character cards (ChibiBodies.card), once at build time:
## each body standing, three-quarter, on a clear background. The screen shows only
## these PNGs, so no body loads before one is picked.
## xvfb-run godot --rendering-driver opengl3 --path . -s tools/render_body_cards.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	GameSettings.quality = 2
	DirAccess.make_dir_recursive_absolute("res://assets/ui/portraits")
	for gender in 2:
		for i in ChibiBodies.count(gender):
			var viewport := SubViewport.new()
			viewport.size = Vector2i(360, 480)
			viewport.own_world_3d = true
			viewport.transparent_bg = true
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var environment := Environment.new()
			environment.background_mode = Environment.BG_CLEAR_COLOR
			environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			environment.ambient_light_color = Color("e5eaff")
			environment.ambient_light_energy = 0.8
			var world := WorldEnvironment.new()
			world.environment = environment
			viewport.add_child(world)
			var key := DirectionalLight3D.new()
			key.rotation_degrees = Vector3(-24, -28, 0)
			key.light_color = Color("fff1e2")
			key.light_energy = 1.2
			viewport.add_child(key)
			var fill := DirectionalLight3D.new()
			fill.rotation_degrees = Vector3(-12, 135, 0)
			fill.light_color = Color("bacfee")
			fill.light_energy = 0.55
			viewport.add_child(fill)
			var hero := HeroVisual.new()
			viewport.add_child(hero)
			hero.setup(ClassData.DEFAULT, "", false, {}, {"gender": gender, "body": i})
			hero.anim.play("Idle")
			hero.anim.seek(0.3, true)
			hero.anim.pause()
			hero.rotation_degrees.y = 18.0
			var camera := Camera3D.new()
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = 2.75
			camera.position = Vector3(0, 1.22, 5.0)
			viewport.add_child(camera)
			for frame in 5:
				await process_frame
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			image.resize(180, 240, Image.INTERPOLATE_LANCZOS)
			var path := "res://assets/ui/portraits/body_%d_%d.png" % [gender, i]
			if image.save_png(path) != OK:
				push_error("Could not save card: %s" % path)
			viewport.queue_free()
			await process_frame
	quit()
