extends Node

const SFX_PATH: String = "res://assets/audio/sfx/%s.%s"
const MUSIC_PATH: String = "res://assets/audio/music/%s.%s"
const MUSIC_EXTENSIONS: Array[String] = ["ogg", "mp3"]
# Background music for the whole game (except the boss fight) and the boss fight music
const MAIN_MUSIC: String = "main_theme"
const BOSS_MUSIC: String = "boss_theme"
# Extensions tried in order (jsfxr exports .wav; .ogg is preferred if it exists)
const SFX_EXTENSIONS: Array[String] = ["ogg", "wav"]
const SFX_POOL_SIZE: int = 16
# Music gain over the original files (2.0 = doubled, about +6 dB); the Music slider scales on top of it
const MUSIC_GAIN_LINEAR: float = 2.0
const SETTINGS_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "audio"
const VOLUME_BUSES: Array[StringName] = [&"Master", &"Music", &"SFX"]
# Volume (dB) per SFX name; anything not listed here plays at 0 dB
const SFX_VOLUME_DB: Dictionary = {
	"shoot": -8.0,
	"hit": -6.0,
	"wall_hit": -10.0,
	"enemy_die": -4.0,
	"ui_hover": -12.0,
	"ui_click": -6.0,
	"eagle_scream": -4.0,
}

var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _next_sfx_index: int = 0
# Already loaded streams (null = file does not exist), to avoid hitting the disk on every shot
var _stream_cache: Dictionary = {}
# How many times each SFX played this frame (cap against overload in hordes)
var _frame_counts: Dictionary = {}
var _frame_id: int = -1
# Music ducking: end (real ms) of the volume dip
var _duck_until: int = 0
var _music_base_db: float = linear_to_db(MUSIC_GAIN_LINEAR)
# Name of the music currently playing (avoids restarting the same track)
var _current_music: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_ensure_bus(&"Music")
	_ensure_bus(&"SFX")
	load_settings()

	for _i: int in SFX_POOL_SIZE:
		var sfx_player := AudioStreamPlayer.new()
		sfx_player.bus = &"SFX"
		add_child(sfx_player)
		_sfx_players.append(sfx_player)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Music"
	add_child(_music_player)

	EventBus.play_sfx_requested.connect(play_sfx)
	EventBus.play_music_requested.connect(play_music)
	EventBus.hitstop_requested.connect(_on_duck_requested)
	EventBus.player_died.connect(_on_player_died)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_defeated.connect(_on_boss_music_ended)
	EventBus.scene_change_requested.connect(_on_scene_change_requested)
	play_music(MAIN_MUSIC)
	print("[Audio] - AudioManager ready")


func _process(_delta: float) -> void:
	# Real-time ducking (hitstop zeroes time_scale, so no tweens here)
	var ducked: bool = Time.get_ticks_msec() < _duck_until
	var target: float = _music_base_db + (FeelConstants.MUSIC_DUCK_DB if ducked else 0.0)
	if not is_equal_approx(_music_player.volume_db, target):
		_music_player.volume_db = move_toward(_music_player.volume_db, target, 2.0)


# Plays a sound effect on the first free player in the pool, with varying pitch and a per-frame cap
func play_sfx(sfx_name: String) -> void:
	var frame: int = Engine.get_process_frames()
	if frame != _frame_id:
		_frame_id = frame
		_frame_counts.clear()
	var count: int = int(_frame_counts.get(sfx_name, 0))
	if count >= FeelConstants.SFX_MAX_PER_FRAME:
		return
	_frame_counts[sfx_name] = count + 1

	var stream: AudioStream = _get_sfx_stream(sfx_name)
	if stream == null:
		return

	var player: AudioStreamPlayer = _get_free_sfx_player()
	player.stream = stream
	player.pitch_scale = 1.0 + randf_range(-FeelConstants.SFX_PITCH_VARIATION, FeelConstants.SFX_PITCH_VARIATION)
	player.volume_db = float(SFX_VOLUME_DB.get(sfx_name, 0.0))
	player.play()


## Lowers the music for a moment (hitstop and death).
func duck_music(duration: float = FeelConstants.MUSIC_DUCK_TIME) -> void:
	_duck_until = maxi(_duck_until, Time.get_ticks_msec() + int(duration * 1000.0))


func _on_duck_requested(_duration: float) -> void:
	duck_music()


func _on_player_died() -> void:
	duck_music(0.6)


# Boss entered the arena: switch to the boss fight music
func _on_boss_spawned(_boss: Node) -> void:
	play_music(BOSS_MUSIC)


# Boss defeated: go back to the main music
func _on_boss_music_ended() -> void:
	play_music(MAIN_MUSIC)


# Scene change (menu, restart, death in the boss fight): ensures the main music
func _on_scene_change_requested(_path: String) -> void:
	play_music(MAIN_MUSIC)


# SFX stream by name (cached; tries .ogg then .wav; warns only once if missing)
func _get_sfx_stream(sfx_name: String) -> AudioStream:
	if _stream_cache.has(sfx_name):
		return _stream_cache[sfx_name]
	var stream: AudioStream = null
	for ext: String in SFX_EXTENSIONS:
		var path: String = SFX_PATH % [sfx_name, ext]
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
			break
	if stream == null:
		print("[Audio] - Warning: SFX not found: %s" % sfx_name)
	_stream_cache[sfx_name] = stream
	return stream


# Plays a looping track on the Music bus (ignored if the same one is already playing)
func play_music(music_name: String) -> void:
	if music_name == _current_music and _music_player.playing:
		return

	var stream: AudioStream = null
	for ext: String in MUSIC_EXTENSIONS:
		var path: String = MUSIC_PATH % [music_name, ext]
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
			break
	if stream == null:
		print("[Audio] - Warning: music not found: %s" % music_name)
		return

	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true

	_current_music = music_name
	_music_player.stream = stream
	_music_player.play()
	print("[Audio] - Music playing: %s" % music_name)


# Stops the current music
func stop_music() -> void:
	_music_player.stop()
	_current_music = ""
	print("[Audio] - Music stopped")


# Sets the linear volume (0.0 to 1.0) of a bus
func set_bus_volume(bus: StringName, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx == -1:
		print("[Audio] - Warning: bus does not exist: %s" % bus)
		return

	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))


# Returns the linear volume (0.0 to 1.0) of a bus
func get_bus_volume(bus: StringName) -> float:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx == -1:
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))


# Saves the volume of every bus to user://settings.cfg
func save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH) # keeps other sections if the file exists
	for bus: StringName in VOLUME_BUSES:
		config.set_value(SETTINGS_SECTION, String(bus), get_bus_volume(bus))
	var err: Error = config.save(SETTINGS_PATH)
	if err != OK:
		push_error("[Audio] - failed to save settings (error %d)" % err)


# Applies the saved volumes (buses without a saved value stay at 100%)
func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for bus: StringName in VOLUME_BUSES:
		set_bus_volume(bus, float(config.get_value(SETTINGS_SECTION, String(bus), 1.0)))


# Creates the audio bus if it does not exist yet
func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return

	AudioServer.add_bus()
	var idx: int = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(idx, bus_name)
	print("[Audio] - Bus created: %s" % bus_name)


# Returns a free player from the pool; if all are busy, uses the next one round-robin
func _get_free_sfx_player() -> AudioStreamPlayer:
	for candidate: AudioStreamPlayer in _sfx_players:
		if not candidate.playing:
			return candidate

	var fallback: AudioStreamPlayer = _sfx_players[_next_sfx_index]
	_next_sfx_index = (_next_sfx_index + 1) % _sfx_players.size()
	return fallback
