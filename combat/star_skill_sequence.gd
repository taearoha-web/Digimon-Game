class_name StarSkillSequence
extends Node
## One owner-bound clock per cast. Leaving/dying cancels every pending contact.
var owner_ref: WeakRef
var victim_ref: WeakRef
var skill: Dictionary
var center := Vector3.ZERO
var origin := Vector3.ZERO
var forward := Vector3.FORWARD
var clock := 0.0
var events: Array[Dictionary] = []
var cursor := 0
var end := 0.0
var aerial := false
var old_wing_mode := 0
var hit_targets: Array[WeakRef] = []

static func launch(hero: Hero, data: Dictionary, target: Mob, aim: Vector3) -> float:
	var seq := StarSkillSequence.new()
	seq.owner_ref=weakref(hero)
	seq.victim_ref=weakref(target) if is_instance_valid(target) else null
	seq.skill=data
	seq.center=Vector3(aim.x,0,aim.z)
	seq.origin=hero.global_position
	seq.forward=Vector3(sin(hero._facing),0,cos(hero._facing))
	seq.aerial=String(data.id)=="celestial_swordfall"
	seq._plan()
	hero.add_child(seq)
	return minf(seq.end,2.4) if String(data.id)=="sacred_sanctuary" else seq.end

func _plan() -> void:
	var release := float(skill.hit_delay)
	var id := String(skill.id)
	var beats: Array = [0.0]
	match id:
		"lionfang_cleave": beats=[0.0,0.26]
		"crown_breaker": beats=[0.0,0.46]
		"hunters_verdict": beats=[0.0,0.26,0.68]
		"heartseeker": beats=[0.0,0.17,0.34,0.51,0.68,1.12]
		"spiral_impaler","leviathan_surge","astral_convergence": beats=[0.0,0.36,0.72]
		"arcane_prism": beats=[0.0,0.22,0.44,0.66]
		"crystal_prison": beats=[0.0,0.85]
		"celestial_hunt","worldsplitter","genesis_nova": beats=[0.0,0.40,0.80,1.3]
		"dawn_salvation": beats=[0.0,0.65,1.3]
		"sacred_sanctuary": beats=[0.0,2.0,4.0,6.0,8.0]
		"celestial_swordfall":
			for i in 10:
				events.append({"at":release+i*0.24,"index":i,"drop":true})
				events.append({"at":release+i*0.24+0.42,"index":i,"count":10})
			end=release+9*0.24+0.42+0.8
			return
	var carriers := id in ["moonpiercer","hunters_verdict","arcane_prism","sanctified_chain","spiral_impaler","leviathan_surge","celestial_hunt"]
	var flight := 0.28 if carriers else 0.0
	for i in beats.size():
		var at := release+float(beats[i])
		if i>0 and id in ["heartseeker","hunters_verdict","crown_breaker","spiral_impaler"]:
			var windup := 0.13 if id=="heartseeker" and i<5 else 0.24
			events.append({"at":at-windup,"motion":true,"windup":windup})
		if carriers: events.append({"at":at,"launch":true,"index":i,"flight":flight})
		events.append({"at":at+flight,"index":i,"count":beats.size()})
	end=release+float(beats.back())+flight+0.6

func _ready() -> void:
	var h := owner_ref.get_ref() as Hero
	if not is_instance_valid(h): queue_free(); return
	name="StarCast_"+String(skill.id)
	if String(skill.shape) in ["burst","self","summon"]: center=origin
	h.visual.skill_action(skill,float(skill.hit_delay))
	StarSkillArt.telegraph(h,skill,center,float(skill.hit_delay))
	if aerial:
		h.set_meta("star_airborne",true)
		old_wing_mode=h.visual.wing_mode
		h.visual.set_wing_mode(HeroVisual.WING_FLY)
	# Stable sort makes carrier precede contact if low FPS advances over both.
	events.sort_custom(func(a,b):return float(a.at)<float(b.at))

