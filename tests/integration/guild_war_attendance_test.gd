extends Node
## The world's AI players come to their guild's war as they really are (GuildWarData,
## WorldPlayers, WorldGear): every league round each guild fields its GUILD_SIDE strongest
## members at Lv.100, online or offline, hunting, on an errand or resting (nobody skips a
## war); each fights with its own level, stars, job and the very pieces it forged with
## their + (WorldGear.equip_at_work), the same on every device; the spawned fighter carries
## that sheet; the side never grows past GUILD_SIDE.
##   godot --headless --path . res://tests/integration/guild_war_attendance_test.tscn
var failures := 0
var checks := 0
const DAY := 86400.0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	WorldPlayers.clear_bonus()
	WorldPlayers.reset_roster()
	WorldEvents.festival_enabled = false
	var w := GuildLeague.week_of(float(WorldPlayers.START_UNIX) + 21.0 * DAY)
	var day := WorldEvents.day_of(GuildLeague.week_start(w)) + 1
	var offline_seen := 0
	var busy_seen := 0
	var plus_seen := 0
	for k in 3:
		var at := GuildLeague.slot_start(day + k, k)
		var seen := _round(at)
		offline_seen += int(seen.offline)
		busy_seen += int(seen.busy)
		plus_seen += int(seen.plus)
	check(offline_seen > 0, "offline members still come to the war (%d)" % offline_seen)
	check(busy_seen > 0, "members busy in the world (hunting, a stall, an errand) still come (%d)" % busy_seen)
	check(plus_seen > 0, "the fighters wear their forged + (%d pieces)" % plus_seen)
	_spawned(GuildLeague.slot_start(day, 0))
	print("GUILD WAR ATTENDANCE: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


## One league round at `at`: who comes and what they wear.
func _round(at: int) -> Dictionary:
	var t := float(at)
	var out := {"offline": 0, "busy": 0, "plus": 0}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var war := GuildWarData.roll_guild_war(rng, GuildLeague.guilds_at(at), t, -1.0, false)
	check(not war.is_empty() and (war.sides as Array).size() == 4, "round %s: all four guilds fight" % GuildLeague.clock_text(at))
	if war.is_empty():
		return out
	var again := GuildWarData.roll_guild_war(rng, GuildLeague.guilds_at(at), t, -1.0, false)
	for s in (war.sides as Array).size():
		var sd: Dictionary = war.sides[s]
		var g := int(sd.guild)
		var lineup: Array = sd.lineup
		var members := WorldPlayers.members_at(g, t)
		var want := GuildWarData.best_members(g, t, GuildWarData.GUILD_SIDE)
		var name := WorldPlayers.guild_name(g)
		# Attendance: the strongest members, all of them, never more than the side.
		check(lineup.size() == mini(members.size(), GuildWarData.GUILD_SIDE) and lineup.size() <= GuildWarData.GUILD_SIDE,
			"%s sends %d of %d members (side %d)" % [name, lineup.size(), members.size(), GuildWarData.GUILD_SIDE])
		var ids := {}
		for f in lineup:
			ids[int(f.world)] = true
		check(want.all(func(i): return ids.has(i)), "%s: every one of its strongest %d is there" % [name, want.size()])
		# The same on every device: rolled again, the same people in the same order.
		var again_ids: Array = (again.sides[s].lineup as Array).map(func(f): return int(f.world))
		check(again_ids == lineup.map(func(f): return int(f.world)), "%s: the line-up is the same rolled again" % name)
		# Each one as it really is.
		var real := true
		var why := ""
		for f in lineup:
			var i := int(f.world)
			var st := WorldPlayers.state(i, t)
			if not bool(st.online):
				out.offline += 1
			elif String(st.get("doing", "")) != "":
				out.busy += 1
			var sheet: Dictionary = f.profile
			if int(f.member.level) != int(st.level) or int(sheet.level) != int(st.level) or int(sheet.paragon.level) != int(st.stars):
				real = false
				why = "%s level/stars" % st.name
				continue
			if String(f.member["class"]) != String(st["class"]):
				real = false
				why = "%s class" % st.name
				continue
			var own := WorldGear.equip_at_work(i, WorldPlayers.work_at(i, t))
			var worn: Dictionary = sheet.equip
			if worn.size() != own.size():
				real = false
				why = "%s gear slots %d / %d" % [st.name, worn.size(), own.size()]
				continue
			for slot in own:
				var a: Dictionary = own[slot]
				var b: Variant = worn.get(slot)
				if not b is Dictionary or String(b.get("name", "")) != String(a.get("name", "")) or int(b.get("plus", 0)) != int(a.get("plus", 0)):
					real = false
					why = "%s %s" % [st.name, slot]
				elif int(a.get("plus", 0)) > 0:
					out.plus += 1
			if absf(float(f.power) - GuildWarData.power_of(HeroStats.compute(sheet))) > 0.01:
				real = false
				why = "%s power" % st.name
		check(real, "%s fights with its members' own level, stars, class and forged gear %s" % [name, why])
	return out


## A spawned fighter carries the world player's own sheet: its gear, level and the power
## its stats give.
func _spawned(at: int) -> void:
	var t := float(at)
	var g := int(GuildLeague.guilds_at(at)[0])
	var i := GuildWarData.best_members(g, t, 1)[0]
	var info := WorldPlayers.fighter(i, t)
	var fighter := SiegeFighter.new()
	fighter.setup_fighter(info, GuildFighter.TEAM_ALLY, null, Vector3.ZERO, "[%s]" % WorldPlayers.guild_name(g))
	var own := WorldGear.equip_at_work(i, WorldPlayers.work_at(i, t))
	var same := true
	for slot in own:
		var e: Variant = fighter._equip.get(slot)
		same = same and e is Dictionary and String(e.name) == String(own[slot].name) and int(e.get("plus", 0)) == int(own[slot].get("plus", 0))
	check(same, "the spawned fighter %s wears its own forged gear" % WorldPlayers.entry(i).name)
	check(fighter.level == int(WorldPlayers.state(i, t).level) and fighter.max_hp == int(HeroStats.compute(info.profile).max_hp), "and fights at its own level and HP (%d)" % fighter.max_hp)
	check(fighter.tag == WorldPlayers.level_text(WorldPlayers.state(i, t)), "its tag shows its level and stars (%s)" % fighter.tag)
	fighter.free()
