class_name StatusEffects
extends Node
## Temporary statuses of an enemy (roots, slow, stun, marked, charmed, weakened) with their own timers.

signal changed(status: StringName, active: bool)

const ROOTS: StringName = &"roots"
const SLOW: StringName = &"slow"
const STUN: StringName = &"stun"
const MARKED: StringName = &"marked"
const CHARMED: StringName = &"charmed"
const WEAKENED: StringName = &"weakened"

# Visual indicators (direct preload: does not depend on the editor's class_name cache)
const INDICATOR_SCRIPT: GDScript = preload("res://enemies/enemy_status_indicator.gd")

# Default slow source when apply(SLOW) is called without a source
const DEFAULT_SLOW_SOURCE: StringName = &"default"

# Bonus damage taken by stunned enemies (Crunchy!); set by the SynergyDirector, applies to all enemies
static var stun_damage_bonus: float = 0.0

# status -> { "time": float, "power": float }
var _active: Dictionary = {}
# Slow per source: source -> { "time": float, "power": float }; different sources multiply
var _slows: Dictionary = {}


## Stun duration: min(cap, STUN_BASE + 0.1 * level + extra); the default cap is STUN_MAX.
static func stun_duration(level: float = 0.0, extra: float = 0.0, cap: float = CombatConstants.STUN_MAX) -> float:
	return minf(maxf(cap, CombatConstants.STUN_MAX), CombatConstants.STUN_BASE + CombatConstants.STUN_PER_LEVEL * level + extra)


## Slow power equivalent to reducing speed by "fraction" (0.4 = -40%).
static func slow_power(fraction: float) -> float:
	return fraction / CombatConstants.SLOW_FACTOR


func _ready() -> void:
	set_process(false)
	# Visual indicators drawn over the owner (sibling of the sprite)
	var owner_node: Node2D = get_parent() as Node2D
	if owner_node != null:
		var indicator: Node2D = INDICATOR_SCRIPT.new()
		indicator.name = "StatusIndicator"
		indicator.setup(self, owner_node.get_node_or_null("HealthComponent") as HealthComponent, owner_node.get_node_or_null("Sprite2D") as Sprite2D)
		owner_node.add_child.call_deferred(indicator)


## Returns true if any status is active.
func has_any() -> bool:
	return not _active.is_empty()


## Applies (or renews) a status; keeps the longest duration and highest power.
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
		print("[Combat] - status %s applied (%.2f s)" % [status, duration])
		changed.emit(status, true)


## Applies (or renews) a slow from a source; within the same source keeps the longest duration/power, across different sources multiplies.
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
		print("[Combat] - status %s applied (%.2f s)" % [SLOW, duration])
		changed.emit(SLOW, true)


## Updates the aggregated SLOW entry (longest time and highest power among the sources) or removes it if there are no sources.
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


## Applies stun with a duration based on the level.
func apply_stun(level: float = 0.0) -> void:
	apply(STUN, stun_duration(level))


## Removes a status immediately.
func clear(status: StringName) -> void:
	if status == SLOW:
		_slows.clear()
	if _active.erase(status):
		changed.emit(status, false)


## Returns true if the status is active.
func has(status: StringName) -> bool:
	return _active.has(status)


## Remaining time of a status (0 if inactive).
func time_left(status: StringName) -> float:
	return float(_active[status]["time"]) if _active.has(status) else 0.0


## Speed multiplier: product of each source's slows (each reduces by SLOW_FACTOR * power), minimum 0.1.
func speed_multiplier() -> float:
	if _slows.is_empty():
		return 1.0
	var mult: float = 1.0
	for source: StringName in _slows:
		mult *= clampf(1.0 - CombatConstants.SLOW_FACTOR * float(_slows[source]["power"]), 0.1, 1.0)
	return clampf(mult, 0.1, 1.0)


## Can move (roots and stun prevent it).
func can_move() -> bool:
	return not has(ROOTS) and not has(STUN)


## Can act: deal contact damage and attack (stun prevents it; roots do not).
func can_act() -> bool:
	return not has(STUN)


## Damage dealt multiplier (weakened reduces by the power, 0.25 = -25%).
func damage_dealt_multiplier() -> float:
	if not has(WEAKENED):
		return 1.0
	return clampf(1.0 - float(_active[WEAKENED]["power"]), 0.0, 1.0)


## Damage taken multiplier: marked (+50%) and, with Crunchy!, stun (+10%); the bonuses multiply.
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
