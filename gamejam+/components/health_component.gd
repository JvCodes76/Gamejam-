class_name HealthComponent
extends Node

signal damaged(amount: int)
signal died()
signal health_changed(current: int, max_value: int)

@export var max_health: int = 5

var current_health: int
var _is_dead: bool = false

const DOT_TICK: float = 0.5
var _dot_dps: float = 0.0
var _dot_time_left: float = 0.0
var _dot_tick: float = 0.0
var _dot_carry: float = 0.0


func _ready() -> void:
	current_health = max_health
	set_process(false)


# Reduz a vida e emite os sinais correspondentes.
func take_damage(amount: int) -> void:
	if _is_dead:
		return
	current_health = maxi(current_health - amount, 0)
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		_is_dead = true
		died.emit()


# Cura a vida até o máximo.
func heal(amount: int) -> void:
	if _is_dead or amount <= 0:
		return
	current_health = mini(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


# Dano ao longo do tempo (tick de 0.5 s): renova a duração e usa o maior dps, sem empilhar.
func apply_dot(dps: float, duration: float) -> void:
	if _is_dead or dps <= 0.0:
		return
	_dot_dps = maxf(_dot_dps, dps)
	_dot_time_left = maxf(_dot_time_left, duration)
	set_process(true)


func _process(delta: float) -> void:
	_dot_time_left -= delta
	_dot_tick -= delta
	if _dot_tick <= 0.0:
		_dot_tick += DOT_TICK
		_dot_carry += _dot_dps * DOT_TICK
		var amount: int = int(_dot_carry)
		_dot_carry -= amount
		if amount > 0:
			take_damage(amount)
	if _dot_time_left <= 0.0:
		_dot_dps = 0.0
		_dot_carry = 0.0
		_dot_tick = 0.0
		set_process(false)
