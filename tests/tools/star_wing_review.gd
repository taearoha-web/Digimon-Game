extends Node3D
var checks:=0
var failures:=0
var output:="/workspace/toon-artifacts/star-wings-092/review"
var camera:Camera3D
var title:Label
func check(ok:bool,note:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",note)
func capture(name:String)->void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/"+name+".png")
func _ready()->void:
	Game.set_process(false)
	InputSetup.ensure_defaults()
	GameSettings.quality=2
	get_window().size=Vector2i(1000,800);get_window().content_scale_size=Vector2i(1000,800)
	DirAccess.make_dir_recursive_absolute(output)
	Scenery.environment(self,Color("53697e"),Color("75909d"),Color("d7e6f0"),Color("fff1dc"))
	var floor_mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(100,100);floor_mesh.mesh=plane;floor_mesh.material_override=MeshKit.toon(Color("576e78"));add_child(floor_mesh)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=5.7;add_child(camera);camera.make_current()
	var layer:=CanvasLayer.new();add_child(layer);title=Label.new();title.position=Vector2(20,18);title.add_theme_font_size_override("font_size",26);layer.add_child(title)
	for rig in 3:
		for cls in ClassData.IDS:
			Game.new_profile(cls,"Wing Review")
			Game.profile.level=100;Game.profile.adv=4
			Game.profile.paragon={"level":100,"points":100,"spent":0,"exp":0,"alloc":{}}
			Game.profile.equip={}
			for slot in ItemData.SLOTS:Game.profile.equip[slot]=StarProgression.item(cls,100,slot,Game.rng)
			Game.profile.equip.wings=StarWingData.item(String(cls),Game.rng,4)
			var visual:=HeroVisual.new();add_child(visual)
			visual.setup(cls,"",true,Game.profile.equip,{} if rig==2 else {"gender":rig})
			visual.play("Idle")
			await get_tree().process_frame
			var wings:=visual.find_child("Wings_star_"+String(cls),true,false) as Node3D
			check(wings!=null,"uploaded wing attached rig%d %s"%[rig,cls])
			var player:=visual._wing_player()
			check(player!=null,"wing player available")
			if player:
				for clip in ["Idle","Flap","Glide","Fold","Unfold"]:check(player.has_animation(clip),"clip "+clip)
				for mode in [HeroVisual.WING_STAND,HeroVisual.WING_FLY,HeroVisual.WING_FOLD]:
					visual.set_wing_mode(mode,true);player.advance(0.3)
					check(player.assigned_animation==("Idle" if mode==HeroVisual.WING_STAND else "Flap" if mode==HeroVisual.WING_FLY else "Fold"),"matching pose")
				visual.set_wing_mode(HeroVisual.WING_FLY,true);visual.set_wing_moving(true);player.advance(0.3)
				check(player.current_animation=="Glide","moving flight glides")
				visual.set_wing_mode(HeroVisual.WING_STAND,true);player.advance(0.25)
			var surfaces:=0
			for mesh in wings.find_children("*","MeshInstance3D",true,false):
				surfaces+=mesh.mesh.get_surface_count()
				check(mesh.global_transform.is_finite(),"finite mesh transform")
				check(mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"no wing shadow pass")
			check(surfaces<=16,"bounded wing surfaces: %d"%surfaces)
			check(ItemLook.icon(Game.profile.equip.wings)!=null,"class icon resolves")
			title.text="TOON TALE • "+StarWingData.item_name(String(cls))+" • 100 ดาว"
			if rig==0:
				camera.position=Vector3(2.7,2.6,6);camera.look_at(Vector3(0,1.5,0))
				await capture(String(cls)+"-front")
				camera.position=Vector3(-2.4,2.5,-6);camera.look_at(Vector3(0,1.5,0))
				await capture(String(cls)+"-back")
			elif cls==&"priest":
				camera.position=Vector3(-2.4,2.5,-6);camera.look_at(Vector3(0,1.5,0))
				await capture("priest-rig-%d"%rig)
			visual.queue_free();await visual.tree_exited;await get_tree().process_frame
	Game.has_profile=false
	print("WING VISUAL: ",checks," checks, ",failures," failures")
	get_tree().quit(failures)
