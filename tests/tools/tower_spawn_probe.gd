extends Node3D
var rows:Array=[]
func _ready()->void:
	Game.set_process(false);InputSetup.ensure_defaults();GameSettings.quality=2
	Game.new_profile(&"mage","Tower spawn probe",{"gender":0})
	Game.profile.level=100;Game.profile.adv=4;Game.profile.party=[]
	var zone:=Zone.new();zone.zone_id=&"tower";add_child(zone)
	zone.set_process(false);zone.hero.set_physics_process(false);zone.tower_run.set_process(false)
	var run:=zone.tower_run
	for floor_no in [1,8,10,29,30,40,49,59,69,79,89,99]:
		run.floor_no=floor_no;run._rng.seed=871+floor_no
		var start:=Time.get_ticks_usec();run._start_floor()
		var longest:=float(Time.get_ticks_usec()-start)/1000.0
		var total:=longest
		var work_frames:=1
		while run.state=="spawning":
			start=Time.get_ticks_usec();run._process(0.016)
			var cost:=float(Time.get_ticks_usec()-start)/1000.0
			longest=maxf(longest,cost);total+=cost;work_frames+=1
			await get_tree().process_frame
		rows.append({"floor":floor_no,"count":run._mobs.size(),"max_spawn_work_ms":longest,"total_spawn_work_ms":total,"work_frames":work_frames})
		for mob in run._mobs:mob.queue_free()
		run._mobs.clear()
		await get_tree().process_frame;await get_tree().process_frame
	var args:=OS.get_cmdline_user_args()
	var file:=FileAccess.open(args[0],FileAccess.WRITE);file.store_string(JSON.stringify(rows,"\t"));file.close()
	print("TOWER SPAWN PROBE ",JSON.stringify(rows))
	zone.queue_free();await zone.tree_exited
	get_tree().quit()
