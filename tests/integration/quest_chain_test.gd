extends Node
## The elder's story chain: every quest is reachable, hunts a monster that
## really lives in its zone, and the post-Lv.100 quests open by ★.
##   godot --headless --path . res://tests/integration/quest_chain_test.tscn
var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	Game.set_process(false)
	Game.new_profile(&"warrior", "Quest QA")
	ZoneData.ensure()
	check(QuestData.ORDER.size() == QuestData.QUESTS.size(), "every quest is in the order (%d/%d)" % [QuestData.ORDER.size(), QuestData.QUESTS.size()])
	for i in QuestData.ORDER.size():
		var id: String = QuestData.ORDER[i]
		var quest := QuestData.get_quest(id)
		check(not quest.is_empty(), "quest exists " + id)
		var expected_next: String = QuestData.ORDER[i + 1] if i + 1 < QuestData.ORDER.size() else ""
		check(String(quest.next) == expected_next, "chain order after " + id)
		var target := StringName(quest.target)
		check(MonsterData.get_monster(target).name != MonsterData.MONSTERS[&"pink_slime"].name or target == &"pink_slime", "real target " + id)
		var zone := ZoneData.get_zone(StringName(quest.zone))
		var lives := zone.has("boss") and StringName(zone.boss.monster) == target
		for camp in zone.get("camps", []):
			lives = lives or camp.monsters.has(target)
		check(lives, "%s hunts a monster of %s" % [id, quest.zone])
		check(int(quest.exp) > 0 and int(quest.gold) > 0, "reward " + id)
	check(QuestData.ORDER.size() >= 40, "the chain continues past Lv.99")
	# ★ gating once the hero is Lv.100.
	Game.profile.level = 100
	var star_quest := QuestData.get_quest("crystal_wolves")
	Game.paragon().level = 49
	check(QuestData.unlock_problem(star_quest) != "", "49 stars cannot take a 50-star quest")
	Game.paragon().level = 50
	check(QuestData.unlock_problem(star_quest) == "", "50 stars can take it")
	Game.profile.level = 98
	check(QuestData.unlock_problem(QuestData.get_quest("void_golems")) != "", "Lv.98 cannot take the void quest")
	Game.profile.level = 99
	check(QuestData.unlock_problem(QuestData.get_quest("void_golems")) == "", "Lv.99 can take the void quest")
	var normal := QuestData.get_quest("dawn_crabs")
	var boss := QuestData.get_quest("dawn_dragon")
	check(int(boss.exp) > int(normal.exp), "a boss quest pays more")
	check(int(QuestData.get_quest("lotus_monks").exp) > int(normal.exp), "later stars pay more")
	# Turning in a boss quest grants a piece of that region's star gear.
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	Game.profile.level = 100
	Game.paragon().level = 30
	var bag: int = Game.profile.inv.size()
	Game.set_quest("dawn_dragon", "active", 0)
	Game.report_kill(&"dawn_ancient_stag", true)
	check(Game.quest_status("dawn_dragon") == "ready", "boss kill finishes the quest")
	main._reward_quest("dawn_dragon")
	var star_pieces := 0
	for item in Game.profile.inv.slice(bag):
		if item is Dictionary and int(item.get("star_tier", 0)) == 50:
			star_pieces += 1
	check(star_pieces == 1, "boss quest pays a 50-star gear piece")
	print("QUEST CHAIN: %s | %d quests, %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", QuestData.ORDER.size(), checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
