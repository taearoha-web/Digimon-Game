extends Node
## Autoload "GameData": read-only registry of every data resource.
##
## Resources are discovered by scanning folders, so adding a new species,
## skill, item or quest is just dropping a .tres file in the right folder.

const DIRS := {
	"species": "res://data/digimon",
	"skills": "res://data/skills",
	"items": "res://data/items",
	"quests": "res://data/quests",
	"dialogue": "res://data/dialogue",
	"npcs": "res://data/npcs",
	"encounters": "res://data/encounters",
	"maps": "res://data/maps",
	"shops": "res://data/shops",
}
const STARTER_ROSTER_PATH := "res://data/config/starter_roster.tres"
const RECRUITMENT_CONFIG_PATH := "res://data/config/recruitment_config.tres"
const TYPE_CHART_PATH := "res://data/config/type_chart.tres"
const CUSTOMIZATION_CATALOG_PATH := "res://data/config/customization_catalog.tres"

var _tables: Dictionary = {}
var starter_roster: StarterRoster
var recruitment_config: RecruitmentConfig
var type_chart: TypeChart
var customization_catalog: CustomizationCatalog


func _ready() -> void:
	reload_all()


func reload_all() -> void:
	_tables.clear()
	for key in DIRS.keys():
		_tables[key] = _load_folder(DIRS[key])
	starter_roster = _load_single(STARTER_ROSTER_PATH, StarterRoster.new()) as StarterRoster
	recruitment_config = _load_single(RECRUITMENT_CONFIG_PATH, RecruitmentConfig.new()) as RecruitmentConfig
	type_chart = _load_single(TYPE_CHART_PATH, TypeChart.new()) as TypeChart
	customization_catalog = _load_single(CUSTOMIZATION_CATALOG_PATH, CustomizationCatalog.new()) as CustomizationCatalog


func get_species(species_id: StringName) -> DigimonSpecies:
	return _lookup("species", species_id) as DigimonSpecies


func get_skill(skill_id: StringName) -> SkillData:
	return _lookup("skills", skill_id) as SkillData


func get_item(item_id: StringName) -> ItemData:
	return _lookup("items", item_id) as ItemData


func get_quest(quest_id: StringName) -> QuestData:
	return _lookup("quests", quest_id) as QuestData


func get_dialogue(dialogue_id: StringName) -> DialogueData:
	return _lookup("dialogue", dialogue_id) as DialogueData


func get_npc(npc_id: StringName) -> NpcData:
	return _lookup("npcs", npc_id) as NpcData


func get_encounter_table(table_id: StringName) -> EncounterTable:
	return _lookup("encounters", table_id) as EncounterTable


func get_map(map_id: StringName) -> MapData:
	return _lookup("maps", map_id) as MapData


func get_shop(shop_id: StringName) -> ShopData:
	return _lookup("shops", shop_id) as ShopData


func get_all(table: String) -> Array:
	return _tables.get(table, {}).values()


func get_all_species() -> Array[DigimonSpecies]:
	var out: Array[DigimonSpecies] = []
	for res in get_all("species"):
		out.append(res)
	out.sort_custom(func(a, b): return a.display_name < b.display_name)
	return out


func get_all_quests() -> Array[QuestData]:
	var out: Array[QuestData] = []
	for res in get_all("quests"):
		out.append(res)
	out.sort_custom(func(a, b): return a.sort_order < b.sort_order)
	return out


func get_ids(table: String) -> Array:
	return _tables.get(table, {}).keys()


func _lookup(table: String, id: StringName) -> Resource:
	if id == &"":
		return null
	return _tables.get(table, {}).get(id)


func _load_single(path: String, fallback: Resource) -> Resource:
	if ResourceLoader.exists(path):
		var res := load(path)
		if res:
			return res
	push_warning("GameData: missing '%s', using defaults" % path)
	return fallback


func _load_folder(dir_path: String) -> Dictionary:
	var result := {}
	for file_name in list_resource_files(dir_path):
		var path := dir_path.path_join(file_name)
		var res := load(path)
		if res == null:
			push_warning("GameData: failed to load %s" % path)
			continue
		var id = res.get("id")
		if id == null or StringName(id) == &"":
			push_warning("GameData: %s has no id" % path)
			continue
		if result.has(StringName(id)):
			push_warning("GameData: duplicate id '%s' in %s" % [id, path])
		result[StringName(id)] = res
	return result


## Lists .tres/.res files; handles ".remap" entries found in exported builds.
static func list_resource_files(dir_path: String) -> PackedStringArray:
	var files := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return files
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var clean := file_name.trim_suffix(".remap")
			if (clean.ends_with(".tres") or clean.ends_with(".res")) and not files.has(clean):
				files.append(clean)
		file_name = dir.get_next()
	dir.list_dir_end()
	files.sort()
	return files
