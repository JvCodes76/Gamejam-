extends Node
## Central game feel: trauma-based screen shake, hitstop and slow-motion.
## Only listens to the EventBus (features never call Juice directly). The camera reads shake_offset/shake_rotation.
## Everything is counted in real time (Time.get_ticks_msec), because hitstop zeroes Engine.time_scale.

# Shake offset and rotation to apply to the active camera this frame
var shake_offset: Vector2 = Vector2.ZERO
var shake_rotation: float = 0.0

var _trauma: float = 0.0
var _noise: FastNoiseLite = FastNoiseLite.new()
var _noise_time: float = 0.0
var _last_ticks: int = 0
# End of hitstop (real ms; 0 = no hitstop)
var _hitstop_until: int = 0
# Slow-motion: scale, end (real ms) and the moment the ramp back ends
var _slowmo_scale: float = 1.0
var _slowmo_until: int = 0
var _slowmo_recover_until: int = 0
# Times (ms) of the latest kills, to detect multi-kills
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
	print("[Juice] - ready")


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	var real_delta: float = float(now - _last_ticks) / 1000.0
	_last_ticks = now
	_update_shake(real_delta)
	_update_time_scale(now)


## Adds trauma (0 to 1). Ignored when "reduce screen shake" is on.
func add_trauma(amount: float) -> void:
	if GameManager.reduce_screen_shake:
		return
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


## Resets shake, hitstop and slow-motion (scene change).
func reset() -> void:
	_trauma = 0.0
	shake_offset = Vector2.ZERO
	shake_rotation = 0.0
	_hitstop_until = 0
	_slowmo_until = 0
	_slowmo_recover_until = 0
	_slowmo_scale = 1.0
	Engine.time_scale = 1.0


## Returns true during a hitstop (used by the audio for ducking).
func is_hitstopped() -> bool:
	return Time.get_ticks_msec() < _hitstop_until


# Trauma decays per second; the offset uses trauma² and continuous noise
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


# Hitstop takes priority (scale 0); then slow-motion, which smoothly returns to 1.0
func _update_time_scale(now: int) -> void:
	var scale: float = 1.0
	# With the inventory/cauldron open the physical items must keep a normal time step (a zero step corrupts the physics)
	if ItemManager.inventory_open:
		pass
	elif now < _hitstop_until:
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
	# Simultaneous hitstops use the latest end, without adding up
	_hitstop_until = maxi(_hitstop_until, until)


func _on_slowmo_requested(scale: float, duration: float) -> void:
	var now: int = Time.get_ticks_msec()
	# A stronger slow-motion (smaller scale) replaces the current one
	if now < _slowmo_until and scale > _slowmo_scale:
		return
	_slowmo_scale = clampf(scale, 0.05, 1.0)
	_slowmo_until = now + int(duration * 1000.0)
	_slowmo_recover_until = _slowmo_until + int(FeelConstants.SLOWMO_RECOVER * 1000.0)
	print("[Juice] - slow-motion %.2f for %.2f s" % [scale, duration])


# Critical: short hitstop and light shake
func _on_damage_dealt(_position: Vector2, _amount: int, is_crit: bool, _color: Color) -> void:
	if not is_crit:
		return
	_on_hitstop_requested(FeelConstants.HITSTOP_CRIT_MS / 1000.0)
	add_trauma(FeelConstants.TRAUMA_CRIT)


# Multi-kill: several kills in a short window trigger hitstop
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