func _process(delta: float) -> void:
	var h := owner_ref.get_ref() as Hero
	if not is_instance_valid(h) or h._dead or not is_instance_valid(h.field) or h.field.is_queued_for_deletion():
		queue_free(); return
	clock+=delta
	if aerial:
		var rise := smoothstep(0.0,1.15,clock)
		var fall := smoothstep(end-0.75,end,clock)
		h.visual.position.y=5.0*rise*(1.0-fall)
		h.visual.set_wing_moving(false)
	while cursor<events.size() and float(events[cursor].at)<=clock:
		var event:Dictionary=events[cursor]
		cursor+=1
		if bool(event.get("motion",false)):
			h.visual.skill_action(skill,float(event.windup))
		elif bool(event.get("launch",false)):
			_launch(h,int(event.index),float(event.flight))
		elif bool(event.get("drop",false)):
			if int(event.index)==0: StarSkillArt.sword_canopy(h.field,center,float(skill.radius),3.4)
			var spot := _sword_spot(h,int(event.index))
			# Reuse the exact landing point selected at launch, even if victim moves.
			set_meta("landing_%d" % int(event.index),spot)
			StarSkillArt.sword_drop(h,h.field,spot,int(event.index),0.42)
		else: _hit(h,int(event.index),int(event.count))
	if clock>=end: queue_free()

func _exit_tree() -> void:
	var h := owner_ref.get_ref() as Hero if owner_ref!=null else null
	if aerial and is_instance_valid(h) and is_instance_valid(h.visual):
		h.remove_meta("star_airborne")
		h.visual.position.y=0.0
		h.visual.set_wing_mode(old_wing_mode)

func _launch(h: Hero, index: int, flight: float) -> void:
	var point := center+Vector3.UP
	var target := victim_ref.get_ref() as Mob if victim_ref!=null else null
	if bool(skill.get("line",false)): point=origin+forward*float(skill.length)+Vector3.UP
	elif String(skill.id)=="leviathan_surge": point=origin+forward*float(skill.radius)+Vector3.UP
	elif String(skill.id)=="sanctified_chain":
		for mob in _area(h,center,float(skill.radius)).slice(0,5): StarSkillArt.launch(h,skill,mob.hit_point(),flight)
		return
	elif h._valid_target(target): point=target.hit_point()
	StarSkillArt.launch(h,skill,point,flight)

func _team_heal(h: Hero, fraction: float) -> void:
	h._heal(fraction,false)
	var bonus := 1.2 if StarProgression.has_full_set(Game.profile,"priest") else 1.0
	for ally in h.get_tree().get_nodes_in_group("companions"):
		if is_instance_valid(ally) and not ally.is_dead() and ally.global_position.distance_to(center)<=float(skill.radius): ally.heal_fraction(fraction*bonus)

func _sword_spot(h: Hero, index: int) -> Vector3:
	var list := _area(h,center,float(skill.radius))
	if not list.is_empty(): return list[index % list.size()].global_position * Vector3(1,0,1)
	var angle := TAU*float(index)/10.0
	return center+Vector3(cos(angle),0,sin(angle))*float(skill.radius)*0.62

func _area(h: Hero, point: Vector3, radius: float) -> Array[Mob]:
	var list: Array[Mob]=[]
	for node in h.get_tree().get_nodes_in_group("mobs"):
		var mob:=node as Mob
		if mob and not mob.is_dead() and Vector2(mob.global_position.x-point.x,mob.global_position.z-point.z).length()<=radius+mob.body_radius(): list.append(mob)
	list.sort_custom(func(a,b):return a.global_position.distance_squared_to(point)<b.global_position.distance_squared_to(point))
	return list

