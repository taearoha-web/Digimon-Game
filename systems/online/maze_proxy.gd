class_name MazeProxy
extends PvpProxy
## A real player in เขาวงกตหนึ่งในใต้หล้า as the hero sees it (MazeMatch): like a duel's
## PvpProxy (a Mob riding on their RemotePlayer, targeted and struck like anyone), but
## the hit goes out as `maze_hit` (MazeMatch.send_hit; the server relays it only while both
## stand in the maze), never while the player stands in a shrine's circle.

var maze: MazeMatch


func setup_maze(p_maze: MazeMatch, id: String, node: Node3D, p_hero: Node3D, info: Dictionary) -> void:
	maze = p_maze
	setup_proxy(null, id, node, p_hero, info)
	template["name"] = "⚔ %s" % OnlineTrade.player_name(id)
	# Many of them may stand round: the small bar of a fighter, not a duel's wide one.
	is_boss = false
	live = true
	name = "MazeRival_%s" % id.left(12)


func _follow() -> void:
	if remote == null or not is_instance_valid(remote):
		remote = Online.remote_node(player_id)
		if remote != null:
			visual.model = remote
			visual._flash_meshes.clear()
	if remote != null and is_instance_valid(remote) and remote.is_inside_tree():
		global_position = remote.global_position
	var p: Dictionary = Online.players().get(player_id, {})
	if p.has("max_hp"):
		max_hp = maxi(1, int(p.max_hp))
	if p.has("hp"):
		hp = clampi(int(p.hp), 1, max_hp)
	if p.has("level"):
		level = int(p.level)
	if _bar != null:
		_bar.set_ratio(float(hp) / float(max_hp))


func take_hit(amount: int, crit: bool, color := Color.WHITE, attacker: Node = null) -> bool:
	if maze == null or not is_instance_valid(maze):
		return false
	if attacker != null and attacker != hero and not (attacker is Summon and (attacker as Summon).summoner == hero):
		return false
	if maze.shields(self):
		BattleVfx.floating_text(get_parent(), top_point(), "ที่หลบภัย", Color("9ff7ff"), 0.8)
		return false
	var scaled := maze.send_hit(player_id, amount, crit)
	if scaled <= 0:
		return false
	_bar.visible = true
	_bar_until = Time.get_ticks_msec() * 0.001 + 6.0
	BattleVfx.damage_number(get_parent(), top_point(), str(scaled) + ("!" if crit else ""), false, 1.35 if crit else 1.0)
	if remote != null and is_instance_valid(remote) and remote.has_method("hit_flash"):
		remote.hit_flash(color)
	return false
