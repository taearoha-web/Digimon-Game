class_name EliteSkillArt
extends Node3D
## Lv80–100 art direction. Cosmetic only: never selects victims or deals damage.
## Shared, finite mesh library; 2–6 budgeted draws per cast, one animation clock.
## A layer is a batched sculpture, not one node per feather, rune or shard.
const SHADER := preload("res://shaders/elite_skill.gdshader")
const IDS := "grand_cross sword_of_justice godly_shield divine_piercing triumph_of_valhalla gladiator tempest lightning_arrow phoenix_rain spirit_of_wind dragon_shot meteor_arrow hell_meteor ice_storm spirit_burst magic_overdrive judgment_ray armageddon divine_judgment prayer seraphim_wrath holy_rain_big miracle last_judgement world_tree fairy_spirit gaia_blessing primal_legion cataclysm elder_dragon dragon_lance gale_cyclone valkyrie_blessing gungnir heaven_rend ragnarok_lance holy_rampart judgment_shield aegis_of_ages meteor_shield sanctuary_wall world_bastion eclipse_fang abyss_vortex phantom_legion midnight_execution shadow_sovereign oblivion_requiem infernal_scream chaos_sovereign raven_storm earth_dominion emperors_command imperial_judgment grand_dissonance aria_of_ruin eternal_echo thunder_crescendo hymn_of_legends grand_finale"
static var _meshes: Dictionary = {}
const GEOMETRY_KINDS := "seal astrolabe snowflake sword spear cut wings phoenix bow dragon tree roots branches crystals spears pillars rain helix cathedral gate bastion banners crown lotus stars feathers leaves fractures lane comet lightning beasts greatshield shield_outline rampart aegis crater_ring chains stave"

static func warm_geometry() -> void:
	for kind in GEOMETRY_KINDS.split(" "):
		geometry(kind)
	MartialGeometry.warm()

var age := 0.0
var lifetime := 1.5
var layers: Array[Dictionary] = []
var owner_ref: WeakRef
var generation := -1

static func handles(skill: Dictionary) -> bool:
	return String(skill.get("id", "")) in IDS.split(" ")

static func palette(skill: Dictionary) -> Dictionary:
	var look := SkillShow.profile_for(skill).duplicate()
	var colors: Array = {
		"warrior":["ed825d","fff2b3","6b223d"], "archer":["5fe6c5","fff0a6","204367"],
		"mage":["ac81fb","f3d6ff","343470"], "priest":["f6bd3f","fff6d0","8a4160"],
		"summoner":["65d9a1","ffe7a5","215b65"], "lancer":["70ccef","fff0ba","334c91"], "defender":["8fc1ff","fff4cc","2c4570"], "assassin":["9a6bff","f4e6ff","2a1240"], "darklord":["e8b64a","fff4d0","4a1020"], "bard":["ff8fcf","fff0f8","4a1036"]
	}.get(String(look.family), ["90dbff","ffffff","234567"])
	var overrides: Dictionary = {
		"grand_cross":["eab875","fff4c9","895149"],"sword_of_justice":["ead28d","fff9db","795c64"],"divine_piercing":["9edbf4","fff2bc","456497"],"judgment_ray":["edcc7a","fff7db","785d68"],"ice_storm":["63c9ff","e7ffff","304eaa"],"hell_meteor":["f77746","fff3a0","7d243f"],
		"meteor_arrow":["ff9763","fff8b9","783568"],"phoenix_rain":["ffb345","fff5bf","c04758"],
		"lightning_arrow":["74c9ff","fff39c","514690"],"elder_dragon":["57c6ad","ffe9a0","285463"],
		"holy_rampart":["ffd25a","fffbe3","8a5a24"],"judgment_shield":["ffcf4d","fffbe0","7a4a20"],"aegis_of_ages":["dceeff","ffffff","3a5a9a"],"meteor_shield":["ff9a48","fff3c0","7a2a30"],"sanctuary_wall":["ffd36a","fffbe8","8a5a40"],"world_bastion":["ffc83a","fff9d8","6a4a1a"],
		"eclipse_fang":["ff4f7b","ffe6ee","3d0d2c"],"infernal_scream":["ff6a2a","fff0b0","6a1a20"],"chaos_sovereign":["8a4dff","f0e2ff","2a0f4a"],"raven_storm":["8a4dff","f0e2ff","1e0f3e"],"imperial_judgment":["e8b64a","fff6d8","3a1a6a"],"midnight_execution":["ff5a86","fff0f4","2a0a28"],"oblivion_requiem":["a77bff","fff0ff","1c0d33"],
		"cataclysm":["46b497","f4d694","34436b"],"fairy_spirit":["ff9ad2","fff4fb","8c3f7a"],"prayer":["a8e7d7","fff4d6","427c86"],"seraphim_wrath":["ffb43c","fff8dc","8c2f66"],"holy_rain_big":["ffc24a","fffbe6","7a4a7e"],
		"grand_dissonance":["b07aff","f2e6ff","2a1040"],"thunder_crescendo":["c79bff","f4ecff","2a1250"],"grand_finale":["ff6fb5","fff4fa","4a0f30"]}
	colors = overrides.get(String(skill.id), colors)
	look.primary = Color(colors[0]); look.accent = Color(colors[1]); look.shade = Color(colors[2])
	if skill.get("fx", {}).has("buff"):
		var support := BuffArt.profile(skill)
		look.primary = support.primary
		look.accent = support.accent
		look.shade = (support.primary as Color).darkened(0.65)
	return look

static func material(look: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	for key in ["primary", "accent", "shade"]:
		mat.set_shader_parameter(key, look[key])
	return mat

static func _root(parent: Node3D, at: Vector3, seconds: float, label: String) -> EliteSkillArt:
	var art := EliteSkillArt.new()
	art.name = label
	art.lifetime = seconds
	parent.add_child(art)
	art.global_position = at
	return art

static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, aim: Vector3, duration: float, visual: HeroVisual) -> void:
	if not handles(skill) or not VfxBudget.can_decorate():
		return
	if MartialSkillArt.handles(skill):
		MartialSkillArt.anticipate(parent,skill,origin,aim,duration,visual)
		return
	var look := palette(skill)
	var art := _root(parent, origin, duration, "EliteInvocation_" + String(skill.id))
	if visual:
		art.owner_ref = weakref(visual)
		art.generation = visual.skill_generation
	var dir := aim-origin
	if Vector2(dir.x,dir.z).length_squared()>0.001:
		art.rotation.y = atan2(dir.x,dir.z)
	var family := String(look.family)
	# Assembles behind/above the weapon; the existing socket charge follows it.
	if family in ["warrior","lancer"]:
		var kind := "spear" if family == "lancer" else "sword"
		art.layer(kind,look,Vector3(0,0.9,0.7),Vector3(0.7,2.7,0.7),Vector3(0.65,0,-0.3),0,duration,Vector3.ZERO,0.0,0.18)
	elif family == "archer":
		art.layer("wings",look,Vector3(0,1.3,0.6),Vector3.ONE*0.75,Vector3.ZERO,0,duration,Vector3.ZERO,0.0,0.18)
	elif family == "defender":
		art.layer("shield_outline",look,Vector3(0,0.08,0),Vector3.ONE*1.5,Vector3.ZERO,0,duration,Vector3.ZERO,0.0,0.12)
	elif family == "darklord":
		# A royal crown gathers over the scepter before the command.
		art.layer("crown",look,Vector3(0,2.2,0.3),Vector3.ONE*0.9,Vector3.ZERO,0,duration,Vector3.UP*0.3,0.4,0.2)
	elif family == "bard":
		# A staff drum rises behind and round the Bard like a music box.
		art.layer("stave",look,Vector3(0,0.9,0),Vector3.ONE*1.05,Vector3.ZERO,0,duration,Vector3.UP*0.35,0.5,0.2)
	elif family == "assassin":
		# Two thin crescents gather across the daggers before the blades move.
		for side in [-1.0,1.0]:
			art.layer("cut",look,Vector3(0,1.1,0.55),Vector3.ONE*0.9,Vector3(0,0,side*0.8),0,duration,Vector3.ZERO,0.0,0.2)
	else:
		var kind := "branches" if family == "summoner" else "seal"
		art.layer(kind,look,Vector3(0,0.08,0),Vector3.ONE*1.25,Vector3.ZERO,0,duration,Vector3.ZERO,0.12,0.12)
	# Targeted sky attacks arrive at their actual release. No fake late impact.
	if String(skill.id) in ["meteor_arrow","last_judgement","holy_rain_big","divine_judgment","aria_of_ruin","grand_finale"]:
		var sky := _root(parent,aim,duration,"EliteSkyCharge")
		sky.owner_ref=art.owner_ref; sky.generation=art.generation
		sky.layer("seal",look,Vector3(0,6,0),Vector3.ONE*1.8,Vector3.ZERO,0,duration,Vector3.ZERO,0.2,0.12)
		if String(skill.id)=="meteor_arrow":
			sky.layer("spear",look,Vector3(0,3.8,0),Vector3(0.65,3.8,0.65),Vector3(PI,0,-0.18),0,duration,Vector3(-2,8,0),0.0,0.4,true)

