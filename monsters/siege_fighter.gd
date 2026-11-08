class_name SiegeFighter
extends GuildFighter
## A GuildFighter in a castle war of any number of guilds (GuildWarMatch: two in a
## practice war, all four in a league round). Friend or foe is the GuildFighter's own
## (anyone of another team is a foe); this one only shows its guild's own colour on its
## name and crown when more than two guilds fight.


func _ready() -> void:
	super._ready()
	# The name in its own guild's colour (the base knows only "ours" and "theirs").
	if team != TEAM_ALLY and siege != null and is_instance_valid(siege) and siege.team_count() > 2 and _label != null and not is_leader:
		_label.modulate = siege.team_color(team).lerp(Color.WHITE, 0.35)


func make_leader() -> void:
	super.make_leader()
	if _label != null and siege != null and is_instance_valid(siege):
		_label.modulate = siege.team_color(team).lerp(Color.WHITE, 0.2)
