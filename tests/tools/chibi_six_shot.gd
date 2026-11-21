extends Node3D
## The six new characters (ChibiBodies 1-3 of each gender) side by side on grass:
##   godot --rendering-driver opengl3 --resolution 1688x780 --path . res://tests/tools/chibi_six_shot.tscn -- OUT.png [stand|action]
const CAST := [
	[0, 1, "warrior", "1H_Melee_Attack_Chop", 0.45], [0, 2, "assassin", "Dualwield_Melee_Attack_Chop", 0.4], [0, 3, "archer", "2H_Ranged_Shoot", 0.45],
	[1, 1, "mage", "Spellcast_Shoot", 0.3], [1, 2, "lancer", "2H_Melee_Attack_Stab", 0.4], [1, 3, "bard", "Cheer", 0.4],
]


func _ready() -> void:
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color("bfe3ff")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.95, 0.97, 1.0); e.ambient_light_energy = 0.75
	var we := WorldEnvironment.new(); we.environment = e; add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-40, 25, 0); l.light_energy = 0.8; l.shadow_enabled = true; add_child(l)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 40); g.mesh = pm
	g.material_override = MeshKit.toon(Color("5e9a4e")); add_child(g)
	var args := OS.get_cmdline_user_args()
	var action := args.size() > 1 and args[1] == "action"
	var cam := Camera3D.new(); add_child(cam)
	cam.fov = 30; cam.position = Vector3(0, 1.9, 11.5); cam.rotation_degrees = Vector3(-4, 0, 0)
	for k in CAST.size():
		var c: Array = CAST[k]
		var h := HeroVisual.new(); add_child(h)
		h.setup(StringName(c[2]), "", true, {}, {"gender": c[0], "body": c[1]})
		h.position = Vector3((k - 2.5) * 2.25, 0, 0)
		h.rotation_degrees.y = 18.0 if not action else 35.0
		var clip := String(c[3]) if action else "Idle"
		if h.anim.has_animation(clip):
			h.anim.play(clip, 0.0)
			h.anim.seek(h.anim.get_animation(clip).length * (float(c[4]) if action else 0.2 + 0.1 * k), true)
			h.anim.pause()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args[0])
	get_tree().quit()
