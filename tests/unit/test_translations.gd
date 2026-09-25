extends TestCase
## Thai translation catalog (res://i18n/th.po): every placeholder of the
## English source must survive translation (or formatting fails at runtime),
## and data resources must switch language in memory.

const PLACEHOLDERS := "%[-+0-9.]*[sdfxX%]|\\{\\w+\\}|\\[/?[a-z]+\\]"


func after_each() -> void:
	TestCase.use_locale("en")


func test_thai_catalog_loaded() -> void:
	var catalog := TranslationServer.get_translation_object("th")
	if check_not_null(catalog, "Thai translation registered in project settings"):
		check(catalog.get_message_count() > 600, "catalog has %d entries" % catalog.get_message_count())


func test_placeholders_survive_translation() -> void:
	var catalog := TranslationServer.get_translation_object("th")
	if catalog == null:
		return
	var re := RegEx.create_from_string(PLACEHOLDERS)
	for msgid in catalog.get_message_list():
		var translated := str(catalog.get_message(msgid))
		check(translated != "", "empty translation for: " + msgid)
		check_eq(_tokens(re, translated), _tokens(re, msgid), "placeholders for: " + msgid)


func test_data_strings_are_translated() -> void:
	var catalog := TranslationServer.get_translation_object("th")
	if catalog == null:
		return
	var sources: Array[String] = []
	for table in ["species", "skills", "items", "npcs", "maps", "shops"]:
		for res in GameData.get_all(table):
			sources.append(str(L10n.source_of(res, &"display_name")))
	for quest in GameData.get_all("quests"):
		sources.append(str(L10n.source_of(quest, &"title")))
		sources.append(str(L10n.source_of(quest, &"summary")))
		for objective in quest.objectives:
			sources.append(str(L10n.source_of(objective, &"description")))
	for dialogue in GameData.get_all("dialogue"):
		for line in dialogue.lines:
			sources.append(str(L10n.source_of(line, &"text")))
	for text in sources:
		if text != "":
			check(str(catalog.get_message(text)) != "", "no Thai for: " + text)


func test_data_switches_language_in_memory() -> void:
	TestCase.use_locale("th")
	check_eq(GameData.get_species(&"agumon").display_name, "อากุมอน", "species name")
	check_eq(GameData.get_item(&"small_patch").display_name, "แพตช์ข้อมูลเล็ก", "item name")
	check_eq(GameData.get_map(&"data_forest").display_name, "ป่าดาต้า", "map name")
	check(GameData.get_dialogue(&"mira_offer").lines[0].text.contains("{player_name}"), "dialogue keeps its variables")
	check_eq(DigimonStats.short_name(DigimonStats.ATTACK), "โจมตี", "stat label")
	check_eq(L10n.t("%s used %s!") % ["อากุมอน", "พุ่งชน"], "อากุมอน ใช้ พุ่งชน!", "battle message")
	check_eq(GameData.get_species(&"agumon").get_stage_name(), "รุกกี้", "stage name")
	TestCase.use_locale("en")
	check_eq(GameData.get_species(&"agumon").display_name, "Agumon", "back to English")
	check_eq(GameData.get_item(&"small_patch").display_name, "Small Data Patch", "item back to English")


func _tokens(re: RegEx, text: String) -> Array:
	var ordered: Array = [] # printf tokens: order matters
	var named: Array = []   # {vars} and BBCode: any order
	for m in re.search_all(text):
		var token := m.get_string()
		if token.begins_with("%"):
			ordered.append(token)
		else:
			named.append(token)
	named.sort()
	return [ordered, named]
