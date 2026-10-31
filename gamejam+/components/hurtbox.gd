class_name Hurtbox
extends Area2D

@export var health_component: HealthComponent


# Repassa o dano recebido ao HealthComponent.
func receive_hit(damage: int) -> void:
	if health_component:
		health_component.take_damage(damage)


# Repassa um dano ao longo do tempo ao HealthComponent.
func apply_dot(dps: float, duration: float, source: StringName = &"dot", tick: float = HealthComponent.DOT_TICK) -> void:
	if health_component:
		health_component.apply_dot(dps, duration, source, tick)


# Aplica um status ao dono (nó StatusEffects irmão), se existir.
func apply_status(status: StringName, duration: float, power: float = 1.0) -> void:
	var effects: StatusEffects = get_parent().get_node_or_null("StatusEffects") as StatusEffects
	if effects != null:
		effects.apply(status, duration, power)
