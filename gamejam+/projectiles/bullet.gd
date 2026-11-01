class_name Bullet
extends Hitbox

const BULLET_SCENE_PATH: String = "res://projectiles/bullet.tscn"

@export var speed: float = 300.0
@export var lifetime: float = 1.5

var direction: Vector2 = Vector2.RIGHT
var modifiers: ProjectileModifiers = null
var shooter_health: HealthComponent = null
# Remaining bounces: after a hit (with no pierce left) the bullet jumps to another enemy; walls always destroy it
var bounce_count: int = 0
# Child bullet of Weird Eye Drops: does not split again, no crit or lifesteal
var split_child: bool = false
# Fraction of the bullet's damage (children use SPLIT_DAMAGE_FRACTION)
var damage_factor: float = 1.0

var _spent: bool = false
var _age: float = 0.0
var _pierce_left: int = 0
# Homing steering level (0 = off) and AOE aura (radius px, 0 = off) with its tick timer
var _homing: float = 0.0
var _aoe_radius: float = 0.0
var _aoe_left: float = 0.0
var _hit_hurtboxes: Array[Hurtbox] = []
# Hurtboxes the child bullet ignores (already hit by the parent)
var _ignored: Array[Hurtbox] = []
# Holy bullet (Light synergy), bullet color and distances since the last trail (mud and cloud)
var _holy: bool = false
var _tint: Color = Color.WHITE
var _mud_distance: float = 0.0
var _cloud_distance: float = 0.0
# Trail (Line2D in global coordinates) with the bullet's latest points
var _trail: Line2D


func _ready() -> void:
	super()
	body_entered.connect(_on_body_entered)
	_build_trail()
	# Spawns bigger and shrinks to the normal scale
	var sprite: Sprite2D = $Sprite2D as Sprite2D
	var target_scale: Vector2 = sprite.scale
	sprite.scale = target_scale * FeelConstants.BULLET_SPAWN_SCALE
	create_tween().tween_property(sprite, "scale", target_scale, FeelConstants.BULLET_SPAWN_TIME)


## Short trail in the bullet's color, with alpha falling off toward the tail.
func _build_trail() -> void:
	_trail = Line2D.new()
	_trail.top_level = true
	_trail.width = FeelConstants.BULLET_TRAIL_WIDTH * (0.7 if split_child else 1.0)
	_trail.z_index = -1
	_trail.z_as_relative = true
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(_tint, 0.0))
	gradient.set_color(1, Color(_tint, 0.7))
	_trail.gradient = gradient
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.3))
	curve.add_point(Vector2(1.0, 1.0))
	_trail.width_curve = curve
	add_child(_trail)


func _update_trail() -> void:
	_trail.add_point(global_position)
	while _trail.get_point_count() > FeelConstants.BULLET_TRAIL_POINTS:
		_trail.remove_point(0)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		_impact(_roll_impact_damage())
		return
	if _homing > 0.0:
		_steer_toward_enemy(delta)
	global_position += direction * speed * delta
	_update_trail()
	if _aoe_radius > 0.0:
		_aoe_left -= delta
		if _aoe_left <= 0.0:
			_aoe_left += CombatConstants.AOE_TICK
			_aoe_tick()
	if modifiers != null:
		if modifiers.synergy.mud_enabled:
			_drop_mud(speed * delta)
		if modifiers.synergy.cloud_enabled:
			_drop_cloud(speed * delta)


## Sets the projectile direction and rotates the sprite.
func setup(new_direction: Vector2) -> void:
	direction = new_direction.normalized()
	rotation = direction.angle()


