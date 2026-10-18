class_name StarSkillArt
extends Node3D
## Star 50/100/150/200 presentation. Cosmetic ONLY. Combat owns every hit,
## movement, buff and summon lifetime. Each root uses one clock and 2/4/6 draws.
## Geometry is finite/shared; materials live only as long as their mesh node.
const SHADER := preload("res://shaders/star_skill.gdshader")
const COLORS := {
	# Each star skill wears its own saturated signature colour, so the
	# twenty read apart at a glance: [primary, bright core, deep shade].
	"lionfang_cleave":["ff9a1f","fff0a0","8a2a10"], "crown_breaker":["e8324a","ffe08a","5a1030"],
	"royal_vanguard":["3a7bff","ffe58a","1c2a6e"], "celestial_swordfall":["ffc83a","fffbe0","6a3fd0"],
	"moonpiercer":["8fb8ff","f4f8ff","2c3a8a"], "hunters_verdict":["1fd38a","f0ffd0","0d5a4a"],
	"sylph_step":["3ff0d0","eafffb","177a8a"], "celestial_hunt":["5a6bff","fff1a0","1f1e6e"],
	"spiral_impaler":["18d8ff","eaffff","15468f"], "heartseeker":["ff2a4f","ffd6dc","5a0a22"],
	"aegis_formation":["4aa8ff","fff2b0","1e3f78"], "worldsplitter":["8a5cff","ffd88a","2e1b5e"],
	"arcane_prism":["c04dff","fbeaff","3a0f6a"], "crystal_prison":["2fb8ff","eaffff","10307a"],
	"astral_convergence":["6f5bff","ffe08a","22145e"], "genesis_nova":["ff4fb0","fff0d0","4a1060"],
	"sanctified_chain":["ffc23a","fffbe0","8a5a20"], "seraph_aegis":["ff8ad0","fff4fb","6a3a8a"],
	"sacred_sanctuary":["2fe0a0","f2fff6","1f6a6a"], "dawn_salvation":["ff7a4a","fff0c0","a03060"],
	"moonwolf_pact":["5fe0a0","f4ffe6","1d5a3e"], "leviathan_surge":["10c8d8","dafffa","0a4a7a"],
	"spirit_court":["9be03a","fff6b0","2f6a3a"], "eclipse_sovereign":["2fa8ff","e8fcff","0b2a6e"],
	"titan_shieldbreak":["ffa64a","fff2c8","6a3412"], "judgment_rebound":["ffe15a","fffbe0","5a4a10"],
	"eternal_aegis":["5fb4ff","f0f8ff","1a3a7a"], "heavens_bulwark":["8fd0ff","fffbe8","2a3f8a"]
}
const MOTIFS := {
	"lionfang_cleave":"lion", "crown_breaker":"crown", "royal_vanguard":"banners", "celestial_swordfall":"celestial",
	"moonpiercer":"moon", "hunters_verdict":"reticle", "sylph_step":"sylph", "celestial_hunt":"constellation",
	"spiral_impaler":"drill", "heartseeker":"heart", "aegis_formation":"phalanx", "worldsplitter":"worldroot",
	"arcane_prism":"prism", "crystal_prison":"prison", "astral_convergence":"planets", "genesis_nova":"genesis",
	"sanctified_chain":"rosary", "seraph_aegis":"seraph", "sacred_sanctuary":"chapel", "dawn_salvation":"sunrise",
	"moonwolf_pact":"sylph", "leviathan_surge":"leviathan", "spirit_court":"court", "eclipse_sovereign":"leviathan",
	"titan_shieldbreak":"worldroot", "judgment_rebound":"crown", "eternal_aegis":"phalanx", "heavens_bulwark":"celestial"
}
const SUPPORT := ["eternal_aegis", "royal_vanguard", "sylph_step", "aegis_formation", "seraph_aegis", "sacred_sanctuary", "spirit_court"]
var age := 0.0
var lifetime := 1.0
var layers: Array[Dictionary] = []
var follow_ref: WeakRef
var generation_ref: WeakRef
var generation := -1
var follow_offset := Vector3.ZERO
var require_alive := false
var buff_id := ""

static func handles(skill: Dictionary) -> bool:
	return COLORS.has(String(skill.get("id", "")))

static func look(skill: Dictionary) -> Dictionary:
	var colors: Array = COLORS.get(String(skill.get("id", "")), ["eaca80","fffbe9","565274"])
	return {"primary":Color(colors[0]),"accent":Color(colors[1]),"shade":Color(colors[2])}

static func _visual(caster: Node3D) -> HeroVisual:
	if caster is HeroVisual: return caster as HeroVisual
	if is_instance_valid(caster) and caster.get("visual") is HeroVisual: return caster.get("visual") as HeroVisual
	return null

static func _root(parent: Node3D, point: Vector3, seconds: float, label: String) -> StarSkillArt:
	if not is_instance_valid(parent): return null
	var art := StarSkillArt.new()
	art.name = label
	art.lifetime = maxf(0.08,seconds)
	parent.add_child(art)
	art.global_position = point
	return art

static func _face(art: StarSkillArt, source: Vector3, target: Vector3) -> void:
	var direction := target-source
	if Vector2(direction.x,direction.z).length_squared()>0.001:
		art.rotation.y=atan2(direction.x,direction.z)

static func _body_point(caster: Node3D) -> Vector3:
	var visual := _visual(caster)
	return visual.skill_emission_position() if visual else caster.global_position+Vector3.UP*1.2

