class_name SkillChoreography
extends RefCounted
## Every active skill has an authored gesture and a visual signature. Clip
## contact times are in the shared KayKit/retargeted chibi source animations.
## Presentation time is remapped to the existing gameplay release, including
## haste. This catalogue never changes MP, damage, cooldowns or hit counts.

const GESTURES := {
	"execution": ["1H_Melee_Attack_Chop", 0.46, 0.55, -0.18, 0.02, 0.28],
	"spear_throw": ["Martial_SpearThrow", 0.72, 0.44, -0.12, 0.02, 0.22],
	"ground_slam": ["Martial_GroundSlam", 0.46, 0.50, -0.16, 0.02, 0.20],
	"storm_spin": ["2H_Melee_Attack_Spin", 1.12, 0.52, 0.0, 0.02, 0.0],
	# clip, source contact, recovery seconds, lean, lift, forward step
	"cleave": ["1H_Melee_Attack_Chop", 0.46, 0.32, -0.10, 0.02, 0.16],
	"draw_cut": ["1H_Melee_Attack_Slice_Diagonal", 0.42, 0.30, -0.07, 0.01, 0.14],
	"cross_cut": ["1H_Melee_Attack_Slice_Horizontal", 0.46, 0.36, -0.08, 0.02, 0.13],
	"whirl": ["2H_Melee_Attack_Spin", 1.12, 0.46, 0.0, 0.09, 0.0],
	"shield": ["Block_Attack", 0.46, 0.34, -0.13, 0.0, 0.14],
	"resolve": ["Cheer", 0.70, 0.43, 0.06, 0.02, 0.0],
	"ward": ["Blocking", 0.40, 0.42, 0.0, 0.0, 0.0],
	"aim": ["2H_Ranged_Shoot", 0.46, 0.32, 0.06, 0.0, -0.08],
	"volley": ["2H_Ranged_Shooting", 0.46, 0.38, 0.07, 0.03, -0.10],
	"skyshot": ["2H_Ranged_Shoot", 0.46, 0.46, -0.18, 0.06, -0.08],
	"bolt": ["Spellcast_Shoot", 0.38, 0.32, -0.09, 0.03, 0.08],
	"weave": ["Spellcasting", 0.36, 0.48, 0.04, 0.07, 0.0],
	"verdict": ["Spellcast_Raise", 1.95, 0.48, 0.10, 0.04, 0.08],
	"raise": ["Spellcast_Raise", 1.04, 0.51, -0.06, 0.12, 0.0],
	"channel": ["Spellcast_Long", 1.48, 0.60, -0.08, 0.20, 0.0],
	"prayer": ["Spellcasting", 0.42, 0.57, 0.09, 0.05, 0.0],
	"invoke": ["Spellcast_Raise", 1.04, 0.57, -0.05, 0.09, 0.0],
	"thrust": ["2H_Melee_Attack_Stab", 0.72, 0.31, -0.13, 0.0, 0.22],
	"spear_sweep": ["2H_Melee_Attack_Slice", 0.48, 0.36, -0.08, 0.04, 0.10],
	"sky_spear": ["2H_Melee_Attack_Stab", 0.72, 0.49, -0.20, 0.16, 0.26],
	"dual_chop": ["Dualwield_Melee_Attack_Chop", 0.52, 0.30, -0.10, 0.02, 0.18],
	"stab": ["1H_Melee_Attack_Stab", 0.40, 0.30, -0.14, 0.0, 0.22],
	"lunge": ["1H_Melee_Attack_Stab", 0.40, 0.36, -0.22, 0.02, 0.42],
	"fling": ["1H_Melee_Attack_Slice_Horizontal", 0.28, 0.32, -0.04, 0.02, 0.04],
	"vanish": ["Dodge_Backward", 0.18, 0.36, 0.08, 0.04, -0.12],
}

