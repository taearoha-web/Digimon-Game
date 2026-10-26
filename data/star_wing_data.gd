class_name StarWingData
extends RefCounted
## Uploaded class wings: one drop-only collection, always unlocked at 100 stars.
const REQUIRED_STARS := 100
const MODEL := "res://assets/models/star_wings/wings_%s.glb"
const INFO := {
	"warrior": {"name":"ปีกพันดาบเทวะ", "stats":{"atk":[520,620],"hp":[2200,2800],"def":[240,300],"mp":[450,550],"crit":[0.06,0.075]}},
	"archer": {"name":"ปีกพฤกษาเทพ", "stats":{"atk":[540,650],"hp":[1500,1900],"def":[155,195],"mp":[500,620],"crit":[0.085,0.10]}},
	"lancer": {"name":"ปีกมังกรเทพเพลิง", "stats":{"atk":[560,680],"hp":[1900,2400],"def":[195,245],"mp":[470,590],"crit":[0.075,0.09]}},
	"mage": {"name":"ปีกนภาจักรวาล", "stats":{"matk":[580,700],"hp":[1450,1850],"def":[150,190],"mp":[850,1100],"crit":[0.07,0.085]}},
	"priest": {"name":"ปีกเซราฟิมหกปีก", "stats":{"matk":[510,620],"hp":[2100,2700],"def":[220,280],"mp":[800,1050],"crit":[0.06,0.075]}},
	"assassin": {"name":"ปีกราชันเงาสุริยคราส", "stats":{"atk":[550,670],"hp":[1700,2150],"def":[170,215],"mp":[460,570],"crit":[0.09,0.105]}},
	"defender": {"name":"ปีกเทพดาราจักรนิรันดร์", "stats":{"atk":[480,600],"hp":[2300,2800],"def":[240,300],"mp":[450,560],"crit":[0.06,0.075]}},
	"darklord": {"name":"ผ้าคลุมจักรพรรดิเหยี่ยวทมิฬ", "stats":{"atk":[540,660],"hp":[2000,2500],"def":[200,250],"mp":[480,600],"crit":[0.07,0.085]}},
	"summoner": {"name":"ปีกราชินีผีเสื้อวิญญาณ", "stats":{"matk":[550,670],"hp":[1850,2350],"def":[175,225],"mp":[900,1150],"crit":[0.065,0.08]}},
}

static func is_wing(item: Dictionary) -> bool:
	return item.get("slot","")=="wings" and int(item.get("star_tier",0))>0

static func item_name(cls: String) -> String:
	return String(INFO.get(cls,INFO.warrior).name)

static func look(cls: String) -> String:
	return "star_wings_%s_100" % (cls if INFO.has(cls) else "warrior")

static func drop_chance(region: StringName, boss: bool, elite: bool) -> float:
	if not StarProgression.is_region(region): return 0.0
	return 0.20 if boss else (0.03 if elite else 0.005)

static func item(cls: String, rng: RandomNumberGenerator, rarity := -1) -> Dictionary:
	if not INFO.has(cls): cls="warrior"
	if rarity<0: rarity=4 if rng.randf()<0.25 else 3
	rarity=clampi(rarity,0,4)
	var result:=ItemData.wings(rng,cls,rarity)
	var stats:Dictionary={}
	var factor:=1.08 if rarity==4 else 1.0
	for key in INFO[cls].stats:
		var span:Array=INFO[cls].stats[key]
		stats[key]=snappedf(rng.randf_range(span[0],span[1])*factor,0.001) if key=="crit" else int(round(rng.randf_range(span[0],span[1])*factor))
	result.merge({"star_tier":100,"star_class":cls,"star_wing_revision":1,"level":200,"class":cls,
		"name":("%s %s" % [item_name(cls),ItemData.RARITY_ADJ[rarity]]).strip_edges(),
		"look":look(cls),"stats":stats,"price":80000 if rarity<4 else 110000},true)
	return result

## Replace retired star wings exactly once; preserve uid, enhancement and gems.
## A worn pre-100-star pair becomes a Lv.100 pair, so full bags never lose gear
## and a locked 100-star item cannot bypass the equipment requirement on load.
static func migrate_profile(profile: Dictionary) -> void:
	var cls:=String(profile.get("class","warrior"))
	var worn:Variant=profile.get("equip",{}).get("wings")
	for piece in profile.get("inv",[])+profile.get("storage",[])+profile.get("equip",{}).values():
		if not piece is Dictionary or not is_wing(piece) or int(piece.get("star_wing_revision",0))==1: continue
		var rng:=RandomNumberGenerator.new()
		rng.seed=hash(String(piece.get("uid",""))+"star-wings-v1")
		var locked_worn:bool=is_same(piece,worn) and (int(profile.get("level",1))<100 or int(profile.get("paragon",{}).get("level",0))<100)
		var fresh:=ItemData.wings(rng,cls,int(piece.get("rarity",3))) if locked_worn else item(cls,rng,int(piece.get("rarity",3)))
		for key in ["star_tier","star_class","star_set","look","star_wing_revision"]: piece.erase(key)
		for key in fresh:
			if key not in ["uid","plus","gems","sockets"]: piece[key]=fresh[key]
		piece["sockets"]=maxi(int(fresh.sockets),maxi(int(piece.get("sockets",0)),piece.get("gems",[]).size()))

static func build(cls: String) -> Node3D:
	if not INFO.has(cls): cls="warrior"
	# The Dark Lord's star "wings" are a floating imperial cape, built in code.
	if cls=="darklord": return CapeArt.build(true)
	var root:Node3D=(load(MODEL % cls) as PackedScene).instantiate()
	root.name="Wings_star_"+cls
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		mesh.set_meta("no_outline",true)
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if cls=="assassin": ShadowWingArt.dress(root,true)
	var player:=root.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if player!=null:
		for clip in ["Idle","Flap","Glide"]:
			if player.has_animation(clip): player.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
		if player.has_animation("Idle"): player.play("Idle")
	return root