func add(kind: String, colors: Dictionary, at: Vector3, size: Vector3, angles := Vector3.ZERO, seconds := 1.0, style := {}) -> void:
	if layers.size()>=[2,4,6][VfxBudget.quality()] or not VfxBudget.can_decorate(): return
	var geometry := MartialGeometry.mesh(kind.trim_prefix("martial/")) if kind.begins_with("martial/") else StarGeometry.mesh(kind)
	var options: Dictionary=style.duplicate()
	# Heraldic emblems and upright seals should remain readable from the
	# fixed gameplay camera, unlike directional physical attack geometry.
	if kind in ["lion","seraph","banners"] or (kind in ["moon","reticle","heart"] and absf(angles.x)>1.0):
		options.face_camera=true
	add_mesh(geometry,kind,colors,at,size,angles,seconds,options)

func add_mesh(geometry: Mesh, label: String, colors: Dictionary, at: Vector3, size: Vector3, angles: Vector3, seconds: float, style := {}) -> void:
	if not geometry or layers.size()>=[2,4,6][VfxBudget.quality()] or not VfxBudget.can_decorate(): return
	var node := MeshInstance3D.new()
	node.name=label.replace("/","_")
	node.mesh=geometry
	var mat := ShaderMaterial.new()
	mat.shader=SHADER
	for key in ["primary","accent","shade"]: mat.set_shader_parameter(key,colors[key])
	mat.set_shader_parameter("opacity",float(style.get("opacity",0.94)))
	mat.set_shader_parameter("spectral",float(style.get("spectral",0)))
	node.material_override=mat
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	VfxBudget.track_decoration(node)
	node.visible=false
	var start := float(style.get("delay",0))
	layers.append({"node":node,"at":at,"size":size,"angles":angles,"seconds":maxf(0.04,seconds),"start":start,"style":style})
	lifetime=maxf(lifetime,start+seconds+0.02)

func _process(delta: float) -> void:
	if generation_ref:
		var visual := generation_ref.get_ref() as HeroVisual
		if not is_instance_valid(visual) or visual.skill_generation!=generation:
			queue_free()
			return
	if follow_ref:
		var target := follow_ref.get_ref() as Node3D
		if not is_instance_valid(target):
			queue_free()
			return
		if require_alive and target.has_method("is_dead") and bool(target.call("is_dead")):
			queue_free()
			return
		global_position=target.global_position+follow_offset
		# BuffArt's engine decides active/overwritten buffs; roots also support
		# explicit cancellation when gameplay removes their owning buff.
	age+=delta
	_draw()
	if age>=lifetime: queue_free()

func _draw() -> void:
	for layer in layers:
		var node: MeshInstance3D=layer.node
		var t := clampf((age-float(layer.start))/float(layer.seconds),0,1)
		var options: Dictionary=layer.style
		node.visible=age>=float(layer.start) and t<1
		if not node.visible: continue
		var reveal := smoothstep(0.0,float(options.get("grow_time",0.18)),t)
		var grow := lerpf(float(options.get("initial",0.45)),1,reveal)
		if bool(options.get("pulse",false)): grow*=1.0+sin(age*2.4)*0.026
		node.scale=(layer.size as Vector3)*maxf(0.001,grow)
		node.position=layer.at
		var travel: Vector3=options.get("travel",Vector3.ZERO)
		var progress := t*t if bool(options.get("accelerate",false)) else t
		node.position+=travel*progress
		node.rotation=(layer.angles as Vector3)+(options.get("turn",Vector3.ZERO) as Vector3)*smoothstep(0,0.7,t)
		node.rotation.y+=float(options.get("spin",0))*age
		node.rotation.z+=sin(age*float(options.get("flap_rate",4)))*float(options.get("flap",0))
		if bool(options.get("face_camera",false)):
			var camera := get_viewport().get_camera_3d()
			if camera:
				var direction := global_basis.inverse()*(camera.global_position-node.global_position)
				node.rotation.y=atan2(direction.x,direction.z)
		if options.has("orbit"):
			var a := age*float(options.get("orbit_speed",0.8))
			node.position+=Vector3(sin(a),0,cos(a))*float(options.orbit)
		var fade := smoothstep(0.0,float(options.get("fade_in",0.045)),t)
		fade*=1.0-smoothstep(minf(float(options.get("decay",0.60)),0.98),1.0,t)
		var mat := node.material_override as ShaderMaterial
		mat.set_shader_parameter("fade",fade)
		mat.set_shader_parameter("age",age)