## Applies the potion modifiers: color, range, pierce, bounce, damage, lifesteal and DoTs.
func apply_modifiers(mods: ProjectileModifiers, shooter: HealthComponent = null) -> void:
	modifiers = mods
	shooter_health = shooter
	lifetime *= mods.range_multiplier
	_pierce_left = mods.pierce_count
	bounce_count = mods.bounce_count
	_homing = mods.homing_level
	_aoe_radius = CombatConstants.AOE_RADIUS_PER_POINT * mods.aoe_level
	set_tint(mods.color)
	_holy = mods.roll_holy()
	if _holy:
		set_tint(SynergyConstants.LIGHT_HOLY_COLOR)
		($Sprite2D as Sprite2D).scale *= 1.4
		print("[Synergy] - holy bullet fired")
	if _aoe_radius > 0.0:
		queue_redraw()


func _draw() -> void:
	if _aoe_radius > 0.0:
		draw_circle(Vector2.ZERO, _aoe_radius, Color(_tint, 0.16))
		draw_arc(Vector2.ZERO, _aoe_radius, 0.0, TAU, 32, Color(_tint, 0.45), 1.0)


## Flame of the Dragon's Blood fire breath: short-lived, pierces everything, a fraction of the damage per flame.
func setup_flame(new_direction: Vector2) -> void:
	speed = CombatConstants.FLAME_SPEED
	lifetime = CombatConstants.FLAME_LIFETIME * modifiers.range_multiplier
	damage_factor = 1.0 / CombatConstants.FLAME_RATE_DIVISOR
	_pierce_left = CombatConstants.FLAME_PIERCE
	bounce_count = 0
	_holy = false
	set_tint(CombatConstants.FLAME_COLOR)
	($Sprite2D as Sprite2D).scale *= 1.3
	setup(new_direction)


## Nearest living enemy not yet hit, within the homing range; null if none.
func _nearest_enemy(max_range: float) -> EnemyBase:
	var best: EnemyBase = null
	var best_dist: float = max_range * max_range
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var enemy: EnemyBase = node as EnemyBase
		if enemy == null or not enemy.is_alive() or enemy.get_hurtbox() in _hit_hurtboxes:
			continue
		var dist: float = global_position.distance_squared_to(enemy.global_position + CombatConstants.ENEMY_BODY_OFFSET)
		if dist <= best_dist:
			best_dist = dist
			best = enemy
	return best


## Homing: turns the direction toward the nearest enemy, limited by the turn rate.
func _steer_toward_enemy(delta: float) -> void:
	var target: EnemyBase = _nearest_enemy(CombatConstants.HOMING_RANGE)
	if target == null:
		return
	var wanted: Vector2 = (target.global_position + CombatConstants.ENEMY_BODY_OFFSET - global_position).normalized()
	var max_turn: float = CombatConstants.HOMING_TURN_RATE_PER_POINT * _homing * delta
	direction = direction.rotated(clampf(direction.angle_to(wanted), -max_turn, max_turn))
	rotation = direction.angle()


## AOE aura: damages every enemy inside the radius with a fraction of the weapon damage.
func _aoe_tick() -> void:
	if modifiers == null:
		return
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = _aoe_radius
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = PhysicsLayers.ENEMY
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var hurtbox: Hurtbox = hit["collider"] as Hurtbox
		if hurtbox == null or hurtbox in _ignored:
			continue
		var mods: ProjectileModifiers = modifiers.for_target(hurtbox)
		hurtbox.receive_hit(mods.roll_secondary_damage(damage, CombatConstants.AOE_TICK_FRACTION * damage_factor), (hurtbox.global_position - global_position).normalized())


## Sets the bullet color (sprite and impact particles).
func set_tint(color: Color) -> void:
	_tint = color
	($Sprite2D as Sprite2D).modulate = color
	if _trail != null:
		_trail.gradient.set_color(0, Color(color, 0.0))
		_trail.gradient.set_color(1, Color(color, 0.7))
	queue_redraw()


## Current bullet color.
func get_tint() -> Color:
	return _tint


## Returns true if the bullet is holy (Light synergy).
func is_holy() -> bool:
	return _holy


