extends Node
## Autoload "AudioManager": music crossfades and pooled sound effects.
##
## Sounds are looked up by id using a folder convention, so replacing a
## placeholder is just dropping a file with the same name:
##   res://audio/sfx/<id>.ogg|.wav     res://audio/music/<id>.ogg|.wav
## Buses: Master, Music, SFX, UI (created at runtime if the layout lacks them).

const SFX_DIR := "res://audio/sfx"
const MUSIC_DIR := "res://audio/music"
const EXTENSIONS := ["ogg", "wav", "mp3"]
const SFX_POOL_SIZE := 10
const UI_POOL_SIZE := 3
const BUSES := ["Music", "SFX", "UI"]

var current_music_id: StringName = &""

var _music_players: Array[AudioStreamPlayer] = []
var _active_music_index := 0
var _sfx_pool: Array[AudioStreamPlayer] = []
var _ui_pool: Array[AudioStreamPlayer] = []
var _stream_cache: Dictionary = {}
var _missing_warned: Dictionary = {}
var _music_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		player.name = "Music%d" % i
		player.finished.connect(_on_music_finished.bind(player))
		add_child(player)
		_music_players.append(player)
	for i in SFX_POOL_SIZE:
		_sfx_pool.append(_make_player("Sfx%d" % i, "SFX"))
	for i in UI_POOL_SIZE:
		_ui_pool.append(_make_player("Ui%d" % i, "UI"))


func play_music(music_id: StringName, fade_time := 1.0) -> void:
	if music_id == current_music_id and _music_players[_active_music_index].playing:
		return
	var stream := _get_stream(MUSIC_DIR, music_id)
	current_music_id = music_id
	var old_player := _music_players[_active_music_index]
	_active_music_index = 1 - _active_music_index
	var new_player := _music_players[_active_music_index]
	if _music_tween:
		_music_tween.kill()
		_music_tween = null
	if not old_player.playing and stream == null:
		return
	_music_tween = create_tween().set_parallel(true)
	if old_player.playing:
		_music_tween.tween_property(old_player, "volume_db", -40.0, fade_time)
	if stream != null:
		new_player.stream = stream
		new_player.volume_db = -40.0
		new_player.play()
		_music_tween.tween_property(new_player, "volume_db", 0.0, fade_time)
	if old_player.playing:
		_music_tween.chain().tween_callback(old_player.stop)


func stop_music(fade_time := 1.0) -> void:
	current_music_id = &""
	if _music_tween:
		_music_tween.kill()
		_music_tween = null
	var any_playing := false
	for player in _music_players:
		any_playing = any_playing or player.playing
	if not any_playing:
		return
	_music_tween = create_tween().set_parallel(true)
	for player in _music_players:
		if player.playing:
			_music_tween.tween_property(player, "volume_db", -40.0, fade_time)
	_music_tween.chain().tween_callback(func():
		for p in _music_players:
			p.stop())


func play_sfx(sfx_id: StringName, volume_db := 0.0, pitch_variation := 0.06) -> void:
	_play_from_pool(_sfx_pool, SFX_DIR, sfx_id, volume_db, pitch_variation)


func play_ui(sfx_id: StringName, volume_db := 0.0) -> void:
	_play_from_pool(_ui_pool, SFX_DIR, sfx_id, volume_db, 0.0)


func has_sound(sfx_id: StringName) -> bool:
	return _get_stream(SFX_DIR, sfx_id) != null


func _play_from_pool(pool: Array[AudioStreamPlayer], dir: String, sfx_id: StringName, volume_db: float, pitch_variation: float) -> void:
	if sfx_id == &"":
		return
	var stream := _get_stream(dir, sfx_id)
	if stream == null:
		return
	var player: AudioStreamPlayer = null
	for candidate in pool:
		if not candidate.playing:
			player = candidate
			break
	if player == null:
		player = pool[0] # Steal the oldest voice.
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()


func _get_stream(dir: String, sound_id: StringName) -> AudioStream:
	var key := dir + "/" + String(sound_id)
	if _stream_cache.has(key):
		return _stream_cache[key]
	var stream: AudioStream = null
	for ext in EXTENSIONS:
		var path := "%s/%s.%s" % [dir, sound_id, ext]
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
			break
	if stream == null and not _missing_warned.has(key):
		_missing_warned[key] = true
		print_verbose("AudioManager: no audio for '%s' (placeholder slot)" % key)
	_stream_cache[key] = stream
	return stream


func _make_player(player_name: String, bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = bus
	add_child(player)
	return player


func _ensure_buses() -> void:
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")


func _on_music_finished(player: AudioStreamPlayer) -> void:
	# Fallback looping for streams imported without loop points.
	if player == _music_players[_active_music_index] and current_music_id != &"":
		player.play()