static func telegraph(caster: Node3D, skill: Dictionary, point: Vector3, duration: float) -> StarSkillArt:
	if not handles(skill) or not is_instance_valid(caster) or not VfxBudget.can_decorate(): return null
	var id := String(skill.id)
	var colors := look(skill)
	var time := maxf(0.12,duration)
	var origin := caster.global_position
	var parent := caster.get_parent() as Node3D
	if not parent: return null
	var art := _root(parent,origin,time,"StarWindup_"+id)
	var visual := _visual(caster)
	if visual:
		art.generation_ref=weakref(visual)
		art.generation=visual.skill_generation
	_face(art,origin,point)
	var opts := {"initial":0.12,"grow_time":0.85,"fade_in":0.15,"decay":0.94,"opacity":0.78}
	var local_target := art.to_local(point)
	var radius := clampf(float(skill.get("radius",4)),1.5,9.0)
	match id:
		"celestial_swordfall":
			art.add("celestial",colors,local_target+Vector3.UP*9,Vector3.ONE*radius,Vector3.ZERO,time,{"initial":0.25,"grow_time":0.90,"fade_in":0.15,"spin":0.12,"decay":0.98})
			art.add("celestial",colors,local_target+Vector3.UP*0.08,Vector3.ONE*radius,Vector3.ZERO,time,opts)
			art.add("feathers",colors,Vector3.ZERO,Vector3(1.6,4,1.6),Vector3.ZERO,time,{"travel":Vector3.UP*2,"decay":0.90,"initial":0.8})
		"celestial_hunt":
			art.add("constellation",colors,local_target+Vector3.UP*6,Vector3.ONE*radius,Vector3.ZERO,time,opts)
			art.add("moon",colors,Vector3(0,1.6,0.7),Vector3.ONE*1.0,Vector3(PI/2,0,0),time,opts)
		"moonpiercer":
			art.add("moon",colors,Vector3(0,1.45,0.6),Vector3.ONE*1.20,Vector3(PI/2,0,0),time,opts)
			art.add("martial/arrow",colors,Vector3(0,1.45,0.1),Vector3(0.4,1.7,0.4),Vector3(PI/2,0,0),time,opts)
		"hunters_verdict", "heartseeker", "crown_breaker":
			art.add(String(MOTIFS[id]),colors,local_target+Vector3.UP*1.3,Vector3.ONE*1.0,Vector3(PI/2 if id!="crown_breaker" else 0,0,0),time,opts)
			art.add("streak",colors,Vector3(0,1.3,0.6),Vector3(0.8,0.8,0.7),Vector3(0,0,PI/2),time,opts)
		"lionfang_cleave":
			art.add("lion",colors,Vector3(0,1.5,-0.35),Vector3.ONE*0.75,Vector3.ZERO,time,opts)
			art.add("fang",colors,Vector3(0,0.08,0),Vector3.ONE*radius*0.6,Vector3.ZERO,time,opts)
		"titan_shieldbreak", "heavens_bulwark":
			art.add("phalanx",colors,Vector3(0,0.1,0),Vector3.ONE*(1.4 if id=="titan_shieldbreak" else 2.2),Vector3.ZERO,time,opts)
			art.add("celestial" if id=="heavens_bulwark" else "fang",colors,Vector3.UP*0.08,Vector3.ONE*radius*0.7,Vector3.ZERO,time,opts)
		"judgment_rebound":
			art.add("crown",colors,local_target+Vector3.UP*1.6,Vector3.ONE*0.9,Vector3.ZERO,time,opts)
			art.add("celestial",colors,local_target+Vector3.UP*0.08,Vector3.ONE*radius*0.8,Vector3.ZERO,time,opts)
		"spiral_impaler":
			art.add("drill",colors,Vector3(0,1.1,0.6),Vector3.ONE*0.65,Vector3.ZERO,time,{"spin":0,"turn":Vector3(0,0,TAU),"initial":0.15,"grow_time":0.9,"decay":0.95})
		"worldsplitter":
			art.add("heart",colors,Vector3(0,0.10,0),Vector3.ONE*radius*0.65,Vector3.ZERO,time,opts)
			art.add("martial/lance",colors,Vector3(0,1.6,0),Vector3(0.65,2.8,0.65),Vector3(0,0,-0.28),time,opts)
		"arcane_prism", "astral_convergence", "genesis_nova":
			var ultimate := id=="genesis_nova"
			art.add(String(MOTIFS[id]),colors,Vector3(0,2.1 if not ultimate else 3.5,0.7),Vector3.ONE*(1.6 if ultimate else 0.9),Vector3.ZERO,time,{"spin":0.65,"initial":0.08,"grow_time":0.9,"decay":0.98,"spectral":1.0})
			art.add("celestial",colors,Vector3.UP*0.08,Vector3.ONE*(2.5 if ultimate else 1.5),Vector3.ZERO,time,opts)
		"crystal_prison":
			art.add("moon",colors,local_target+Vector3.UP*0.08,Vector3.ONE*radius,Vector3.ZERO,time,opts)
			art.add("shards",colors,local_target,Vector3(radius*0.7,0.5,radius*0.7),Vector3.ZERO,time,opts)
		"sanctified_chain":
			art.add("rosary",colors,Vector3(0,1.4,0.4),Vector3.ONE*0.7,Vector3(PI/2,0,0),time,opts)
			art.add("sunrise",colors,Vector3.UP*0.06,Vector3.ONE*1.2,Vector3.ZERO,time,opts)
		"dawn_salvation":
			art.add("sunrise",colors,Vector3.UP*7,Vector3.ONE*radius*0.72,Vector3.ZERO,time,opts)
			art.add("feathers",colors,Vector3.UP*0.1,Vector3(radius*0.5,2,radius*0.5),Vector3.ZERO,time,{"travel":Vector3.UP,"decay":0.95})
		"moonwolf_pact", "leviathan_surge", "eclipse_sovereign":
			var grand := id=="eclipse_sovereign"
			art.add("moon",colors,Vector3(0,1.6,1.0),Vector3.ONE*(2.1 if grand else 1.25),Vector3(PI/2,0,0),time,opts)
			art.add("court",colors,Vector3(0,0.06,1),Vector3.ONE*(2.0 if grand else 1.2),Vector3.ZERO,time,opts)
		_:
			art.add(String(MOTIFS[id]),colors,Vector3(0,0.15,0),Vector3.ONE*1.15,Vector3.ZERO,time,opts)
			art.add("sunrise" if id=="seraph_aegis" else "celestial",colors,Vector3.UP*0.07,Vector3.ONE*1.8,Vector3.ZERO,time,opts)
	art._draw()
	return art