## signature / gesture : explicit skill IDs, including support and summon skills.
const GROUPS := {
	"cleave/cleave": "power_strike destroyer sword_of_justice chaos_strike royal_crush chaos_sovereign",
	"cross/cross_cut": "raving triple_impact avenging_crash grand_cross",
	"cleave/draw_cut": "brandish",
	"shield/shield": "impact stagger",
	"greatshield/shield": "shield_bash shield_slam aegis_strike bulwark_charge shield_wave",
	"roar/resolve": "roar war_cry night_lord",
	"focus/resolve": "concentration berserker focus beast_rage killing_focus critical_damage commanders_aura lord_of_command emperors_command",
	"wind/weave": "swift_axe wind_stance",
	"fault/cleave": "bone_crash double_crash",
	"blade/draw_cut": "sword_blast piercing divine_piercing",
	"shield/ward": "holy_valor drastic_spirit godly_shield iron_resolve dragon_stance brace iron_wall thorn_guard unbreakable iron_defense",
	"wings/resolve": "triumph_of_valhalla valkyrie_blessing shadow_sovereign summon",
	"sword_court/cleave": "gladiator",
	"arrow/aim": "wind_arrow perfect_aim elemental_shot perforation lethal_sight",
	"arrow/volley": "arrow_of_rage fierce_wind dragon_shot",
	"rain/skyshot": "avalanche tempest",
	"phoenix/invoke": "scout_hawk golden_falcon",
	"fire/skyshot": "bomb_shot",
	"beast/invoke": "recall_wolverine force_of_nature spirit_cat wolf_pack giant_frog forest_guardian alpha_wolves fire_elemental summon_muspell primal_legion",
	"phoenix/aim": "phoenix_shot",
	"focus/aim": "dionic_sight",
	"roots/skyshot": "ensnare",
	"wind/volley": "hurricane",
	"lightning/aim": "arrow_of_thunder lightning_arrow",
	"phoenix/skyshot": "phoenix_rain",
	"wings/weave": "spirit_of_wind",
	"comet/skyshot": "meteor_arrow",
	"rune/bolt": "agony holy_mind force force_wave chaotic_diseier",
	"fire/bolt": "fire_bolt fire_burst fire_scream fire_blast",
	"shield/weave": "zenith energy_shield holy_reflection",
	"fire/raise": "fire_ball flame_wave",
	"tide/raise": "watornado",
	"rune/weave": "enchant_weapon spirit_elemental vague spirit_link",
	"beam/bolt": "dead_ray sylvan_ray",
	"judgment/verdict": "judgment_ray",
	"fault/raise": "diastrophism earth_shatter",
	"blade/invoke": "dancing_sword",
	"vortex/channel": "distortion spirit_burst",
	"meteor/channel": "meteo hell_meteor armageddon dark_comet",
	"wings/channel": "silraphim heaven_light seraphim_wrath",
	"frost/raise": "slow_speed glacial_spike",
	"lightning/raise": "divine_lightning chain_lightning electric_spike plasma_storm thunder_lord",
	"lightning/channel": "thunder_storm",
	"frost/channel": "ice_storm",
	"focus/channel": "magic_overdrive",
	"sun/bolt": "holy_bolt multi_spark vigor_ball",
	"lotus/prayer": "second_wind healing grand_healing virtual_life regeneration_field hand_of_god prayer regrowth life_bloom gaia_blessing fairy_spirit",
	"sun/raise": "extinction judgement_light divine_judgment infernal_scream imperial_judgment",
	"wings/prayer": "resurrection blessing_aura miracle",
	"rain/raise": "holy_rain_big",
	"cathedral/channel": "last_judgement",
	"thorn/bolt": "thorn_shot nature_wrath",
	"roots/weave": "forest_blessing",
	"roots/bolt": "vine_lash",
	"roots/raise": "entangle thorn_storm cataclysm",
	"spores/raise": "spore_burst",
	"tree/invoke": "ancient_treant world_tree",
	"elder_dragon/channel": "elder_dragon",
	"lance/thrust": "thrust skewer charge_dash impale spear_wave dragon_tooth vanguard_strike dragon_lance gungnir",
	"cyclone/whirl": "round_slash brutal_swing rage_of_zecram cyclone_strike whirl spinning_pike blade_flurry thousand_cuts",
	"cleave/spear_sweep": "hook_strike heaven_rend",
	"wind/spear_sweep": "typhoon_spear gale_cyclone",
	"wings/thrust": "lancer_rush",
	"lance/sky_spear": "sky_pierce",
	"world_spear/sky_spear": "ragnarok_lance",
	"challenge/shield": "provoke grand_provoke",
	"shieldquake/ground_slam": "ground_quake quake_slam titan_quake world_bastion earthshake earth_dominion",
	"shieldflight/spear_throw": "shield_toss rebound_storm",
	"shieldquake/whirl": "shockwave_wall",
	"shieldquake/execution": "bastion_crush",
	"wings/ward": "guardian_oath aegis_of_ages",
	"sun/storm_spin": "holy_rampart",
	"judgment/execution": "judgment_shield",
	"meteor/ground_slam": "meteor_shield",
	"cathedral/ward": "sanctuary_wall",
	"cross/dual_chop": "twin_fang night_raid shadow_dance eclipse_fang",
	"cleave/dual_chop": "crimson_cut",
	"blade/stab": "venom_edge backstab throat_slit",
	"lance/lunge": "shadow_step",
	"blade/fling": "fan_of_knives phantom_daggers phantom_legion birds raven_storm",
	"wind/vanish": "shadow_veil smoke_bomb",
	"rune/vanish": "shadow_clone",
	"spores/fling": "deadly_venom",
	"rune/dual_chop": "death_mark",
	"vortex/whirl": "abyss_vortex",
	"fault/execution": "midnight_execution",
	"cyclone/storm_spin": "oblivion_requiem",
}