## Configures this bullet as a child of Weird Eye Drops: inherits color, effects and reduced damage, without splitting again.
func setup_child(parent: Bullet, new_direction: Vector2) -> void:
	split_child = true
	damage = parent.damage
	damage_factor = SynergyConstants.SPLIT_DAMAGE_FRACTION
	modifiers = parent.modifiers
	shooter_health = null
	lifetime = parent.lifetime * SynergyConstants.SPLIT_LIFETIME_FRACTION
	_holy = parent._holy
	_pierce_left = 0
	bounce_count = 0
	_homing = parent._homing
	_hit_hurtboxes = parent._hit_hurtboxes.duplicate()
	_ignored = parent._hit_hurtboxes.duplicate()
	set_tint(parent._tint)
	($Sprite2D as Sprite2D).scale = ($Sprite2D as Sprite2D).scale * 0.8
	setup(new_direction)


## Ground point under the bullet (it flies at the height of the player's body): mud and cloud stay on the ground, not in the air.
func _ground_point() -> Vector2:
	return global_position + Vector2(0.0, CombatConstants.BODY_HEIGHT)


## Leaves a mud puddle every EARTH_TRAIL_SPACING px traveled.
func _drop_mud(step: float) -> void:
	_mud_distance += step
	if _mud_distance < SynergyConstants.EARTH_TRAIL_SPACING:
		return
	_mud_distance -= SynergyConstants.EARTH_TRAIL_SPACING
	MudTrail.spawn(get_tree().current_scene, _ground_point(), SynergyConstants.EARTH_TRAIL_RADIUS, SynergyConstants.EARTH_TRAIL_LIFETIME, modifiers.synergy.mud_slow, modifiers.mud_dps(damage))


## Leaves a cloud (Spice bag) every CLOUD_TRAIL_SPACING px traveled.
func _drop_cloud(step: float) -> void:
	_cloud_distance += step
	if _cloud_distance < SynergyConstants.CLOUD_TRAIL_SPACING:
		return
	_cloud_distance -= SynergyConstants.CLOUD_TRAIL_SPACING
	CloudTrail.spawn(get_tree().current_scene, _ground_point(), SynergyConstants.CLOUD_TRAIL_RADIUS, SynergyConstants.CLOUD_TRAIL_LIFETIME, modifiers.synergy.cloud_slow)


## Applies damage (with crit per hit), status effects and lifesteal; consumes the bullet if no pierce remains.
func apply_hit(area: Area2D) -> void:
	if not area is Hurtbox:
		return
	var hurtbox: Hurtbox = area as Hurtbox
	if hurtbox in _ignored or hurtbox in _hit_hurtboxes:
		return
	# Against the boss only the items it is not immune to apply
	var mods: ProjectileModifiers = modifiers.for_target(hurtbox) if modifiers != null else null
	var dealt: int = damage
	var crit: bool = false
	if mods != null:
		var extra: float = (1.0 + SynergyConstants.LIGHT_HOLY_BONUS if _holy else 1.0) * damage_factor
		dealt = mods.roll_damage(damage, extra)
		if not split_child and mods.roll_crit():
			dealt = maxi(roundi(dealt * mods.crit_multiplier()), 1)
			crit = true
			print("[Combat] - critical! damage %d" % dealt)
	hurtbox.receive_hit(dealt, direction, crit)
	EventBus.play_sfx_requested.emit("crit" if crit else "hit")
	if mods != null:
		mods.apply_on_hit_effects(hurtbox, damage)
		if _holy:
			mods.try_holy_slay(hurtbox)
		if mods.synergy.arc_enabled:
			MagicArc.chain_from(hurtbox, mods, damage)
		if shooter_health != null and is_instance_valid(shooter_health):
			shooter_health.heal(mods.roll_heal(dealt, shooter_health.max_health))
	hit_landed.emit()
	_hit_hurtboxes.append(hurtbox)
	_split(global_position, direction)
	if _pierce_left > 0:
		_pierce_left -= 1
		if mods != null:
			mods.try_tea(hurtbox)
	elif bounce_count > 0 and _bounce_to_next_enemy():
		return
	else:
		_impact(dealt, true)


