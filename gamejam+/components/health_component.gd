class_name HealthComponent
extends Node

signal damaged(amount: int)
signal died()
signal health_changed(current: int, max_value: int)

@export var max_health: int = 5

var current_health: int
var _is_dead: bool = false


func _ready() -> void:
	current_health = max_health


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
