extends Node
## When each world player reaches its milestones (days after the world opened) and how
## many hours a week it plays.
##   godot --headless --path . res://tests/tools/world_timeline.tscn
func _ready() -> void:
	var start := float(WorldPlayers.START_UNIX)
	var marks := [[10, 0], [50, 0], [100, 0], [100, 50], [100, 100], [100, 200]]
	for i in WorldPlayers.size():
		var e: Dictionary = WorldPlayers.entry(i)
		var line := "%-16s %-9s %-9s %5.1f h/wk eff %.2f |" % [e.name, e["class"], e.style, WorldPlayers.played_minutes(i, start + 28 * 86400) / 60.0 / 4.0, WorldPlayers.efficiency(i)]
		var day := 0.0
		for m in marks:
			while day < 400.0:
				var s: Dictionary = WorldPlayers.state(i, start + day * 86400.0)
				if int(s.level) > int(m[0]) or (int(s.level) == int(m[0]) and int(s.stars) >= int(m[1])):
					break
				day += 0.25
			line += " %s %5.1fd" % ["Lv%d" % m[0] if m[1] == 0 else "★%d" % m[1], day]
		print(line)
	get_tree().quit()