## Release carrier. Call once at release; point is an actual target, not a
## random decorative victim. Returns a finite root and never schedules damage.
static func launch(caster: Node3D, skill: Dictionary, point: Vector3, duration := 0.5) -> StarSkillArt:
	if not handles(skill) or not is_instance_valid(caster) or not VfxBudget.can_decorate(): return null
	var parent := caster.get_parent() as Node3D
	if not parent: return null
	var id := String(skill.id)
	var colors := look(skill)
	var source := _body_point(caster)
	var art := _root(parent,source,duration+0.10,"StarLaunch_"+id)
	var delta := point-source
	_face(art,source,point)
	var travel := art.global_basis.inverse()*delta
	var kind: String={"moonpiercer":"martial/arrow","hunters_verdict":"martial/arrow","spiral_impaler":"drill","arcane_prism":"prism","sanctified_chain":"rosary","leviathan_surge":"leviathan","celestial_hunt":"martial/arrow"}.get(id,String(MOTIFS[id]))
	var angles := Vector3(PI/2,0,0) if kind=="martial/arrow" else Vector3.ZERO
	var size := Vector3.ONE*(2.0 if id=="leviathan_surge" else 0.7)
	if kind=="martial/arrow": size=Vector3(0.65,2.5,0.65)
	art.add(kind,colors,Vector3.ZERO,size,angles,duration,{"initial":1,"travel":travel,"decay":0.98,"spectral":1.0 if id=="arcane_prism" else 0.0})
	art.add("streak",colors,Vector3.ZERO,Vector3(1.0,1.0,1.6),Vector3.ZERO,duration,{"initial":1,"travel":travel,"decay":0.95,"opacity":0.65})
	if id=="leviathan_surge": art.add("fang",colors,Vector3(0,-1.0,0),Vector3(2.8,1.8,2.8),Vector3.ZERO,duration,{"initial":0.6,"travel":travel,"decay":0.98})
	if id=="moonpiercer": art.add("moon",colors,Vector3.ZERO,Vector3.ONE*0.9,Vector3(PI/2,0,0),duration,{"initial":1,"travel":travel,"decay":0.95})
	art._draw()
	return art

