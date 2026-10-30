extends Node

const SFX_PATH: String = "res://assets/audio/sfx/%s.ogg"
const MUSIC_PATH: String = "res://assets/audio/music/%s.ogg"
const SFX_POOL_SIZE: int = 8

var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _next_sfx_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_ensure_bus(&"Music")
	_ensure_bus(&"SFX")

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
	print("[Audio] - AudioManager pronto")


# Toca um efeito sonoro no primeiro player livre do pool
func play_sfx(sfx_name: String) -> void:
	var stream: AudioStream = _load_stream(SFX_PATH % sfx_name)
	if stream == null:
		return

	var player: AudioStreamPlayer = _get_free_sfx_player()
	player.stream = stream
	player.play()
	print("[Audio] - SFX tocando: %s" % sfx_name)


# Toca uma música em loop no bus Music
func play_music(music_name: String) -> void:
	var stream: AudioStream = _load_stream(MUSIC_PATH % music_name)
	if stream == null:
		return

	var ogg: AudioStreamOggVorbis = stream as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = true

	_music_player.stream = stream
	_music_player.play()
	print("[Audio] - Música tocando: %s" % music_name)


# Para a música atual
func stop_music() -> void:
	_music_player.stop()
	print("[Audio] - Música parada")


# Define o volume linear (0.0 a 1.0) de um bus
func set_bus_volume(bus: StringName, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx == -1:
		print("[Audio] - Aviso: bus não existe: %s" % bus)
		return

	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))


# Cria o bus de áudio caso ele ainda não exista
func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return

	AudioServer.add_bus()
	var idx: int = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(idx, bus_name)
	print("[Audio] - Bus criado: %s" % bus_name)


# Carrega o stream; se o arquivo não existir, apenas avisa e retorna null
func _load_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		print("[Audio] - Aviso: arquivo não encontrado: %s" % path)
		return null

	return load(path) as AudioStream


# Retorna um player livre do pool; se todos estiverem ocupados, usa o próximo em rodízio
func _get_free_sfx_player() -> AudioStreamPlayer:
	for candidate: AudioStreamPlayer in _sfx_players:
		if not candidate.playing:
			return candidate

	var fallback: AudioStreamPlayer = _sfx_players[_next_sfx_index]
	_next_sfx_index = (_next_sfx_index + 1) % _sfx_players.size()
	return fallback