static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, delay := 0.0) -> void:
	if not VfxBudget.can_decorate():
		return
	var id := String(skill.id)
	var look := palette(skill)
	var shape := String(skill.shape)
	var directed := id in ["grand_cross","sword_of_justice","divine_piercing","gladiator","dragon_lance","gungnir","ragnarok_lance","dragon_shot","lightning_arrow","seraphim_wrath","eclipse_fang","phantom_legion"]
	var at := origin if directed or shape in ["self","summon","burst"] else center
	if MartialSkillArt.handles(skill):
		at = center if shape=="blast" else origin
	var art := _root(parent,at,delay+1.65,"EliteSkill_"+id)
	var delta := center-origin
	if Vector2(delta.x,delta.z).length_squared()>0.001:
		art.rotation.y=atan2(delta.x,delta.z)
	var radius := maxf(2.0,float(skill.get("radius",3.0)))
	var d := maxf(delay,0.0)
	if MartialSkillArt.handles(skill):
		MartialSkillArt.play(art,skill,center,origin,d)
		art._draw()
		return
	# Silhouette first, flourish second. These layers replace the generic stack.
	match id:
		"grand_cross":
			for side in [-1.0,1.0]:
				art.layer("sword",look,Vector3(side*1.25,0.1,2),Vector3(0.9,3.7,0.9),Vector3(0,0,side*0.8),d,0.95,Vector3.ZERO,0.0,0.65,false,{"turn":Vector3(0,0,-side*0.45)})
			for side in [-1.0,1.0]:
				art.layer("cut",look,Vector3(0,1.4,2),Vector3(2.8,2.8,2.8),Vector3(0,0,side*0.8),d,0.85,Vector3(0,0,0.65))
			art.layer("fractures",look,Vector3(0,0.06,2.5),Vector3.ONE*3,Vector3.ZERO,d,1.3)
		"sword_of_justice","gladiator":
			var ultimate := id=="gladiator"
			art.layer("sword",look,Vector3(0,0.5,2.7),Vector3(2.8 if ultimate else 2.1,5.4 if ultimate else 4.2,1.8),Vector3(0,0,0.2),d,0.65,Vector3(0,1,0),0,0.8,true,{"turn":Vector3(0,0,-0.35)})
			art.layer("cut",look,Vector3(0,1.7,2),Vector3.ONE*(4.3 if ultimate else 3.2),Vector3(0,0,-0.3),d,0.8,Vector3(0,0,0.9))
			art.layer("fractures",look,Vector3(0,0.09,delta.length()),Vector3.ONE*2.6,Vector3.ZERO,d,1.4)
			if ultimate:
				art.layer("crown",look,Vector3(0,0.1,delta.length()),Vector3.ONE*2.3,Vector3.ZERO,d,1.1)
		"divine_piercing","dragon_lance","gungnir","ragnarok_lance":
			var ultimate := id=="ragnarok_lance"
			var length := float(skill.get("pierce",{}).get("len",15.0)) if id in ["gungnir","ragnarok_lance"] else maxf(4.0,delta.length())
			art.layer("sword" if id=="divine_piercing" else "spear",look,Vector3(0,1.25,0.5),Vector3(2.5 if ultimate else 1.65,length,2.0 if ultimate else 1.4),Vector3(PI*0.5,0,0),d,0.75,Vector3(0,0,0.4),0,0.75)
			art.layer("lane",look,Vector3(0,0.1,0),Vector3(1.3,length/10.0,length/10.0),Vector3.ZERO,d,1.25)
			if id=="dragon_lance":
				art.layer("dragon",look,Vector3(0,1.1,2),Vector3.ONE*1.6,Vector3.ZERO,d,0.9,Vector3(0,0,2))
			else:
				art.layer("seal",look,Vector3(0,1.3,1),Vector3.ONE*(2.4 if ultimate else 1.5),Vector3(PI/2,0,0),d,0.95,Vector3.ZERO,0.4)
			if ultimate:
				art.layer("wings",look,Vector3(0,1.4,1.5),Vector3.ONE*1.65,Vector3.ZERO,d,1.1)
		"gale_cyclone","heaven_rend":
			art.layer("helix",look,Vector3.ZERO,Vector3(radius*0.7,3.5,radius*0.7),Vector3.ZERO,d,1.35,Vector3.ZERO,2.0)
			art.layer("spears",look,Vector3.ZERO,Vector3(radius*0.85,3.2,radius*0.85),Vector3.ZERO,d,1.0,Vector3.ZERO,0.6)
			art.layer("fractures" if id=="heaven_rend" else "feathers",look,Vector3(0,0.1,0),Vector3.ONE*radius*0.8,Vector3.ZERO,d,1.5,Vector3.UP*0.5)
		"tempest","phoenix_rain":
			art.layer("rain",look,Vector3.ZERO,Vector3(radius*0.8,6,radius*0.8),Vector3.ZERO,d,0.8,Vector3.UP*2.4,0,1.0,true)
			art.layer("seal",look,Vector3(0,0.1,0),Vector3.ONE*radius*0.8,Vector3.ZERO,d,1.2,Vector3.ZERO,0.15)
			art.layer("phoenix" if id=="phoenix_rain" else "helix",look,Vector3(0,2.5,0),Vector3.ONE*(3.2 if id=="phoenix_rain" else radius*0.55),Vector3.ZERO,d,1.45,Vector3.UP*0.6,0.15)
		"lightning_arrow":
			art.layer("bow",look,Vector3(0,1.5,0.6),Vector3.ONE*2,Vector3.ZERO,d,0.7)
			art.layer("lightning",look,Vector3(0,1.4,1),Vector3(0.7,0.7,maxf(delta.length(),4.0)),Vector3.ZERO,d,0.7)
			art.layer("seal",look,Vector3(0,1.4,0.8),Vector3.ONE*1.5,Vector3(PI/2,0,0),d,1.0,Vector3.ZERO,0.5)
		"dragon_shot":
			art.layer("dragon",look,Vector3(0,1.4,2),Vector3.ONE*2.8,Vector3.ZERO,d,1.2,Vector3(0,0,3))
			art.layer("bow",look,Vector3(0,1.5,0.8),Vector3.ONE*2.0,Vector3.ZERO,d,0.7)
			art.layer("feathers",look,Vector3(0,1,2),Vector3(3,2,3),Vector3.ZERO,d,1.3,Vector3(0,0,2),0.3)
		"meteor_arrow":
			art.layer("spear",look,Vector3(0,4.7,0),Vector3(0.8,4.7,0.8),Vector3(PI,0,-0.18),d,0.7)
			art.layer("comet",look,Vector3(0,0.7,0),Vector3(1.2,3.5,1.2),Vector3(0,0,0.18),d,1.05)
			art.layer("fractures",look,Vector3(0,0.06,0),Vector3.ONE*2.2,Vector3.ZERO,d,1.4)
		"hell_meteor":
			art.layer("comet",look,Vector3(0,0.6,0),Vector3(2.3,4.5,2.3),Vector3(0,0,0.2),d,1.15)
			art.layer("crystals",look,Vector3(0,0.05,0),Vector3(radius*0.65,2,radius*0.65),Vector3.ZERO,d,1.5)
			art.layer("fractures",look,Vector3(0,0.09,0),Vector3.ONE*radius*0.9,Vector3.ZERO,d,1.5)
		"ice_storm":
			art.layer("crystals",look,Vector3.ZERO,Vector3(radius*0.86,5.3,radius*0.86),Vector3.ZERO,d,1.45,Vector3.ZERO,0,0.15)
			art.layer("snowflake",look,Vector3(0,0.09,0),Vector3.ONE*radius*0.92,Vector3.ZERO,d,1.5)
			art.layer("feathers",look,Vector3(0,2.8,0),Vector3(radius*0.8,1.8,radius*0.8),Vector3.ZERO,d,1.5,Vector3.UP*1.6,0.6,0.65,true)
		"spirit_burst":
			for tilt in [Vector3.ZERO,Vector3(0.55,0,0.5),Vector3(-0.55,0,-0.5)]:
				art.layer("astrolabe",look,Vector3(0,2,0),Vector3.ONE*radius*0.55,tilt,d,1.4,Vector3.ZERO,0.5)
			art.layer("stars",look,Vector3(0,1.5,0),Vector3.ONE*radius*0.8,Vector3.ZERO,d,1.5,Vector3.UP*0.4)
		"divine_judgment","holy_rain_big","last_judgement":
			var ultimate := id=="last_judgement"
			art.layer("cathedral",look,Vector3.ZERO,Vector3(radius*0.65,6.8 if ultimate else 4.8,radius*0.65),Vector3.ZERO,d,1.5)
			art.layer("seal",look,Vector3(0,0.08,0),Vector3.ONE*radius*0.9,Vector3.ZERO,d,1.5,Vector3.ZERO,0.25)
			art.layer("rain" if id=="holy_rain_big" else "pillars",look,Vector3.ZERO,Vector3(radius*0.6,5.6,radius*0.6),Vector3.ZERO,d,0.85,Vector3.UP*1.3,0,1,true)
			art.layer("feathers",look,Vector3(0,1.2,0),Vector3(radius*0.65,2,radius*0.65),Vector3.ZERO,d,1.65,Vector3.UP*2.2,0.35,0.65,true)
			if ultimate:
				art.layer("wings",look,Vector3(0,6.8,0),Vector3.ONE*3.2,Vector3.ZERO,d,1.4)
				art.layer("seal",look,Vector3(0,6.8,0),Vector3.ONE*radius*0.6,Vector3.ZERO,d,1.4,Vector3.ZERO,-0.1)
		"seraphim_wrath":
			art.layer("wings",look,Vector3(0,2.1,0.5),Vector3.ONE*2.6,Vector3.ZERO,d,1.25,Vector3.ZERO,0.0,0.65,false,{"flap":0.08})
			art.layer("sword",look,Vector3(0,1.4,1),Vector3(1,7,1),Vector3(PI/2,0,0),d,0.8,Vector3(0,0,1.5),0.0,0.65,false,{"turn":Vector3(0,0,1.2)})
			art.layer("feathers",look,Vector3(0,3.4,1),Vector3(3,2,3),Vector3.ZERO,d,1.4,Vector3(0,2.0,2),0.4,0.65,true)
		"world_tree","cataclysm":
			art.layer("tree" if id=="world_tree" else "roots",look,Vector3.ZERO,Vector3(radius*0.7,6.8 if id=="world_tree" else 4,radius*0.7),Vector3.ZERO,d,1.6,Vector3.ZERO,0,0.12)
			art.layer("branches",look,Vector3(0,0.07,0),Vector3.ONE*radius*0.9,Vector3.ZERO,d,1.5)
			art.layer("leaves",look,Vector3(0,1.5,0),Vector3(radius*0.8,2,radius*0.8),Vector3.ZERO,d,1.65,Vector3.UP*1.2,0.35)
		"fairy_spirit":
			# A small gate of light, the fairy's wings rising from it and a lotus of healing underneath.
			art.layer("gate",look,Vector3(0,0.1,1),Vector3.ONE*1.8,Vector3.ZERO,d,1.4)
			art.layer("wings",look,Vector3(0,1.3,1.2),Vector3.ONE*1.3,Vector3.ZERO,d,1.2,Vector3(0,0.5,0.3))
			art.layer("lotus",look,Vector3(0,0.07,1),Vector3.ONE*2.4,Vector3.ZERO,d,1.5,Vector3.ZERO,-0.1)
			art.layer("feathers",look,Vector3(0,1.0,1),Vector3(1.6,2,1.6),Vector3.ZERO,d,1.6,Vector3.UP*0.8,0.2)
		"primal_legion","elder_dragon":
			var elder := id=="elder_dragon"
			art.layer("gate",look,Vector3(0,0.1,1),Vector3.ONE*(3 if elder else 2.2),Vector3.ZERO,d,1.4)
			art.layer("dragon" if id!="primal_legion" else "beasts",look,Vector3(0,1.7,1.4),Vector3.ONE*(2.9 if elder else 1.9),Vector3.ZERO,d,1.1,Vector3(0,0.2,0.6))
			art.layer("seal",look,Vector3(0,0.08,1),Vector3.ONE*(4 if elder else 3),Vector3.ZERO,d,1.55,Vector3.ZERO,-0.1)
			if elder:
				art.layer("crown",look,Vector3(0,4.5,1),Vector3.ONE*2,Vector3.ZERO,d,1.4)
		"holy_rampart":
			# The wall of light rises from the ground around the Defender, an aegis dome closes over it and the floor caves in.
			art.layer("rampart",look,Vector3.ZERO,Vector3(radius*0.62,3.0,radius*0.62),Vector3.ZERO,d,1.5,Vector3.ZERO,0.0,1.0,false,{"drop":-3.2,"land":0.18,"decay":0.6})
			art.layer("crater_ring",look,Vector3(0,0.06,0),Vector3.ONE*radius*0.9,Vector3.ZERO,d,1.5,Vector3.ZERO,0.0,0.3)
			art.layer("aegis",look,Vector3.ZERO,Vector3.ONE*radius*0.8,Vector3.ZERO,d+0.05,1.45,Vector3.ZERO,0.15,0.6,false,{"fade_in":0.12,"decay":0.55})
			art.layer("pillars",look,Vector3.ZERO,Vector3(radius*0.7,4.5,radius*0.7),Vector3.ZERO,d,1.0,Vector3.UP*0.8,0.0,0.0)
			art.layer("shield_outline",look,Vector3(0,0.1,0),Vector3.ONE*radius*1.4,Vector3.ZERO,d,0.9,Vector3.ZERO,0.0,0.2)
			art.layer("stars",look,Vector3(0,1,0),Vector3(radius*0.8,3,radius*0.8),Vector3.ZERO,d,1.6,Vector3.UP*1.2)
		"judgment_shield":
			# The great shield falls face-down from the sky onto the victim; the seal of judgment hangs over the crater.
			var reach := maxf(2.0,delta.length())
			art.layer("greatshield",look,Vector3(0,0.9,reach),Vector3(2.3,2.6,2.3),Vector3(PI/2,0,0),d,1.3,Vector3.ZERO,0.0,1.0,false,{"drop":4.0,"land":0.17,"decay":0.6})
			art.layer("crater_ring",look,Vector3(0,0.07,reach),Vector3.ONE*3.2,Vector3.ZERO,d+0.15,1.3,Vector3.ZERO,0.0,0.25)
			art.layer("seal",look,Vector3(0,2.8,reach),Vector3.ONE*2.4,Vector3.ZERO,d,1.2,Vector3.ZERO,0.8,0.5,false,{"fade_in":0.1})
			art.layer("shield_outline",look,Vector3(0,0.1,reach),Vector3.ONE*3.8,Vector3.ZERO,d+0.15,0.9,Vector3.ZERO,0.0,0.3)
			art.layer("stars",look,Vector3(0,0.5,reach),Vector3(2.2,2.5,2.2),Vector3.ZERO,d+0.15,1.3,Vector3.UP*1.0)
		"aegis_of_ages":
			# A white and blue aegis grows out of the raised shield over the caster, ringed by a rampart.
			art.layer("aegis",look,Vector3(0,0.05,0),Vector3.ONE*3.4,Vector3.ZERO,d,1.6,Vector3.ZERO,0.2,0.2,false,{"decay":0.6})
			art.layer("rampart",look,Vector3.ZERO,Vector3(2.5,1.9,2.5),Vector3.ZERO,d,1.5,Vector3.ZERO,0.0,1.0,false,{"drop":-2.0,"land":0.18})
			art.layer("greatshield",look,Vector3(0,1.5,0.8),Vector3.ONE*1.6,Vector3.ZERO,d,1.0,Vector3(0,0.7,0),0.0,0.5,false,{"face_camera":true})
			art.layer("seal",look,Vector3(0,0.07,0),Vector3.ONE*3.0,Vector3.ZERO,d,1.5,Vector3.ZERO,-0.3)
			art.layer("stars",look,Vector3(0,0.3,0),Vector3(2.6,3,2.6),Vector3.ZERO,d,1.65,Vector3.UP*1.2)
		"meteor_shield":
			# The Defender's shield comes down like a comet; the crater opens and a rampart bursts up at the landing.
			art.layer("greatshield",look,Vector3(0,1.5,0),Vector3.ONE*2.4,Vector3(0.25,0,0),d,1.0,Vector3.ZERO,0.0,1.0,false,{"drop":4.5,"land":0.12,"decay":0.55,"front":2,"face_camera":true})
			art.layer("comet",look,Vector3(0,1.0,0),Vector3(2.4,4.6,2.4),Vector3(0,0,0.15),d,1.0,Vector3.ZERO,0.0,1.0,false,{"drop":4.5,"land":0.12,"decay":0.45})
			art.layer("crater_ring",look,Vector3(0,0.08,0),Vector3.ONE*radius*0.9,Vector3.ZERO,d+0.1,1.5,Vector3.ZERO,0.0,0.2)
			art.layer("rampart",look,Vector3.ZERO,Vector3(radius*0.6,2.6,radius*0.6),Vector3.ZERO,d+0.1,1.25,Vector3.ZERO,0.0,1.0,false,{"drop":-2.8,"land":0.14,"decay":0.5})
			art.layer("shield_outline",look,Vector3(0,0.1,0),Vector3.ONE*radius*1.5,Vector3.ZERO,d+0.1,0.9,Vector3.ZERO,0.0,0.2)
			art.layer("stars",look,Vector3(0,0.6,0),Vector3(radius*0.7,3,radius*0.7),Vector3.ZERO,d+0.1,1.5,Vector3.UP*1.4)
		"sanctuary_wall":
			# A cathedral of gold with a rampart at its base, sealed under an aegis.
			art.layer("cathedral",look,Vector3.ZERO,Vector3(2.6,4.2,2.6),Vector3.ZERO,d,1.6,Vector3.ZERO,0.0,0.25)
			art.layer("rampart",look,Vector3.ZERO,Vector3(2.2,2.0,2.2),Vector3.ZERO,d,1.5,Vector3.ZERO,0.0,1.0,false,{"drop":-2.1,"land":0.18})
			art.layer("aegis",look,Vector3.ZERO,Vector3.ONE*3.2,Vector3.ZERO,d+0.05,1.5,Vector3.ZERO,0.1,0.5,false,{"fade_in":0.12,"decay":0.55})
			art.layer("seal",look,Vector3(0,0.07,0),Vector3.ONE*2.9,Vector3.ZERO,d,1.5,Vector3.ZERO,-0.3)
			art.layer("stars",look,Vector3(0,0.3,0),Vector3(2.4,2.5,2.4),Vector3.ZERO,d,1.65,Vector3.UP*1.0)
		"world_bastion":
			# The shield is planted in the world: three rampart rings rise in turn, chains anchor the field and a crown settles.
			art.layer("greatshield",look,Vector3(0,2.6,0),Vector3.ONE*2.6,Vector3.ZERO,d,1.65,Vector3.ZERO,0.0,1.0,false,{"drop":-5.4,"land":0.2,"decay":0.65,"front":2,"face_camera":true})
			for i in 3:
				var f: float=[0.4,0.7,1.0][i]
				art.layer("rampart",look,Vector3.ZERO,Vector3(radius*f,2.2+i*0.7,radius*f),Vector3.ZERO,d+i*0.12,1.5-i*0.1,Vector3.ZERO,0.0,1.0,false,{"drop":-(2.4+i*0.7),"land":0.16,"decay":0.55})
			art.layer("chains",look,Vector3(0,0.12,0),Vector3.ONE*radius,Vector3.ZERO,d+0.2,1.4,Vector3.ZERO,0.0,0.2)
			art.layer("crown",look,Vector3(0,4.8,0),Vector3.ONE*2.4,Vector3.ZERO,d+0.15,1.45,Vector3.UP*0.6,0.4)
		"eclipse_fang":
			# Two dagger blades cross over the victim under a dark eclipse disc, the cuts tearing an X.
			var reach := maxf(2.0,delta.length())
			for side in [-1.0,1.0]:
				art.layer("sword",look,Vector3(side*0.7,1.1,reach-0.5),Vector3(0.6,2.3,0.6),Vector3(0,0,side*0.75),d,0.75,Vector3.ZERO,0.0,0.6,false,{"turn":Vector3(0,0,-side*0.7)})
				art.layer("cut",look,Vector3(0,1.3,reach),Vector3.ONE*2.7,Vector3(0,0,side*0.85),d+0.06*(side+1.0),0.75,Vector3(0,0,0.45))
			art.layer("seal",look,Vector3(0,1.5,reach+0.3),Vector3.ONE*2.1,Vector3(PI/2,0,0),d,1.05,Vector3.ZERO,0.7,0.5)
			art.layer("fractures",look,Vector3(0,0.07,reach),Vector3.ONE*2.5,Vector3.ZERO,d,1.3)
		"abyss_vortex":
			# A spiral of night drags everything inward: a counter-turning helix, chains and a caved-in ring.
			art.layer("helix",look,Vector3.ZERO,Vector3(radius*0.75,3.8,radius*0.75),Vector3.ZERO,d,1.45,Vector3.ZERO,-2.4)
			art.layer("chains",look,Vector3(0,0.1,0),Vector3.ONE*radius*0.9,Vector3.ZERO,d,1.4,Vector3.ZERO,1.2,0.3)
			art.layer("crater_ring",look,Vector3(0,0.06,0),Vector3.ONE*radius*0.85,Vector3.ZERO,d,1.5,Vector3.ZERO,-0.6,0.3)
			art.layer("stars",look,Vector3(0,1.2,0),Vector3(radius*0.7,2.5,radius*0.7),Vector3.ZERO,d,1.5,Vector3.UP*0.8,1.5)
		"phantom_legion":
			# Shadow wings open behind the caster and a ring of phantom daggers flies out from them.
			art.layer("wings",look,Vector3(0,1.5,-0.5),Vector3.ONE*2.3,Vector3.ZERO,d,1.2,Vector3.ZERO,0.0,0.6,false,{"flap":0.08})
			art.layer("spears",look,Vector3(0,0.6,0),Vector3(4.2,1.0,4.2),Vector3.ZERO,d,0.9,Vector3.ZERO,0.0,0.12)
			art.layer("lane",look,Vector3(0,0.1,0),Vector3(1.2,0.9,0.9),Vector3.ZERO,d,1.1)
			art.layer("seal",look,Vector3(0,0.07,0),Vector3.ONE*2.6,Vector3.ZERO,d,1.3,Vector3.ZERO,-0.4)
		"midnight_execution":
			# A crescent drops out of the night sky onto the mark; the ground shatters in a ring of fractures.
			art.layer("cut",look,Vector3(0,1.8,0),Vector3.ONE*3.6,Vector3(0,0,0.25),d,0.85,Vector3(0,-1.2,0),0.0,0.6,false,{"drop":3.5,"land":0.14,"decay":0.5})
			art.layer("crater_ring",look,Vector3(0,0.07,0),Vector3.ONE*radius*0.85,Vector3.ZERO,d+0.12,1.4,Vector3.ZERO,0.0,0.25)
			art.layer("fractures",look,Vector3(0,0.09,0),Vector3.ONE*radius*0.9,Vector3.ZERO,d+0.12,1.5)
			art.layer("crown",look,Vector3(0,0.1,0),Vector3.ONE*radius*0.5,Vector3.ZERO,d+0.12,1.2,Vector3.UP*0.6,0.4)
		"oblivion_requiem":
			# The requiem: every blade of the night turns around the caster, under a seal and a crown of stars.
			art.layer("spears",look,Vector3.ZERO,Vector3(radius*0.85,3.0,radius*0.85),Vector3.ZERO,d,1.2,Vector3.ZERO,2.2,0.5)
			art.layer("helix",look,Vector3.ZERO,Vector3(radius*0.7,4.2,radius*0.7),Vector3.ZERO,d,1.5,Vector3.ZERO,2.6)
			art.layer("seal",look,Vector3(0,0.08,0),Vector3.ONE*radius*0.95,Vector3.ZERO,d,1.55,Vector3.ZERO,-0.35)
			art.layer("crater_ring",look,Vector3(0,0.06,0),Vector3.ONE*radius*0.8,Vector3.ZERO,d+0.1,1.4,Vector3.ZERO,0.0,0.25)
			art.layer("wings",look,Vector3(0,2.2,0),Vector3.ONE*3.0,Vector3.ZERO,d,1.4,Vector3.ZERO,0.0,0.6,false,{"flap":0.1})
			art.layer("stars",look,Vector3(0,1.0,0),Vector3(radius*0.8,3,radius*0.8),Vector3.ZERO,d,1.6,Vector3.UP*1.4)
		"infernal_scream":
			# Hell's roar: a ring of fire climbs round the Lord over a cracked crater.
			art.layer("helix",look,Vector3.ZERO,Vector3(radius*0.7,3.4,radius*0.7),Vector3.ZERO,d,1.3,Vector3.ZERO,2.0)
			art.layer("crater_ring",look,Vector3(0,0.06,0),Vector3.ONE*radius*0.85,Vector3.ZERO,d,1.4,Vector3.ZERO,0.0,0.25)
			art.layer("fractures",look,Vector3(0,0.08,0),Vector3.ONE*radius*0.9,Vector3.ZERO,d,1.5)
			art.layer("stars",look,Vector3(0,1.0,0),Vector3(radius*0.7,3,radius*0.7),Vector3.ZERO,d,1.5,Vector3.UP*1.2)
		"chaos_sovereign":
			# The scepter of chaos comes down on one foe: a dark seal over it, the ground torn under it.
			var reach := maxf(2.0,delta.length())
			art.layer("sword",look,Vector3(0,2.2,reach-0.3),Vector3(0.8,2.8,0.8),Vector3(0.6,0,0),d,0.7,Vector3(0,-1.2,0.3),0.0,0.6)
			art.layer("seal",look,Vector3(0,1.5,reach+0.3),Vector3.ONE*2.2,Vector3(PI/2,0,0),d,1.05,Vector3.ZERO,0.7,0.5)
			art.layer("fractures",look,Vector3(0,0.07,reach),Vector3.ONE*2.6,Vector3.ZERO,d,1.3)
		"raven_storm":
			# Wings open behind the Lord and a storm of raven shadows flies out round him.
			art.layer("wings",look,Vector3(0,1.5,-0.5),Vector3.ONE*2.4,Vector3.ZERO,d,1.2,Vector3.ZERO,0.0,0.6,false,{"flap":0.1})
			art.layer("feathers",look,Vector3(0,1.0,0),Vector3(4.0,2.0,4.0),Vector3.ZERO,d,1.1,Vector3.UP*0.6,1.6)
			art.layer("seal",look,Vector3(0,0.07,0),Vector3.ONE*2.6,Vector3.ZERO,d,1.3,Vector3.ZERO,-0.4)
		"earth_dominion":
			# The earth obeys: a great crater, fault lines and pillars of rock and light round the Lord.
			art.layer("crater_ring",look,Vector3(0,0.06,0),Vector3.ONE*radius*0.9,Vector3.ZERO,d,1.5,Vector3.ZERO,0.0,0.25)
			art.layer("fractures",look,Vector3(0,0.08,0),Vector3.ONE*radius,Vector3.ZERO,d,1.6)
			art.layer("pillars",look,Vector3.ZERO,Vector3(radius*0.75,2.6,radius*0.75),Vector3.ZERO,d+0.08,1.3,Vector3.ZERO,0.0,0.3)
			art.layer("crown",look,Vector3(0,0.1,0),Vector3.ONE*radius*0.45,Vector3.ZERO,d+0.12,1.2,Vector3.UP*0.6,0.4)
		"imperial_judgment":
			# The emperor's verdict: a crown of light in the sky, columns, a great seal and lightning.
			art.layer("crown",look,Vector3(0,5.0,0),Vector3.ONE*2.8,Vector3.ZERO,d,1.5,Vector3.UP*0.5,0.4)
			art.layer("pillars",look,Vector3.ZERO,Vector3(radius*0.8,3.4,radius*0.8),Vector3.ZERO,d,1.4,Vector3.ZERO,0.6,0.3)
			art.layer("seal",look,Vector3(0,0.08,0),Vector3.ONE*radius*0.95,Vector3.ZERO,d,1.55,Vector3.ZERO,-0.35)
			art.layer("lightning",look,Vector3(0,1.5,0),Vector3(radius*0.7,3,radius*0.7),Vector3.ZERO,d+0.05,0.9)
			art.layer("crater_ring",look,Vector3(0,0.06,0),Vector3.ONE*radius*0.8,Vector3.ZERO,d+0.1,1.4,Vector3.ZERO,0.0,0.25)
		"grand_dissonance":
			# The off-key staff: a cracked seal under the field, a tilted staff ring turning overhead, chains of sound.
			art.layer("seal",look,Vector3(0,0.08,0),Vector3.ONE*radius*0.95,Vector3.ZERO,d,1.5,Vector3.ZERO,-0.35)
			art.layer("fractures",look,Vector3(0,0.08,0),Vector3.ONE*radius*0.7,Vector3.ZERO,d,1.5)
			art.layer("stave",look,Vector3(0,2.6,0),Vector3(radius*0.45,1.6,radius*0.45),Vector3(0.12,0,-0.1),d,1.4,Vector3.ZERO,0.8)
			art.layer("chains",look,Vector3(0,1,0),Vector3(radius*0.55,2,radius*0.55),Vector3.ZERO,d,1.3,Vector3.ZERO,0.4)
			art.layer("stars",look,Vector3(0,1.0,0),Vector3(radius*0.7,3,radius*0.7),Vector3.ZERO,d,1.5,Vector3.UP*1.2)
			art.layer("crater_ring",look,Vector3(0,0.06,0),Vector3.ONE*radius*0.55,Vector3.ZERO,d+0.1,1.3,Vector3.ZERO,0.0,0.25)
		"aria_of_ruin":
			# The aria's column: a helix of light on the foe, a seal, pillars, a turning staff and rising stars.
			art.layer("helix",look,Vector3.ZERO,Vector3(1.3,5.5,1.3),Vector3.ZERO,d,1.2,Vector3.ZERO,2.6)
			art.layer("seal",look,Vector3(0,0.08,0),Vector3.ONE*2.8,Vector3.ZERO,d,1.3,Vector3.ZERO,0.5)
			art.layer("pillars",look,Vector3.ZERO,Vector3(2,4,2),Vector3.ZERO,d,1.1,Vector3.ZERO,0.4,0.3)
			art.layer("stave",look,Vector3(0,3.2,0),Vector3.ONE*1.2,Vector3.ZERO,d,1.3,Vector3.ZERO,1.2)
			art.layer("stars",look,Vector3(0,1.0,0),Vector3(2,3,2),Vector3.ZERO,d,1.4,Vector3.UP*1.4)
			art.layer("crater_ring",look,Vector3(0,0.06,0),Vector3.ONE*2.4,Vector3.ZERO,d,1.2,Vector3.ZERO,0.0,0.25)
		"eternal_echo":
			# The echo that never ends: a staff ring round the first foe, a spiral of light, a seal, stars.
			art.layer("stave",look,Vector3(0,1,0),Vector3.ONE*1.4,Vector3.ZERO,d,1.3,Vector3.ZERO,1.6)
			art.layer("helix",look,Vector3.ZERO,Vector3(1.2,3.6,1.2),Vector3.ZERO,d,1.2,Vector3.ZERO,3.0)
			art.layer("seal",look,Vector3(0,0.08,0),Vector3.ONE*2.4,Vector3.ZERO,d,1.3,Vector3.ZERO,-0.5)
			art.layer("stars",look,Vector3(0,1.0,0),Vector3(2.2,3,2.2),Vector3.ZERO,d,1.4,Vector3.UP*1.0)
		"thunder_crescendo":
			# The sky drum: a crater round the Bard, lightning, a seal and a staff of thunder over him.
			# A burst rings the caster, so its near side runs under the camera: the solid pieces stay close in.
			art.layer("crater_ring",look,Vector3(0,0.06,0),Vector3.ONE*radius*0.4,Vector3.ZERO,d,1.4,Vector3.ZERO,0.0,0.25)
			art.layer("lightning",look,Vector3(0,1.5,0),Vector3(radius*0.7,3,radius*0.7),Vector3.ZERO,d+0.05,0.9)
			art.layer("seal",look,Vector3(0,0.08,0),Vector3.ONE*radius*0.95,Vector3.ZERO,d,1.5,Vector3.ZERO,-0.35)
			art.layer("stave",look,Vector3(0,3.4,0),Vector3(radius*0.4,1.6,radius*0.4),Vector3.ZERO,d,1.3,Vector3.ZERO,1.4)
			art.layer("fractures",look,Vector3(0,0.08,0),Vector3.ONE*radius*0.45,Vector3.ZERO,d,1.5)
		"grand_finale":
			# The finale's hall: a cathedral of light over the stage, pillars, a staff in the sky, a crater,
			# rising stars and the crackle of fireworks.
			art.layer("cathedral",look,Vector3(0,0.1,0),Vector3(radius*0.45,radius*0.55,radius*0.45),Vector3.ZERO,d,1.6,Vector3.ZERO,0.0,0.25)
			art.layer("pillars",look,Vector3.ZERO,Vector3(radius*0.8,3.6,radius*0.8),Vector3.ZERO,d,1.4,Vector3.ZERO,0.5,0.3)
			art.layer("stave",look,Vector3(0,4.0,0),Vector3(radius*0.5,1.8,radius*0.5),Vector3.ZERO,d,1.5,Vector3.ZERO,1.0)
			art.layer("crater_ring",look,Vector3(0,0.06,0),Vector3.ONE*radius*0.55,Vector3.ZERO,d+0.05,1.4,Vector3.ZERO,0.0,0.25)
			art.layer("stars",look,Vector3(0,1.0,0),Vector3(radius*0.8,3.5,radius*0.8),Vector3.ZERO,d,1.6,Vector3.UP*1.6)
			art.layer("lightning",look,Vector3(0,1.5,0),Vector3(radius*0.6,3,radius*0.6),Vector3.ZERO,d+0.08,0.9)
		_:
			# Lasting support skills: each uses its own batched relief.
			var shapes := {"godly_shield":"bastion","triumph_of_valhalla":"banners","spirit_of_wind":"helix","magic_overdrive":"astrolabe","prayer":"lotus","miracle":"cathedral","gaia_blessing":"tree","valkyrie_blessing":"wings","shadow_sovereign":"wings","emperors_command":"banners","hymn_of_legends":"stave"}
			var kind: String = shapes.get(id,"seal")
			art.layer(kind,look,Vector3(0,0.15,0),Vector3(2.4,3.8 if kind=="cathedral" else 2.4,2.4),Vector3.ZERO,d,1.55,Vector3.ZERO,0.15 if kind in ["helix","astrolabe","stave"] else 0,0.25)
			art.layer("lotus" if id in ["prayer","gaia_blessing"] else "seal",look,Vector3(0,0.07,0),Vector3.ONE*2.7,Vector3.ZERO,d,1.5,Vector3.ZERO,-0.3)
			art.layer("leaves" if id=="gaia_blessing" else "stars",look,Vector3(0,0.3,0),Vector3(2,2.5,2),Vector3.ZERO,d,1.65,Vector3.UP*1.0)
	art._draw()

