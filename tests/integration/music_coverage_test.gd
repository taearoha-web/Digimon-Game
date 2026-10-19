extends Node
## Every place has its own music: each zone (the star regions, the divine region,
## the tower, the ranked coliseum, the guild war and the training arena included),
## the town, the title screen and the victory / defeat jingles each resolve to a
## distinct Ogg Vorbis file, no id is shared by two places, loops are flagged and
## 60-100 s long, no WAV music is left and the whole set fits the download budget.
## godot --headless --path . res://tests/integration/music_coverage_test.tscn
var failures: Array[String] = []
var checks := 0

const MUSIC_DIR := "res://audio/music"
const JINGLES: Array[StringName] = [&"victory", &"defeat"]
const SIZE_BUDGET_BYTES := 14 * 1024 * 1024
## The places that must each have a track (ids as data/zone_data.gd names them).
const PLACES: Array[StringName] = [&"town", &"meadow", &"dark_forest", &"desert", &"snow", &"volcano", &"graveyard", &"swamp",
	&"storm", &"sky", &"abyss", &"void", &"tower", &"dawn_forest", &"crystal_valley", &"sky_citadel", &"eclipse_realm",
	&"lotus_sanctum", &"pvp", &"guildwar", &"arena"]


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func _ready() -> void:
	Game.set_process(false)
	ZoneData.ensure()
	var place_of := {}
	for place in PLACES:
		check(ZoneData.ZONES.has(place), "zone exists: " + String(place))
	for zone_id in ZoneData.ZONES:
		var zone: Dictionary = ZoneData.ZONES[zone_id]
		var music: StringName = zone.get("music", &"")
		check(music != &"", "zone %s names its music" % zone_id)
		check(AudioManager.has_music(music), "zone %s music '%s' resolves to a stream" % [zone_id, music])
		check(not place_of.has(music), "music '%s' belongs to one place only (%s reuses %s's)" % [music, zone_id, place_of.get(music, "")])
		place_of[music] = String(zone_id)
	# ui/main_menu.gd plays "title", ui/ending_screen.gd plays "victory", "defeat" is the loss jingle.
	for extra in [&"title", &"victory", &"defeat"]:
		check(AudioManager.has_music(extra), "'%s' resolves to a stream" % extra)
		check(not place_of.has(extra), "'%s' is not also a zone's music (%s)" % [extra, place_of.get(extra, "")])
		place_of[extra] = String(extra)
	var files := {}
	var total_bytes := 0
	for music in place_of:
		var path := _stream_path(music)
		check(path.ends_with(".ogg"), "%s is Ogg Vorbis, got '%s'" % [music, path])
		check(not files.has(path), "%s has its own file (shared with %s)" % [music, files.get(path, "")])
		files[path] = String(music)
		var stream := load(path) as AudioStreamOggVorbis
		check(stream != null, "%s loads as AudioStreamOggVorbis" % music)
		if stream == null:
			continue
		var is_loop: bool = music not in JINGLES
		check(stream.loop == is_loop, "%s import loop flag is %s" % [music, str(is_loop)])
		var length := stream.get_length()
		if is_loop:
			check(length >= 60.0 and length <= 100.0, "%s loop is 60-100 s (%.1f s)" % [music, length])
		else:
			check(length >= 3.0 and length <= 20.0, "%s jingle is 3-20 s (%.1f s)" % [music, length])
		var file := FileAccess.open(path, FileAccess.READ)
		check(file != null, "%s is readable" % path)
		if file:
			total_bytes += file.get_length()
	check(total_bytes <= SIZE_BUDGET_BYTES, "all music together fits %d MB (%.2f MB)" % [SIZE_BUDGET_BYTES / 1048576, total_bytes / 1048576.0])
	var leftover := []
	var dir := DirAccess.open(MUSIC_DIR)
	check(dir != null, "music folder exists")
	if dir:
		for name in dir.get_files():
			if name.ends_with(".wav") or name.ends_with(".mp3"):
				leftover.append(name)
	check(leftover.is_empty(), "no WAV/MP3 music left (web pack size): " + ", ".join(leftover))
	# The same stream serves the whole run: play_music keeps the loop flag on the shared resource.
	AudioManager.play_music(&"meadow", 0.0)
	var playing := AudioManager._music_players[AudioManager._active_music_index].stream as AudioStreamOggVorbis
	check(playing != null and playing.loop, "play_music starts a looping Ogg stream")
	AudioManager.play_music(&"victory", 0.0)
	var jingle := AudioManager._music_players[AudioManager._active_music_index].stream as AudioStreamOggVorbis
	check(jingle != null and not jingle.loop, "a jingle plays once")
	AudioManager.stop_music(0.0)
	print("MUSIC COVERAGE: %d places, %.2f MB; %d checks, %d failures" % [place_of.size(), total_bytes / 1048576.0, checks, failures.size()])
	for f in failures:
		print("  FAIL ", f)
	get_tree().quit(failures.size())


func _stream_path(music: StringName) -> String:
	for ext in AudioManager.EXTENSIONS:
		var path := "%s/%s.%s" % [MUSIC_DIR, music, ext]
		if ResourceLoader.exists(path):
			return path
	return ""
