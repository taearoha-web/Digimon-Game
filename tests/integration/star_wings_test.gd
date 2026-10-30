extends Node
var checks:=0
var failures:=0
class DropZone:
	extends Zone
	var wing_drops:Array[Dictionary]=[]
	var jewels:={}
	func _spawn_loot(item:Dictionary,_gold:int,_from:Vector3)->void:
		if item.get("slot","")=="wings": wing_drops.append(item)
		if item.get("kind","")=="jewel": jewels[item.id]=int(jewels.get(item.id,0))+1
func check(ok:bool,note:String)->void:
	checks+=1
	if not ok: failures+=1;printerr("FAIL ",note)
func setup(cls:StringName,stars:=100)->void:
	Game.new_profile(cls,"Wing migration QA")
	Game.profile.level=100
	Game.profile.paragon={"level":stars,"exp":0,"points":stars,"spent":0,"alloc":{}}
	Game.profile.inv=[]
	Game.profile.equip={}
func retired(cls:String,tier:int)->Dictionary:
	var result:=ItemData.wings(Game.rng,cls,3)
	result.merge({"star_tier":tier,"star_class":cls,"class":"","level":100+tier,"look":"star_wings_%d"%tier,"star_set":"old_set","plus":7,"gems":["ruby_0"],"sockets":3},true)
	return result
