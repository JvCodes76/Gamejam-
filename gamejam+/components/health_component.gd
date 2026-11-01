class_name HealthComponent
extends Node

signal damaged(amount: int)
signal died()
signal health_changed(current: int, max_value: int)
# Damage over time dealt (source and actual amount)
signal dot_damaged(source: StringName, amount: int)  # emitted on every tick, even with 0
# Damage ignored by the negation chance (Darkness synergy)
signal damage_negated(amount: int)

@export var max_health: int = 75

var current_health: int
var _is_dead: bool = false

const DOT_TICK: float = 0.5
const TICK_EPSILON: float = 0.001

# Damage taken multiplier (e.g. marked); the fraction is accumulated
var damage_taken_multiplier: float = 1.0
# Resistance of the owner (e.g. the boss): damage_scale applies to all damage (hits and DoT), direct_damage_scale
# only to direct hits (take_damage, not DoT ticks). Separate from damage_taken_multiplier, which statuses overwrite.
var damage_scale: float = 1.0
var direct_damage_scale: float = 1.0
# Chance to completely negate incoming damage (0 = never)
var negate_chance: float = 0.0

# source -> { dps, time, tick_every, tick_left, carry }; different sources stack
var _dots: Dictionary = {}
var _taken_carry: float = 0.0
var _direct_carry: float = 0.0
var _scale_carry: float = 0.0
# True while a DoT tick applies damage (hit feedback ignores this damage)
var applying_dot: bool = false


func _ready() -> void:
	current_health = max_health
	set_process(false)


# Reduces health and emits the corresponding signals.
func take_damage(amount: int) -> void:
	if direct_damage_scale != 1.0:
		_direct_carry += amount * direct_damage_scale
		amount = int(_direct_carry)
		_direct_carry -= amount
		if amount <= 0:
			return
	_apply_damage(amount)


# Applies the damage (negation and multiplier) and returns the damage actually dealt.
func _apply_damage(amount: int) -> int:
	if _is_dead:
		return 0
	if negate_chance > 0.0 and randf() < negate_chance:
		damage_negated.emit(amount)
		return 0
	if damage_scale != 1.0:
		_scale_carry += amount * damage_scale
		amount = int(_scale_carry)
		_scale_carry -= amount
		if amount <= 0:
			return 0
	if damage_taken_multiplier != 1.0:
		_taken_carry += amount * damage_taken_multiplier
		amount = int(_taken_carry)
		_taken_carry -= amount
		if amount <= 0:
			return 0
	current_health = maxi(current_health - amount, 0)
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		_is_dead = true
		died.emit()
	return amount


# Kills instantly, ignoring negation and multipliers.
func kill() -> void:
	if _is_dead:
		return
	var lost: int = current_health
	current_health = 0
	damaged.emit(lost)
	health_changed.emit(current_health, max_health)
	_is_dead = true
	died.emit()


# Heals health up to the maximum.
func heal(amount: int) -> void:
	if _is_dead or amount <= 0:
		return
	current_health = mini(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


# Returns true if already dead.
func is_dead() -> bool:
	return _is_dead


# Damage over time per source: renews the duration and uses the highest dps of the same source, without stacking on it.
# max_stacks > 1 makes the source stack: each application adds its dps (up to max_stacks) and resets the duration.
func apply_dot(dps: float, duration: float, source: StringName = &"dot", tick: float = DOT_TICK, max_stacks: int = 1) -> void:
	if _is_dead or dps <= 0.0:
		return
	var dot: Dictionary = _dots.get(source, {"dps": 0.0, "time": 0.0, "tick_every": tick, "tick_left": tick, "carry": 0.0, "stacks": 0})
	if max_stacks > 1:
		var stacks: int = int(dot.get("stacks", 0))
		if stacks < max_stacks:
			dot["dps"] = float(dot["dps"]) + dps
			dot["stacks"] = stacks + 1
		dot["time"] = duration
	else:
		dot["dps"] = maxf(float(dot["dps"]), dps)
		dot["time"] = maxf(float(dot["time"]), duration)
	_dots[source] = dot
	set_process(true)


func _process(delta: float) -> void:
	for source: StringName in _dots.keys():
		var dot: Dictionary = _dots[source]
		dot["time"] = float(dot["time"]) - delta
		dot["tick_left"] = float(dot["tick_left"]) - delta
		if float(dot["tick_left"]) <= TICK_EPSILON:
			dot["tick_left"] = float(dot["tick_left"]) + float(dot["tick_every"])
			dot["carry"] = float(dot["carry"]) + float(dot["dps"]) * float(dot["tick_every"])
			var amount: int = int(dot["carry"])
			dot["carry"] = float(dot["carry"]) - amount
			applying_dot = true
			var dealt: int = _apply_damage(amount) if amount > 0 else 0
			applying_dot = false
			if not _is_dead or dealt > 0:
				dot_damaged.emit(source, dealt)
		if float(dot["time"]) <= TICK_EPSILON:
			_dots.erase(source)
	if _dots.is_empty() or _is_dead:
		_dots.clear()
		set_process(false)


# Active DoT sources (status indicators).
func active_dot_sources() -> Array:
	return _dots.keys()
