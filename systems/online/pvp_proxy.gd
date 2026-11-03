class_name PvpProxy
extends Mob
## The duel opponent as the hero sees it: a [Mob] (group "mobs", so the hero's targeting,
## attacks and skills find it like the arena's Rival) riding on the opponent's
## RemotePlayer, with no AI, no physics and no model of its own. A hit does not take HP
## here: it is sent to the opponent as `pvp_hit` (OnlineDuel.send_hit) at the duel's
## damage scale, shown as a number and a hit flash on the RemotePlayer; the opponent's own
## game applies its defence and dodge. Its HP is the opponent's, from their `state`.

## Who this stands for (an Online player id) and their RemotePlayer.
var player_id := ""
var remote: Node3D
var duel: OnlineDuel
## Hits only count while the fight is on (not during the 3-2-1).
var live := false
## Set by OnlineDuel while a hit of the opponent is applied to the hero: a Thorn Guard
## reflection coming back is halved like against a Rival.
var reflecting := false


func setup_proxy(p_duel: OnlineDuel, id: String, node: Node3D, p_hero: Node3D, info: Dictionary) -> void:
	duel = p_duel
	player_id = id
	remote = node
	hero = p_hero
	monster_id = &"pvp_proxy"
	level = maxi(1, int(info.get("level", 1)))
	max_hp = maxi(1, int(info.get("max_hp", 1)))
	hp = clampi(int(info.get("hp", max_hp)), 1, max_hp)
	# No defence here: the hit goes out raw and the opponent mitigates it (pvp_hit).
	stats = {"hp": max_hp, "atk": 0.0, "def": 0.0, "exp": 0, "gold": 0}
	template = {"name": "⚔ %s" % OnlineTrade.player_name(id), "model": "", "height": 1.9, "speed": 0.0,
		"aggro": false, "attack": "melee", "boss": false, "color": Color.WHITE}
	# The HUD's wide bar shows the opponent like the arena's rival.
	is_boss = true
	hostile = true
	_speed = 0.0
	_base_speed = 0.0
	if node != null:
		home = node.global_position


func _make_visual() -> MonsterVisual:
	var v := MonsterVisual.new()
	v.height = 1.9
	# The flash lands on the RemotePlayer's own meshes; nothing else of the visual runs.
	v.model = remote
	v.set_meta("freeze_expression", true)
	add_child(v)
	return v


func _ready() -> void:
	super._ready()
	set_physics_process(false)
	visual.scale = Vector3.ONE
	# The RemotePlayer has its own name tag and shadow.
	_label.visible = false
	for child in get_children():
		if child is MeshInstance3D and child != _ring:
			child.queue_free()
	_follow()


func _process(_delta: float) -> void:
	_follow()


func _physics_process(_delta: float) -> void:
	pass


func _follow() -> void:
	if remote == null or not is_instance_valid(remote):
		remote = duel.remote() if duel != null else null
		visual.model = remote
		visual._flash_meshes.clear()
	if remote != null and is_instance_valid(remote) and remote.is_inside_tree():
		global_position = remote.global_position
	var p: Dictionary = Online.players().get(player_id, {})
	if p.has("max_hp"):
		max_hp = maxi(1, int(p.max_hp))
	if p.has("hp"):
		# Never "dead" here: the opponent's own game decides the fall (duel_over).
		hp = clampi(int(p.hp), 1, max_hp)
	if p.has("level"):
		level = int(p.level)
	if _bar != null:
		_bar.set_ratio(float(hp) / float(max_hp))


func set_dormant(_on: bool) -> void:
	pass


## The hero (or what it summoned, which hits in the hero's name) struck the opponent.
func take_hit(amount: int, crit: bool, color := Color.WHITE, attacker: Node = null) -> bool:
	if _dead or not live or duel == null:
		return false
	if attacker != null and attacker != hero:
		return false
	var scaled := duel.send_hit(amount, crit, reflecting)
	if scaled <= 0:
		return false
	_bar.visible = true
	_bar_until = Time.get_ticks_msec() * 0.001 + 6.0
	BattleVfx.damage_number(get_parent(), top_point(), str(scaled) + ("!" if crit else ""), false, 1.35 if crit else 1.0)
	if remote != null and is_instance_valid(remote) and remote.has_method("hit_flash"):
		remote.hit_flash(color)
	else:
		visual.flash(Color(1, 1, 1))
	return false


# The opponent's own game moves, stuns and marks it: nothing of that runs here.
func knock_back(_from: Vector3, _strength := 2.5) -> void:
	pass


func shove_out(_center: Vector3, _radius: float) -> void:
	pass


func apply_stun(_seconds: float) -> void:
	pass


func apply_slow(_seconds: float) -> void:
	pass


func apply_freeze(_seconds: float) -> void:
	pass


func apply_burn(_dps: float, _seconds: float) -> void:
	pass


func apply_shred(_fraction: float, _seconds: float) -> void:
	pass


func apply_weaken(_fraction: float, _seconds: float) -> void:
	pass


func taunt(_by: Node3D, _seconds: float) -> void:
	pass


func provoke(_alert_pack := true) -> void:
	pass


func _die() -> void:
	pass