func layer(kind: String, look: Dictionary, at: Vector3, size: Vector3, angles := Vector3.ZERO, start := 0.0, seconds := 1.2, travel := Vector3.ZERO, spin := 0.0, initial := 0.65, reverse := false, style := {}) -> void:
	if layers.size() >= [2, 4, 6][VfxBudget.quality()] or not VfxBudget.can_decorate():
		return
	var node := MeshInstance3D.new()
	node.name = kind.capitalize()
	node.mesh = MartialGeometry.mesh(kind.trim_prefix("martial/")) if kind.begins_with("martial/") else geometry(kind)
	# Only the material this layer draws with is built (the comet's flame wins
	# over a martial brush, which wins over the elite relief).
	if kind == "comet":
		var flame := ShaderMaterial.new()
		flame.shader = MeteorArt.FLAME_SHADER
		flame.set_shader_parameter("ember", Color("cd3c26"))
		flame.set_shader_parameter("gold", Color("ffd173"))
		node.material_override = flame
	elif bool(style.get("martial",false)):
		var mat := ShaderMaterial.new()
		mat.shader=MartialSkillArt.SHADER
		for key in ["primary","accent","shade"]: mat.set_shader_parameter(key,look[key])
		mat.set_shader_parameter("opacity",float(style.get("opacity",0.95)))
		node.material_override=mat
	else:
		node.material_override = material(look)
	if kind in ["tree", "roots", "leaves"]:
		(node.material_override as ShaderMaterial).set_shader_parameter("opacity", 0.68)
	# Hero silhouettes draw after the translucent ground rings around them, which
	# would otherwise paint over the plate (every layer is depth_draw_never).
	if kind in ["greatshield","comet"] or style.has("front"):
		node.material_override.render_priority=int(style.get("front",1))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	VfxBudget.track_decoration(node)
	node.visible=false
	layers.append({"node":node,"at":at,"size":size,"angles":angles,"start":start,"seconds":seconds,"travel":travel,"spin":spin,"initial":initial,"reverse":reverse,"style":style,"kind":kind})
	lifetime=maxf(lifetime,start+seconds+0.02)

