extends Node3D
## Repeated live actors/casts, scene cancellation, boss gates and cache plateau.
var failures:=0
var checks:=0
func check(ok:bool,why:String)->void:
	checks+=1
	if not ok: failures+=1;printerr("FAIL ",why)
func profile(cls:StringName)->void:
	Game.new_profile(cls,"Lifecycle QA")
	Game.profile.level=100;Game.profile.adv=4
	Game.profile.paragon={"level":200,"points":200,"spent":0,"exp":0,"alloc":{}}
	Game.profile.look={"gender":0};Game.profile.equip={};Game.profile.party=[]
	for slot in ItemData.EQUIP_SLOTS: Game.profile.equip[slot]=StarProgression.item(cls,100 if slot=="wings" else 200,slot,Game.rng)
func _ready()->void:
	Game.set_process(false);GameSettings.quality=2;InputSetup.ensure_defaults()
	var catalog:Array=[]
	for cls in ClassData.IDS:
		for skill in StarSkillData.pool(cls):
			catalog.append({"id":skill.id,"name":skill.name,"desc":skill.desc,"class":String(cls),"star":skill.star,"shape":skill.shape})
	# The catalog is an artifact for local review; on CI the folder does not exist (skip it).
	var f:=FileAccess.open("/workspace/toon-artifacts/star-expansion/catalog.json",FileAccess.WRITE)
	if f!=null:
		f.store_string(JSON.stringify(catalog,"  "));f.close()
	profile(&"warrior");Game.paragon().level=199
	var zone:=Zone.new();zone.zone_id=&"eclipse_realm";add_child(zone);zone.set_process(false)
	zone._boss_timer=0;zone._tick_boss(1)
	check(not is_instance_valid(zone._boss),"final boss gated below star 200")
	Game.paragon().level=200;zone._tick_boss(1)
	check(is_instance_valid(zone._boss),"final boss appears at star 200")
	zone._boss.set_physics_process(false);zone.hero.set_physics_process(false)
	zone._boss._victim=zone.hero;StarAttack.start(zone._boss,true)
	var attack:StarAttack
	for child in zone._boss.get_children():
		if child is StarAttack: attack=child;break
	check(attack!=null and attack.points.size()==8,"eclipse boss eight locked warning circles")
	if attack:
		attack.set_process(false)
		var locked:=attack.points.duplicate()
		zone.hero.position+=Vector3(5,0,3)
		check(attack.points==locked,"warning circles do not chase moving player")
		zone._boss._stun=1.0;attack._process(0.01)
		check(attack.is_queued_for_deletion(),"stun cancels enemy attack")
	zone.queue_free();await zone.tree_exited;await get_tree().process_frame
	var baseline:=0
	var final_count:=0
	for cycle in 6:
		GameSettings.quality=cycle%3
		for cls in ClassData.IDS:
			for skill in StarSkillData.pool(cls):
				profile(cls)
				var field:=Node3D.new();add_child(field)
				var hero:=Hero.new();hero.field=field;field.add_child(hero);hero.set_physics_process(false)
				var mob:=Mob.new();mob.setup(&"eclipse_warrior",100,Vector3(0,0,2),hero);field.add_child(mob);mob.set_physics_process(false);mob.position=Vector3(0,0,2);mob.hp=100000000;mob.max_hp=mob.hp
				hero.target=mob;Game.profile.mp=100000;Game.profile.hp=100000
				hero._cast(skill)
				var seq:StarSkillSequence
				for child in hero.get_children():
					if child is StarSkillSequence:seq=child;break
				check(seq!=null,"actual cast created "+String(skill.id))
				if seq:
					seq.set_process(false)
					seq._process(0.2 if cycle%2 else seq.end+0.1)
					if cycle%2==0:check(seq.is_queued_for_deletion(),"normal cast ends")
				# Reproduce travel/new-profile during tree_exited before deferred free.
				field.queue_free();await field.tree_exited
				Game.inventory_changed.emit()
				await get_tree().process_frame
				check(VfxBudget.counters()=={"particles":0,"decorations":0,"lights":0},"scene releases all visual reservations")
		await get_tree().process_frame
		var objects:=int(Performance.get_monitor(Performance.OBJECT_COUNT))
		if cycle==2:baseline=objects
		final_count=objects
		print("STAR CYCLE ",cycle," objects=",objects)
	check(final_count<=baseline+8,"warm object count plateaus: %d -> %d"%[baseline,final_count])
	print("STAR LIFECYCLE: 144 casts, %d checks, %d failures"%[checks,failures])
	Game.has_profile=false
	get_tree().quit(failures)
