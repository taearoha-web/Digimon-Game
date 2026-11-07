extends SceneTree
## Offline production step for the village pets (PetData): bakes each pet model and the
## few KayKit animation clips it needs into one runtime GLB under assets/models/pets/.
##
##   godot --headless --path . -s res://tools/bake_pets.gd -- /path/to/sources
##
## The source folder holds the original CC0 files listed in
## assets/vendor/pets/SOURCE.json (Monster.glb, FrostGolem.glb, Druid.glb,
## Rig_{Medium,Large}_*.glb),
## downloaded from the pinned jam-ready-assets commit. Clip tracks of the shared KayKit
## libraries are already addressed "Rig_X/Skeleton3D:<bone>", the same path the character
## files use, so retargeting only re-roots the tracks onto the model's skeleton. Clips
## are renamed to the aliases MonsterVisual understands (Idle, Walk, Run, Attack, Skill1,
## Skill2, Hit, Death); everything else in the libraries is left out. The models keep
## their original palette texture; the fire recolour is a separate skin
## (assets/models/pets/skins/, a gradient-mapped copy of the original atlas) that
## MonsterVisual swaps in (PetData "skin").

const OUT := "res://assets/models/pets/"

## model file -> {source, rig, clips: {alias: [library, source clip]}}
const BAKES := {
	"KaijuRex": {
		"source": "Monster.glb", "rig": "Rig_Medium",
		"clips": {
			"Idle": ["General", "Idle_A"], "Walk": ["MovementBasic", "Walking_A"],
			"Run": ["MovementBasic", "Running_A"], "Attack": ["CombatMelee", "Melee_Unarmed_Attack_Punch_A"],
			"Skill1": ["CombatMelee", "Melee_Unarmed_Attack_Kick"], "Skill2": ["General", "Throw"],
			"Hit": ["General", "Hit_A"], "Death": ["General", "Death_A"],
		},
	},
	# The earth pet: the KayKit Adventurers Druid, with magic clips for its nature spells.
	"GroveDruid": {
		"source": "Druid.glb", "rig": "Rig_Medium",
		"clips": {
			"Idle": ["General", "Idle_A"], "Walk": ["MovementBasic", "Walking_A"],
			"Run": ["MovementBasic", "Running_A"], "Attack": ["CombatRanged", "Ranged_Magic_Shoot"],
			"Skill1": ["CombatRanged", "Ranged_Magic_Spellcasting"], "Skill2": ["CombatRanged", "Ranged_Magic_Summon"],
			"Hit": ["General", "Hit_A"], "Death": ["General", "Death_A"],
		},
	},
	"FrostGolem": {
		"source": "FrostGolem.glb", "rig": "Rig_Large",
		"clips": {
			"Idle": ["General", "Idle_A"], "Walk": ["MovementBasic", "Walking_A"],
			"Run": ["MovementBasic", "Running_A"], "Attack": ["CombatMelee", "Melee_Unarmed_Punch"],
			"Skill1": ["CombatMelee", "Melee_Unarmed_Smash"], "Skill2": ["CombatMelee", "Melee_2H_Slam"],
			"Hit": ["General", "Hit_A"], "Death": ["General", "Death_A"],
		},
	},
}

func _initialize() -> void:
	call_deferred("_bake")


func _bake() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: -s res://tools/bake_pets.gd -- <source folder>")
		quit(1)
		return
	var src: String = args[0]
	for name in BAKES:
		var spec: Dictionary = BAKES[name]
		var scene := _load(src.path_join(String(spec.source)))
		var skel := scene.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := AnimationPlayer.new()
		player.name = "AnimationPlayer"
		scene.add_child(player)
		player.owner = scene
		var lib := AnimationLibrary.new()
		var skel_path := String(scene.get_path_to(skel))
		var libraries := {}
		for alias in spec.clips:
			var pair: Array = spec.clips[alias]
			var lib_name := "%s_%s.glb" % [spec.rig, pair[0]]
			if not libraries.has(lib_name):
				libraries[lib_name] = _load(src.path_join(lib_name))
			var src_player := (libraries[lib_name] as Node).find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			var clip := src_player.get_animation(String(pair[1])).duplicate(true) as Animation
			for t in clip.get_track_count():
				var path := String(clip.track_get_path(t))
				var colon := path.find(":")
				if colon >= 0:
					clip.track_set_path(t, NodePath(skel_path + path.substr(colon)))
			clip.loop_mode = Animation.LOOP_LINEAR if alias in ["Idle", "Walk", "Run"] else Animation.LOOP_NONE
			lib.add_animation(alias, clip)
		player.add_animation_library("", lib)
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var err := doc.append_from_scene(scene, state)
		if err == OK:
			err = doc.write_to_filesystem(state, ProjectSettings.globalize_path(OUT + name + ".glb"))
		print("BAKED %s.glb: %s, %d clips" % [name, error_string(err), lib.get_animation_list().size()])
		for node in libraries.values():
			(node as Node).free()
		scene.free()
	quit()


func _load(path: String) -> Node:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		push_error("bake_pets: cannot read %s" % path)
		return Node3D.new()
	return doc.generate_scene(state)
