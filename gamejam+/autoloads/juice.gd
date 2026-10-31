extends Node
## Game feel central: screen shake por trauma, hitstop e slow-motion.
## Só escuta o EventBus (as features nunca chamam o Juice direto). A câmera lê shake_offset/shake_rotation.
## Tudo é contado em tempo real (Time.get_ticks_msec), porque o hitstop zera o Engine.time_scale.

# Offset e rotação de tremida a aplicar na câmera ativa neste quadro
var shake_offset: Vector2 = Vector2.ZERO
var shake_rotation: float = 0.0

var _trauma: float = 0.0
var _noise: FastNoiseLite = FastNoiseLite.new()
var _noise_time: float = 0.0
var _last_ticks: int = 0
# Fim do hitstop (ms reais; 0 = sem hitstop)
var _hitstop_until: int = 0
# Slow-motion: escala, fim (ms reais) e momento em que a volta termina
var _slowmo_scale: float = 1.0
var _slowmo_until: int = 0
var _slowmo_recover_until: int = 0
# Momentos (ms) das últimas mortes, para detectar multi-kill
var _recent_kills: Array[int] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_noise.seed = randi()
	_noise.frequency = 0.5
	_last_ticks = Time.get_ticks_msec()
	EventBus.screen_shake_requested.connect(add_trauma)
	EventBus.hitstop_requested.connect(_on_hitstop_requested)
	EventBus.slowmo_requested.connect(_on_slowmo_requested)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.scene_change_requested.connect(_on_scene_change_requested)
	print("[Juice] - pronto")


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	var real_delta: float = float(now - _last_ticks) / 1000.0
	_last_ticks = now
	_update_shake(real_delta)
	_update_time_scale(now)


## Soma trauma (0 a 1). Com "reduzir tremida" ligado, é ignorado.
func add_trauma(amount: float) -> void:
	if GameManager.reduce_screen_shake:
		return
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


## Zera shake, hitstop e slow-motion (troca de cena).
func reset() -> void:
	_trauma = 0.0
	shake_offset = Vector2.ZERO
	shake_rotation = 0.0
	_hitstop_until = 0
	_slowmo_until = 0
	_slowmo_recover_until = 0
	_slowmo_scale = 1.0
	Engine.time_scale = 1.0


## Retorna true durante um hitstop (usado pelo áudio para o ducking).
func is_hitstopped() -> bool:
	return Time.get_ticks_msec() < _hitstop_until


# Trauma decai por segundo; o offset usa trauma² e ruído contínuo
func _update_shake(real_delta: float) -> void:
	if _trauma <= 0.0:
		shake_offset = Vector2.ZERO
		shake_rotation = 0.0
		return
	_trauma = maxf(_trauma - FeelConstants.SHAKE_DECAY * real_delta, 0.0)
	_noise_time += real_delta * FeelConstants.SHAKE_NOISE_SPEED
	var power: float = _trauma * _trauma
	shake_offset = Vector2(_noise.get_noise_2d(_noise_time, 0.0), _noise.get_noise_2d(0.0, _noise_time)) * FeelConstants.SHAKE_MAX_OFFSET * power
	shake_rotation = _noise.get_noise_2d(_noise_time, _noise_time) * FeelConstants.SHAKE_MAX_ROTATION * power


# Hitstop tem prioridade (escala 0); depois o slow-motion, que volta a 1.0 de forma suave
func _update_time_scale(now: int) -> void:
	var scale: float = 1.0
	if now < _hitstop_until:
		scale = 0.0
	elif now < _slowmo_until:
		scale = _slowmo_scale
	elif now < _slowmo_recover_until:
		var t: float = 1.0 - float(_slowmo_recover_until - now) / (FeelConstants.SLOWMO_RECOVER * 1000.0)
		scale = lerpf(_slowmo_scale, 1.0, clampf(t, 0.0, 1.0))
	if not is_equal_approx(Engine.time_scale, scale):
		Engine.time_scale = scale


func _on_hitstop_requested(duration: float) -> void:
	var until: int = Time.get_ticks_msec() + int(duration * 1000.0)
	# Hitstops simultâneos usam o maior fim, sem somar
	_hitstop_until = maxi(_hitstop_until, until)


func _on_slowmo_requested(scale: float, duration: float) -> void:
	var now: int = Time.get_ticks_msec()
	# Um slow-motion mais forte (escala menor) substitui o atual
	if now < _slowmo_until and scale > _slowmo_scale:
		return
	_slowmo_scale = clampf(scale, 0.05, 1.0)
	_slowmo_until = now + int(duration * 1000.0)
	_slowmo_recover_until = _slowmo_until + int(FeelConstants.SLOWMO_RECOVER * 1000.0)
	print("[Juice] - slow-motion %.2f por %.2f s" % [scale, duration])


# Crítico: hitstop curto e tremida leve
func _on_damage_dealt(_position: Vector2, _amount: int, is_crit: bool, _color: Color) -> void:
	if not is_crit:
		return
	_on_hitstop_requested(FeelConstants.HITSTOP_CRIT_MS / 1000.0)
	add_trauma(FeelConstants.TRAUMA_CRIT)


# Multi-kill: várias mortes numa janela curta geram hitstop
func _on_enemy_died(_position: Vector2, _was_marked: bool, _is_basic: bool) -> void:
	var now: int = Time.get_ticks_msec()
	_recent_kills.append(now)
	while not _recent_kills.is_empty() and now - _recent_kills[0] > int(FeelConstants.MULTI_KILL_WINDOW_MS):
		_recent_kills.pop_front()
	if _recent_kills.size() >= FeelConstants.MULTI_KILL_COUNT:
		_recent_kills.clear()
		_on_hitstop_requested(FeelConstants.HITSTOP_ELITE_DEATH_MS / 1000.0)
		print("[Juice] - multi-kill")


func _on_scene_change_requested(_path: String) -> void:
	reset()
