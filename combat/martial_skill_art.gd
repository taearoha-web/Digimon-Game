class_name MartialSkillArt
extends RefCounted
## Art-only staging for the 18 martial elite skills. Damage, flight duration,
## targets and cooldowns remain owned by the existing combat implementation.
const SHADER := preload("res://shaders/martial_art.gdshader")
const COLORS := {
	"grand_cross":["efb95a","fff3c6","703224"],"sword_of_justice":["eac16a","fffce6","754a37"],
	"godly_shield":["dbbf83","fff9df","615077"],"divine_piercing":["96d5ef","fff9d4","315080"],
	"triumph_of_valhalla":["e8aa40","fff1b0","943d28"],"gladiator":["e84748","ffe9a5","571529"],
	"tempest":["49cba7","dcfff2","17556b"],"lightning_arrow":["529af4","fff39e","29437c"],
	"phoenix_rain":["f48c32","fff4ac","ac244a"],"spirit_of_wind":["60dcb6","edffe8","24556c"],
	"dragon_shot":["eb653b","ffedab","932142"],"meteor_arrow":["ed6d38","fff3b3","702446"],
	"dragon_lance":["ea6334","ffdc85","8a2236"],"gale_cyclone":["69d6c7","ebffff","326c91"],
	"valkyrie_blessing":["e2c98a","fffbe8","778ab9"],"gungnir":["d9b452","ffffd5","4e6ca0"],
	"heaven_rend":["819beb","ffffcb","384077"],"ragnarok_lance":["5579c9","ffdf83","282b65"]
}
static func handles(skill: Dictionary) -> bool:
	return COLORS.has(String(skill.get("id","")))

static func look(skill: Dictionary) -> Dictionary:
	var c: Array=COLORS[String(skill.id)]
	return {"primary":Color(c[0]),"accent":Color(c[1]),"shade":Color(c[2])}

static func add(art: EliteSkillArt, kind: String, colors: Dictionary, at: Vector3, size: Vector3, rot := Vector3.ZERO, start := 0.0, seconds := 1.0, style := {}) -> void:
	var options: Dictionary=style.duplicate()
	options.martial=true
	art.layer("martial/"+kind,colors,at,size,rot,start,seconds,options.get("travel",Vector3.ZERO),float(options.get("spin",0)),float(options.get("initial",0.95)),false,options)

static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, aim: Vector3, duration: float, visual: HeroVisual) -> void:
	if not VfxBudget.can_decorate(): return
	var art := EliteSkillArt._root(parent,origin,duration,"MartialInvocation_"+String(skill.id))
	if visual:
		art.owner_ref=weakref(visual); art.generation=visual.skill_generation
	var dir := aim-origin
	if Vector2(dir.x,dir.z).length_squared()>0.001: art.rotation.y=atan2(dir.x,dir.z)
	var c := look(skill)
	var id := String(skill.id)
	var opts := {"fade_in":0.16,"decay":1.0,"initial":0.3,"opacity":0.80}
	if id=="gladiator":
		add(art,"champion",c,Vector3(0,0,-0.85),Vector3.ONE*1.8,Vector3.ZERO,0,duration,opts)
	elif id=="divine_piercing":
		add(art,"sword_fan",c,Vector3.ZERO,Vector3.ONE,Vector3.ZERO,0,duration,opts)
	elif id=="ragnarok_lance":
		add(art,"lance",c,Vector3(0,1.2,-1.3),Vector3(2.6,6.4,2.6),Vector3(PI/2,0,0),0,duration,opts)
		add(art,"gates",c,Vector3(0,1.3,1),Vector3(1.6,1.6,4),Vector3.ZERO,0,duration,opts)
	elif id in ["tempest","phoenix_rain","meteor_arrow","lightning_arrow","dragon_shot"]:
		add(art,"bow",c,Vector3(0,1.35,0.55),Vector3.ONE*(1.35 if id=="meteor_arrow" else 0.9),Vector3(0,0,PI/2),0,duration,opts)
		if id=="meteor_arrow":
			var sky := EliteSkillArt._root(parent,aim,duration,"MartialSkyCharge")
			sky.owner_ref=art.owner_ref; sky.generation=art.generation
			add(sky,"rune",c,Vector3(0,7,0),Vector3.ONE*1.6,Vector3(PI/2,0,0),0,duration,opts)
	elif id in ["godly_shield","triumph_of_valhalla","valkyrie_blessing","spirit_of_wind"]:
		add(art,"crest",c,Vector3(0,1.8,-0.3),Vector3.ONE*0.8,Vector3.ZERO,0,duration,opts)
	else:
		var spear := id in ["dragon_lance","gungnir","heaven_rend","gale_cyclone"]
		add(art,"lance" if spear else "blade",c,Vector3(0,1,0.5),Vector3(0.7,2.1,0.7),Vector3(0.6,0,-0.2),0,duration,opts)
	art._draw()

