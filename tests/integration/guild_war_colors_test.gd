extends Node
## Every guild keeps its own colour in a league war, whatever team slot it takes and
## whichever guild the hero is in: Alpha gold, Neverdie rose, Titan blue, 3DLnw green
## (WorldPlayers.GUILD_COLORS), also in a round mirrored online (only team_guilds known,
## no "guilds" roster flag) — never the team order's blue / red / green / orange. The war's
## lists colour each guild by name the same way; a practice war keeps blue / red.
##   godot --headless --path . res://tests/integration/guild_war_colors_test.tscn
var failures: Array[String] = []
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func _ready() -> void:
	var C := WorldPlayers.GUILD_COLORS
	var orders := [
		[WorldPlayers.LNW, WorldPlayers.ALPHA, WorldPlayers.NEVERDIE, WorldPlayers.TITAN],
		[WorldPlayers.TITAN, WorldPlayers.LNW, WorldPlayers.ALPHA, WorldPlayers.NEVERDIE],
		[WorldPlayers.NEVERDIE, WorldPlayers.TITAN, WorldPlayers.LNW, WorldPlayers.ALPHA],
	]
	for order in orders:
		var m := GuildWarMatch.new()
		m._ensure_teams(4)
		# Mirrored online: the roster carries no "guilds" flag, only the sides' guilds.
		m.roster = {}
		for t in 4:
			m.team_guilds[t] = int(order[t])
		check(m.guild_colored(), "a league war wears guild colours (%s)" % [order])
		for t in 4:
			var g := int(order[t])
			check(m.team_color(t) == C[g], "%s at team %d is its own colour, got %s" % [WorldPlayers.GUILD_NAMES[g], t, m.team_color(t)])
		m.free()
	check(C[WorldPlayers.LNW] == Color("8dff7a"), "3DLnw is green")
	# A practice war: blue / red by team.
	var p := GuildWarMatch.new()
	p._ensure_teams(2)
	p.roster = {}
	check(not p.guild_colored(), "a practice war has no guild colours")
	check(p.team_color(0) == GuildWarMatch.HIRED_COLORS[0] and p.team_color(1) == GuildWarMatch.HIRED_COLORS[1], "a practice war is blue / red")
	p.free()
	# The war's lists: by guild name.
	var lnw := GuildWarScreen._side_color("3DLnw", 0)
	check(lnw.g > lnw.b and lnw.g > lnw.r, "3DLnw's rows are green even as our side (%s)" % lnw)
	var titan := GuildWarScreen._side_color("Titan", 1)
	check(titan.b > titan.r, "Titan's rows are blue (%s)" % titan)
	check(GuildWarScreen._side_color("กิลด์รับจ้าง", 1) == Color("ff9a8a"), "a hired guild keeps the enemy rose")
	print("GUILD WAR COLORS: %s | %d checks, %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
