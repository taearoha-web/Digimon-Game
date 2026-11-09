class_name StoryStage
extends Node
## บัลลังก์เงา (StoryChapter2.STAGE_ID): the chapter's finale stage, a node on the Zone
## like TowerRun. After a short intro the queen (shadow_queen) rises at the throne with
## StoryBoss moves; her three phases follow the Mob's own HP phases (70% and 40%): each
## one stops her for a moment and speaks a line (`speech`, shown as a dialog interrupt),
## widens her move set and shortens her cycle. Her death ends the stage (`finished`
## {won: true}) after END_DELAY; StoryChapter then plays the ending and pays the quest.
## The hero falling is the game's ordinary death (Main sends the hero home; the stage is
## built afresh next time).

signal finished(result: Dictionary)
signal speech(speaker: String, text: String)
signal phase_started(phase: int)

const INTRO := 3.0
const END_DELAY := 2.6
const THRONE := Vector3(22, 0, 0)
const BOSS_LEVEL := EndgameFields.BOSS_LEVEL + 10
## Move sets by phase and their cycle haste.
const PHASE_MOVES := [["lance", "nova"], ["lance", "rain", "nova", "veil"], ["rain", "lance", "veil", "nova", "lance"]]
const PHASE_HASTE := [1.0, 0.8, 0.62]
const PHASE_STUN := 2.4

var zone: Node3D
var hero: Node3D
var state := "intro"
var boss: Mob
var phase := 0
var result: Dictionary = {}
var _timer := INTRO
var _end_timer := 0.0


func setup(p_zone: Node3D, p_hero: Node3D) -> void:
	zone = p_zone
	hero = p_hero


func _ready() -> void:
	name = "StoryStage"
	if zone != null and "banner_requested" in zone:
		zone.banner_requested.emit("%s · %s" % [StoryChapter2.STAGE_TITLE, StoryChapter2.VILLAIN])
	Game.say("บัลลังก์เงา: ราชินีเงามี 3 ช่วง หลบรูปร่างสีม่วงบนพื้น แล้วฟันเธอให้ล้ม", &"quest")


func _process(delta: float) -> void:
	if not is_instance_valid(zone) or not is_instance_valid(hero):
		queue_free()
		return
	step(delta)


## One step of the stage (tests drive it with big deltas).
func step(delta: float) -> void:
	match state:
		"intro":
			_timer -= delta
			if _timer <= 0.0:
				spawn_boss()
		"fight":
			if boss == null or not is_instance_valid(boss) or boss.is_dead():
				_win()
		"ending":
			_end_timer -= delta
			if _end_timer <= 0.0:
				state = "done"
				finished.emit(result)


func spawn_boss() -> void:
	if state != "intro":
		return
	state = "fight"
	boss = Mob.new()
	boss.setup(&"shadow_queen", BOSS_LEVEL, THRONE, hero)
	boss.position = THRONE + Vector3(0, 0.3, 0)
	zone.add_child(boss)
	boss.hostile = true
	var moves := StoryBoss.new()
	moves.setup(boss, zone, PHASE_MOVES[0], StoryChapter2.QUEEN_ADDS)
	boss.add_child(moves)
	boss.phase_changed.connect(_on_phase)
	boss.died.connect(func(_m: Mob): _win())
	VfxKit.shockwave(zone, THRONE + Vector3(0, 0.1, 0), StoryBoss.COLOR, 9.0)
	_say(0)
	phase_started.emit(0)


## The Mob's HP phases (1 at 70%, 2 at 40%): a line, a pause and a wider move set.
func _on_phase(_mob: Mob, p: int) -> void:
	if p <= phase or p >= PHASE_MOVES.size():
		return
	phase = p
	boss.apply_stun(PHASE_STUN)
	var moves := StoryBoss.of(boss)
	if moves:
		moves.set_moves(PHASE_MOVES[p], PHASE_HASTE[p])
	if zone != null and "banner_requested" in zone:
		zone.banner_requested.emit("ช่วงที่ %d: %s" % [p + 1, ["หอกเงา", "ม่านเงาและฝนดาวดับ", "คลั่งสุดขีด"][p]])
	_say(p)
	phase_started.emit(p)


func _say(k: int) -> void:
	var line := String(StoryChapter2.QUEEN_LINES[clampi(k, 0, StoryChapter2.QUEEN_LINES.size() - 1)])
	var parts := line.split(": ", true, 1)
	speech.emit(parts[0] if parts.size() > 1 else StoryChapter2.VILLAIN, parts[1] if parts.size() > 1 else line)


func _win() -> void:
	if state != "fight":
		return
	state = "ending"
	_end_timer = END_DELAY
	result = {"won": true, "phase": phase}
	if zone != null and "banner_requested" in zone:
		zone.banner_requested.emit("เงาเหนือดวงดาวดับแล้ว!")
	AudioManager.play_sfx(&"quest_complete")
