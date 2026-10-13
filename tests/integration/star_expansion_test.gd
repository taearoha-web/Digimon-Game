extends Node3D
var checks:=0
var failures:=0
class Target:
	extends Mob
	var contacts:=0
	func take_hit(amount:int,crit:bool,color:=Color.WHITE,attacker:Node=null)->bool:
		contacts+=1
		return super.take_hit(amount,crit,color,attacker)
func check(ok:bool,note:String)->void:
	checks+=1
	if not ok: failures+=1;printerr("FAIL ",note)
func profile(cls:StringName,stars:=200)->void:
	Game.new_profile(cls,"Star QA")
	Game.profile.level=100
	Game.profile.adv=4
	Game.profile.paragon={"level":stars,"points":stars,"spent":0,"exp":0,"alloc":{}}
	Game.profile.look={"gender":0}
	Game.profile.gold=10000000
	Game.profile.inv=[]
	Game.profile.equip={}
	for slot in ItemData.EQUIP_SLOTS: Game.profile.equip[slot]=StarProgression.item(cls,100 if slot=="wings" else 200,slot,Game.rng)
	Game.profile.hp=100000
	Game.profile.mp=100000
	Game.fill_loadout()
func _ready()->void:
	Game.set_process(false)
	GameSettings.quality=2
	ZoneData.ensure()
	for cls in ClassData.IDS:
		profile(cls)
		var unique:Dictionary={}
		for skill in StarSkillData.pool(cls):
			unique[skill.id]=true
			Game.paragon().level=int(skill.star)-1
			check(not Game.skill_unlocked(skill),"locked before milestone "+skill.id)
			Game.paragon().level=int(skill.star)
			check(Game.skill_unlocked(skill),"unlocked at milestone "+skill.id)
			check(ResourceLoader.exists("res://assets/icons/skills/%s.svg" % skill.id),"skill icon "+skill.id)
		check(unique.size()==4,"four unique skills")
		for tier in StarProgression.TIERS:
			for slot in ItemData.EQUIP_SLOTS:
				if slot=="wings" and tier!=100: continue
				var item:=StarProgression.item(cls,tier,slot,Game.rng)
				check(Game._valid_item(item),"valid generated item "+String(item.name))
				check(ItemLook.icon(item)!=null,"item icon "+ItemLook.look_of(item))
			Game.paragon().level=tier
			check(StarProgression.claim(tier),"milestone first claim")
			check(not StarProgression.claim(tier),"milestone not duplicated")
			Game.profile.flags["star_mat_%d"%tier]=1000
			Game.profile.flags["star_core_%d"%tier]=100
			var before:=int(Game.profile.gold)
			check(StarProgression.craft(tier,"weapon"),"craft funded recipe")
			check(int(Game.profile.gold)==before-int(StarProgression.cost(tier,"weapon").gold),"craft exact cost")
		Game.paragon().level=200
		check(Game.save_code_roundtrip(),"new gear/materials transfer roundtrip "+String(cls))
		Game.profile.flags["star_mat_200"]=0
		var snapshot:=Game.profile.duplicate(true)
		check(not StarProgression.craft(200,"wings"),"unfunded craft rejected")
		check(snapshot==Game.profile,"rejected craft leaves profile intact")
	for rig in 3:
		for cls in ClassData.IDS:
			profile(cls)
			var visual:=HeroVisual.new();add_child(visual)
			visual.setup(cls,"",true,Game.profile.equip,{} if rig==2 else {"gender":rig})
			for node in visual._body_nodes+visual._hold_nodes:
				if node is BoneAttachment3D: check(visual._skeleton.find_bone(node.bone_name)>=0,"equipment bone exists rig%d %s %s"%[rig,cls,node.bone_name])
			check(visual._emission_grip!=null,"star weapon supplies casting socket")
			if cls==&"warrior":
				visual.skill_action(ClassData.find_skill(cls,"celestial_swordfall"),1.6)
				for elapsed in [1.6,2.4]:
					visual._advance_skill_motion(elapsed)
					var grip:=visual._skeleton.global_transform*visual._skeleton.get_bone_global_pose(visual._emission_bone)*visual._emission_grip.transform
					check(grip.basis.y.normalized().dot(Vector3.UP)>0.98,"sword points sky through barrage rig%d" % rig)
			visual.queue_free();await visual.tree_exited;await get_tree().process_frame
	for i in 4:
		var id:StringName=StarProgression.REGIONS[i]
		check(ZoneData.access_reason(id,100,int(StarProgression.ENTRY[i])-1)!="","region gate below")
		check(ZoneData.access_reason(id,100,int(StarProgression.ENTRY[i]))=="","region gate at")
		check(StarMonsters.ids_for(id).size()==8,"region roster")
		var zone:=ZoneData.get_zone(id)
		check(zone.camps.size()==5,"farm camps")
		for camp in zone.camps:
			check(int(camp.count)==10,"ten monsters per farm camp")
		for mid in StarMonsters.ids_for(id):
			check(is_equal_approx(float(StarMonsters.get_monster(mid).hp),float(StarMonsters.MONSTERS[mid].hp)*10.0),"ten times health "+String(mid))
			var model:String="res://assets/models/monsters/"+String(StarMonsters.MONSTERS[mid].model)
			check(ResourceLoader.exists(model+".glb") or ResourceLoader.exists(model+".gltf") or ResourceLoader.exists(model+".fbx"),"model "+String(mid))
		check(StarRegionArt.layout(id).spawn.length()<53,"reachable start")
	profile(&"warrior")
	var menu:=GameMenu.new()
	add_child(menu)
	menu.open_menu(&"star_path")
	check(menu._content.find_children("*","Button",true,false).size()>=12,"star forge menu built")
	menu.close_menu();menu.queue_free();await menu.tree_exited
	for quality in 3:
		GameSettings.quality=quality
		for cls in ClassData.IDS:
			for skill in StarSkillData.pool(cls):
				profile(cls)
				var field:=Node3D.new();add_child(field)
				var hero:=Hero.new();hero.field=field;field.add_child(hero);hero.set_physics_process(false)
				var target:=Target.new();target.setup(&"dawn_stag",100,Vector3(0,0,3),hero);target.position=Vector3(0,0,3);field.add_child(target);target.set_physics_process(false)
				target.hp=100000000;target.max_hp=target.hp
				hero.target=target
				Game.profile.mp=100000
				if skill.id=="celestial_swordfall":
					hero.visual.equip.erase("wings")
					hero._cast(skill)
					check(int(Game.profile.mp)==100000 and hero.get_node_or_null("StarCast_"+skill.id)==null,"wings required atomically")
					hero.visual.set_equipment(Game.profile.equip.merged({"wings":StarWingData.item(String(cls),Game.rng)},true))
				hero._cast(skill)
				var seq:=hero.get_node_or_null("StarCast_"+String(skill.id)) as StarSkillSequence
				check(seq!=null,"real cast starts "+String(skill.id))
				if seq:
					seq.set_process(false)
					var peak:=0.0
					while seq.clock<seq.end:
						seq._process(0.05)
						hero.visual._advance_skill_motion(0.05)
						peak=maxf(peak,hero.visual.position.y)
						if seq.is_queued_for_deletion():break
					var expected:int={"lionfang_cleave":2,"crown_breaker":2,"celestial_swordfall":10,"moonpiercer":1,"hunters_verdict":3,"celestial_hunt":4,"spiral_impaler":3,"heartseeker":6,"worldsplitter":4,"arcane_prism":4,"crystal_prison":2,"astral_convergence":3,"genesis_nova":4,"sanctified_chain":1,"dawn_salvation":3,"leviathan_surge":3}.get(skill.id,0)
					check(target.contacts==expected,"actual contacts %s: %d vs %d" % [skill.id,target.contacts,expected])
					if skill.id=="celestial_swordfall":check(peak>=4.99,"ascends five meters")
					if skill.shape=="summon":check(hero._summons.size()==1 and is_equal_approx(hero._summons[0].life,24.0),"summon lives 24 sec")
				field.queue_free();await field.tree_exited;await get_tree().process_frame
				check(VfxBudget.counters()=={"particles":0,"decorations":0,"lights":0},"cast cleanup "+String(skill.id))
	profile(&"priest")
	var field:=Node3D.new();add_child(field)
	var hero:=Hero.new();hero.field=field;field.add_child(hero);hero.set_physics_process(false)
	for id in ["seraph_aegis","sacred_sanctuary","royal_vanguard"]:
		var cls:=&"warrior" if id=="royal_vanguard" else &"priest"
		var entry:=ClassData.find_skill(cls,id)
		hero.receive_buff(entry.fx.buff,entry.color,entry.name,false,id)
	check(not BuffBook.contains(hero._buffs,"seraph_aegis",false) and hero._buffs.size()==2,"third self buff replaces oldest")
	for id in ["seraph_aegis","aegis_formation"]:
		var entry:=ClassData.find_skill(&"lancer" if id=="aegis_formation" else &"priest",id)
		hero.receive_buff(entry.fx.buff,entry.color,entry.name,true,id)
	check(hero._buffs.size()==4,"two self plus two allied buffs")
	check(BuffBook.absorb(hero._buffs,100)==0,"shield absorbs actual damage")
	field.queue_free();await field.tree_exited
	Game.has_profile=false
	print("STAR EXPANSION: ",checks," checks, ",failures," failures")
	get_tree().quit(failures)
