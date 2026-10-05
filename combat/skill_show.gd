class_name SkillShow
extends RefCounted
## Extra spectacle layered on top of a skill's normal effect: ground slams,
## ice spikes, columns of light, fire rings, power-up vortexes and a camera
## punch for the heavy ones. Used by the hero and by AI companions.


## center: where the skill lands; origin: the caster's feet; camera: optional.
static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, camera: ThirdPersonCamera = null) -> void:
	var color: Color = skill.color
	var radius := float(skill.get("radius", 3.0))
	var big := false
	match String(skill.id):
		"whirlwind":
			VfxKit.vortex(parent, origin, color, 3.2, 0.8)
			VfxKit.slam(parent, origin, color, radius * 0.9)
		"earthquake":
			VfxKit.slam(parent, origin, color, radius)
			VfxKit.spikes(parent, origin, radius, Color("a8784a"), 16, 2.0)
			big = true
		"power_slash", "rage_slash", "holy_blade", "shield_bash":
			VfxKit.star_burst(parent, center + Vector3(0, 1.0, 0), color, 2.4)
			if skill.id == "holy_blade":
				VfxKit.pillar(parent, center, color, 10.0, 1.1, 0.6)
		"battle_roar", "divine_wall", "blessing", "eagle_eye", "swift_step":
			VfxKit.vortex(parent, origin, color, 3.6, 0.9)
			VfxKit.pillar(parent, origin, color, 8.0, 1.3, 0.8)
			VfxKit.shockwave(parent, origin + Vector3(0, 0.12, 0), color, 4.0)
			big = true
		"frost_nova":
			VfxKit.spikes(parent, origin, radius, Color("a8ecff"), 18, 2.4)
			VfxKit.shockwave(parent, origin + Vector3(0, 0.12, 0), Color("dff8ff"), radius * 1.2)
		"blizzard":
			VfxKit.spikes(parent, center, radius, Color("a8ecff"), 22, 2.8, 0.5)
			VfxKit.column_rain(parent, center, radius, Color("e6f8ff"), 16, 1.0, 10.0)
			big = true
		"ice_spear", "fireball", "power_shot", "piercing_shot", "holy_bolt", "judgement":
			VfxKit.star_burst(parent, center + Vector3(0, 1.0, 0), color, 2.0)
			if skill.id == "judgement":
				VfxKit.pillar(parent, center, color, 16.0, 1.8, 0.7)
				big = true
		"meteor":
			VfxKit.fire_ring(parent, center, Color("ff6a2a"), radius, 22, 1.6)
			VfxKit.slam(parent, center, color, radius)
			big = true
		"inferno":
			VfxKit.fire_ring(parent, center, Color("ff6a2a"), radius, 18, 1.4)
			big = true
		"sea_of_flame":
			VfxKit.fire_ring(parent, origin, Color("ff7a2a"), radius, 28, 1.6)
			VfxKit.vortex(parent, origin, Color("ff7a2a"), 3.5, 0.9)
			big = true
		"chain_lightning":
			VfxKit.star_burst(parent, center + Vector3(0, 1.0, 0), color, 2.2)
		"holy_nova", "sanctuary":
			VfxKit.get_ring_delay(parent, origin, color, radius * 0.8, 0.12)
			VfxKit.get_ring_delay(parent, origin, Color.WHITE, radius * 0.55, 0.24)
			VfxKit.column_rain(parent, origin, radius, color, 10, 0.5, 8.0)
		"holy_rain":
			VfxKit.column_rain(parent, center, radius, color, 22, 1.1, 12.0)
			VfxKit.shockwave(parent, center + Vector3(0, 0.12, 0), color, radius)
			big = true
		"heal", "divine_heal":
			VfxKit.vortex(parent, origin, Color("6dff9a"), 3.4, 0.9)
		"storm_volley", "triple_shot":
			VfxKit.vortex(parent, origin, color, 2.4, 0.5)
		"gale_burst":
			VfxKit.vortex(parent, origin, color, 3.0, 0.7)
			VfxKit.get_ring_delay(parent, origin, color, radius, 0.1)
		"arrow_rain":
			VfxKit.column_rain(parent, center, radius, color, 10, 0.6, 12.0)
	if big and camera:
		camera.punch(5.0)
