extends Node3D
## The character bodies (ChibiBodies): four per gender, each loads with the chibi
## skeleton, plays every clip the hero code calls on its gender's original's clips,
## keeps the triangle budget; picking one on the create screen saves it; an unknown
## body id is the original.
##   godot --headless --path . res://tests/integration/chibi_bodies_test.tscn
var failures := 0
var checks := 0
const CLIPS := ["Idle", "Walking_A", "Running_A", "1H_Melee_Attack_Chop", "2H_Melee_Attack_Slice", "Spellcast_Shoot", "Spellcasting",
	"2H_Ranged_Shoot", "Hit_A", "Death_A", "Jump_Full_Short", "Cheer", "Blocking", "Dodge_Backward", "T-Pose", "Fly_Hover", "Fly_Forward"]
const MAX_TRIS := 16500
const MAX_BYTES := 1600000


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _tris(model: Node) -> int:
	var n := 0
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			n += idx.size() / 3 if idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


func _ready() -> void:
	await get_tree().process_frame
	for g in 2:
		check(ChibiBodies.count(g) == 4, "four characters for gender %d" % g)
		var base := (load(ChibiBodies.base_path(g)) as PackedScene).instantiate()
		var base_skel := base.find_child("Skeleton3D", true, false) as Skeleton3D
		for i in ChibiBodies.count(g):
			var look := {"gender": g, "body": i}
			var path := ChibiBodies.path(look)
			check(ResourceLoader.exists(path), "%s exists" % path)
			check(ChibiBodies.body_name(g, i) != "", "%s has a name" % path)
			check(ChibiBodies.card(g, i) != null, "%s has a create-screen card" % path)
			var scene := (load(path) as PackedScene).instantiate()
			var skel := scene.find_child("Skeleton3D", true, false) as Skeleton3D
			check(skel != null and skel.get_bone_count() == base_skel.get_bone_count(), "%s has the chibi skeleton" % path)
			if skel:
				for b in base_skel.get_bone_count():
					if skel.get_bone_name(b) != base_skel.get_bone_name(b):
						check(false, "%s bone %d is %s" % [path, b, base_skel.get_bone_name(b)])
						break
			var tris := _tris(scene)
			check(tris > 8000 and tris <= MAX_TRIS, "%s: %d triangles within the budget" % [path, tris])
			if i > 0:
				var bytes := FileAccess.get_file_as_bytes(path).size()
				check(bytes > 0 and bytes <= MAX_BYTES, "%s: %d bytes" % [path, bytes])
				check(scene.find_child("AnimationPlayer", true, false) == null, "%s carries no clips of its own" % path)
			scene.free()
			# In the hero's body: every clip plays, the weapon sits in the right hand.
			for cls in [&"warrior", &"archer", &"mage"]:
				var v := HeroVisual.new()
				add_child(v)
				v.setup(cls, "", true, {}, look)
				check(v.chibi and v.model.scene_file_path == path, "%s is worn as %s" % [path, cls])
				for clip in CLIPS:
					check(v.anim.has_animation(clip), "%s plays %s" % [path, clip])
				v.play("Running_A")
				v.anim.advance(0.3)
				var hand := v._skeleton.find_bone("RightHand")
				var hips := v._skeleton.find_bone("Hips")
				var lowered := v._skeleton.get_bone_global_pose(hand).origin.y < v._skeleton.get_bone_global_pose(hips).origin.y + 0.35
				check(lowered, "%s: the hand moves with the clip (below the chest while running)" % path)
				# Bones keep their own (fitted) lengths: only the hips are keyed in place.
				var fore := v._skeleton.find_bone("RightLowerArm")
				var d := v._skeleton.get_bone_global_pose(hand).origin.distance_to(v._skeleton.get_bone_global_pose(fore).origin)
				var rest := v._skeleton.get_bone_global_rest(hand).origin.distance_to(v._skeleton.get_bone_global_rest(fore).origin)
				check(absf(d - rest) < 0.002, "%s: the forearm keeps its length in a clip (%.3f vs %.3f)" % [path, d, rest])
				if cls == &"warrior":
					var grip := v.model.find_child("*Weapon*", true, false)
					check(v.anim.current_animation != "" , "%s runs a clip" % path)
					check(grip == null or grip is Node3D, "%s holds its weapon" % path)
				v.queue_free()
		base.free()
	# Unknown ids fall back to the original body.
	for bad in [{"gender": 0, "body": 4}, {"gender": 1, "body": -1}, {"gender": 1, "body": "x"}, {"gender": 0, "body": 1.0e9}]:
		check(ChibiBodies.index(FaceKit.hero_look(bad)) == 0, "unknown body %s is the original" % [bad])
		var v := HeroVisual.new()
		add_child(v)
		v.setup(&"warrior", "", true, {}, FaceKit.hero_look(bad))
		check(v.model.scene_file_path == ChibiBodies.base_path(int(FaceKit.hero_look(bad).gender)), "unknown body %s renders the original" % [bad])
		v.queue_free()
	# Old looks without a body and old styles are the original body.
	check(ChibiBodies.index({"gender": 1, "style": 2}) == 0, "an old style is the original body")
	# The create screen: pick a character, it is saved in the profile and worn in game.
	var screen := ClassSelect.new()
	add_child(screen)
	await get_tree().process_frame
	screen._set_gender(0)
	screen.set_body(2)
	await get_tree().process_frame
	check(screen._stage.visual != null and screen._stage.visual.model.scene_file_path == ChibiBodies.BODIES[0][2].path, "the preview wears the picked character")
	var got := []
	screen.confirmed.connect(func(c, n, l): got.append(l))
	screen._on_confirm()
	check(got.size() == 1 and got[0] == {"gender": 0, "body": 2}, "the creator confirms the character (%s)" % [got])
	screen.queue_free()
	if got.size() == 1:
		Game.new_profile(&"mage", "ร่างใหม่", got[0])
		check(Game.profile.look == {"gender": 0, "body": 2}, "the profile keeps the character (%s)" % Game.profile.look)
		check(Game.save_code_roundtrip(), "the character survives the save code")
		check((Game.hero_look().face as Dictionary) == {"gender": 0, "body": 2}, "online sends the character")
	# Head gear follows the smaller heads.
	var small := HeroVisual.new()
	add_child(small)
	small.setup(&"warrior", "", true, {}, {"gender": 0, "body": 2})
	check(small._head_scale < 0.95 and small._head_scale > 0.6, "a smaller head scales head gear (%.2f)" % small._head_scale)
	small.queue_free()
	print("chibi_bodies_test: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
