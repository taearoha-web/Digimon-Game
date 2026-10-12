class_name TowerRun
extends Node
## One climb of the Void Tower: spawns each floor's monsters, pays the floor
## reward when they are all dead, rests a few seconds and goes up. Ends when
## the hero falls (no penalty: the floors reached and the shards are kept).

signal finished(result: Dictionary)

var zone: Node3D
var hero: Hero
var floor_no := 1
var start_floor := 1
var state := "intro"

var _timer := 3.5
var _mobs: Array[Mob] = []
var _rng := RandomNumberGenerator.new()
var _shards := 0
var _gold := 0
var _end_timer := 0.0
var _result: Dictionary = {}
var _pending: Array[Dictionary] = []
var last_spawn_ms := 0.0
var peak_spawn_ms := 0.0


func setup(p_zone: Node3D, p_hero: Hero, p_start: int) -> void:
	zone = p_zone
	hero = p_hero
	start_floor = p_start
	floor_no = p_start


func _ready() -> void:
	_rng.randomize()
	zone.banner_requested.emit("หอคอยห้วงวิบัติ · เริ่มที่ชั้น %d" % floor_no)
	Game.say("ฆ่ามอนสเตอร์ให้หมดเพื่อขึ้นชั้นถัดไป ตายแล้วไม่เสียอะไร (เก็บรางวัลที่ได้ไว้)", &"quest")


func _process(delta: float) -> void:
	if not is_instance_valid(hero) or not is_instance_valid(zone):
		queue_free()
		return
	match state:
		"intro", "rest":
			_timer -= delta
			if _timer <= 0.0:
				_start_floor()
		"spawning":
			if hero.is_dead():
				_discard_pending_wave()
				_end()
			else:
				_spawn_one()
		"fight":
			_mobs = _mobs.filter(func(m): return is_instance_valid(m) and not m.is_dead())
			if hero.is_dead():
				_end()
			elif _mobs.is_empty():
				_clear_floor()
		"ending":
			_end_timer -= delta
			if _end_timer <= 0.0:
				state = "done"
				finished.emit(_result)


func _start_floor() -> void:
	if state == "spawning": return
	state = "spawning"
	_mobs.clear()
	_pending.clear()
	var plan := TowerData.spec(floor_no, _rng)
	zone.banner_requested.emit(("ชั้น %d · บอส!" if plan.boss else "ชั้น %d") % floor_no)
	var hp_m := TowerData.hp_mult(floor_no)
	var atk_m := TowerData.atk_mult(floor_no)
	var ids: Array = plan.ids
	for i in ids.size():
		var angle := TAU * float(i) / float(ids.size()) + _rng.randf() * 0.4
		var spot := hero.global_position + Vector3(cos(angle), 0, sin(angle)) * _rng.randf_range(9.0, 14.0)
		spot.y = 0.0
		_pending.append({"id":ids[i],"spot":spot,"hp":hp_m,"atk":atk_m})


## Instantiate at most ONE model per rendered frame, even after a long frame.
## The complete wave becomes targetable together; no early kill/reward exploit.
func _spawn_one() -> void:
	if _pending.is_empty(): return
	var start := Time.get_ticks_usec()
	var entry:Dictionary = _pending.pop_front()
	var mob := Mob.new()
	mob.setup(entry.id,100,entry.spot,hero)
	mob.stats["hp"] = int(float(mob.stats.hp)*float(entry.hp))
	mob.stats["atk"] = int(float(mob.stats.atk)*float(entry.atk))
	mob.hp=int(mob.stats.hp);mob.max_hp=mob.hp
	mob.position=entry.spot+Vector3(0,0.3,0)
	zone.add_child(mob)
	mob.visible=false
	mob.process_mode=Node.PROCESS_MODE_DISABLED
	mob.remove_from_group("mobs")
	mob.visual.remove_from_group("anim_lod")
	_mobs.append(mob)
	last_spawn_ms=float(Time.get_ticks_usec()-start)/1000.0
	peak_spawn_ms=maxf(peak_spawn_ms,last_spawn_ms)
	if _pending.is_empty():
		for ready_mob in _mobs:
			ready_mob.add_to_group("mobs")
			ready_mob.visual.add_to_group("anim_lod")
			ready_mob.visible=true
			ready_mob.process_mode=Node.PROCESS_MODE_INHERIT
			ready_mob.provoke(false)
		state="fight"


func _discard_pending_wave() -> void:
	_pending.clear()
	for mob in _mobs:
		if is_instance_valid(mob): mob.queue_free()
	_mobs.clear()


func _exit_tree() -> void:
	if state=="spawning": _discard_pending_wave()


func _clear_floor() -> void:
	var gold := TowerData.gold_reward(floor_no)
	var shards := TowerData.shard_reward(floor_no)
	_gold += gold
	_shards += shards
	Game.add_gold(gold)
	Game.tower_add_shards(shards)
	Game.tower_floor_cleared(floor_no)
	zone.banner_requested.emit("ชั้น %d สำเร็จ!" % floor_no)
	Game.say("ชั้น %d: เหรียญ +%d · ผลึกห้วงวิบัติ +%d" % [floor_no, gold, shards], &"success")
	AudioManager.play_sfx(&"quest_complete", -2.0)
	hero.receive_heal(0.35)
	floor_no += 1
	state = "rest"
	_timer = 6.0


func _end() -> void:
	state = "ending"
	_end_timer = 2.4
	var reached := floor_no - 1 if floor_no > start_floor or _shards > 0 else maxi(0, floor_no - 1)
	_result = {
		"floor": floor_no, "cleared": floor_no - start_floor, "shards": _shards, "gold": _gold,
		"best": int(Game.tower().best), "new_best": int(Game.tower().best) > int(Game.tower().get("best_before", 0)),
		"start": start_floor, "reached": reached,
	}
	zone.banner_requested.emit("จบการปีนหอคอย · ถึงชั้น %d" % floor_no)
	var stats := Game.stats_now()
	Game.profile["hp"] = stats.max_hp
	Game.profile["mp"] = stats.max_mp
	Game.save()
