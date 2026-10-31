class_name HealthComponent
extends Node

signal damaged(amount: int)
signal died()
signal health_changed(current: int, max_value: int)
# Dano ao longo do tempo causado (fonte e quantidade real)
signal dot_damaged(source: StringName, amount: int)  # emitido a cada tick, mesmo com 0
# Dano ignorado pela chance de negação (sinergia Darkness)
signal damage_negated(amount: int)

@export var max_health: int = 5

var current_health: int
var _is_dead: bool = false

const DOT_TICK: float = 0.5
const TICK_EPSILON: float = 0.001

# Multiplicador de dano recebido (ex.: marked); a fração é acumulada
var damage_taken_multiplier: float = 1.0
# Chance de negar um dano recebido por completo (0 = nunca)
var negate_chance: float = 0.0

# source -> { dps, time, tick_every, tick_left, carry }; fontes diferentes empilham
var _dots: Dictionary = {}
var _taken_carry: float = 0.0


func _ready() -> void:
	current_health = max_health
	set_process(false)


# Reduz a vida e emite os sinais correspondentes.
func take_damage(amount: int) -> void:
	_apply_damage(amount)


# Aplica o dano (negação e multiplicador) e retorna o dano realmente causado.
func _apply_damage(amount: int) -> int:
	if _is_dead:
		return 0
	if negate_chance > 0.0 and randf() < negate_chance:
		damage_negated.emit(amount)
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


# Mata na hora, ignorando negação e multiplicadores.
func kill() -> void:
	if _is_dead:
		return
	var lost: int = current_health
	current_health = 0
	damaged.emit(lost)
	health_changed.emit(current_health, max_health)
	_is_dead = true
	died.emit()


# Cura a vida até o máximo.
func heal(amount: int) -> void:
	if _is_dead or amount <= 0:
		return
	current_health = mini(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


# Retorna true se já morreu.
func is_dead() -> bool:
	return _is_dead


# Dano ao longo do tempo por fonte: renova a duração e usa o maior dps da mesma fonte, sem empilhar nela.
func apply_dot(dps: float, duration: float, source: StringName = &"dot", tick: float = DOT_TICK) -> void:
	if _is_dead or dps <= 0.0:
		return
	var dot: Dictionary = _dots.get(source, {"dps": 0.0, "time": 0.0, "tick_every": tick, "tick_left": tick, "carry": 0.0})
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
			var dealt: int = _apply_damage(amount) if amount > 0 else 0
			if not _is_dead or dealt > 0:
				dot_damaged.emit(source, dealt)
		if float(dot["time"]) <= TICK_EPSILON:
			_dots.erase(source)
	if _dots.is_empty() or _is_dead:
		_dots.clear()
		set_process(false)