static func play(art: EliteSkillArt, skill: Dictionary, center: Vector3, origin: Vector3, delay: float) -> void:
	var id := String(skill.id)
	var c := look(skill)
	var radius := float(skill.get("radius",3.0))
	var distance := maxf(1.0,origin.distance_to(center))
	var d := delay
	# All motifs animate on one finite owner clock. Prioritize core + contact on
	# low quality; extra polish is third through sixth, never extra hit callbacks.
	match id:
		"grand_cross":
			add(art,"cross",c,Vector3(0,0.12,0),Vector3.ONE*radius,Vector3.ZERO,d,1.0,{"initial":0.18})
			add(art,"sweep",c,Vector3(0,1.1,0),Vector3(radius,1,radius),Vector3(0.10,0,0.12),d,0.65,{"spin":3.8,"initial":0.65})
			add(art,"shock",c,Vector3(0,0.22,0),Vector3.ONE*radius,Vector3.ZERO,d+0.04,0.9,{"initial":0.35})
			add(art,"sparks",c,Vector3.ZERO,Vector3(radius*0.8,2,radius*0.8),Vector3.ZERO,d,1.2,{"travel":Vector3.UP*0.6})
		"sword_of_justice":
			add(art,"blade",c,Vector3(0,0.4,distance),Vector3(2,4.3,1.3),Vector3(0,0,-0.3),d,0.7,{"turn":Vector3(0,0,0.55),"decay":0.3})
			add(art,"sweep",c,Vector3(0,1.8,distance),Vector3.ONE*2.7,Vector3(PI/2,0,0),d,0.6,{"spin":1.1,"initial":0.7})
			add(art,"sparks",c,Vector3(0,0.4,distance),Vector3(1.6,2.8,1.6),Vector3.ZERO,d,1.0,{"travel":Vector3.UP*0.6})
		"godly_shield":
			add(art,"shield",c,Vector3(0,1.6,0.65),Vector3.ONE*1.7,Vector3.ZERO,d,1.3,{"initial":0.25,"fade_in":0.06})
			add(art,"shock",c,Vector3(0,0.13,0),Vector3.ONE*3,Vector3.ZERO,d,1.1,{"initial":0.2,"travel":Vector3.UP*0.6})
			for s in [-1.0,1.0]:
				add(art,"shield",c,Vector3(s*1.8,1.2,0),Vector3.ONE*1.2,Vector3(0,s*0.9,0),d+0.10,1.2,{"initial":0.15,"travel":Vector3.UP*0.3})
			add(art,"sparks",c,Vector3.ZERO,Vector3(2,2.6,2),Vector3.ZERO,d,1.5,{"travel":Vector3.UP*0.8})
		"divine_piercing":
			# Actual eight-victim fan is rendered by flight(), never a fake lane.
			add(art,"sweep",c,Vector3(0,1.1,0.65),Vector3(2.8,1.2,2.8),Vector3(0,0,0.2),d,0.7,{"spin":1.3})
			add(art,"rune",c,Vector3(0,1.4,0.7),Vector3.ONE*1.3,Vector3.ZERO,d,0.75,{"initial":0.4})
		"triumph_of_valhalla":
			add(art,"triumph",c,Vector3(0,0,-1.1),Vector3.ONE*1.6,Vector3.ZERO,d,1.55,{"initial":0.25,"fade_in":0.08})
			add(art,"crest",c,Vector3(0,3.1,-0.7),Vector3.ONE*1.25,Vector3.ZERO,d+0.10,1.5,{"travel":Vector3.UP*0.4})
			add(art,"shock",c,Vector3(0,0.07,0),Vector3.ONE*3.6,Vector3.ZERO,d,1.4,{"initial":0.2})
			add(art,"sparks",c,Vector3.ZERO,Vector3(2.6,4,2.6),Vector3.ZERO,d,1.6,{"travel":Vector3.UP*0.7})
		"gladiator":
			add(art,"champion",c,Vector3(0,0,-0.8),Vector3.ONE*2.15,Vector3.ZERO,d,1.15,{"opacity":0.74,"strike":true,"decay":0.4})
			add(art,"sweep",c,Vector3(0,2.5,distance*0.7),Vector3.ONE*4.0,Vector3(PI/2,0,-0.25),d,0.7,{"spin":1.65,"initial":0.8})
			add(art,"blade",c,Vector3(0,0.5,distance),Vector3(2.6,5,1.6),Vector3(0.10,0,-0.35),d,0.7,{"turn":Vector3(0.5,0,0.7),"opacity":0.88})
			add(art,"crest",c,Vector3(0,0.12,distance),Vector3.ONE*2.4,Vector3(-PI/2,0,0),d,1.3)
			add(art,"sparks",c,Vector3(0,0.2,distance),Vector3(2.5,4,2.5),Vector3.ZERO,d,1.3,{"travel":Vector3.UP*0.6})
			add(art,"fault",c,Vector3(0,0.08,distance),Vector3.ONE*2.7,Vector3.ZERO,d,1.3)
		"tempest", "phoenix_rain":
			var fire := id=="phoenix_rain"
			# Rain begins at release and reaches the ground at the existing .55s hit.
			add(art,"fire_rain" if fire else "rain",c,Vector3(0,0.15,0),Vector3(radius,4,radius),Vector3.ZERO,0,d+0.75,{"drop":5.0,"land":d,"decay":0.7,"airborne":true})
			add(art,"shock",c,Vector3(0,0.09,0),Vector3.ONE*radius,Vector3.ZERO,d,1.1,{"initial":0.6,"opacity":0.66})
			if fire:
				add(art,"phoenix",c,Vector3(0,5.5,0),Vector3.ONE*2.3,Vector3(-PI/3,0,0),0,1.75,{"travel":Vector3.UP*0.25,"airborne":true})
				for side in [-1,1]:
					add(art,"wing_left" if side<0 else "wing_right",c,Vector3(0,5.5,0),Vector3.ONE*2.3,Vector3(-PI/3,0,float(side)*0.2),0,1.7,{"flap":float(side)*0.22,"airborne":true})
			else:
				add(art,"storm",c,Vector3(0,0.3,0),Vector3(radius,4,radius),Vector3.ZERO,0,1.5,{"spin":2.5,"opacity":0.6,"airborne":true})
				add(art,"sparks",c,Vector3.ZERO,Vector3(radius,2,radius),Vector3.ZERO,d,1.4)
		"lightning_arrow", "meteor_arrow", "dragon_shot":
			add(art,"bow",c,Vector3(0,1.3,0.65),Vector3.ONE*(1.5 if id=="meteor_arrow" else 1.05),Vector3(0,0,PI/2),d,0.8,{"initial":0.8,"decay":0.25})
			add(art,"rune",c,Vector3(0,1.3,0.8),Vector3.ONE*1.3,Vector3.ZERO,d,0.75,{"initial":0.5,"turn":Vector3(0,0,0.6)})
			if id=="dragon_shot":
				add(art,"dragon",c,Vector3(0,1.7,0.1),Vector3.ONE*1.25,Vector3(0,0,0.2),d,0.65,{"travel":Vector3(0,0,1.5),"decay":0.2})
		"spirit_of_wind":
			add(art,"wind_aura",c,Vector3.ZERO,Vector3.ONE*1.8,Vector3.ZERO,d,1.5,{"initial":0.4})
			add(art,"wind",c,Vector3(0,0.1,0),Vector3(2.7,2.1,2.7),Vector3.ZERO,d,1.4,{"spin":3.8,"opacity":0.6})
			add(art,"phoenix",c,Vector3(0,2.8,-0.6),Vector3.ONE*0.8,Vector3.ZERO,d,1.1,{"travel":Vector3(0,0.7,-0.4)})
		"dragon_lance":
			add(art,"dragon",c,Vector3(0,1.2,3),Vector3(1.8,1.8,3),Vector3.ZERO,d,0.95,{"travel":Vector3(0,0,4),"decay":0.3})
			add(art,"lance",c,Vector3(0,1.1,0),Vector3(1.3,10,1.3),Vector3(PI/2,0,0),d,0.7)
			add(art,"wind",c,Vector3(0,1.1,0),Vector3(1,11,1),Vector3(PI/2,0,0),d,1.1,{"spin":2.2})
		"gale_cyclone":
			add(art,"storm",c,Vector3(0,0.1,0),Vector3(radius,3.7,radius),Vector3.ZERO,d,1.3,{"spin":5.0,"initial":0.4})
			add(art,"sweep",c,Vector3(0,1,0),Vector3(radius,1,radius),Vector3(0.12,0,0),d,0.8,{"spin":5.0})
			add(art,"sparks",c,Vector3.ZERO,Vector3(radius,2.1,radius),Vector3.ZERO,d,1.3,{"spin":1.5})
		"valkyrie_blessing":
			for side in [-1,1]:
				add(art,"wing_left" if side<0 else "wing_right",c,Vector3(0,2,-0.4),Vector3.ONE*2.1,Vector3(0,0,float(side)*0.3),d,1.5,{"flap":float(side)*0.16,"initial":0.35})
			add(art,"crest",c,Vector3(0,3.7,-0.4),Vector3.ONE*0.8,Vector3.ZERO,d,1.4)
			add(art,"rune",c,Vector3(0,0.08,0),Vector3.ONE*2.5,Vector3(PI/2,0,0),d,1.4,{"turn":Vector3(0,0,0.4)})
			add(art,"sparks",c,Vector3.ZERO,Vector3(2.3,3.3,2.3),Vector3.ZERO,d,1.5)
		"gungnir":
			add(art,"lance",c,Vector3(0,1.2,0),Vector3(3.0,12.5,2.3),Vector3(PI/2,0,0),d,0.85,{"travel":Vector3(0,0,0.5)})
			add(art,"rune",c,Vector3(0,1.2,1.6),Vector3.ONE*1.8,Vector3.ZERO,d,1.0,{"turn":Vector3(0,0,0.45)})
			add(art,"wind",c,Vector3(0,1.2,1.5),Vector3(0.8,10,0.8),Vector3(PI/2,0,0),d,0.9,{"spin":2.5})
		"heaven_rend":
			add(art,"fault",c,Vector3(0,0.08,0),Vector3.ONE*radius,Vector3.ZERO,d,1.5,{"initial":0.2})
			add(art,"shock",c,Vector3(0,0.3,0),Vector3(radius,2,radius),Vector3.ZERO,d,0.95,{"initial":0.12,"travel":Vector3.UP*0.4})
			add(art,"sweep",c,Vector3(0,2,1),Vector3.ONE*4.6,Vector3(PI/2,0,0),d,0.6,{"spin":1.8,"decay":0.25})
			add(art,"sparks",c,Vector3.ZERO,Vector3(radius*0.8,3.3,radius*0.8),Vector3.ZERO,d,1.3,{"travel":Vector3.UP*0.6})
		"ragnarok_lance":
			add(art,"lance",c,Vector3(0,1.3,0),Vector3(6.5,12.5,4.5),Vector3(PI/2,0,0),d,1.1,{"decay":0.35})
			add(art,"gates",c,Vector3(0,1.5,2),Vector3(2,2,9),Vector3.ZERO,d,1.2,{"turn":Vector3(0,0,0.6),"opacity":0.8})
			add(art,"wind",c,Vector3(0,1.3,1),Vector3(1.3,17,1.3),Vector3(PI/2,0,0),d,1.2,{"spin":3.0})
			add(art,"fault",c,Vector3(0,0.08,7),Vector3(1.6,1,7),Vector3.ZERO,d,1.45)
			add(art,"sparks",c,Vector3(0,0.3,7),Vector3(1.5,3,7),Vector3.ZERO,d,1.4,{"travel":Vector3.UP*0.7})
	art.lifetime=maxf(art.lifetime,2.3)

