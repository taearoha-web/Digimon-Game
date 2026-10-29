extends Node
## A world player in the hero's party levels by the party's shared EXP only: its own
## schedule stops counting while it is in the party (it used to keep both, so a Lv.12
## friend reached Lv.22 while the hero went from 13 to 20), and carries on from where the
## party left it once it leaves.

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	Game.set_process(false)
	WorldPlayers.persist = false
	WorldPlayers.clear_bonus()
	WorldPresence.enabled = true
	var t0 := float(WorldPlayers.START_UNIX) + 2.4 * 86400.0
	WorldPresence.clock_offset = t0 - WorldPlayers.now()
	Game.new_profile(&"warrior", "ปาร์ตี้QA", FaceKit.default_look())
	# Someone online now who keeps playing over the next three hours.
	var who := -1
	for i in WorldPlayers.size():
		var s := WorldPlayers.state(i, t0)
		if bool(s.online) and WorldPlayers.played_minutes(i, t0 + 3.0 * 3600.0) > WorldPlayers.played_minutes(i, t0) + 30.0:
			who = i
			break
	check(who >= 0, "a player who keeps playing is online")
	if who < 0:
		_finish()
		return
	var level0 := int(WorldPlayers.state(who, t0).level)
	Game.profile.level = level0
	check(Game.party_invite(who) == "", "the player joins")
	var own0 := WorldPlayers.own_minutes(who, t0)
	# Three hours in the party with no kills: no progress from its own schedule.
	var t1 := t0 + 3.0 * 3600.0
	WorldPresence.clock_offset = t1 - WorldPlayers.now()
	check(is_equal_approx(WorldPlayers.own_minutes(who, t1), own0), "its own play stops counting in the party (%.1f -> %.1f min)" % [own0, WorldPlayers.own_minutes(who, t1)])
	check(int(WorldPlayers.state(who, t1).level) == level0, "its level stays where the party found it (Lv.%d -> Lv.%d)" % [level0, int(WorldPlayers.state(who, t1).level)])
	# The party's kills: its share of the EXP levels it.
	var lvl := level0
	for k in 40:
		WorldPlayers.add_exp(who, 20000.0, lvl, 0)
		lvl = int(WorldPlayers.state(who, t1).level)
	check(lvl > level0, "the party's shared EXP levels it (Lv.%d -> Lv.%d)" % [level0, lvl])
	# It leaves: the party time is skipped and its schedule carries on from there.
	Game.party_kick(who)
	check(not WorldPlayers.paused.has(String(WorldPlayers.entry(who).name)), "leaving resumes its schedule")
	check(int(WorldPlayers.state(who, t1).level) == lvl, "it keeps the level the party gave it (Lv.%d)" % int(WorldPlayers.state(who, t1).level))
	var t2 := t1 + 3600.0
	var gained := WorldPlayers.own_minutes(who, t2) - WorldPlayers.own_minutes(who, t1)
	var played := WorldPlayers.played_minutes(who, t2) - WorldPlayers.played_minutes(who, t1)
	check(gained >= 0.0 and is_equal_approx(gained, played), "after the party only the minutes it plays count (%.1f of %.1f)" % [gained, played])
	# Letting the whole party go resumes everyone.
	WorldPresence.clock_offset = t2 - WorldPlayers.now()
	Game.party_invite(who, true)
	Game.dismiss_party()
	check(WorldPlayers.paused.is_empty(), "dismissing the party resumes every schedule")
	_finish()


func _finish() -> void:
	print("PARTY EXP: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
