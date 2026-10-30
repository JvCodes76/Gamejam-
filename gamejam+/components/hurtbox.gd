class_name Hurtbox
extends Area2D

@export var health_component: HealthComponent


# Repassa o dano recebido ao HealthComponent.
func receive_hit(damage: int) -> void:
	if health_component:
		health_component.take_damage(damage)
