extends Node3D
## Exercise normal expiry, interrupted scenes, pause, saturation and cache stability.
var failures := 0
var checks := 0
var casts := 0
func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",why)
func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	EliteSkillArt.warm_geometry()
	var catalogue: Array[Dictionary] = []
	for family in ClassData.IDS:
		for skill in ClassData.pool(family):
			if int(skill.level)>=80 and not skill.has("star"):
				catalogue.append(skill)
	check(catalogue.size()==48,"all 48 elite skills selected")
	var baseline := -1
	var final_count := -1
	for cycle in 10:
		GameSettings.quality = cycle%3
		for skill in catalogue:
			check(EliteSkillArt.handles(skill),"covered "+String(skill.id))
			var snapshot: Dictionary=skill.duplicate(true)
			var field := Node3D.new()
			add_child(field)
			if String(skill.id) in ["armageddon","judgment_ray"]:
				# These keep their own hit/visual clocks; dedicated tests cover damage.
				field.queue_free()
				await field.tree_exited
				continue
			SkillShow.play(field,skill,Vector3(0,0,4),Vector3.ZERO)
			casts+=1
			var art := field.get_node_or_null("EliteSkill_"+String(skill.id)) as EliteSkillArt
			check(art!=null,"runtime routes to new art")
			if art:
				art.set_process(false)
				if cycle%2==0:
					art._process(3.0)
					check(art.is_queued_for_deletion(),"normal expiry queues all layers")
					await art.tree_exited
					# ClassFlourish keeps its own short-lived, self-freeing holder.
					var left := field.get_children().filter(func(n: Node): return not String(n.name).begins_with("ClassFlourish_"))
					check(left.is_empty(),"normal expiry leaves no nodes")
			check(skill==snapshot,"art preserves all combat parameters")
			field.queue_free()
			await field.tree_exited
			await get_tree().process_frame
			check(VfxBudget.counters()=={"particles":0,"decorations":0,"lights":0},"all visual reservations released")
		await get_tree().process_frame
		var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
		if cycle==2: baseline=objects
		if cycle==9: final_count=objects
		print("ELITE CYCLE ",cycle," objects=",objects," geometry=",EliteSkillArt._meshes.size())
	check(final_count<=baseline+8,"stable objects after warm caches: %d -> %d"%[baseline,final_count])
	check(EliteSkillArt._meshes.size()==EliteSkillArt.GEOMETRY_KINDS.split(" ").size(),"finite shared geometry library")
	var field := Node3D.new()
	add_child(field)
	var skill := ClassData.find_skill(&"lancer","ragnarok_lance")
	SkillShow.play(field,skill,Vector3(0,0,3),Vector3.ZERO)
	var art := field.get_node("EliteSkill_ragnarok_lance") as EliteSkillArt
	var age := art.age
	get_tree().paused=true
	await get_tree().create_timer(0.10,true).timeout
	check(art.age==age,"pause freezes art clock")
	get_tree().paused=false
	field.queue_free()
	await field.tree_exited
	# Hell Meteor's replacement art keeps the real callback and cancellation.
	for cancel in [false, true]:
		var meteor_field := Node3D.new()
		add_child(meteor_field)
		while VfxBudget.can_decorate():
			var slot := Node.new()
			meteor_field.add_child(slot)
			VfxBudget.track_decoration(slot)
		var hits := {"count":0}
		VfxKit.meteor(meteor_field,Vector3.ZERO,Color.ORANGE,0.15,9.0,func(): hits.count+=1,true)
		check(hits.count==0,"meteor does not hit at launch")
		check(meteor_field.find_child("EssentialMeteorBody",true,false)!=null,"meteor body survives saturation")
		if cancel:
			meteor_field.queue_free()
			await meteor_field.tree_exited
		await get_tree().create_timer(0.25).timeout
		check(hits.count==(0 if cancel else 1),"sculpted meteor exactly one callback or cancelled")
		if not cancel:
			meteor_field.queue_free()
			await meteor_field.tree_exited
		check(VfxBudget.counters()=={"particles":0,"decorations":0,"lights":0},"meteor cleanup under saturation")
	print("ELITE LIFECYCLE: %s | %d casts, %d checks, %d failures, objects %d -> %d"%["PASS" if failures==0 else "FAIL",casts,checks,failures,baseline,final_count])
	get_tree().quit(failures)