## A contact is paired with a real combat hit. Repeated hits use compact marks;
## first/final contacts receive the signature so target count cannot multiply
## giant scenery sculptures. index is the zero-based actual hit number.
static func strike(parent: Node3D, skill: Dictionary, point: Vector3, index := 0, source := Vector3.ZERO) -> StarSkillArt:
	if not handles(skill) or not VfxBudget.can_decorate(): return null
	ClassFlourish.star_beat(parent, skill, point, index, source)
	var id := String(skill.id)
	var colors := look(skill)
	var art := _root(parent,point,1.6,"StarContact_"+id)
	if not art: return null
	_face(art,source,point)
	var radius := clampf(float(skill.get("radius",4.0)),1.4,9.0)
	var at := Vector3.UP*0.08
	var impact_size := 1.5
	# Finale beats keep a different silhouette from their preparation contact.
	if index>0 and id in ["crystal_prison","genesis_nova","worldsplitter","astral_convergence","dawn_salvation"]:
		var final := index >= (1 if id=="crystal_prison" else (2 if id in ["astral_convergence","dawn_salvation"] else 3))
		if final:
			var motif := "shards" if id=="crystal_prison" else ("worldroot" if id=="worldsplitter" else "sunrise")
			art.add(motif,colors,at,Vector3(radius,3.0 if motif in ["shards","worldroot"] else radius,radius),Vector3.ZERO,1.35,{"initial":0.18,"travel":Vector3.UP*(0.8 if motif=="shards" else 0),"spectral":1.0 if id in ["genesis_nova","astral_convergence"] else 0.0})
			art.add("impact",colors,at+Vector3.UP*0.02,Vector3.ONE*radius,Vector3.ZERO,1.0,{"initial":0.02})
			art.add("feathers" if id=="dawn_salvation" else "shards",colors,Vector3.UP*0.2,Vector3(radius*0.7,3,radius*0.7),Vector3.ZERO,1.5,{"travel":Vector3.UP*0.8})
			art._draw()
			return art
	if index>0 and id not in ["heartseeker","hunters_verdict","crown_breaker","celestial_swordfall","eclipse_sovereign"]:
		art.add("impact",colors,at,Vector3.ONE*1.15,Vector3.ZERO,0.50,{"initial":0.10})
		art.add("shards",colors,Vector3.UP*0.25,Vector3.ONE*0.75,Vector3.ZERO,0.65,{"travel":Vector3.UP*0.4,"initial":0.7,"orbit":0.12,"orbit_speed":3.0,"pulse":true})
		art._draw()
		return art
	match id:
		"lionfang_cleave":
			art.add("lion",colors,Vector3(0,1.5,-0.3),Vector3.ONE*1.8,Vector3.ZERO,0.75,{"travel":Vector3(0,0,1.4),"initial":0.55,"decay":0.4})
			art.add("fang",colors,Vector3(0,0.25,0),Vector3(radius,1.4,radius),Vector3.ZERO,0.7,{"initial":0.5,"turn":Vector3(0,0.6,0)})
			art.add("shards",colors,at,Vector3(radius*0.6,1.8,radius*0.6),Vector3.ZERO,1.0,{"travel":Vector3.UP*0.45,"pulse":true})
		"crown_breaker":
			art.add("crown",colors,Vector3.UP*2.0,Vector3.ONE*(1.65 if index>0 else 0.95),Vector3.ZERO,0.85,{"initial":0.75,"travel":Vector3.UP*0.3,"turn":Vector3(0.25,0.4,0.2)})
			art.add("martial/sweep",colors,Vector3.UP*1.2,Vector3.ONE*(2.8 if index>0 else 1.4),Vector3(PI/2,0,0.4),0.50,{"initial":0.4,"spin":1.6})
			art.add("shards",colors,Vector3.UP*0.5,Vector3(1.6,2.6,1.6),Vector3.ZERO,1.0,{"travel":Vector3.UP*0.35})
		"royal_vanguard":
			art.add("banners",colors,Vector3(0,0.1,-0.5),Vector3.ONE*1.5,Vector3.ZERO,1.7,{"initial":0.08,"fade_in":0.08})
			art.add("lion",colors,Vector3(0,2.0,0.1),Vector3.ONE*0.8,Vector3.ZERO,1.3,{"travel":Vector3.UP*0.5})
			impact_size=2.8
		"celestial_swordfall":
			var final := index>=9
			impact_size=2.6 if final else 1.2
			art.add("shards",colors,at,Vector3(1.3,2.0,1.3)*(1.8 if final else 1.0),Vector3.ZERO,0.9,{"travel":Vector3.UP*0.8,"initial":0.55})
			art.add("impact",colors,at,Vector3.ONE*impact_size,Vector3.ZERO,0.8,{"initial":0.05})
			if final:
				art.add("celestial",colors,at+Vector3.UP*0.01,Vector3.ONE*radius,Vector3.ZERO,1.3,{"initial":0.80,"spin":0.12})
				art.add("feathers",colors,Vector3.UP*0.3,Vector3(radius*0.65,3,radius*0.65),Vector3.ZERO,1.4,{"travel":Vector3.UP})
		"moonpiercer":
			art.add("moon",colors,Vector3.UP,Vector3.ONE*1.6,Vector3(PI/2,0,0),0.65,{"initial":0.2,"travel":Vector3(0,0,0.6)})
			art.add("shards",colors,Vector3.UP*0.4,Vector3(0.8,1.8,0.8),Vector3.ZERO,0.85)
		"hunters_verdict":
			var final := index>=2
			art.add("reticle",colors,Vector3.UP*1.3,Vector3.ONE*(1.7 if final else 0.85),Vector3(PI/2,0,0),0.6,{"initial":1.15,"turn":Vector3(0,0,0.45)})
			art.add("shards",colors,Vector3.UP*0.5,Vector3.ONE*(1.7 if final else 0.75),Vector3.ZERO,0.75,{"travel":Vector3.UP*0.3})
			impact_size=1.8 if final else 0.65
		"sylph_step":
			art.add("sylph",colors,Vector3.UP,Vector3.ONE*1.6,Vector3.ZERO,1.5,{"initial":0.4,"spin":0.65})
			art.add("martial/wind",colors,at,Vector3(2.6,1.8,2.6),Vector3.ZERO,1.2,{"initial":0.2,"spin":2.5,"opacity":0.65})
			impact_size=2.6
		"celestial_hunt":
			art.add("constellation",colors,Vector3.UP*5.8,Vector3.ONE*radius,Vector3.ZERO,2.0,{"initial":0.9,"spin":0.04,"decay":0.82})
			art.add("reticle",colors,at,Vector3.ONE*radius*0.9,Vector3.ZERO,1.4,{"initial":0.9,"spin":0.25})
			art.add("shards",colors,Vector3.UP*0.25,Vector3(radius*0.6,2.4,radius*0.6),Vector3.ZERO,1.5,{"travel":Vector3.UP*0.45})
		"spiral_impaler":
			art.add("drill",colors,Vector3(0,1,-1.4),Vector3(1.8,1.8,2.2),Vector3.ZERO,0.7,{"initial":0.55,"turn":Vector3(0,0,PI*1.5),"travel":Vector3(0,0,1)})
			art.add("impact",colors,Vector3.UP,Vector3.ONE*1.6,Vector3(PI/2,0,0),0.75,{"initial":0.05})
		"heartseeker":
			var final := index>=5
			art.add("heart",colors,Vector3.UP*1.2,Vector3.ONE*(1.8 if final else 0.65+index*0.11),Vector3(PI/2,0,0),0.5,{"initial":0.9,"turn":Vector3(0,0,index*0.16)})
			art.add("streak",colors,Vector3.UP*1.2,Vector3(1,1,1.8 if final else 0.85),Vector3.ZERO,0.32,{"initial":1,"travel":Vector3(0,0,0.5)})
			if final: art.add("shards",colors,Vector3.UP*0.4,Vector3(1.8,2.6,1.8),Vector3.ZERO,0.85,{"travel":Vector3.UP*0.5})
			impact_size=2.2 if final else 0.5
		"titan_shieldbreak":
			art.add("worldroot",colors,at,Vector3(radius,2.2,radius),Vector3.ZERO,1.3,{"initial":0.15,"grow_time":0.2,"decay":0.62})
			art.add("martial/fault",colors,at+Vector3.UP*0.015,Vector3.ONE*radius,Vector3.ZERO,1.5,{"initial":0.08,"grow_time":0.3})
			art.add("phalanx",colors,Vector3(0,0.1,0),Vector3.ONE*1.6,Vector3.ZERO,1.0,{"initial":0.4})
			impact_size=radius
		"judgment_rebound":
			art.add("crown",colors,Vector3.UP*1.8,Vector3.ONE*1.3,Vector3.ZERO,0.8,{"initial":0.7,"travel":Vector3.UP*0.3,"turn":Vector3(0,1.2,0)})
			art.add("shards",colors,Vector3.UP*0.4,Vector3(radius*0.6,2.4,radius*0.6),Vector3.ZERO,1.0,{"travel":Vector3.UP*0.4})
			impact_size=radius*0.7
		"eternal_aegis":
			art.add("phalanx",colors,Vector3(0,0.1,0),Vector3.ONE*2.4,Vector3.ZERO,1.7,{"initial":0.12,"fade_in":0.08})
			art.add("celestial",colors,at,Vector3.ONE*radius,Vector3.ZERO,1.7,{"initial":0.5,"spin":0.15})
			impact_size=radius
		"heavens_bulwark":
			art.add("celestial",colors,at,Vector3.ONE*radius,Vector3.ZERO,1.6,{"initial":0.6,"spin":0.2})
			art.add("phalanx",colors,Vector3(0,0.1,0),Vector3.ONE*2.6,Vector3.ZERO,1.4,{"initial":0.2})
			art.add("shards",colors,Vector3.UP*0.3,Vector3(radius*0.7,3.4,radius*0.7),Vector3.ZERO,1.6,{"travel":Vector3.UP*0.7})
			impact_size=radius
		"aegis_formation":
			art.add("phalanx",colors,Vector3(0,0.1,0),Vector3.ONE*2.0,Vector3.ZERO,1.5,{"initial":0.15,"fade_in":0.08})
			art.add("celestial",colors,at,Vector3.ONE*radius,Vector3.ZERO,1.5,{"initial":0.5})
			impact_size=radius
		"worldsplitter":
			art.add("worldroot",colors,at,Vector3(radius,3.0,radius),Vector3.ZERO,1.5,{"initial":0.15,"grow_time":0.20,"decay":0.62})
			art.add("martial/fault",colors,at+Vector3.UP*0.015,Vector3.ONE*radius,Vector3.ZERO,1.8,{"initial":0.08,"grow_time":0.30})
			art.add("shards",colors,Vector3.UP*0.2,Vector3(radius*0.65,4,radius*0.65),Vector3.ZERO,1.6,{"travel":Vector3.UP*0.65})
			impact_size=radius
		"arcane_prism":
			art.add("prism",colors,Vector3.UP*1.4,Vector3.ONE*1.45,Vector3(0.3,0,0.2),0.75,{"initial":0.18,"spin":1.4,"spectral":1.0,"pulse":true})
			art.add("shards",colors,Vector3.UP*0.3,Vector3(1.6,2.4,1.6),Vector3.ZERO,1.0,{"spectral":1.0,"orbit":0.2,"orbit_speed":2.2})
		"crystal_prison":
			art.add("prison",colors,at,Vector3(radius,2.2,radius),Vector3.ZERO,1.8,{"initial":0.1,"grow_time":0.22,"decay":0.80})
			art.add("shards",colors,Vector3.UP*0.2,Vector3(radius*0.80,3,radius*0.80),Vector3.ZERO,1.6,{"delay":0.25,"travel":Vector3.UP*0.25,"initial":0.6,"pulse":true})
			impact_size=radius
		"astral_convergence":
			art.add("planets",colors,Vector3.UP*2.0,Vector3.ONE*radius*0.65,Vector3.ZERO,1.8,{"initial":1.15,"spin":0.9,"spectral":1.0})
			art.add("constellation",colors,at,Vector3.ONE*radius,Vector3.ZERO,1.8,{"initial":1.1,"spin":-0.2})
			art.add("shards",colors,Vector3.UP*0.3,Vector3(radius*0.7,2.5,radius*0.7),Vector3.ZERO,1.4,{"travel":Vector3.UP*0.8,"spectral":1.0,"orbit":0.25,"orbit_speed":1.6})
			impact_size=radius
		"genesis_nova":
			art.add("genesis",colors,Vector3.UP*3.0,Vector3.ONE*radius*0.55,Vector3.ZERO,1.6,{"initial":0.35,"spin":0.8,"spectral":1.0,"decay":0.45})
			art.add("celestial",colors,at,Vector3.ONE*radius,Vector3.ZERO,1.8,{"initial":0.08,"grow_time":0.35,"spin":0.20,"spectral":1.0})
			art.add("sunrise",colors,Vector3.UP*0.3,Vector3.ONE*radius*1.08,Vector3.ZERO,1.4,{"initial":0.02,"delay":0.15,"spectral":1.0})
			art.add("shards",colors,Vector3.UP*0.4,Vector3(radius*0.7,4,radius*0.7),Vector3.ZERO,1.8,{"travel":Vector3.UP*0.6,"spectral":1.0,"orbit":0.3,"orbit_speed":1.2,"pulse":true})
			impact_size=radius
		"sanctified_chain":
			art.add("sunrise",colors,Vector3.UP*1.1,Vector3.ONE*0.8,Vector3(PI/2,0,0),0.7,{"initial":0.08})
			art.add("feathers",colors,Vector3.UP*0.5,Vector3.ONE*0.8,Vector3.ZERO,0.9,{"travel":Vector3.UP*0.5})
		"seraph_aegis":
			art.add("seraph",colors,Vector3(0,1.5,0.1),Vector3.ONE*1.3,Vector3.ZERO,1.6,{"initial":0.20,"flap":0.06,"flap_rate":3})
			art.add("feathers",colors,Vector3.UP*0.3,Vector3(2.0,2.0,2.0),Vector3.ZERO,1.5,{"travel":Vector3.UP*0.4})
			impact_size=2.6
		"sacred_sanctuary":
			art.add("chapel",colors,at,Vector3(radius,2.4,radius),Vector3.ZERO,2.0,{"initial":0.2,"grow_time":0.22,"decay":0.9})
			art.add("sunrise",colors,at+Vector3.UP*0.025,Vector3.ONE*radius*0.65,Vector3.ZERO,1.8,{"spin":-0.15,"opacity":0.70})
			art.add("feathers",colors,at,Vector3(radius*0.7,2.2,radius*0.7),Vector3.ZERO,1.8,{"travel":Vector3.UP*0.8})
			impact_size=radius
		"dawn_salvation":
			art.add("sunrise",colors,Vector3.UP*6.5,Vector3.ONE*radius*0.8,Vector3.ZERO,1.6,{"initial":0.90,"spin":0.10})
			art.add("seraph",colors,Vector3.UP*5.7,Vector3.ONE*2.0,Vector3.ZERO,1.4,{"initial":0.85,"flap":0.05})
			art.add("sunrise",colors,at,Vector3.ONE*radius,Vector3.ZERO,1.7,{"initial":0.08,"grow_time":0.30})
			art.add("feathers",colors,Vector3.UP*0.2,Vector3(radius*0.7,4,radius*0.7),Vector3.ZERO,1.9,{"travel":Vector3.UP*1.0})
			impact_size=radius
		"moonwolf_pact":
			art.add("sylph",colors,Vector3(0,1.0,-0.6),Vector3.ONE*1.7,Vector3.ZERO,1.2,{"initial":0.55,"spin":0.8})
			art.add("feathers",colors,Vector3(0,0.2,-0.4),Vector3(1.6,3,1.6),Vector3.ZERO,1.1,{"travel":Vector3(0,0.8,1.2),"decay":0.7})
			art.add("shards",colors,at,Vector3.ONE*1.8,Vector3.ZERO,1.2)
		"leviathan_surge":
			art.add("leviathan",colors,Vector3(0,0.8,-1),Vector3.ONE*2.2,Vector3.ZERO,1.4,{"initial":0.55,"travel":Vector3(0,0,2.5),"decay":0.65})
			art.add("fang",colors,at,Vector3(radius,1.8,radius),Vector3.ZERO,1.2,{"initial":0.25,"travel":Vector3(0,0,0.8)})
			art.add("shards",colors,at,Vector3(radius*0.7,3,radius*0.7),Vector3.ZERO,1.5,{"travel":Vector3.UP*0.7})
			impact_size=radius
		"spirit_court":
			art.add("court",colors,Vector3.UP*1.3,Vector3.ONE*1.8,Vector3.ZERO,1.7,{"initial":0.15,"spin":0.6})
			art.add("celestial",colors,at,Vector3.ONE*2.5,Vector3.ZERO,1.6,{"initial":0.4,"spin":-0.1})
			impact_size=radius
		"eclipse_sovereign":
			if index==0:
				art.add("leviathan",colors,Vector3(0,0.8,-0.6),Vector3.ONE*2.6,Vector3.ZERO,1.5,{"initial":0.6,"travel":Vector3(0,0,2.0),"decay":0.65})
				art.add("sunrise",colors,Vector3.UP*0.08,Vector3.ONE*3.0,Vector3.ZERO,1.5,{"initial":0.2})
			elif index%3==1:
				art.add("fang",colors,Vector3.UP*1.0,Vector3(radius,2,radius),Vector3.ZERO,0.8,{"initial":0.6,"turn":Vector3(0,0.6,0)})
			else:
				art.add("sunrise",colors,at,Vector3.ONE*radius,Vector3.ZERO,1.1,{"initial":0.1})
				art.add("shards",colors,at,Vector3(radius*0.7,3,radius*0.7),Vector3.ZERO,1.3,{"travel":Vector3.UP*0.6})
			impact_size=radius
	art.add("impact",colors,at,Vector3.ONE*impact_size,Vector3.ZERO,0.8,{"initial":0.04,"opacity":0.75,"spectral":1.0 if id in ["arcane_prism","genesis_nova","astral_convergence"] else 0.0})
	art._draw()
	return art

