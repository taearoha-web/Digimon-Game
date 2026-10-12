extends Node3D
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",message)
func _ready()->void:
	Game.set_process(false);InputSetup.ensure_defaults();GameSettings.quality=2
	Game.new_profile(&"mage","Tower regression",{"gender":0});Game.profile.level=100;Game.profile.adv=4;Game.profile.party=[]
	var zone:=Zone.new();zone.zone_id=&"tower";add_child(zone);zone.set_process(false);zone.hero.set_physics_process(false)
	var run:=zone.tower_run;run.set_process(false)
	for floor_no in [1,10,29]:
		run.floor_no=floor_no;run.state="rest";run._start_floor()
		var expected:=5 if floor_no<29 else 12
		var gold_before:=int(Game.profile.gold)
		check(run.state=="spawning" and run._mobs.is_empty(),"planning floor creates no synchronous model burst")
		for i in expected:
			run._process(4.0)
			check(run._mobs.size()==i+1,"one model per frame even with large delta")
			if i<expected-1:
				check(run.state=="spawning" and get_tree().get_nodes_in_group("mobs").is_empty(),"partial wave is not targetable")
				check(not run._mobs.back().visible and run._mobs.back().process_mode==Node.PROCESS_MODE_DISABLED,"partial wave is hidden and cannot attack")
		check(run.state=="fight" and run._pending.is_empty(),"complete wave enters fight")
		check(get_tree().get_nodes_in_group("mobs").size()==expected,"wave publishes all enemies together")
		check(int(Game.profile.gold)==gold_before,"spawning pays no floor rewards")
		var first:Mob=run._mobs[0]
		check(int(first.stats.hp)==int(float(MonsterData.stats_for(first.monster_id,100).hp)*TowerData.hp_mult(floor_no)),"floor strength is preserved")
		for mob in run._mobs:mob.queue_free()
		run._mobs.clear();await get_tree().process_frame;await get_tree().process_frame
	# Dying during assembly cannot spawn the rest of the wave or award a floor.
	run.state="rest";run._start_floor();run._process(0.016)
	zone.hero._dead=true;var best:=int(Game.tower().best);run._process(0.016)
	check(run.state=="ending" and run._pending.is_empty() and run._mobs.is_empty(),"death cancels incomplete wave")
	check(int(Game.tower().best)==best,"cancelled wave grants no progress")
	await get_tree().process_frame;await get_tree().process_frame
	zone.hero._dead=false;run.state="rest";run._start_floor();run._process(0.016)
	var incomplete:WeakRef=weakref(run._mobs[0]);run.queue_free();await run.tree_exited;await get_tree().process_frame;await get_tree().process_frame
	check(incomplete.get_ref()==null,"removing controller frees its incomplete models")
	zone.queue_free();await zone.tree_exited
	print("TOWER SPAWN: %d checks, %d failures"%[checks,failures]);get_tree().quit(failures)