func _process(delta: float) -> void:
	if owner_ref:
		var owner_visual := owner_ref.get_ref() as HeroVisual
		if not is_instance_valid(owner_visual) or owner_visual.skill_generation!=generation:
			queue_free()
			return
	age+=delta
	_draw()
	if age>=lifetime:
		queue_free()

func _draw() -> void:
	for data in layers:
		var node: MeshInstance3D = data.node
		var t := clampf((age-float(data.start))/float(data.seconds),0,1)
		node.visible=age>=float(data.start) and t<1
		var rise := 1.0-pow(1.0-minf(t*3.0,1.0),3.0)
		node.scale = data.size*maxf(0.005,lerpf(float(data.initial),1.0,rise))
		var style: Dictionary=data.get("style",{})
		node.rotation=data.angles+Vector3.UP*t*float(data.spin)
		node.rotation+=(style.get("turn",Vector3.ZERO) as Vector3)*smoothstep(0.0,0.65,t)
		node.rotation.z+=sin(t*TAU)*float(style.get("flap",0))
		if bool(style.get("face_camera",false)) and is_inside_tree():
			# A planted shield turns its face to the gameplay camera, like the star emblems.
			var camera := get_viewport().get_camera_3d()
			if camera:
				var toward := global_basis.inverse()*(camera.global_position-node.global_position)
				node.rotation.y=atan2(toward.x,toward.z)
		node.position=data.at+(data.travel as Vector3)*(1.0-smoothstep(0.0,1.0,t) if bool(data.reverse) else t)
		if style.has("drop"):
			node.position.y+=float(style.drop)*(1.0-smoothstep(0.0,maxf(0.01,float(style.land)),age-float(data.start)))
		var mat := node.material_override as ShaderMaterial
		if String(data.get("kind",""))=="martial/champion":
			mat.set_shader_parameter("morph",smoothstep(0.0,0.18,age-float(data.start)) if bool(style.get("strike",false)) else 0.0)
		mat.set_shader_parameter("age",age)
		var fade := 1.0-smoothstep(minf(float(style.get("decay",0.48)),0.98),1.0,t)
		if style.has("fade_in"): fade*=smoothstep(0.0,float(style.fade_in),t)
		mat.set_shader_parameter("fade",fade)