static func flight(parent: Node3D, skill: Dictionary, from: Vector3, to: Vector3, seconds: float, size: float) -> Node3D:
	var id := String(skill.id)
	var root := Node3D.new()
	root.name="MartialFlight_"+id
	parent.add_child(root)
	var start := to+Vector3(-1.2,8,0.3) if id=="meteor_arrow" else from
	root.global_position=start
	var delta := to-start
	if delta.length_squared()>0.001: root.look_at(to,Vector3.RIGHT if absf(delta.normalized().y)>0.98 else Vector3.UP,true)
	var body := MeshInstance3D.new()
	body.name="EssentialSkillProjectile"
	body.mesh=MartialGeometry.mesh("dragon_arrow" if id=="dragon_shot" else "blade" if id=="divine_piercing" else "meteor" if id=="meteor_arrow" else "arrow")
	var mat := ShaderMaterial.new()
	mat.shader=SHADER
	for key in look(skill): mat.set_shader_parameter(key,look(skill)[key])
	body.material_override=mat
	body.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)
	body.scale=Vector3.ONE*size*(0.65 if id=="dragon_shot" else 1.25 if id=="meteor_arrow" else 1.0)
	if id!="dragon_shot": body.rotation.x=-PI/2 if id=="meteor_arrow" else PI/2
	var trail := EliteSkillArt._root(root,root.global_position,seconds,"MartialFlightTrail")
	trail.transform=Transform3D.IDENTITY
	add(trail,"wind",look(skill),Vector3(0,0,-0.6),Vector3(0.28,2.6,0.28),Vector3(PI/2,0,0),0,seconds,{"spin":2,"decay":1.0})
	if id=="lightning_arrow":
		add(trail,"bolt",look(skill),Vector3(0,0,-1.5),Vector3.ONE,Vector3.ZERO,0,seconds,{"decay":1.0})
	var tw := root.create_tween()
	tw.tween_property(root,"global_position",to,seconds)
	tw.tween_callback(root.queue_free)
	return root

