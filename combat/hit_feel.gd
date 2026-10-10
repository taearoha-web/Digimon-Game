class_name HitFeel
extends RefCounted
## What makes a hit feel heavy besides the picture: a split-second hitstop on
## crits and big skills, and element debris flying off the target.

const STOP_GAP_MS := 180

static var _stopped := false
static var _last_stop := 0


## Freezes the game for [param seconds] of real time (very slow time, not a pause,
## so input and UI keep running). Never chains: AoE hits share one stop.
static func hitstop(tree: SceneTree, seconds: float) -> void:
	if _stopped or tree == null:
		return
	var now := Time.get_ticks_msec()
	if now - _last_stop < STOP_GAP_MS:
		return
	_last_stop = now
	_stopped = true
	var before := Engine.time_scale
	Engine.time_scale = 0.06
	tree.create_timer(seconds, true, false, true).timeout.connect(func():
		Engine.time_scale = before if before > 0.06 else 1.0
		_stopped = false, CONNECT_ONE_SHOT)


## How long a hit stops: crits a little, big skills more, both the most.
static func stop_for(crit: bool, mult: float) -> float:
	var big := mult >= 6.0
	if crit and big:
		return 0.075
	if big:
		return 0.05
	return 0.035 if crit else 0.0


## Bits of the skill's element thrown off the target.
static func debris(parent: Node3D, pos: Vector3, skill: Dictionary) -> void:
	if skill.is_empty() or not VfxBudget.can_decorate(1):
		return
	var color: Color = skill.get("color", Color.WHITE)
	match SkillShow.style_of(skill):
		"fire":
			VfxArt.motes(parent, pos, Color("ffb050"), "ember", 10, 0.6, 1.2, 0.8)
		"ice":
			VfxArt.motes(parent, pos, Color("d8f4ff"), "snow", 9, 0.7, 0.4, 0.7)
		"thunder":
			VfxKit.sparks(parent, pos, Color("fff6a0"), 12, 6.0, 0.25)
		"leaf":
			VfxArt.motes(parent, pos, color, "leaf", 8, 0.7, 0.8, 0.9)
		"holy", "heal":
			VfxArt.motes(parent, pos, Color("fff0b0"), "star", 8, 0.6, 1.0, 0.8)
		"arcane":
			VfxArt.motes(parent, pos, color.lightened(0.3), "diamond", 8, 0.6, 0.8, 0.8)
		"earth":
			VfxKit.sparks(parent, pos - Vector3(0, 0.6, 0), Color("c9a07a"), 14, 4.0, 0.5)
		_:
			VfxKit.sparks(parent, pos, color.lightened(0.4), 10, 5.5, 0.3)