## Persistent support emblems occupy a single (low) or two (medium/high) budget
## slots. Gameplay should free the returned root immediately on overwrite.
static func buff(caster: Node3D, skill: Dictionary, duration: float) -> StarSkillArt:
	if not is_instance_valid(caster) or not handles(skill) or not VfxBudget.can_decorate(): return null
	var parent := caster.get_parent() as Node3D
	if not parent: return null
	var id := String(skill.id)
	var art := _root(parent,caster.global_position,duration,"StarBuff_"+id)
	art.follow_ref=weakref(caster)
	art.require_alive=true
	art.buff_id=id
	var colors := look(skill)
	var kind: String=MOTIFS[id]
	var y := 1.5 if id in ["seraph_aegis","sylph_step","spirit_court"] else 0.10
	var scale_v := Vector3.ONE*(0.65 if id in ["sylph_step","spirit_court"] else 0.80)
	if id=="sacred_sanctuary": scale_v=Vector3(1.4,0.5,1.4)
	art.add(kind,colors,Vector3(0,y,-0.35),scale_v,Vector3.ZERO,duration,{"initial":0.45,"fade_in":0.01,"decay":0.98,"opacity":0.70,"spin":0.4 if id in ["sylph_step","spirit_court"] else 0.0,"pulse":true})
	if VfxBudget.quality()>0:
		art.add("moon" if id=="sylph_step" else "reticle",colors,Vector3.UP*0.06,Vector3.ONE*0.85,Vector3.ZERO,duration,{"initial":0.8,"fade_in":0.01,"decay":0.98,"opacity":0.40,"spin":-0.15})
	art._draw()
	return art

