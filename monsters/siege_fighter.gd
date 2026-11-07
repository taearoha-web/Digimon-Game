class_name SiegeFighter
extends GuildFighter
## A GuildFighter in a castle war of any number of guilds (GuildWarMatch: two in a
## practice war, all four in a league round). Everything is the GuildFighter's but who is
## friend or foe: everyone of another team is an enemy, everyone of its own team a friend
## (the hero and its summons are team 0's), and a camp is safe for the guild it belongs to
## (SiegeArena.camp). The lists come from the match, worked out once a physics frame for
## all the fighters together (GuildWarMatch.hostiles / friends) instead of each fighter
## walking the scene's groups.


func _ready() -> void:
	super._ready()
	# The name in its own guild's colour (the base knows only "ours" and "theirs").
	if team != TEAM_ALLY and siege != null and is_instance_valid(siege) and siege.team_count() > 2 and _label != null and not is_leader:
		_label.modulate = siege.team_color(team).lerp(Color.WHITE, 0.35)


func make_leader() -> void:
	super.make_leader()
	if _label != null and siege != null and is_instance_valid(siege):
		_label.modulate = siege.team_color(team).lerp(Color.WHITE, 0.2)


func _summons_are_enemies() -> bool:
	return team != TEAM_ALLY


func _targets() -> Array[Node3D]:
	if siege == null or not is_instance_valid(siege):
		return super._targets()
	var out: Array[Node3D] = []
	for node in siege.hostiles(team):
		# Worked out once a frame: one freed since (a summon gone) is left out.
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			out.append(node)
	# The leader's online party fights on team 0's side (EntitySync).
	if team != TEAM_ALLY and EntitySync.hosting():
		_add_remote_targets(out)
	# Every guild batters the same gates.
	if objective != null and is_instance_valid(objective) and objective.breakable and not objective.is_dead():
		out.append(objective)
	return out


func _teammates() -> Array[Node3D]:
	if siege == null or not is_instance_valid(siege):
		return super._teammates()
	var out: Array[Node3D] = []
	for node in siege.friends(team):
		if node != self and is_instance_valid(node):
			out.append(node)
	return out


## True for someone standing in its own guild's camp (where it heals and comes back).
func _in_own_camp(t: Node3D) -> bool:
	if t is CastleGate:
		return false
	var their := 0
	if t is GuildFighter:
		their = (t as GuildFighter).team
	elif t is Summon:
		their = TEAM_ALLY
	elif t is SummonMob:
		var caster: Variant = (t as SummonMob).caster
		their = (caster as GuildFighter).team if caster is GuildFighter and is_instance_valid(caster) else TEAM_ENEMY
	var home := SiegeArena.camp(their)
	return _flat_distance_from(t.global_position, home) < SiegeArena.CAMP_RADIUS
