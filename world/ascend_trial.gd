class_name AscendTrial
extends Node
## ลานบททดสอบเทวาลัย (AscensionData.STAGE_ID): the ★500 trial stage, a node on the Zone
## like StoryStage. After a short intro the guardian (AscensionData.BOSS_ID, class-agnostic)
## descends at the altar with the field bosses' light moves (its BossAttack behaviors) and
## the story bosses' telegraphed ones (StoryBoss); its three phases follow the Mob's own HP
## phases (70% and 40%): each stuns it for a moment, widens its move set and shortens its
## cycle. At ENRAGE_SECONDS it is enraged (ENRAGE_ATK, the fastest cycle): win before that.
## Its death promotes the hero (AscensionData.promote) under the Ascension's celebration
## (AscendCelebration), then the hero is sent back to the village. The hero falling is the
## game's ordinary death (home; the sage lets it try again).

signal finished(result: Dictionary)

const INTRO := 3.0
const END_DELAY := 6.0
const ALTAR := Vector3(20, 0, 0)
const BOSS_LEVEL := 300
const PHASE_MOVES := [["lance", "nova"], ["rain", "lance", "nova", "veil"], ["rain", "nova", "lance", "veil", "rain"]]
const PHASE_HASTE := [0.95, 0.75, 0.6]
const ENRAGE_HASTE := 0.42
const PHASE_STUN := 2.0

var zone: Node3D
var hero: Node3D
var state := "intro"
var boss: Mob
var phase := 0
var clock := 0.0
var enraged := false
var result: Dictionary = {}
var _timer := INTRO
var _end_timer := 0.0


func setup(p_zone: Node3D, p_hero: Node3D) -> void:
	zone = p_zone
	hero = p_hero


func _ready() -> void:
	name = "AscendTrial"
	AscensionData.note_try()
	_banner("%s · %s" % [AscensionData.STAGE_TITLE, AscensionData.BOSS_NAME])
	Game.say("%s: ปราบ%s ภายใน %d วินาทีก่อนมันคลั่ง หลบเงาสีทองบนพื้น" % [AscensionData.TITLE, AscensionData.BOSS_NAME, int(AscensionData.ENRAGE_SECONDS)], &"quest")
	if zone is Node3D and is_instance_valid(zone):
		AscendCelebration.altar(zone, ALTAR)


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
			clock += delta
			if boss == null or not is_instance_valid(boss) or boss.is_dead():
				_win()
			elif not enraged and clock >= AscensionData.ENRAGE_SECONDS:
				enrage()
		"ending":
			_end_timer -= delta
			if _end_timer <= 0.0:
				state = "done"
				finished.emit(result)
				_go_home()


func spawn_boss() -> void:
	if state != "intro":
		return
	state = "fight"
	boss = Mob.new()
	boss.setup(AscensionData.BOSS_ID, BOSS_LEVEL, ALTAR, hero)
	boss.position = ALTAR + Vector3(0, 0.3, 0)
	zone.add_child(boss)
	boss.hostile = true
	var moves := StoryBoss.new()
	moves.setup(boss, zone, PHASE_MOVES[0], AscensionData.ADDS)
	moves.haste = PHASE_HASTE[0]
	boss.add_child(moves)
	boss.phase_changed.connect(_on_phase)
	boss.died.connect(func(_m: Mob): _win())
	VfxKit.shockwave(zone, ALTAR + Vector3(0, 0.1, 0), Color("ffd86a"), 10.0)


func _on_phase(_mob: Mob, p: int) -> void:
	if p <= phase or p >= PHASE_MOVES.size():
		return
	phase = p
	boss.apply_stun(PHASE_STUN)
	var moves := StoryBoss.of(boss)
	if moves:
		moves.set_moves(PHASE_MOVES[p], ENRAGE_HASTE if enraged else PHASE_HASTE[p])
	_banner("ช่วงที่ %d: %s" % [p + 1, ["ดาบแสง", "ฝนดาวและม่านเทวะ", "เทวะพิโรธ"][p]])


## Past ENRAGE_SECONDS: its blows land ENRAGE_ATK times harder and its moves come fastest.
func enrage() -> void:
	if enraged or boss == null or not is_instance_valid(boss):
		return
	enraged = true
	boss.stats.atk = float(boss.stats.atk) * AscensionData.ENRAGE_ATK
	if "_unweakened_atk" in boss:
		boss._unweakened_atk = float(boss._unweakened_atk) * AscensionData.ENRAGE_ATK
	var moves := StoryBoss.of(boss)
	if moves:
		moves.set_moves(PHASE_MOVES[PHASE_MOVES.size() - 1], ENRAGE_HASTE)
	_banner("%s คลั่งแล้ว! พลังโจมตีพุ่งสูง" % AscensionData.BOSS_NAME)
	Game.say("%s คลั่งแล้ว! รีบปิดฉากให้ได้" % AscensionData.BOSS_NAME, &"warning")


func _win() -> void:
	if state != "fight":
		return
	state = "ending"
	_end_timer = END_DELAY
	var promoted := AscensionData.promote()
	result = {"won": true, "phase": phase, "seconds": clock, "promoted": promoted}
	AudioManager.play_sfx(&"quest_complete")
	if promoted:
		_banner("เปลี่ยนอาชีพขั้นที่ 6: %s!" % Game.class_data().name)
		AscendCelebration.play(zone, hero)
		Game.save()


func _banner(text: String) -> void:
	if zone != null and "banner_requested" in zone:
		zone.banner_requested.emit(text)


func _go_home() -> void:
	# Main holds the zone: the first ancestor that can travel.
	var main: Node = zone.get_parent() if is_instance_valid(zone) else null
	while main != null and not main.has_method("go"):
		main = main.get_parent()
	if main != null and Game.current_zone == AscensionData.STAGE_ID:
		main.go(&"town")