## Capture the equipped weapon mesh, including every visible surface, in its
## authored +Y direction. A visual retains only ONE cache entry, replaced when
## equipment refresh replaces its Held_* node. Never duplicate scripts, bones,
## emitters or enhancement nodes. Ten falling swords share one surface.
static func _is_enhancement(node: MeshInstance3D) -> bool:
	var mat := node.material_override as StandardMaterial3D
	if mat and (mat.blend_mode==BaseMaterial3D.BLEND_MODE_ADD or mat.billboard_mode!=BaseMaterial3D.BILLBOARD_DISABLED): return true
	for surface in node.mesh.get_surface_count():
		mat=node.mesh.surface_get_material(surface) as StandardMaterial3D
		if mat and (mat.blend_mode==BaseMaterial3D.BLEND_MODE_ADD or mat.billboard_mode!=BaseMaterial3D.BILLBOARD_DISABLED): return true
	return false

static func equipped_sword(caster: Node3D) -> Mesh:
	var visual := _visual(caster)
	if not visual or not is_instance_valid(visual._emission_grip): return MartialGeometry.mesh("blade")
	var grip := visual._emission_grip
	if grip.get_child_count()==0: return MartialGeometry.mesh("blade")
	var weapon := grip.get_child(0) as Node3D
	if not weapon: return MartialGeometry.mesh("blade")
	var key := weapon.get_instance_id()
	if int(visual.get_meta("star_sword_source",0))==key:
		return visual.get_meta("star_sword_mesh") as Mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inv := weapon.global_transform.affine_inverse()
	var meshes: Array[Node]=weapon.find_children("*","MeshInstance3D",true,false)
	if weapon is MeshInstance3D: meshes.push_front(weapon)
	var count := 0
	for item in meshes:
		var node := item as MeshInstance3D
		if not node.mesh or not node.is_visible_in_tree(): continue
		# Enhancement particles are excluded by type; decorative halo child
		# meshes are excluded because authored model geometry is in GLB meshes.
		if node.name.begins_with("Enhance") or node.name.begins_with("Glow"): continue
		if _is_enhancement(node): continue
		var transform := inv*node.global_transform
		for surface in node.mesh.get_surface_count():
			var arrays := node.mesh.surface_get_arrays(surface)
			if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX]==null: continue
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			for i in (indices.size() if not indices.is_empty() else vertices.size()):
				var p := transform*vertices[indices[i] if not indices.is_empty() else i]
				st.set_color(Color(0.35+0.4*float(surface%3)/2.0,1,0))
				st.set_uv(Vector2(p.x,p.y))
				st.add_vertex(p)
				count+=1
	if count==0: return MartialGeometry.mesh("blade")
	st.generate_normals()
	st.index()
	var result := st.commit()
	visual.set_meta("star_sword_source",key)
	visual.set_meta("star_sword_mesh",result)
	return result

