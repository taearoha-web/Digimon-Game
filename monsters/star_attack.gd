class_name StarAttack
extends Node
## Owner-bound, dodgeable attacks: warnings lock their positions before impact.
var mob: Mob
var victim: WeakRef
var special := false
var age := 0.0
var contact := 0.70
var end := 1.5
var fired := false
var points: Array[Vector3] = []
var origin := Vector3.ZERO
var forward := Vector3.FORWARD
var radius := 2.0
var behavior := ""
var warned: Node3D
var seed_skill: Dictionary

static func start(actor: Mob, boss_move := false) -> void:
	if not actor._alive(actor._victim): return
	var attack := StarAttack.new()
	attack.mob=actor
	attack.victim=weakref(actor._victim)
	attack.special=boss_move
	actor._winding=true
	actor._attack_timer=2.4 if not actor.is_boss else 1.8
	if boss_move: actor._slam_timer=8.0
	actor.add_child(attack)

func _ready() -> void:
	origin=mob.global_position*Vector3(1,0,1)
	var target:=victim.get_ref() as Node3D
	forward=((target.global_position-origin)*Vector3(1,0,1)).normalized()
	behavior=String(mob.template.get("behavior","cleave"))
	var motif: String = {"root_ring":"lionfang_cleave","crystal_fault":"crystal_prison","sun_lances":"dawn_salvation","eclipse_crown":"eclipse_sovereign"}.get(behavior,"crown_breaker")
	seed_skill={"id":motif,"star":50,"radius":3.0,"color":mob.template.get("color",Color.ORANGE),"class":&"warrior","shape":"blast"}
	if special:
		contact=1.25; end=2.05; radius=3.0
		match behavior:
			"root_ring":
				for i in 6: points.append(origin+Vector3(cos(TAU*i/6.0),0,sin(TAU*i/6.0))*5.5)
			"crystal_fault":
				for i in 3: points.append(origin+forward*(3.0+i*4.0))
			"sun_lances":
				for ally in mob._targets().slice(0,3): points.append(ally.global_position*Vector3(1,0,1))
			_:
				radius=2.5
				for i in 8: points.append(origin+Vector3(cos(TAU*i/8.0),0,sin(TAU*i/8.0))*6.5)
	elif behavior in ["pounce","charge"]:
		contact=0.8;end=1.55;radius=2.0 if behavior=="pounce" else 2.8
		points.append(origin+forward*minf(5.5,origin.distance_to(target.global_position)))
	elif String(mob.template.attack)=="ranged":
		contact=1.0;radius=2.3
		points.append(target.global_position*Vector3(1,0,1))
	else:
		radius=2.0+mob.body_radius()*0.6
		points.append(origin+forward*1.8)
	warned=Node3D.new()
	warned.name="StarEnemyWarnings"
	mob.get_parent().add_child(warned)
	for spot in points: VfxKit.danger_circle(warned,spot,radius,contact)
	mob.visual.action("attack",int(end*1000.0))
	mob._anim_lock=Time.get_ticks_msec()+int(end*1000.0)

func _process(delta: float) -> void:
	if not is_instance_valid(mob) or mob.is_dead() or mob._stun>0.0 or mob._returning:
		queue_free();return
	age+=delta
	if not special and behavior in ["charge","pounce"] and age>contact-0.28 and age<=contact:
		var move: Vector3=(points[0]-mob.global_position)*Vector3(1,0,1)
		mob.move_and_collide(move.limit_length(18.0*delta))
	if not fired and age>=contact:
		fired=true
		if special: StarSkillArt.strike(mob.get_parent(),seed_skill,origin,0,origin-forward)
		for spot in points:
			var contact_skill := seed_skill.duplicate()
			contact_skill.id="arcane_prism"
			StarSkillArt.strike(mob.get_parent(),contact_skill,spot,1,origin)
		# Each actor is hit once even if adjacent warning circles overlap.
		for ally in mob._targets():
			for spot in points:
				if ((ally.global_position-spot)*Vector3(1,0,1)).length()<=radius:
					ally.take_damage(float(mob.stats.atk)*mob._atk_scale*(1.65 if special else 1.0),mob)
					break
	if age>=end: queue_free()

func _exit_tree() -> void:
	if is_instance_valid(warned): warned.queue_free()
	if is_instance_valid(mob): mob._winding=false
