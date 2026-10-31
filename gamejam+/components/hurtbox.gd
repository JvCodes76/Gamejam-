class_name Hurtbox
extends Area2D

@export var health_component: HealthComponent


# Repassa o dano recebido ao HealthComponent.
func receive_hit(damage: int) -> void:
	if health_component:
		health_component.take_damage(damage)


# Repassa um dano ao longo do tempo ao HealthComponent.
func apply_dot(dps: float, duration: float) -> void:
	if health_component:
		health_component.apply_dot(dps, duration)
