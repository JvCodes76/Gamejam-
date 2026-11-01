extends Node

const SFX_PATH: String = "res://assets/audio/sfx/%s.%s"
const MUSIC_PATH: String = "res://assets/audio/music/%s.%s"
const MUSIC_EXTENSIONS: Array[String] = ["ogg", "mp3"]
# Música de fundo do jogo todo (menos a luta contra o boss) e música da bossfight
const MAIN_MUSIC: String = "main_theme"
const BOSS_MUSIC: String = "boss_theme"
# Extensões tentadas na ordem (o jsfxr exporta .wav; .ogg tem preferência se existir)
const SFX_EXTENSIONS: Array[String] = ["ogg", "wav"]
const SFX_POOL_SIZE: int = 16
# Volume (dB) por nome de SFX; o que não está aqui toca em 0 dB
const SFX_VOLUME_DB: Dictionary = {
	"shoot": -8.0,
	"hit": -6.0,
	"wall_hit": -10.0,
	"enemy_die": -4.0,
	"ui_hover": -12.0,
	"ui_click": -6.0,
}

var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _next_sfx_index: int = 0
# Streams já carregados (null = arquivo não existe), para não bater no disco a cada tiro
var _stream_cache: Dictionary = {}
# Quantas vezes cada SFX tocou no quadro atual (limite contra estouro em hordas)
var _frame_counts: Dictionary = {}
var _frame_id: int = -1
# Ducking da música: fim (ms reais) do abaixamento
var _duck_until: int = 0
var _music_base_db: float = 0.0
# Nome da música tocando agora (evita reiniciar a mesma faixa)
var _current_music: String = ""


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
	EventBus.hitstop_requested.connect(_on_duck_requested)
	EventBus.player_died.connect(_on_player_died)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_defeated.connect(_on_boss_music_ended)
	EventBus.scene_change_requested.connect(_on_scene_change_requested)
	play_music(MAIN_MUSIC)
	print("[Audio] - AudioManager pronto")


func _process(_delta: float) -> void:
	# Ducking em tempo real (o hitstop zera o time_scale, então nada de tween aqui)
	var ducked: bool = Time.get_ticks_msec() < _duck_until
	var target: float = _music_base_db + (FeelConstants.MUSIC_DUCK_DB if ducked else 0.0)
	if not is_equal_approx(_music_player.volume_db, target):
		_music_player.volume_db = move_toward(_music_player.volume_db, target, 2.0)


# Toca um efeito sonoro no primeiro player livre do pool, com pitch variando e limite por quadro
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


## Abaixa a música por um instante (hitstop e morte).
func duck_music(duration: float = FeelConstants.MUSIC_DUCK_TIME) -> void:
	_duck_until = maxi(_duck_until, Time.get_ticks_msec() + int(duration * 1000.0))


func _on_duck_requested(_duration: float) -> void:
	duck_music()


func _on_player_died() -> void:
	duck_music(0.6)


# Boss entrou na arena: troca para a música da bossfight
func _on_boss_spawned(_boss: Node) -> void:
	play_music(BOSS_MUSIC)


# Boss derrotado: volta para a música principal
func _on_boss_music_ended() -> void:
	play_music(MAIN_MUSIC)


# Troca de cena (menu, reinício, morte na bossfight): garante a música principal
func _on_scene_change_requested(_path: String) -> void:
	play_music(MAIN_MUSIC)


# Stream do SFX pelo nome (cache; tenta .ogg e depois .wav; avisa só uma vez se não existir)
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
		print("[Audio] - Aviso: SFX não encontrado: %s" % sfx_name)
	_stream_cache[sfx_name] = stream
	return stream


# Toca uma música em loop no bus Music (ignora se a mesma já estiver tocando)
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
		print("[Audio] - Aviso: música não encontrada: %s" % music_name)
		return

	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true

	_current_music = music_name
	_music_player.stream = stream
	_music_player.play()
	print("[Audio] - Música tocando: %s" % music_name)


# Para a música atual
func stop_music() -> void:
	_music_player.stop()
	_current_music = ""
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


# Retorna um player livre do pool; se todos estiverem ocupados, usa o próximo em rodízio
func _get_free_sfx_player() -> AudioStreamPlayer:
	for candidate: AudioStreamPlayer in _sfx_players:
		if not candidate.playing:
			return candidate

	var fallback: AudioStreamPlayer = _sfx_players[_next_sfx_index]
	_next_sfx_index = (_next_sfx_index + 1) % _sfx_players.size()
	return fallback
