extends Node3D
var cam:Camera3D
var title:Label
var output:="/workspace/toon-artifacts/star-expansion/review"
func make_profile(cls:StringName,stars:=200)->void:
	Game.new_profile(cls,"Star Adventure QA")
	Game.profile.level=100;Game.profile.adv=4
	Game.profile.paragon={"level":stars,"points":stars,"spent":0,"exp":0,"alloc":{}}
	Game.profile.look={"gender":0}
	Game.profile.equip={}
	for slot in ItemData.EQUIP_SLOTS:Game.profile.equip[slot]=(StarWingData.item(String(cls),Game.rng) if stars>=100 else ItemData.wings(Game.rng,String(cls))) if slot=="wings" else StarProgression.item(cls,stars if stars in StarProgression.TIERS else 50,slot,Game.rng)
	Game.profile.hp=100000;Game.profile.mp=100000
	Game.profile.party=[]
	Game.fill_loadout()
func capture(file:String)->void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/"+file+".png")
	print("CAPTURE ",file)
func _ready()->void:
	Game.set_process(false)
	InputSetup.ensure_defaults()
	GameSettings.load_settings();GameSettings.quality=2
	get_window().size=Vector2i(1280,720);get_window().content_scale_size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(output)
	var mode:="skills" if OS.get_cmdline_user_args().is_empty() else OS.get_cmdline_user_args()[0]
	if mode=="maps":await maps();get_tree().quit();return
	Scenery.environment(self,Color("6d91ac"),Color("7f9b9c"),Color("d3e5f0"),Color("ffedda"))
	var ground:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(120,120);ground.mesh=plane;ground.material_override=MeshKit.toon(Color("526e60"));add_child(ground)
	cam=Camera3D.new();cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=20;add_child(cam);cam.position=Vector3(12,13,18);cam.look_at(Vector3(0,2,1));cam.make_current()
	var layer:=CanvasLayer.new();add_child(layer);title=Label.new();title.position=Vector2(22,16);title.add_theme_font_size_override("font_size",25);layer.add_child(title)
	if mode=="gear": await gear()
	elif mode=="monsters":await monsters()
	else: await skills()
	Game.has_profile=false
	get_tree().quit()
func maps()->void:
	for id in StarProgression.REGIONS:
		make_profile(&"warrior")
		Game.current_zone=id
		var zone:=Zone.new();zone.zone_id=id;add_child(zone)
		var hud:=HUD.new();add_child(hud);hud.bind(zone)
		await get_tree().create_timer(0.3).timeout
		zone.hero.set_physics_process(false)
		for mob in get_tree().get_nodes_in_group("mobs"):mob.set_physics_process(false)
		await capture("map-play-"+String(id))
		zone._boss_timer=0;zone._tick_boss(0.1)
		var overview:=Camera3D.new();overview.projection=Camera3D.PROJECTION_ORTHOGONAL;overview.size=120;zone.add_child(overview);overview.position=Vector3(5,96,64);overview.look_at(Vector3.ZERO);overview.make_current()
		hud.visible=false
		await capture("map-overview-"+String(id))
		zone.hero.global_position=zone._boss_spot+Vector3(0,0,9)
		overview.size=24;overview.position=zone._boss_spot+Vector3(9,12,18);overview.look_at(zone._boss_spot+Vector3(0,2,0))
		if zone._boss:
			zone._boss.set_physics_process(false);zone._boss._victim=zone.hero;StarAttack.start(zone._boss,true)
		await get_tree().create_timer(0.4).timeout
		await capture("boss-"+String(id))
		hud.queue_free();zone.queue_free();await zone.tree_exited
	make_profile(&"mage")
func gear()->void:
	cam.size=12;cam.position=Vector3(5,4,12);cam.look_at(Vector3(0,1.5,0))
	for stars in StarProgression.TIERS:
		var batch:=Node3D.new();add_child(batch)
		for i in 6:
			var cls:StringName=ClassData.IDS[i];make_profile(cls,stars)
			var h:=HeroVisual.new();batch.add_child(h);h.setup(cls,"",true,Game.profile.equip,{"gender":i%2});h.position=Vector3(-6.3+i*2.5,0,0);h.rotation_degrees.y=15;h.play("Idle")
		title.text="TOON TALE • Star %d equipment"%stars
		await get_tree().create_timer(0.25).timeout
		await capture("gear-%d"%stars)
		batch.queue_free();await batch.tree_exited
func monsters()->void:
	cam.size=22;cam.position=Vector3(4,9,24);cam.look_at(Vector3(0,2,0))
	for id in StarProgression.REGIONS:
		var batch:=Node3D.new();add_child(batch)
		var roster:=StarMonsters.ids_for(id)
		for i in 7:
			var def:=StarMonsters.get_monster(roster[i]);var model:=MonsterVisual.new();batch.add_child(model);model.setup(def.model,def.height,0,def.get("tint",Color.WHITE));StarMonsterArt.attach(model,def);model.position=Vector3(-10+i*3.4,0,0);model.play("idle")
		title.text="TOON TALE • "+String(id)
		await get_tree().create_timer(0.1).timeout
		await capture("monsters-"+String(id))
		batch.queue_free();await batch.tree_exited
func skills()->void:
	for cls in ClassData.IDS:
		for skill in StarSkillData.pool(cls):
			var args:=OS.get_cmdline_user_args()
			if args.size()>1 and not String(skill.id) in args[1].split(","): continue
			make_profile(cls)
			var field:=Node3D.new();add_child(field)
			var hero:=Hero.new();hero.field=field;field.add_child(hero);hero.set_physics_process(false);hero.position=Vector3(-2,0,1)
			var mob:=Mob.new();mob.setup(&"eclipse_warrior",100,Vector3(2,0,-1),hero);mob.position=Vector3(2,0,-1);field.add_child(mob);mob.set_physics_process(false);mob.hp=100000000;mob.max_hp=mob.hp;hero.target=mob
			Game.profile.mp=100000
			title.text="TOON TALE • %s • Star %d" % [skill.name,int(skill.star)]
			cam.size=24 if int(skill.star)==200 else 21
			hero._cast(skill)
			await get_tree().create_timer(float(skill.hit_delay)*0.65).timeout
			await capture(String(skill.id)+"-prepare")
			await get_tree().create_timer(float(skill.hit_delay)*0.35+0.38).timeout
			await capture(String(skill.id)+"-impact")
			await get_tree().create_timer(1.0 if skill.id!="celestial_swordfall" else 1.6).timeout
			await capture(String(skill.id)+"-finish")
			field.queue_free();await field.tree_exited
