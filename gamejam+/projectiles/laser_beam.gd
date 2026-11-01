class_name LaserBeam
extends Node2D
## Laser (Brimstone): child of the muzzle, so it follows the aim. First it charges (a growing glow),
## then a beam deals 100% of the weapon damage per tick to everything on the line, stopping at walls.

signal finished

var mods: ProjectileModifiers = null
var base_damage: int = 1
var shooter_health: HealthComponent = null

var _charge: float = 0.0
var _firing: bool = false
var _age: float = 0.0
var _tick_left: float = 0.0
var _length: float = 0.0
var _tint: Color = Color.WHITE


func _ready() -> void:
	z_index = CombatConstants.Z_ARC
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Starts as a charge glow at the muzzle.
func setup(new_mods: ProjectileModifiers, new_base_damage: int, shooter: HealthComponent) -> void:
	mods = new_mods
	base_damage = new_base_damage
	shooter_health = shooter
	_tint = new_mods.color.lerp(Color(1.0, 0.1, 0.1), 0.6)


## Charge progress (0 to 1) while the player holds the button.
func set_charge(ratio: float) -> void:
	_charge = clampf(ratio, 0.0, 1.0)
	queue_redraw()


## Releases the beam.
func fire() -> void:
	_firing = true
	_age = 0.0
	_tick_left = 0.0
	EventBus.play_sfx_requested.emit("shoot")
	EventBus.screen_shake_requested.emit(FeelConstants.TRAUMA_PLAYER_HURT * 0.5)


func _physics_process(delta: float) -> void:
	if not _firing:
		return
	_age += delta
	if _age >= CombatConstants.LASER_DURATION:
		finished.emit()
		queue_free()
		return
	var dir: Vector2 = Vector2.RIGHT.rotated(global_rotation)
	_length = _beam_length(dir)
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left += CombatConstants.LASER_TICK
		_damage_line(dir)
	queue_redraw()


func _draw() -> void:
	if not _firing:
		draw_circle(Vector2.ZERO, 2.0 + 5.0 * _charge, Color(_tint, 0.35 + 0.5 * _charge))
		return
	var fade: float = 1.0 - _age / CombatConstants.LASER_DURATION * 0.5
	var width: float = CombatConstants.LASER_WIDTH
	draw_line(Vector2.ZERO, Vector2(_length, 0.0), Color(_tint, 0.35 * fade), width * 1.8)
	draw_line(Vector2.ZERO, Vector2(_length, 0.0), Color(_tint, 0.9 * fade), width)
	draw_line(Vector2.ZERO, Vector2(_length, 0.0), Color(1.0, 1.0, 1.0, fade), width * 0.4)
	draw_circle(Vector2(_length, 0.0), width * 0.8, Color(_tint, 0.7 * fade))


## Beam length: the maximum range or the distance to the first wall.
func _beam_length(dir: Vector2) -> float:
	var max_length: float = CombatConstants.LASER_RANGE * mods.range_multiplier
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, global_position + dir * max_length, PhysicsLayers.PROJECTILE_WALL_MASK)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return max_length
	return global_position.distance_to(hit["position"])


## One tick: damage and potion effects to every enemy on the line.
func _damage_line(dir: Vector2) -> void:
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(maxf(_length, 1.0), CombatConstants.LASER_WIDTH)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(dir.angle(), global_position + dir * _length * 0.5)
	query.collision_mask = PhysicsLayers.ENEMY
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var hurtbox: Hurtbox = hit["collider"] as Hurtbox
		if hurtbox == null:
			continue
		var target_mods: ProjectileModifiers = mods.for_target(hurtbox)
		var dealt: int = target_mods.roll_secondary_damage(base_damage, CombatConstants.LASER_FRACTION)
		hurtbox.receive_hit(dealt, dir)
		target_mods.apply_on_hit_effects(hurtbox, base_damage)
		if shooter_health != null and is_instance_valid(shooter_health):
			shooter_health.heal(target_mods.roll_heal(dealt, shooter_health.max_health))