func _ready()->void:
	Game.set_process(false)
	ZoneData.ensure()
	var rng:=RandomNumberGenerator.new();rng.seed=917
	for cls in ClassData.IDS:
		setup(cls)
		for rarity in 5:
			for roll in 12:
				var item:=StarWingData.item(String(cls),rng,rarity)
				check(Game._valid_item(item),"valid new wing "+String(cls))
				var main:String=ItemData.WING_INFO[cls].stat
				check(item.stats[main]>float(ItemData.WING_INFO[cls].base)*1.2*1.16,"main stronger than max legacy mythic")
				check(not item.stats.has("matk" if main=="atk" else "atk"),"class-specific damage stat")
				for key in ItemData.WING_BONUS:check(item.stats[key]>ItemData.WING_BONUS[key][1],"each bonus stronger than max legacy")
		var wing:=StarWingData.item(String(cls),rng)
		Game.paragon().level=99;check(not Game.equip_problem(wing).is_empty(),"99-star gate")
		Game.paragon().level=100;check(Game.equip_problem(wing).is_empty(),"100-star unlock")
		Game.profile.level=99;check(not Game.equip_problem(wing).is_empty(),"level-100 gate")
		Game.profile.level=100
		Game.profile["class"]=String(ClassData.IDS[(ClassData.IDS.find(cls)+1)%6]);check(not Game.equip_problem(wing).is_empty(),"other class blocked")
		Game.profile["class"]=String(cls)
		Game.profile.inv.append(wing);check(Game.equip_from_bag(0),"equip unlocked wing")
		wing["plus"]=9;wing["sockets"]=3;wing["gems"]=["ruby_0"]
		var uid:String=wing.uid
		Game.tower()["shards"]=10000
		check(Game.tower_reroll_wings(wing)=="ok","reroll new collection")
		check(int(wing.level)==200 and int(wing.star_tier)==100 and wing.uid==uid and wing.plus==9 and wing.gems==["ruby_0"],"reroll preserves gate uid plus gems")
		check(String(wing.name).begins_with(StarWingData.item_name(String(cls))),"reroll keeps uploaded wing name")
		for tier in [50,100,150,200]:
			var old:=retired(String(cls),tier)
			var old_uid:String=old.uid
			Game.profile.inv.append(old)
			var bank:=retired(String(cls),tier);Game.profile.storage.append(bank)
			StarWingData.migrate_profile(Game.profile)
			check(int(old.level)==200 and int(old.star_tier)==100 and old["class"]==String(cls),"retired bag wing becomes own class 100-star")
			check(int(bank.level)==200 and int(bank.star_tier)==100,"retired storage wing migrated")
			check(old.uid==old_uid and old.plus==7 and old.gems==["ruby_0"] and old.sockets==3,"migration preserves investment")
			check(Game._valid_item(old),"migrated item accepted")
		var unchanged:=Game.profile.duplicate(true);StarWingData.migrate_profile(Game.profile)
		check(unchanged==Game.profile,"migration idempotent")
		var legacy:=ItemData.wings(rng,String(cls),4);Game.profile.inv.append(legacy)
		var legacy_before:=legacy.duplicate(true);StarWingData.migrate_profile(Game.profile)
		check(legacy==legacy_before,"level 100 original preserved")
		check(Game.save_code_roundtrip(),"new wings transfer save roundtrip")
		for tier in [50,150,200]:check(StarProgression.item(cls,tier,"wings",rng).is_empty(),"retired tiers cannot be generated")
		# A pre-100-star player keeps a valid pair and their investment even with full bags.
		setup(cls,50)
		Game.profile.equip.wings=retired(String(cls),50)
		var worn_uid:String=Game.profile.equip.wings.uid
		for i in Game.MAX_BAG:Game.profile.inv.append(ItemData.potion("hp_s",1))
		for i in Game.STORAGE_SIZE:Game.profile.storage.append(ItemData.potion("mp_s",1))
		StarWingData.migrate_profile(Game.profile)
		var worn:Dictionary=Game.profile.equip.wings
		check(int(worn.level)==100 and not worn.has("star_tier") and worn.uid==worn_uid and worn.plus==7 and worn.gems==["ruby_0"],"locked equipped migration safe when all bags full")
		check(Game.equip_problem(worn).is_empty() and Game.save_code_roundtrip(),"migrated below-100 profile remains playable and saveable")
	setup(&"mage")
	for region in StarProgression.REGIONS:
		var zone:=DropZone.new();zone.zone_id=region;zone.data=ZoneData.get_zone(region);zone.rng.seed=911
		var mob:=Mob.new();mob.template={};mob.level=110
		for i in 1200:zone._star_loot(mob,Vector3.ZERO)
		mob.is_boss=true
		for i in 100:zone._star_loot(mob,Vector3.ZERO)
		check(zone.wing_drops.is_empty(),"100-star wings never drop in "+String(region))
		zone.jewels.clear();mob.is_boss=false
		for i in 30000:zone._drop_jewels(Vector3.ZERO)
		var stars:=int(zone.data.get("star",0))
		check(int(zone.jewels.get("chaos",0))>150 and int(zone.jewels.get("chaos",0))<450,"chaos jewels drop about 1%% in %s (%d)"%[region,int(zone.jewels.get("chaos",0))])
		check((int(zone.jewels.get("feather",0))>0)==(stars>=ItemData.FEATHER_STARS) and int(zone.jewels.get("feather",0))<90*max(1,stars/50),"feathers drop only in fields of 50 stars and up (%s %d★: %d)"%[region,stars,int(zone.jewels.get("feather",0))])
		mob.free();zone.free()
	# Each deeper feather field adds 0.1%: 50★ 0.1%, 100★ 0.2%, 150★ 0.3%, 200★ 0.4%.
	check(ItemData.feather_chance(1)==0.0 and is_equal_approx(ItemData.feather_chance(50),0.001) and is_equal_approx(ItemData.feather_chance(100),0.002) and is_equal_approx(ItemData.feather_chance(150),0.003) and is_equal_approx(ItemData.feather_chance(200),0.004),"feather chance climbs 0.1% per field")
	# The forge crafts them: Lv.100 wings + a chaos jewel + a feather, 30%.
	var lv100:=ItemData.wings(Game.rng,"mage",2)
	lv100["plus"]=4;lv100["gems"]=["ruby_0"]
	check(StarWingData.can_craft(lv100) and not StarWingData.can_craft(StarWingData.item("mage",rng)),"only Lv.100 wings can be crafted")
	Game.profile.inv=[lv100]
	check(Game.craft_star_wings(lv100).begins_with("เพชรไม่พอ"),"crafting needs a chaos jewel and a feather")
	var made:=0
	var tries:=400
	for i in tries:
		var pair:=ItemData.wings(Game.rng,"warrior",1)
		pair["plus"]=4;pair["gems"]=["ruby_0"]
		var uid:String=pair.uid
		Game.profile.inv=[pair,ItemData.jewel("chaos"),ItemData.jewel("feather")]
		var result:=Game.craft_star_wings(pair)
		check(Game.jewel_count("chaos")==0 and Game.jewel_count("feather")==0,"a try uses one chaos jewel and one feather")
		if result=="ok":
			made+=1
			check(StarWingData.is_wing(pair) and pair["class"]=="mage" and int(pair.level)==200 and pair.uid==uid and int(pair.plus)==4 and pair.gems==["ruby_0"],"crafted wings are the class's 100-star wings and keep plus and gems")
		else:
			check(result=="fail" and not StarWingData.is_wing(pair) and Game.profile.inv.size()==1,"a failed try keeps the Lv.100 wings")
	check(made>int(tries*0.22) and made<int(tries*0.38),"about 30%% of tries succeed (%d/%d)"%[made,tries])
	var worn:=ItemData.wings(Game.rng,"mage",1)
	Game.profile.equip["wings"]=worn
	Game.profile.inv=[ItemData.jewel("chaos"),ItemData.jewel("feather")]
	check(Game.craft_star_wings(worn)!="ok" and Game.jewel_count("chaos")==1,"worn wings must go back to the bag first")
	Game.profile.equip={};Game.profile.inv=[]
	var catalogue:=StarGearData.catalogue().filter(func(i):return i.slot=="wings")
	check(catalogue.size()==ClassData.IDS.size(),"one class wing per class in new catalogue")
	var looks:Dictionary={}
	for item in catalogue:looks[item.look]=true;check(int(item.star_tier)==100 and item["class"]!="","catalogue only 100-star class wings")
	check(looks.size()==ClassData.IDS.size(),"one distinct icon id per class")
	Game.has_profile=false
	print("STAR WINGS: ",checks," checks, ",failures," failures")
	get_tree().quit(failures)