func _hit(h: Hero, index: int, count: int) -> void:
	var id:=String(skill.id)
	var target:=victim_ref.get_ref() as Mob if victim_ref!=null else null
	if String(skill.shape)=="summon":
		h._summon(skill,float(skill.mult)*h.rank_mult(skill))
		StarSkillArt.strike(h.field,skill,center,index,origin)
		return
	if String(skill.shape)=="self":
		if index==0:
			var fx:Dictionary=skill.get("fx",{})
			if fx.has("buff"):
				h.receive_buff(fx.buff,skill.color,skill.name,false,skill.id)
				if id!="sylph_step":
					for ally in h.get_tree().get_nodes_in_group("companions")+h.get_tree().get_nodes_in_group("summons"):
						if is_instance_valid(ally) and not ally.is_dead() and ally.global_position.distance_to(origin)<=12.0: ally.receive_party_buff(fx.buff,skill.color,skill.name,skill.id)
		if id=="sacred_sanctuary":
			# The field belongs to its buff; replacement ends healing immediately.
			if not BuffBook.contains(h._buffs,id,false): return
			if h.global_position.distance_to(center)<=float(skill.radius): h._heal(0.06,false)
			for ally in h.get_tree().get_nodes_in_group("companions"):
				if is_instance_valid(ally) and not ally.is_dead() and ally.global_position.distance_to(center)<=float(skill.radius): ally.heal_fraction(0.06*(1.2 if StarProgression.has_full_set(Game.profile,"priest") else 1.0))
		StarSkillArt.strike(h.field,skill,center,index,origin)
		return
	var victims:Array[Mob]=[]
	var point:=center
	var share:=1.0/float(count)
	if id=="celestial_swordfall":
		point=get_meta("landing_%d" % index,center)
		victims=_area(h,point,2.0)
	elif bool(skill.get("line",false)):
		for m in _area(h,origin,float(skill.get("length",15.0))):
			var offset:Vector3=(m.global_position-origin)*Vector3(1,0,1)
			var along:=offset.dot(forward)
			if along>=-m.body_radius() and along<=float(skill.length) and (offset-forward*along).length()<=float(skill.width)+m.body_radius(): victims.append(m)
		point=origin+forward*float(skill.length)*0.55
	elif String(skill.shape)=="single":
		if h._valid_target(target) and h._flat(target.global_position-h.global_position).length()<=float(skill.range)+3.0:
			victims.append(target);point=target.global_position
		if id=="heartseeker": share=0.10 if index<5 else 0.50
		elif id=="crown_breaker": share=0.32 if index==0 else 0.68
		elif id=="hunters_verdict": share=0.25 if index<2 else 0.5
	elif id=="sanctified_chain":
		victims=_area(h,center,float(skill.radius)).slice(0,5)
	else:
		victims=_area(h,center,float(skill.radius))
		if id in ["lionfang_cleave","leviathan_surge"]:
			victims= victims.filter(func(m):return ((m.global_position-origin)*Vector3(1,0,1)).normalized().dot(forward)>=0.25)
		if id=="celestial_hunt" and index==count-1:
			victims.clear()
			if h._valid_target(target): victims.append(target);point=target.global_position
	StarSkillArt.strike(h.field,skill,point,index,origin)
	for mob in victims:
		if id=="astral_convergence" and not mob.is_boss:
			mob.global_position=mob.global_position.move_toward(Vector3(center.x,mob.global_position.y,center.z),1.3)
		var damage:=float(skill.mult)*share*h.rank_mult(skill)
		if id in ["heartseeker","spiral_impaler"] and index>=2 and StarProgression.has_full_set(Game.profile,"lancer"): damage*=1.15
		if id=="sanctified_chain": StarSkillArt.strike(h.field,skill,mob.global_position,0,origin)
		h._deal(mob,damage,skill.color,skill.vfx,false,skill)
		if not mob.is_dead() and skill.get("fx",{}).has("shred"): mob.apply_shred(0.2,6.0)
	if id=="sanctified_chain" and not victims.is_empty(): _team_heal(h,0.12)
	if id=="dawn_salvation": _team_heal(h,0.10)