static func sword_drop(caster: Node3D, parent: Node3D, point: Vector3, index: int, flight := 0.42) -> StarSkillArt:
	if not is_instance_valid(caster) or not is_instance_valid(parent) or not VfxBudget.can_decorate(): return null
	var art := _root(parent,point,flight+0.025,"CelestialEquippedSword_%02d"%index)
	var colors := look({"id":"celestial_swordfall"})
	var mesh := equipped_sword(caster)
	var bounds := mesh.get_aabb()
	# Keep the exact silhouette's proportions; a normal blade is 3m tall.
	var size := 3.0/maxf(0.1,bounds.size.y)
	var yaw := float(index)*TAU/10
	# The +Y blade faces down. Its tip reaches the actual point at flight end.
	var at := Vector3(0,9.0+bounds.end.y*size,0)
	art.add_mesh(mesh,"EquippedGoldenSword",colors,at,Vector3.ONE*size,Vector3(PI,yaw,0),flight,{"initial":1.0,"travel":Vector3(0,-9,0),"accelerate":true,"fade_in":0.015,"decay":0.98})
	art.add("streak",colors,Vector3.UP*9.8,Vector3(1,1,2),Vector3(PI/2,0,0),flight,{"initial":1,"travel":Vector3(0,-9,0),"accelerate":true,"decay":0.98})
	art._draw()
	return art

## The overhead seal remains during the real ten-hit sequence. The caller
## passes total flight+hit duration; this helper emits no decorative swords.
static func sword_canopy(parent: Node3D, point: Vector3, radius: float, duration: float) -> StarSkillArt:
	if not VfxBudget.can_decorate(): return null
	var art := _root(parent,point,duration,"CelestialSwordCanopy")
	if not art: return null
	var colors := look({"id":"celestial_swordfall"})
	art.add("celestial",colors,Vector3.UP*9.0,Vector3.ONE*radius,Vector3.ZERO,duration,{"initial":0.9,"spin":0.07,"fade_in":0.02,"decay":0.97})
	art.add("celestial",colors,Vector3.UP*0.075,Vector3.ONE*radius,Vector3.ZERO,duration,{"initial":1,"spin":-0.04,"fade_in":0.02,"decay":0.97,"opacity":0.55})
	art.add("moon",colors,Vector3.UP*9.25,Vector3.ONE*radius*1.1,Vector3.ZERO,duration,{"initial":0.9,"spin":-0.05,"fade_in":0.02,"decay":0.97})
	art._draw()
	return art