static func contact(parent: Node3D, skill: Dictionary, at: Vector3) -> void:
	if not VfxBudget.can_decorate(): return
	var art := EliteSkillArt._root(parent,at,1.2,"MartialContact_"+String(skill.id))
	var c := look(skill)
	var meteor := String(skill.id)=="meteor_arrow"
	add(art,"sparks",c,Vector3.ZERO,Vector3(2.8,4.8,2.8) if meteor else Vector3(0.7,1.2,0.7),Vector3.ZERO,0,1.0 if meteor else 0.55,{"initial":0.1,"travel":Vector3.UP*0.4})
	if String(skill.id)=="lightning_arrow":
		add(art,"bolt",c,Vector3(0,-0.6,0),Vector3.ONE*0.9,Vector3(-PI/2,0,0),0,0.5)
	if meteor:
		add(art,"meteor",c,Vector3(0,-0.3,0),Vector3(2.0,2.2,2.0),Vector3.ZERO,0,0.95,{"opacity":0.85,"decay":0.25})
		add(art,"crater",c,Vector3(0,-at.y+0.06,0),Vector3.ONE*2.6,Vector3.ZERO,0,1.2)
		add(art,"shock",c,Vector3(0,-at.y+0.16,0),Vector3.ONE*3.1,Vector3.ZERO,0,0.85,{"initial":0.1})
	art._draw()
