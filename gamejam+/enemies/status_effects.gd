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

# status -> { "time": float, "power": float }
var _active: Dictionary = {}


## Duração do stun: min(teto, STUN_BASE + 0.1 * nível + extra); o teto padrão é STUN_MAX.
static func stun_duration(level: float = 0.0, extra: float = 0.0, cap: float = CombatConstants.STUN_MAX) -> float:
	return minf(maxf(cap, CombatConstants.STUN_MAX), CombatConstants.STUN_BASE + CombatConstants.STUN_PER_LEVEL * level + extra)


## Potência de slow que equivale a reduzir a velocidade em "fraction" (0.4 = -40%).
static func slow_power(fraction: float) -> float:
	return fraction / CombatConstants.SLOW_FACTOR


func _ready() -> void:
	set_process(false)


## Aplica (ou renova) um status; mantém a maior duração e potência.
func apply(status: StringName, duration: float, power: float = 1.0) -> void:
	if duration <= 0.0:
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


## Aplica stun com duração baseada no nível.
func apply_stun(level: float = 0.0) -> void:
	apply(STUN, stun_duration(level))


## Remove um status imediatamente.
func clear(status: StringName) -> void:
	if _active.erase(status):
		changed.emit(status, false)


## Retorna true se o status está ativo.
func has(status: StringName) -> bool:
	return _active.has(status)


## Tempo restante de um status (0 se inativo).
func time_left(status: StringName) -> float:
	return float(_active[status]["time"]) if _active.has(status) else 0.0


## Multiplicador de velocidade (slow reduz em SLOW_FACTOR).
func speed_multiplier() -> float:
	if not has(SLOW):
		return 1.0
	return clampf(1.0 - CombatConstants.SLOW_FACTOR * float(_active[SLOW]["power"]), 0.1, 1.0)


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


## Multiplicador de dano recebido (marked).
func damage_taken_multiplier() -> float:
	return 1.0 + CombatConstants.MARKED_DAMAGE_BONUS if has(MARKED) else 1.0


func _process(delta: float) -> void:
	for status: StringName in _active.keys():
		_active[status]["time"] = float(_active[status]["time"]) - delta
		if float(_active[status]["time"]) <= 0.0:
			_active.erase(status)
			changed.emit(status, false)
	if _active.is_empty():
		set_process(false)
