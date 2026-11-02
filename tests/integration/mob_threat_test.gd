extends Node3D
## Field monsters go for whoever hits them hardest (Mob threat), else the closest;
## the Defender's taunt still pulls them; rivals keep their own targeting.
var checks := 0
var failures := 0

class Victim:
	extends Node3D
	var dead := false
	func is_dead() -> bool: return dead
	func take_damage(_amount: float, _source: Node) -> void: pass


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", note)

func victim(at: Vector3, group: String) -> Victim:
	var v := Victim.new()
	add_child(v)
	v.position = at
	if group != "":
		v.add_to_group(group)
	return v

func _ready() -> void:
	Game.set_process(false)
	var hero := victim(Vector3(2, 0, 0), "")
	var ally := victim(Vector3(8, 0, 0), "companions")
	var player := victim(Vector3(0, 0, 9), "world_players")
	var mob := Mob.new()
	mob.setup(&"pink_slime", 1, Vector3.ZERO, hero)
	add_child(mob)
	mob.position = Vector3.ZERO
	mob.max_hp = 10000000
	mob.hp = 10000000
	mob.set_physics_process(false)
	await get_tree().process_frame
	check(mob._pick_victim() == hero, "nobody hit it yet: the closest (the hero)")
	mob.take_hit(300, false, Color.WHITE, ally)
	mob.take_hit(100, false, Color.WHITE, hero)
	check(mob._pick_victim() == ally, "the companion hit hardest: it goes for the companion, not the closer hero")
	mob.take_hit(900, false, Color.WHITE, player)
	check(mob._pick_victim() == player, "a world player who hits harder takes it over")
	mob.take_hit(2000, false, Color.WHITE, hero)
	check(mob._pick_victim() == hero, "the hero out-damages them all and has it back")
	check(is_equal_approx(mob.threat_of(hero), 2100.0) or mob.threat_of(hero) > 2000.0, "threat adds up the hero's hits")
	# Hits without an attacker (environment) add nothing.
	var before := mob._threat.size()
	mob.take_hit(5000, false, Color.WHITE, null)
	check(mob._threat.size() == before and mob._pick_victim() == hero, "a hit with no attacker adds no threat")
	# Dead or out of reach: the next in line.
	hero.dead = true
	check(mob._pick_victim() == player, "the top hitter fell: the next hardest hitter")
	hero.dead = false
	mob.take_hit(5000, false, Color.WHITE, player)
	check(mob._pick_victim() == player, "the world player is on top now")
	player.position = Vector3(0, 0, Mob.LEASH + Mob.THREAT_REACH + 5.0)
	# (The hero's threat was dropped when it fell, so the companion is next.)
	check(mob._pick_victim() == ally, "a hitter far beyond the leash is not chased: the next one")
	player.position = Vector3(0, 0, 9)
	# Threat fades: an old hit counts half every THREAT_HALF_LIFE seconds.
	for key in mob._threat:
		mob._threat[key].at = float(mob._threat[key].at) - Mob.THREAT_HALF_LIFE * 20.0
	check(mob._pick_victim() == hero and mob._threat.is_empty(), "long-faded threat is forgotten: back to the closest")
	mob.take_hit(50, false, Color.WHITE, ally)
	var fresh := mob.threat_of(ally)
	mob._threat[ally.get_instance_id()].at = float(mob._threat[ally.get_instance_id()].at) - Mob.THREAT_HALF_LIFE
	check(absf(mob.threat_of(ally) - fresh * 0.5) < 1.0, "threat halves after THREAT_HALF_LIFE")
	# The hero's own hits name the hero as the attacker (Hero._hit passes self).
	var hero_src := FileAccess.get_file_as_string("res://characters/hero.gd")
	check(hero_src.contains("mob.take_hit(amount, crit, color, self)"), "the hero's hits are credited to the hero")
	# Going home forgets the fight.
	mob._threat.clear()
	mob.take_hit(100, false, Color.WHITE, ally)
	mob._returning = true
	mob.hostile = false
	mob.global_position = mob.home
	mob.set_physics_process(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	mob.set_physics_process(false)
	check(mob._threat.is_empty(), "back home, the monster forgets who hit it")
	# The Defender's taunt still wins over threat while it lasts.
	mob.take_hit(9000, false, Color.WHITE, player)
	mob.taunt(ally, 5.0)
	check(mob._victim == ally and mob._victim_timer >= 5.0, "a taunt pulls it to the Defender for its seconds")
	# Rivals (duel, guild war) keep their own targeting.
	var rival := Rival.new()
	check(rival.has_method("_pick_victim"), "rivals override the pick")
	rival.free()
	mob.queue_free()
	await get_tree().process_frame
	print("MOB THREAT: ", checks, " checks, ", failures, " failures")
	get_tree().quit(failures)
