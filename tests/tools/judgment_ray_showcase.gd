extends Node3D
class Dummy extends Mob:
	var hits := 0
	func take_hit(amount: int, critical: bool, color := Color.WHITE, attacker: Node = null) -> bool:
		hits+=1
		return super.take_hit(amount,critical,color,attacker)
var out_dir := "/workspace/toon-artifacts/judgment-ray-v076"
var title: Label
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	Game.set_process(false)
	GameSettings.load_settings()
	GameSettings.quality=2
	Game.new_profile(&"mage","Judgment Ray",{"gender":1})
	Game.profile.level=100
	Game.profile.adv=4
	Game.profile.skills["judgment_ray"]=1
	Game.profile.hp=100000
	Game.profile.mp=100000
	get_window().size=Vector2i(1280,720)
	get_window().content_scale_size=Vector2i(1280,720)
	Scenery.environment(self,Color("789bba"),Color("adc2c6"),Color("d9e5f0"),Color("ffe4bf"))
	var paths: Array[PackedVector2Array]=[]
	Scenery.ground(self,60,Color("607f61"),Color("779265"),912,Color("a59f7e"),paths,2.5,[Vector3.ZERO],&"meadow")
	var camera := Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=20
	add_child(camera)
	camera.position=Vector3(12,10,20)
	camera.look_at(Vector3(0,4.3,0))
	camera.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	title=Label.new()
	title.position=Vector2(28,22)
	title.add_theme_font_size_override("font_size",28)
	title.add_theme_constant_override("outline_size",5)
	title.add_theme_color_override("font_outline_color",Color("292431"))
	layer.add_child(title)
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field=field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.stats.haste=0.0
	hero.stats.crit=0.0
	hero.position=Vector3(-4,0,1)
	var mob := Dummy.new()
	mob.setup(&"forest_orc",100,Vector3.ZERO,hero)
	field.add_child(mob)
	mob.position=Vector3(1.5,0,0)
	mob.hp=10000000
	mob.max_hp=mob.hp
	mob.set_physics_process(false)
	hero.target=mob
	hero.set_facing(atan2(mob.position.x-hero.position.x,mob.position.z-hero.position.z))
	VfxKit.warm_shaders(field,Vector3.ZERO)
	await get_tree().create_timer(0.5).timeout
	hero._cast(ClassData.find_skill(&"mage","judgment_ray"))
	await get_tree().create_timer(0.57).timeout
	await capture("01-invocation","Invocation / Heaven seal and target lock")
	await get_tree().create_timer(0.54).timeout
	await capture("02-verdict","Judgment Ray / One decisive hit")
	await get_tree().create_timer(0.33).timeout
	await capture("03-afterglow","Afterglow / Shockwave and dissolving runes")
	await get_tree().create_timer(1.3).timeout
	var f:=FileAccess.open(out_dir.path_join("showcase.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"actual_cast":true,"hits":mob.hits,"remaining_sequences":get_tree().get_nodes_in_group("judgment_ray_sequences").size()},"\t"))
	field.queue_free()
	await field.tree_exited
	print("JUDGMENT SHOWCASE: ",mob.hits if is_instance_valid(mob) else "completed", " / real cast captured")
	get_tree().quit()
func capture(file: String, label: String) -> void:
	title.text="TOON TALE / "+label
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file+".png"))
