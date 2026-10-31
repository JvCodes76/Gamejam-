class_name StatusEffects
extends Node
## Status temporários de um inimigo (roots, slow, stun, marked, charmed, weakened) com timers próprios.

signal changed(status: StringName, active: bool)

const ROOTS: StringName = &"roots"
const SLOW: StringName = &"slow"
const STUN: StringName = &"stun"
const MARKED: StringName = &"marked"
const CHARMED: StringName = &"charmed"
const WEAKENED: StringName = &"weakened"

# Fonte padrão de slow quando apply(SLOW) é chamado sem fonte
const DEFAULT_SLOW_SOURCE: StringName = &"default"

# Bônus de dano recebido por atordoados (Crunchy!); definido pelo SynergyDirector, vale para todos os inimigos
static var stun_damage_bonus: float = 0.0

# status -> { "time": float, "power": float }
var _active: Dictionary = {}
# Slow por fonte: fonte -> { "time": float, "power": float }; fontes diferentes multiplicam
var _slows: Dictionary = {}


## Duração do stun: min(teto, STUN_BASE + 0.1 * nível + extra); o teto padrão é STUN_MAX.
static func stun_duration(level: float = 0.0, extra: float = 0.0, cap: float = CombatConstants.STUN_MAX) -> float:
	return minf(maxf(cap, CombatConstants.STUN_MAX), CombatConstants.STUN_BASE + CombatConstants.STUN_PER_LEVEL * level + extra)


## Potência de slow que equivale a reduzir a velocidade em "fraction" (0.4 = -40%).
static func slow_power(fraction: float) -> float:
	return fraction / CombatConstants.SLOW_FACTOR


func _ready() -> void:
	set_process(false)
	# Indicadores visuais desenhados sobre o dono (irmão do sprite)
	var owner_node: Node2D = get_parent() as Node2D
	if owner_node != null:
		var indicator: EnemyStatusIndicator = EnemyStatusIndicator.new()
		indicator.name = "StatusIndicator"
		indicator.setup(self, owner_node.get_node_or_null("HealthComponent") as HealthComponent, owner_node.get_node_or_null("Sprite2D") as Sprite2D)
		owner_node.add_child.call_deferred(indicator)


## Retorna true se algum status está ativo.
func has_any() -> bool:
	return not _active.is_empty()


## Aplica (ou renova) um status; mantém a maior duração e potência.
func apply(status: StringName, duration: float, power: float = 1.0) -> void:
	if duration <= 0.0:
		return
	if status == SLOW:
		apply_slow(DEFAULT_SLOW_SOURCE, duration, power)
		return
	var was_active: bool = _active.has(status)
	var entry: Dictionary = _active.get(status, {"time": 0.0, "power": 0.0})
	entry["time"] = maxf(float(entry["time"]), duration)
	entry["power"] = maxf(float(entry["power"]), power)
	_active[status] = entry
	set_process(true)
	if not was_active:
		print("[Combat] - status %s aplicado (%.2f s)" % [status, duration])
		changed.emit(status, true)


## Aplica (ou renova) uma lentidão de uma fonte; na mesma fonte mantém a maior duração/potência, em fontes diferentes multiplica.
func apply_slow(source: StringName, duration: float, power: float = 1.0) -> void:
	if duration <= 0.0:
		return
	var was_active: bool = _active.has(SLOW)
	var entry: Dictionary = _slows.get(source, {"time": 0.0, "power": 0.0})
	entry["time"] = maxf(float(entry["time"]), duration)
	entry["power"] = maxf(float(entry["power"]), power)
	_slows[source] = entry
	_sync_slow()
	set_process(true)
	if not was_active:
		print("[Combat] - status %s aplicado (%.2f s)" % [SLOW, duration])
		changed.emit(SLOW, true)


## Atualiza a entrada agregada de SLOW (maior tempo e potência entre as fontes) ou a remove se não há fontes.
func _sync_slow() -> void:
	if _slows.is_empty():
		_active.erase(SLOW)
		return
	var time: float = 0.0
	var power: float = 0.0
	for source: StringName in _slows:
		time = maxf(time, float(_slows[source]["time"]))
		power = maxf(power, float(_slows[source]["power"]))
	_active[SLOW] = {"time": time, "power": power}


## Aplica stun com duração baseada no nível.
func apply_stun(level: float = 0.0) -> void:
	apply(STUN, stun_duration(level))


## Remove um status imediatamente.
func clear(status: StringName) -> void:
	if status == SLOW:
		_slows.clear()
	if _active.erase(status):
		changed.emit(status, false)


## Retorna true se o status está ativo.
func has(status: StringName) -> bool:
	return _active.has(status)


## Tempo restante de um status (0 se inativo).
func time_left(status: StringName) -> float:
	return float(_active[status]["time"]) if _active.has(status) else 0.0


## Multiplicador de velocidade: produto dos slows de cada fonte (cada um reduz em SLOW_FACTOR * potência), mínimo 0.1.
func speed_multiplier() -> float:
	if _slows.is_empty():
		return 1.0
	var mult: float = 1.0
	for source: StringName in _slows:
		mult *= clampf(1.0 - CombatConstants.SLOW_FACTOR * float(_slows[source]["power"]), 0.1, 1.0)
	return clampf(mult, 0.1, 1.0)


## Pode se mover (roots e stun impedem).
func can_move() -> bool:
	return not has(ROOTS) and not has(STUN)


## Pode agir: causar dano de contato e atacar (stun impede; roots não).
func can_act() -> bool:
	return not has(STUN)


## Multiplicador de dano causado (weakened reduz pela potência, 0.25 = -25%).
func damage_dealt_multiplier() -> float:
	if not has(WEAKENED):
		return 1.0
	return clampf(1.0 - float(_active[WEAKENED]["power"]), 0.0, 1.0)


## Multiplicador de dano recebido: marked (+50%) e, com Crunchy!, stun (+10%); os bônus multiplicam.
func damage_taken_multiplier() -> float:
	var mult: float = 1.0 + CombatConstants.MARKED_DAMAGE_BONUS if has(MARKED) else 1.0
	if has(STUN) and stun_damage_bonus > 0.0:
		mult *= 1.0 + stun_damage_bonus
	return mult


func _process(delta: float) -> void:
	if not _slows.is_empty():
		for source: StringName in _slows.keys():
			_slows[source]["time"] = float(_slows[source]["time"]) - delta
			if float(_slows[source]["time"]) <= 0.0:
				_slows.erase(source)
		_sync_slow()
		if _slows.is_empty():
			changed.emit(SLOW, false)
	for status: StringName in _active.keys():
		if status == SLOW:
			continue
		_active[status]["time"] = float(_active[status]["time"]) - delta
		if float(_active[status]["time"]) <= 0.0:
			_active.erase(status)
			changed.emit(status, false)
	if _active.is_empty():
		set_process(false)