## Elite gestures add distinct weight transfer and controlled follow-through.
## twist, lift, step, crouch; applied to the visual rig only, never the actor.
const ELITE_MOTION := {
	"grand_cross": ["storm_spin", .24, .03, .08, .10],
	"sword_of_justice": ["cleave", -.24, .04, .24, .10],
	"godly_shield": ["shield", .08, .02, .08, .07],
	"divine_piercing": ["draw_cut", .32, .02, .22, .07],
	"triumph_of_valhalla": ["resolve", .10, .06, .00, .04],
	"gladiator": ["execution", -.36, .03, .34, .16],
	"tempest": ["skyshot", .14, .03, -.10, .06],
	"lightning_arrow": ["aim", -.14, .01, -.12, .06],
	"phoenix_rain": ["skyshot", .18, .04, -.12, .07],
	"spirit_of_wind": ["resolve", .14, .05, .00, .04],
	"dragon_shot": ["volley", -.18, .02, -.16, .08],
	"meteor_arrow": ["skyshot", .22, .03, -.18, .12],
	"hell_meteor": ["channel", -.08, .12, .02, .05],
	"ice_storm": ["raise", .13, .08, .02, .04],
	"spirit_burst": ["weave", .22, .17, .00, .06],
	"magic_overdrive": ["channel", -.10, .19, .00, .04],
	"judgment_ray": ["verdict", .04, .05, .09, .06],
	"armageddon": ["channel", -.15, .20, .02, .07],
	"divine_judgment": ["raise", .07, .10, .04, .04],
	"prayer": ["prayer", -.04, .05, .00, .03],
	"seraphim_wrath": ["raise", .12, .13, .05, .05],
	"holy_rain_big": ["raise", -.08, .12, .00, .04],
	"miracle": ["prayer", .10, .15, .00, .03],
	"last_judgement": ["channel", -.12, .19, .05, .06],
	"world_tree": ["invoke", -.12, .10, .00, .05],
	"fairy_spirit": ["prayer", -.05, .08, .00, .04],
	"gaia_blessing": ["prayer", -.07, .09, .00, .04],
	"primal_legion": ["invoke", .18, .06, .06, .06],
	"cataclysm": ["raise", -.19, .06, .08, .08],
	"elder_dragon": ["channel", -.15, .18, .04, .07],
	"dragon_lance": ["thrust", .22, .01, .35, .09],
	"gale_cyclone": ["storm_spin", .32, .02, .03, .08],
	"valkyrie_blessing": ["ward", -.08, .06, .00, .05],
	"gungnir": ["spear_throw", -.30, .02, .30, .10],
	"heaven_rend": ["ground_slam", .22, .03, .25, .14],
	"ragnarok_lance": ["sky_spear", -.34, .02, .40, .17],
	"holy_rampart": ["storm_spin", .26, .03, .00, .10],
	"judgment_shield": ["ground_slam", -.32, .03, .30, .15],
	"aegis_of_ages": ["ward", -.06, .06, .00, .05],
	"meteor_shield": ["ground_slam", .10, .55, .38, .18],
	"sanctuary_wall": ["ward", .06, .05, .00, .04],
	"world_bastion": ["ground_slam", -.20, .06, .10, .20],
	"eclipse_fang": ["dual_chop", -.30, .03, .32, .12],
	"abyss_vortex": ["storm_spin", .30, .04, .00, .10],
	"phantom_legion": ["fling", .26, .03, .06, .08],
	"midnight_execution": ["execution", -.34, .10, .36, .16],
	"shadow_sovereign": ["resolve", .12, .06, .00, .05],
	"oblivion_requiem": ["storm_spin", .36, .05, .02, .12],
}