static func _append(st: SurfaceTool, mesh: Mesh, at: Vector3, scale_v: Vector3, angles := Vector3.ZERO, gold := 0.0) -> void:
	BuffArt._append_tinted(st,mesh,Transform3D(Basis.from_euler(angles)*Basis.from_scale(scale_v),at),gold)

static func _line(st: SurfaceTool, points: PackedVector3Array, width: float, gold := 0.7) -> void:
	_append(st,SpellSpectacle._tube_mesh(points,width),Vector3.ZERO,Vector3.ONE,Vector3.ZERO,gold)

static func _ring(st: SurfaceTool, radius: float, height: float, width: float, gold := 0.7, segments := 64) -> void:
	var pts := PackedVector3Array()
	for i in segments+1:
		var a := TAU*float(i)/segments
		pts.append(Vector3(sin(a)*radius,height,cos(a)*radius))
	_line(st,pts,width,gold)

static func _feather(st: SurfaceTool, at: Vector3, size: Vector3, angles: Vector3, gold := 0.0) -> void:
	_append(st,BuffArt._grove_leaf_mesh(),at,size,angles,gold)

static func geometry(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	if kind == "comet":
		_meshes[kind] = MeteorArt._flame_mesh()
		return _meshes[kind]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"seal","astrolabe","snowflake":
			for r in [0.68,0.89,1.0]:
				_ring(st,r,0,0.006 if r!=1.0 else 0.012)
			for i in 12:
				var a := TAU*i/12.0
				var radial := Vector3(sin(a),0,cos(a))
				var side := Vector3(cos(a),0,-sin(a))
				var pos := radial*0.79
				_line(st,PackedVector3Array([pos-side*0.028,pos+radial*0.06,pos+side*0.028,pos-radial*0.06,pos-side*0.028]),0.007)
				if i%2==0:
					_line(st,PackedVector3Array([radial*0.22,radial*0.62,radial*0.55+side*0.14,radial*0.62,radial*0.55-side*0.14]),0.014,0.4)
				if kind=="astrolabe":
					_append(st,SpellSpectacle._crystal_mesh(),radial*0.98,Vector3(0.08,0.16,0.08),Vector3.ZERO,0.8)
				if kind=="snowflake":
					_line(st,PackedVector3Array([radial*0.64+side*0.15,radial*0.76,radial*0.64-side*0.15]),0.018,1)
		"sword","spear":
			# Sculpted pommel, guard, blade bevel, inlaid fuller, twin spear barbs.
			_append(st,SpellSpectacle._blade_mesh(false),Vector3(0,0.38,0),Vector3(0.85 if kind=="spear" else 0.5,0.55,0.3),Vector3.ZERO,0.12)
			_line(st,PackedVector3Array([Vector3(0,0,0),Vector3(0,0.55,0)]),0.055,0.4)
			_line(st,PackedVector3Array([Vector3(-0.34,0.26,0),Vector3(-0.12,0.32,0.025),Vector3(0,0.28,0.04),Vector3(0.12,0.32,0.025),Vector3(0.34,0.26,0)]),0.025,1)
			_append(st,SpellSpectacle._crystal_mesh(),Vector3(0,0.31,0),Vector3(0.10,0.12,0.07),Vector3.ZERO,1)
			_line(st,PackedVector3Array([Vector3(0,0.4,0.031),Vector3(0,0.88,0.018)]),0.008,1)
			if kind=="spear":
				for sign in [-1.0,1.0]:
					_append(st,SpellSpectacle._crystal_mesh(),Vector3(sign*0.32,0.53,0),Vector3(0.14,0.23,0.075),Vector3(0,0,-sign*0.38),0.6)
		"cut":
			for i in 40:
				var t := float(i)/40
				var u := float(i+1)/40
				var a := -1.25+t*2.5
				var b := -1.25+u*2.5
				var p := Vector3(sin(a),cos(a),0)
				var q := Vector3(sin(b),cos(b),0)
				var w := sin(t*PI)*0.25
				var v := sin(u*PI)*0.25
				st.set_color(Color(0.1,1,0)); SpellSpectacle._tri(st,p,q,q*(1-v)); SpellSpectacle._tri(st,p,q*(1-v),p*(1-w))
			var pts := PackedVector3Array()
			for i in 41:
				var a := -1.25+float(i)/40*2.5
				pts.append(Vector3(sin(a),cos(a),0.006))
			_line(st,pts,0.014,1)
		"wings","phoenix","bow":
			for side in [-1.0,1.0]:
				_line(st,PackedVector3Array([Vector3(0,0.2,0),Vector3(side*0.7,0.8,0),Vector3(side*1.4,1.15,0)]),0.035,1)
				for i in 9:
					var f := float(i)/8
					_feather(st,Vector3(side*(0.18+f*1.15),0.2+f*0.75,0),Vector3(0.46,0.9-f*0.15,0.4),Vector3(0,0,side*(0.65+f*0.55)),0.08+float(i%3)*0.18)
			if kind=="phoenix":
				_append(st,SpellSpectacle._crystal_mesh(),Vector3(0,0.15,0.12),Vector3(0.24,0.7,0.2),Vector3.ZERO,0.7)
				for i in 5:
					_feather(st,Vector3(0,0.1,0),Vector3(0.4,1.5,0.4),Vector3(0,0,PI+(i-2)*0.22),0.3)
		"dragon":
			var pts := PackedVector3Array([Vector3(0,-0.1,-1.2),Vector3(-0.22,0.05,-0.8),Vector3(0,0.35,-0.3),Vector3(0,0.3,0.25),Vector3(0,0.65,0.65)])
			_line(st,pts,0.19,0.1)
			_append(st,SpellSpectacle._sphere_mesh(),Vector3(0,0.62,0.85),Vector3(0.35,0.32,0.45),Vector3.ZERO,0.15)
			_append(st,SpellSpectacle._crystal_mesh(),Vector3(0,0.63,1.16),Vector3(0.22,0.14,0.28),Vector3(PI/2,0,0),0.7)
			for side in [-1.0,1.0]:
				_append(st,SpellSpectacle._crystal_mesh(),Vector3(side*0.25,0.96,0.68),Vector3(0.06,0.27,0.06),Vector3(-0.35,0,side*0.25),1)
				for i in 7:
					var f := float(i)/6
					_feather(st,Vector3(side*(0.2+f*0.9),0.38+f*0.35,-0.15),Vector3(0.58,0.95,0.5),Vector3(0.3,0,side*(0.7+f*0.6)),0.12+f*0.6)
				_append(st,SpellSpectacle._sphere_mesh(),Vector3(side*0.28,0.72,0.99),Vector3.ONE*0.05,Vector3.ZERO,1)
			for i in 5:
				_append(st,SpellSpectacle._crystal_mesh(),Vector3(0,0.57,-0.6+i*0.25),Vector3(0.08,0.17,0.1),Vector3.ZERO,0.85)
		"tree","roots","branches":
			if kind=="tree":
				_line(st,PackedVector3Array([Vector3.ZERO,Vector3(-0.07,0.35,0),Vector3(0.03,0.68,0),Vector3(0,0.94,0)]),0.055,0.35)
			for i in 8:
				var a := TAU*i/8.0
				var r := Vector3(sin(a),0,cos(a))
				var top := 0.68+float(i%3)*0.12
				var pts := PackedVector3Array([Vector3(0,0.1,0),r*0.25+Vector3.UP*0.08,r*0.65+Vector3.UP*(top if kind!="branches" else 0.02),r*0.95+Vector3.UP*(top-0.15 if kind!="branches" else 0.04)])
				_line(st,pts,0.025 if kind=="branches" else 0.045,0.5)
				for j in 4:
					var at := r*(0.4+j*0.14)+Vector3.UP*(top+0.03*(j%2) if kind=="tree" else 0.1+j*0.16 if kind=="roots" else 0.02)
					_feather(st,at,Vector3(0.50,0.21,0.7) if kind=="tree" else Vector3(0.3,0.3,0.4),Vector3(0.5,a,(j%2*2-1)*0.6),0.12+j*0.12)
			if kind=="tree":
				_ring(st,0.27,1,0.008,1)
		"crystals","spears","pillars","rain":
			for i in 12:
				var a := TAU*i/12.0
				var r := 0.45+float(i%3)*0.21
				var pos := Vector3(sin(a)*r,0,cos(a)*r)
				if kind=="crystals":
					_append(st,SpellSpectacle._crystal_mesh(),pos+Vector3.UP*(0.22+float(i%3)*0.06),Vector3(0.075,0.42+float(i%3)*0.12,0.085),Vector3(cos(a)*0.23,0,-sin(a)*0.23),float(i%3)*0.25)
				elif kind=="spears":
					_append(st,geometry("spear"),pos,Vector3(0.18,0.9,0.18),Vector3(0,0,-0.3),0.3)
				elif kind=="rain":
					_append(st,geometry("spear"),pos+Vector3.UP*(0.3+float(i%3)*0.15),Vector3(0.07,0.3,0.07),Vector3(PI,0,0.18),0.8)
				else:
					_append(st,SpellSpectacle._crystal_mesh(),pos+Vector3.UP*0.5,Vector3(0.06,1,0.06),Vector3.ZERO,0.8)
					_ring_at(st,pos,0.10,0.015)
		"helix":
			for lane in 3:
				var pts := PackedVector3Array()
				for i in 49:
					var t := float(i)/48
					var a := TAU*(t*1.25+lane/3.0)
					pts.append(Vector3(sin(a)*(1-t*0.2),t,cos(a)*(1-t*0.2)))
				_line(st,pts,0.022 if lane==0 else 0.012,float(lane)*0.3)
		"cathedral","gate","bastion","banners","crown":
			var count := 6 if kind!="gate" else 2
			for i in count:
				var a := TAU*i/count
				var r := Vector3(sin(a),0,cos(a))
				var side := Vector3(cos(a),0,-sin(a))
				if kind=="cathedral" or kind=="gate":
					_line(st,PackedVector3Array([r-side*0.18,r-side*0.18+Vector3.UP*0.7,r+Vector3.UP,r+side*0.18+Vector3.UP*0.7,r+side*0.18]),0.017,0.75)
					_append(st,SpellSpectacle._crystal_mesh(),r+Vector3.UP*0.84,Vector3(0.055,0.13,0.055),Vector3.ZERO,1)
				elif kind=="banners":
					_line(st,PackedVector3Array([r,r+Vector3.UP*1.15]),0.014,1)
					_feather(st,r+Vector3.UP*0.45,Vector3(0.6,0.55,0.1),Vector3(0,a,0.3),0.1)
				elif kind=="bastion":
					_append(st,SkillTableau.shield_mesh(),r+Vector3.UP*0.4,Vector3(0.33,0.65,0.24),Vector3(0,a,0),0.3)
					_append(st,geometry("sword"),r+Vector3.UP*0.1,Vector3(0.3,0.6,0.3),Vector3(0,a,0),0.85)
				else:
					_append(st,SpellSpectacle._crystal_mesh(),r+Vector3.UP*0.25,Vector3(0.12,0.5,0.12),Vector3.ZERO,0.7)
			_ring(st,1,0.05,0.02)
		"lotus":
			for i in 12:
				var a := TAU*i/12.0
				_feather(st,Vector3(sin(a),0,cos(a))*0.12,Vector3(0.7,1.0,0.5),Vector3(0.9,a,0),float(i%3)*0.22)
			_ring(st,0.8,0.05,0.013)
		"stars","feathers","leaves":
			for i in 24:
				var a := i*2.39996
				var r := 0.35+float(i%5)*0.13
				var pos := Vector3(sin(a)*r,float(i%7)/7,cos(a)*r)
				if kind=="stars":
					_append(st,SpellSpectacle._crystal_mesh(),pos,Vector3(0.018,0.075,0.018),Vector3.ZERO,1)
				elif kind=="feathers":
					# Bright accent vanes with a dark shade quill: no beige paper.
					_feather(st,pos,Vector3(0.18,0.13,0.18),Vector3(0.6,a,0.8),0.1+float(i%3)*0.15)
					_append(st,SpellSpectacle._crystal_mesh(),pos+Vector3(0,0.02,0),Vector3(0.012,0.09,0.012),Vector3(0.6,a,0.8),1.0)
				else:
					_feather(st,pos,Vector3(0.18,0.13,0.18),Vector3(0.6,a,0.8),float(i%3)*0.3)
		"fractures","lane":
			for i in 10:
				var a := TAU*i/10.0
				var r := Vector3(sin(a),0,cos(a))
				var side := Vector3(cos(a),0,-sin(a))
				var pts := PackedVector3Array([r*0.15,r*0.45+side*0.08,r*0.67-side*0.1,r*(0.8+float(i%3)*0.09)])
				if kind=="lane":
					pts=PackedVector3Array([Vector3(-0.6,0,i),Vector3(0,0,i+0.3),Vector3(0.6,0,i)])
				_line(st,pts,0.018,0.85)
		"lightning":
			for branch in 3:
				var pts := PackedVector3Array()
				for i in 10:
					pts.append(Vector3(sin(i*3.8+branch)*0.22,cos(i*2.5+branch)*0.18,float(i)/9))
				_line(st,pts,0.045 if branch==0 else 0.02,0.85 if branch==0 else 0.1)
		"beasts":
			for i in 3:
				var a := TAU*i/3.0
				_append(st,SkillTableau.creature_mesh("wolf"),Vector3(sin(a),0,cos(a)),Vector3.ONE*0.8,Vector3(0,a,0),0.15+i*0.2)
		"greatshield":
			# A heater great shield, +Y up and +Z face: layered plate, gold rim, two inlaid rims, a cross and a boss crystal.
			_append(st,SkillTableau.shield_mesh(),Vector3.ZERO,Vector3(1,1,0.7),Vector3.ZERO,0.1)
			_line(st,_heater(1.0,0.19),0.045,1)
			_line(st,_heater(0.78,0.22),0.02,0.85)
			_line(st,_heater(0.52,0.235),0.014,0.6)
			_line(st,PackedVector3Array([Vector3(0,0.72,0.24),Vector3(0,-0.72,0.24)]),0.03,0.9)
			_line(st,PackedVector3Array([Vector3(-0.5,0.3,0.24),Vector3(0.5,0.3,0.24)]),0.03,0.9)
			_append(st,SpellSpectacle._crystal_mesh(),Vector3(0,0.1,0.26),Vector3(0.22,0.3,0.22),Vector3(PI/2,0,0),1)
		"shield_outline":
			# The same heater drawn flat on the ground (+Y normal, top towards +Z): a rim, an inlay and the boss ring.
			var flat := PackedVector3Array()
			var inner := PackedVector3Array()
			for p in _heater(1.0,0.0):
				flat.append(Vector3(p.x,0,p.y))
				inner.append(Vector3(p.x*0.8,0,p.y*0.8))
			_line(st,flat,0.02,1)
			_line(st,inner,0.009,0.7)
			_ring_at(st,Vector3.ZERO,0.16,0.012)
		"rampart":
			# Eight great shields edge to edge in a ring, a crenellated top and gold rims above and below.
			for i in 8:
				var a := TAU*i/8.0
				var r := Vector3(sin(a),0,cos(a))
				_append(st,geometry("greatshield"),r+Vector3.UP*0.5,Vector3(0.47,0.5,0.35),Vector3(0,a,0),0.3)
			for i in 16:
				var a := TAU*(i+0.5)/16.0
				_append(st,SpellSpectacle._crystal_mesh(),Vector3(sin(a),1.04,cos(a)),Vector3(0.08,0.12,0.06),Vector3(0,a,0),0.9)
			_ring(st,1.0,0.03,0.022,1)
			_ring(st,1.0,0.98,0.016,1)
		"aegis":
			# A half dome of latitude rings and meridian arcs with a boss crystal at the crown.
			_ring(st,1.0,0.02,0.03,1)
			for lat in [0.26,0.61,0.96,1.31]:
				_ring(st,cos(lat),sin(lat),0.012,0.6,48)
			for i in 8:
				var a := TAU*i/8.0
				var pts := PackedVector3Array()
				for j in 13:
					var lat := PI*0.5*float(j)/12.0
					pts.append(Vector3(sin(a)*cos(lat),sin(lat),cos(a)*cos(lat)))
				_line(st,pts,0.02,0.85)
			_append(st,SpellSpectacle._crystal_mesh(),Vector3(0,1.02,0),Vector3(0.12,0.25,0.12),Vector3.ZERO,1)
		"crater_ring":
			# Fractures radiating from the centre, a raised rim of wedges and chunks thrown past it.
			for i in 10:
				var a := TAU*i/10.0
				var r := Vector3(sin(a),0,cos(a))
				var side := Vector3(cos(a),0,-sin(a))
				_line(st,PackedVector3Array([r*0.12,r*0.4+side*0.08,r*0.62-side*0.1,r*(0.78+float(i%3)*0.08)]),0.018,0.85)
			_ring(st,0.82,0.06,0.03,0.8)
			for i in 12:
				var a := TAU*(i+0.5)/12.0
				var r := Vector3(sin(a),0,cos(a))
				_append(st,SpellSpectacle._crystal_mesh(),r*0.82+Vector3.UP*0.08,Vector3(0.16,0.22+float(i%2)*0.08,0.12),Vector3(cos(a)*0.6,0,-sin(a)*0.6),0.3)
				if i%3!=0:
					_append(st,SpellSpectacle._crystal_mesh(),r*(1.02+float(i%3)*0.09)+Vector3.UP*0.03,Vector3(0.07,0.12,0.07),Vector3(cos(a)*1.2,0,-sin(a)*1.2),0.55)
		"stave":
			# Five staff lines round a ring (a music-box drum), open at the back, notes riding them.
			for j in 5:
				var pts := PackedVector3Array()
				for i in 49:
					var a := lerpf(-2.85,2.85,float(i)/48.0)
					pts.append(Vector3(sin(a),0.09*j,cos(a)))
				_line(st,pts,0.008,0.55+0.08*j)
			for k in 7:
				var a := lerpf(-2.5,2.5,float(k)/6.0)
				var p := Vector3(sin(a),0.045+0.09*float(k%4),cos(a))
				_append(st,SpellSpectacle._sphere_mesh(),p,Vector3(0.06,0.045,0.04),Vector3(0,a,-0.4),1.0)
				var tangent := Vector3(cos(a),0,-sin(a))
				_line(st,PackedVector3Array([p+tangent*0.05,p+tangent*0.05+Vector3.UP*0.2]),0.006,0.9)
		"chains":
			# Six radial chains of alternating links running out to anchor crystals at the rim.
			for i in 6:
				var a := TAU*i/6.0
				var r := Vector3(sin(a),0,cos(a))
				var side := Vector3(cos(a),0,-sin(a))
				for k in 9:
					var c := r*(0.12+k*0.1)
					var across := Vector3.UP if k%2==0 else side
					var pts := PackedVector3Array()
					for j in 11:
						var t := TAU*j/10.0
						pts.append(c+r*cos(t)*0.055+across*sin(t)*0.032)
					_line(st,pts,0.009,0.85 if k%2==0 else 0.4)
				_append(st,SpellSpectacle._crystal_mesh(),r*1.0+Vector3.UP*0.08,Vector3(0.1,0.26,0.1),Vector3.ZERO,1)
	st.generate_normals()
	var mesh := st.commit()
	_meshes[kind]=mesh
	return mesh

static func _ring_at(st: SurfaceTool, pos: Vector3, radius: float, width: float) -> void:
	var pts := PackedVector3Array()
	for i in 25:
		var a := TAU*i/24.0
		pts.append(pos+Vector3(sin(a)*radius,0.02,cos(a)*radius))
	_line(st,pts,width,1)

## The closed heater rim of SkillTableau.shield_mesh at [param size], pushed to depth [param z].
static func _heater(size: float, z: float) -> PackedVector3Array:
	var rim := PackedVector3Array()
	for p in [Vector2(0,1),Vector2(-0.45,0.86),Vector2(-0.82,0.57),Vector2(-0.76,0.1),Vector2(-0.66,-0.37),Vector2(-0.36,-0.74),Vector2(0,-1),Vector2(0.36,-0.74),Vector2(0.66,-0.37),Vector2(0.76,0.1),Vector2(0.82,0.57),Vector2(0.45,0.86),Vector2(0,1)]:
		rim.append(Vector3(p.x*size,p.y*size,z))
	return rim
