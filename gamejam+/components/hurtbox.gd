class_name Hurtbox
extends Area2D

## Emitted before the damage: direction of the hit (zero if unknown) and whether it was a critical.
signal hit_received(direction: Vector2, is_crit: bool)

@export var health_component: HealthComponent
## Invincibility after taking damage (s). 0 = no i-frames (enemies).
@export var invulnerability_time: float = 0.0

# Current hit data (valid during the HealthComponent's damaged signal)
var last_hit_direction: Vector2 = Vector2.ZERO
var last_hit_crit: bool = false

var _invulnerable_left: float = 0.0


func _ready() -> void:
	set_physics_process(false)


## Passes the received damage to the HealthComponent (ignored during i-frames).
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


## Turns on invincibility for "duration" seconds.
func start_invulnerability(duration: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left, duration)
	set_physics_process(true)


## Returns true during i-frames.
func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


func _physics_process(delta: float) -> void:
	_invulnerable_left -= delta
	if _invulnerable_left <= 0.0:
		_invulnerable_left = 0.0
		set_physics_process(false)


# Passes damage over time to the HealthComponent.
func apply_dot(dps: float, duration: float, source: StringName = &"dot", tick: float = HealthComponent.DOT_TICK) -> void:
	if health_component:
		health_component.apply_dot(dps, duration, source, tick)


# Applies a status to the owner (sibling StatusEffects node), if it exists.
func apply_status(status: StringName, duration: float, power: float = 1.0) -> void:
	var effects: StatusEffects = get_parent().get_node_or_null("StatusEffects") as StatusEffects
	if effects != null:
		effects.apply(status, duration, power)


# Applies a slow from a named source (different sources multiply); fraction 0.4 = -40%.
func apply_slow(source: StringName, duration: float, fraction: float) -> void:
	var effects: StatusEffects = get_parent().get_node_or_null("StatusEffects") as StatusEffects
	if effects != null:
		effects.apply_slow(source, duration, StatusEffects.slow_power(fraction))
