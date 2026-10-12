extends Node3D
class Dummy extends Mob:
	var hits := 0
	var damage := 0
	func take_hit(amount: int, critical: bool, color := Color.WHITE, attacker: Node = null) -> bool:
		hits+=1
		damage+=amount
		return super.take_hit(amount,critical,color,attacker)
class RivalDummy extends Rival:
	var hits := 0
	func _ready() -> void:
		set_physics_process(false)
	func _hit(_victim: Node3D, _mult: float, _color: Color) -> void:
		hits+=1
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",label)
func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	GameSettings.quality=2
	Game.new_profile(&"mage","Judgment QA",{"gender":1})
	Game.profile.level=100
	Game.profile.adv=4
	Game.profile.hp=100000
	Game.profile.mp=100000
	Game.profile.skills["judgment_ray"]=1
	Game.profile.loadout[0]="judgment_ray"
	var skill:=ClassData.find_skill(&"mage","judgment_ray")
	check(skill.shape=="single" and not skill.projectile,"one target; no travelling projectile")
	check(skill.mp==130 and skill.cd==12.0 and is_equal_approx(skill.mult,24.0*ClassData.damage_curve(96)),"unchanged mana, cooldown and damage curve")
	var field:=Node3D.new()
	add_child(field)
	var hero:=Hero.new()
	hero.field=field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.stats.atk=100.0
	hero.stats.crit=0.0
	hero.stats.haste=0.0
	hero.position=Vector3(-5,0,0)
	var mobs: Array[Dummy]=[]
	for i in 2:
		var mob:=Dummy.new()
		mob.setup(&"forest_orc",100,Vector3.ZERO,hero)
		field.add_child(mob)
		mob.position=Vector3(float(i),0,0)
		mob.hp=10000000
		mob.max_hp=mob.hp
		mob.stats.def=0
		mob.set_physics_process(false)
		mobs.append(mob)
	hero.target=mobs[0]
	var mana:=int(Game.profile.mp)
	check(hero.use_skill(0)=="","player button queues Judgment Ray")
	hero._combat_step(1.0/60.0)
	var seq:=get_tree().get_first_node_in_group("judgment_ray_sequences") as JudgmentRaySequence
	check(seq!=null,"real cast launches celestial sequence")
	seq.set_process(false)
	check(hero.use_skill(0)=="cooldown","cooldown blocks duplicate button")
	check(int(Game.profile.mp)==mana-130,"MP charged once")
	seq._process(0.7)
	check(mobs[0].hits==0 and mobs[1].hits==0,"opening and target rings do no damage")
	mobs[0].position=Vector3(3,0,1)
	seq._process(0.1)
	check(seq.global_position.is_equal_approx(Vector3(3,0,1)),"lock follows the chosen moving target")
	seq.set_process(true)
	get_tree().paused=true
	var age:=seq.elapsed
	await get_tree().create_timer(0.1,true).timeout
	check(seq.elapsed==age and mobs[0].hits==0,"pause freezes art and damage clock")
	get_tree().paused=false
	seq.set_process(false)
	seq._process(0.25)
	check(mobs[0].hits==1 and mobs[1].hits==0,"pillar deals exactly one hit; adjacent enemy untouched")
	check(mobs[0].damage>=1473 and mobs[0].damage<=1731,"real single hit retains expected rank-one damage roll")
	check(seq.art._beam.visible and is_equal_approx(seq.art._beam.scale.y,JudgmentRayArt.HEIGHT),"pillar reaches ground on the damage frame")
	seq._process(0.4)
	check(mobs[0].hits==1 and mobs[1].hits==0,"shockwave and rune fragments add no damage")
	seq._process(1.0)
	await seq.tree_exited
	# Every cancellation is checked before the only impact can fire.
	var received: Array=[]
	for reason in ["death","target_dead","caster_zone","target_zone","interrupt","target_freed"]:
		var victim:=mobs[0]
		hero.visual.skill_action(skill,1.05)
		seq=JudgmentRaySequence.launch(field,hero,victim,1.05,func(v):received.append(v),hero.visual,false)
		seq.set_process(false)
		match reason:
			"death":hero._dead=true
			"target_dead":victim._dead=true
			"caster_zone":hero.reparent(self)
			"target_zone":victim.reparent(self)
			"interrupt":hero.visual.release()
			"target_freed":victim.queue_free()
		seq._process(2.0)
		check(seq.is_queued_for_deletion() and received.is_empty(),"cancel without delayed damage: "+reason)
		await seq.tree_exited
		hero._dead=false
		if is_instance_valid(victim):
			victim._dead=false
			if victim.get_parent()!=field:victim.reparent(field)
		if hero.get_parent()!=field:hero.reparent(field)
	var buddy:=Companion.new()
	buddy.setup({"class":"mage","name":"Ally","level":100,"exp":0,"gender":0},0,hero,field)
	field.add_child(buddy)
	buddy.set_physics_process(false)
	buddy.target=mobs[1]
	buddy.mp=1000
	buddy._cast(skill)
	seq=get_tree().get_first_node_in_group("judgment_ray_sequences") as JudgmentRaySequence
	seq.set_process(false)
	seq._process(1.05)
	check(mobs[1].hits==1 and buddy.mp==870,"companion casts one hit and pays once")
	seq.queue_free()
	await seq.tree_exited
	var rival:=RivalDummy.new()
	field.add_child(rival)
	rival._resolve(skill,hero,hero.position)
	seq=get_tree().get_first_node_in_group("judgment_ray_sequences") as JudgmentRaySequence
	seq.set_process(false)
	seq._process(0.1)
	seq._process(0.1)
	check(rival.hits==1,"rival resolver routes exactly one hit")
	seq.queue_free()
	await seq.tree_exited
	seq=JudgmentRaySequence.launch(field,rival,hero,1.0,func(v):received.append(v),null,false)
	seq.set_process(false)
	rival.duel_over=true
	seq._process(1.0)
	check(seq.is_queued_for_deletion() and received.is_empty(),"duel ending cancels pending verdict")
	await seq.tree_exited
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame
	for quality in 3:
		GameSettings.quality=quality
		var scope:=Node3D.new()
		add_child(scope)
		while VfxBudget.can_decorate():
			var reservation:=Node.new()
			scope.add_child(reservation)
			VfxBudget.track_decoration(reservation)
		var art:=JudgmentRayArt.new()
		scope.add_child(art)
		art.draw_stage(1.0,0.05)
		check(art._beam.visible and art._ground!=null and art._sky!=null,"essential pillar and seals survive saturated quality %d"%quality)
		check(VfxBudget.counters().decorations==VfxBudget.decoration_limit(),"quality cap respected %d"%quality)
		scope.queue_free()
		await scope.tree_exited
		check(VfxBudget.counters()=={"particles":0,"decorations":0,"lights":0},"no reservations after quality %d cleanup"%quality)
	check(get_tree().get_nodes_in_group("judgment_ray_sequences").is_empty(),"all sequences removed")
	# Allow existing shared hit feedback timers to release their callbacks too.
	await get_tree().create_timer(0.8).timeout
	print("JUDGMENT RAY: %s | %d checks, %d failures"%["PASS" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)
