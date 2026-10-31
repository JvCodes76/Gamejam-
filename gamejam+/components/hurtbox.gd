class_name Hurtbox
extends Area2D

## Emitido antes do dano: direção do golpe (zero se desconhecida) e se foi crítico.
signal hit_received(direction: Vector2, is_crit: bool)

@export var health_component: HealthComponent
## Invencibilidade após levar dano (s). 0 = sem i-frames (inimigos).
@export var invulnerability_time: float = 0.0

# Dados do golpe atual (válidos durante o sinal damaged do HealthComponent)
var last_hit_direction: Vector2 = Vector2.ZERO
var last_hit_crit: bool = false

var _invulnerable_left: float = 0.0


func _ready() -> void:
	set_physics_process(false)


## Repassa o dano recebido ao HealthComponent (ignora durante os i-frames).
func receive_hit(damage: int, direction: Vector2 = Vector2.ZERO, is_crit: bool = false) -> void:
	if health_component == null or is_invulnerable():
		return
	last_hit_direction = direction
	last_hit_crit = is_crit
	hit_received.emit(direction, is_crit)
	var before: int = health_component.current_health
	health_component.take_damage(damage)
	last_hit_crit = false
	if invulnerability_time > 0.0 and health_component.current_health < before:
		start_invulnerability(invulnerability_time)


## Liga a invencibilidade por "duration" segundos.
func start_invulnerability(duration: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left, duration)
	set_physics_process(true)


## Retorna true durante os i-frames.
func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


func _physics_process(delta: float) -> void:
	_invulnerable_left -= delta
	if _invulnerable_left <= 0.0:
		_invulnerable_left = 0.0
		set_physics_process(false)


# Repassa um dano ao longo do tempo ao HealthComponent.
func apply_dot(dps: float, duration: float, source: StringName = &"dot", tick: float = HealthComponent.DOT_TICK) -> void:
	if health_component:
		health_component.apply_dot(dps, duration, source, tick)


# Aplica um status ao dono (nó StatusEffects irmão), se existir.
func apply_status(status: StringName, duration: float, power: float = 1.0) -> void:
	var effects: StatusEffects = get_parent().get_node_or_null("StatusEffects") as StatusEffects
	if effects != null:
		effects.apply(status, duration, power)


# Aplica uma lentidão de uma fonte nomeada (fontes diferentes multiplicam); fraction 0.4 = -40%.
func apply_slow(source: StringName, duration: float, fraction: float) -> void:
	var effects: StatusEffects = get_parent().get_node_or_null("StatusEffects") as StatusEffects
	if effects != null:
		effects.apply_slow(source, duration, StatusEffects.slow_power(fraction))
