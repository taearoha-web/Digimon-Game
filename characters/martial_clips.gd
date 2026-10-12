class_name MartialClips
extends RefCounted
## Keep the imported body/feet and layer offline-baked two-hand weapon poses.
## These two aliases exist on all three rigs; no runtime retarget or IK.
static func prepare(player: AnimationPlayer) -> void:
	var library := player.get_animation_library("")
	for pair in [["Martial_SpearThrow","2H_Melee_Attack_Stab"],["Martial_GroundSlam","1H_Melee_Attack_Chop"]]:
		if not library.has_animation(pair[0]):
			library.add_animation(pair[0],library.get_animation(pair[1]).duplicate())