static var _cues: Dictionary = {}

static func cue_for(skill: Dictionary) -> Dictionary:
	if _cues.is_empty():
		for group in GROUPS:
			var parts := String(group).split("/")
			for id in String(GROUPS[group]).split(" ", false):
				_cues[id] = {"signature": parts[0], "gesture": parts[1]}
	var id := String(skill.get("id", ""))
	var cue: Dictionary = _cues.get(id, {"signature": "rune", "gesture": String(skill.get("gesture", "bolt"))})
	var motion: Array = ELITE_MOTION.get(id, [])
	var gesture := String(motion[0]) if not motion.is_empty() else String(cue.gesture)
	var spec: Array = GESTURES[gesture]
	var result := {"signature": cue.signature, "gesture": gesture, "choreographed": _cues.has(id) or skill.has("star"),
		"clip": spec[0], "contact": spec[1], "recovery": spec[2],
		"lean": spec[3], "lift": spec[4], "step": spec[5]}
	if not motion.is_empty():
		result.elite = true
		result.twist = motion[1]
		result.lift = motion[2]
		result.step = motion[3]
		result.crouch = motion[4]
		result.recovery = float(spec[2]) + 0.12
	if id in ["tempest","phoenix_rain","meteor_arrow"]:
		result.upper_pitch = -0.48 if id=="meteor_arrow" else -0.32
	if skill.has("star"):
		result.elite = true
		result.twist = 0.18
		result.crouch = 0.08
		if id == "celestial_swordfall":
			result.recovery = 3.4
			result.sky_sword = true
	return result

static func source_time(cue: Dictionary, elapsed: float, release: float, length: float) -> float:
	var verdict := String(cue.gesture) == "verdict"
	var contact := minf(float(cue.contact), length * (0.98 if verdict else 0.85))
	if bool(cue.get("sky_sword",false)) and elapsed > release:
		return lerpf(contact,length,smoothstep(release+2.62,release+3.4,elapsed))
	if elapsed <= release:
		var t := clampf(elapsed / maxf(release, 0.01), 0.0, 1.0)
		if verdict:
			# Lift the staff, hold the invocation, then drive it down at impact.
			if t < 0.60:
				return lerpf(0.0, 0.55, smoothstep(0.0, 0.60, t))
			if t < 0.78:
				return lerpf(0.55, 1.59, smoothstep(0.60, 0.78, t))
			return lerpf(1.59, contact, smoothstep(0.78, 1.0, t))
		# Gather weight first, accelerate into contact; support spells breathe smoothly.
		var flowing := String(cue.gesture) in ["weave", "prayer", "invoke", "channel", "ward", "resolve"]
		var phase := smoothstep(0.0, 1.0, t) if flowing else t * t * (2.0 - t)
		if bool(cue.get("elite", false)):
			# Three readable beats: preparation, held tension, committed release.
			if flowing:
				phase = smoothstep(0.0, 1.0, t)
			elif t < 0.48:
				phase = 0.30 * smoothstep(0.0, 0.48, t)
			elif t < 0.68:
				phase = lerpf(0.30, 0.38, smoothstep(0.48, 0.68, t))
			else:
				phase = lerpf(0.38, 1.0, smoothstep(0.68, 1.0, t))
		return contact * phase
	return lerpf(contact, length, ease(clampf((elapsed - release) / float(cue.recovery), 0.0, 1.0), 0.72))