## Bounce: redirects the bullet to the nearest enemy not yet hit and refunds part of its range. False if none is near.
func _bounce_to_next_enemy() -> bool:
	var target: EnemyBase = _nearest_enemy(CombatConstants.BOUNCE_RANGE)
	if target == null:
		return false
	bounce_count -= 1
	direction = (target.global_position + CombatConstants.ENEMY_BODY_OFFSET - global_position).normalized()
	rotation = direction.angle()
	_age = maxf(_age - lifetime * CombatConstants.BOUNCE_LIFETIME_REFUND, 0.0)
	print("[Combat] - bullet bounced to another enemy (%d left)" % bounce_count)
	return true


## Split (Eye of Giant Newt / Weird Eye Drops): spawns split_count child bullets fanned around "dir", leaving from "origin"; children do not split.
func _split(origin: Vector2, dir: Vector2) -> void:
	if split_child or modifiers == null or modifiers.split_count <= 0:
		return
	var scene: Node = get_tree().current_scene
	var count: int = modifiers.split_count
	var span: float = SynergyConstants.SPLIT_ANGLE_DEG
	for i: int in count:
		# One child leaves to a random side; two or more are spread evenly across +-span
		var offset: float = span * (1.0 if randf() < 0.5 else -1.0) if count == 1 else lerpf(-span, span, float(i) / float(count - 1))
		var child: Bullet = (load(BULLET_SCENE_PATH) as PackedScene).instantiate() as Bullet
		child.global_position = origin
		child.setup_child(self, dir.rotated(deg_to_rad(offset)))
		scene.add_child.call_deferred(child)
	print("[Combat] - projectile split into %d" % count)


## Avoids double damage in the same frame after the bullet has already hit something.
func _on_area_entered(area: Area2D) -> void:
	if _spent:
		return
	super(area)


## Tall wall or tall obstacle volume (low obstacles do not collide): destroys the bullet (enemies are handled by the Hurtbox, so pierce and bounce work).
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") or _spent:
		return
	var wall: Dictionary = _probe_wall()
	_wall_feedback(Vector2(wall["position"]))
	_impact(_roll_impact_damage())


## Impact damage without a direct target (wall or end of range): no crit, with the bullet's damage fraction.
func _roll_impact_damage() -> int:
	if modifiers == null:
		return damage
	return modifiers.roll_damage(damage, damage_factor)


## Bullet died on the wall: mini burst with a ring and notice on the EventBus.
func _wall_feedback(at: Vector2) -> void:
	var scene: Node = get_tree().current_scene
	if scene != null:
		var fx: ImpactEffect = ImpactEffect.spawn_burst(scene, at, 7.0, _tint, 5, 0.3, 1.0, 0.6)
		fx.global_position = at
	EventBus.bullet_hit_wall.emit(at, _tint)
	EventBus.play_sfx_requested.emit("wall_hit")


## Point and normal of the touched wall: short ray along the direction; with no hit, uses the opposite direction as the normal.
func _probe_wall() -> Dictionary:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position - direction * 12.0, global_position + direction * 10.0, PhysicsLayers.PROJECTILE_WALL_MASK)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"position": global_position, "normal": -direction}
	return hit


## Destroys the bullet on contact and creates the impact effect (only once). The explosion (Explosive) only happens on an enemy hit.
func _impact(dealt: int, hit_enemy: bool = false) -> void:
	if _spent:
		return
	_spent = true
	var explode: bool = hit_enemy and modifiers != null and modifiers.explosive
	ImpactEffect.spawn(get_tree().current_scene, global_position, dealt, _tint, modifiers, damage, _hit_hurtboxes, explode)
	queue_free()
